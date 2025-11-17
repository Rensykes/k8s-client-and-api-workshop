# Train Company Orchestrator — Local cluster scripts

This folder contains setup and cleanup scripts to create the required Kubernetes namespace and RBAC resources, and to deploy the `train-company-orchestrator` application locally (e.g. on minikube / Docker Desktop).

Files:
- `k8s/setup-cluster.ps1` — PowerShell helper to apply namespace and RBAC.
- `k8s/cleanup-cluster.ps1` — PowerShell helper to delete resources.
- `k8s/setup-cluster.sh` — Bash helper to apply namespace and RBAC.
- `k8s/cleanup-cluster.sh` — Bash helper to delete resources.

Quick Usage

1. Build the JAR and image (PowerShell):

```powershell
cd train-company-orchestrator
mvn -DskipTests package
docker build -t train-company-orchestrator:latest . -f Dockerfile
```

If you use `minikube` and want to load the image into the cluster:

```powershell
minikube image load train-company-orchestrator:latest
```

2. Create the cluster resources (PowerShell):

```powershell
cd ../k8s
.\setup-cluster.ps1
```

Or using Bash:

```bash
cd ../k8s
./setup-cluster.sh
```

3. Deploy the app:

```powershell
kubectl apply -f deployment.yaml
```

4. Port-forward and test the pod-listing endpoint:

```powershell
kubectl -n train-orchestrator port-forward svc/train-orchestrator-svc 8080:8080
curl.exe http://localhost:8080/api/k8s/pods/raw
```

5. Trigger a sleep Job (HTTP POST):

```powershell
curl.exe -X POST "http://localhost:8080/api/k8s/jobs/sleep?seconds=60"
```

6. Cleanup resources (PowerShell):

```powershell
cd ../k8s
.\cleanup-cluster.ps1
```

Or using Bash:

```bash
./cleanup-cluster.sh
```

Troubleshooting
- Ensure `kubectl` is configured to talk to the correct cluster.
- If using Docker Desktop with minikube, ensure `minikube` is installed and running or use `docker build` + `minikube image load` per above.

Run Locally (without deploying to the cluster)
---------------------------------------------

You can run the Spring Boot app locally and have it talk to the Kubernetes cluster using your kubeconfig (recommended for development). The app will behave like `kubectl` and use the same credentials/contexts.

PowerShell example:

```powershell
# Ensure kubectl points to the right cluster
kubectl config current-context

# Optional: point the app to a specific kubeconfig file
$env:KUBECONFIG = 'C:\Users\you\.kube\config'

# Build and run
cd ..\train-company-orchestrator
mvn -DskipTests package
java -jar target\train-company-orchestrator-0.0.1-SNAPSHOT.jar

# In another shell test the endpoints
curl.exe http://localhost:8080/api/k8s/pods/raw
curl.exe -X POST "http://localhost:8080/api/k8s/jobs/sleep?seconds=60"
```

Bash example:

```bash
# Ensure kubectl points to the right cluster
kubectl config current-context

# Optional: use a specific kubeconfig
export KUBECONFIG="$HOME/.kube/config"

cd ../train-company-orchestrator
mvn -DskipTests package
java -jar target/train-company-orchestrator-0.0.1-SNAPSHOT.jar

# Test endpoints
curl http://localhost:8080/api/k8s/pods/raw
curl -X POST "http://localhost:8080/api/k8s/jobs/sleep?seconds=60"
```

Run with a ServiceAccount token (least-privileged)
------------------------------------------------
If you prefer the app to use the same ServiceAccount as the in-cluster deployment (recommended for demos that require least privilege), create a kubeconfig that uses the service account token and run the jar with `KUBECONFIG` pointing to it.

```bash
# Create a token (kubectl >= 1.24)
kubectl -n train-orchestrator create token orchestrator-sa --duration=24h > sa.token
TOKEN=$(cat sa.token)
SERVER=$(kubectl config view -o jsonpath='{.clusters[0].cluster.server}')
CLUSTER_NAME=$(kubectl config view -o jsonpath='{.clusters[0].name}')

# Save CA if needed
kubectl get secret -n train-orchestrator $(kubectl -n train-orchestrator get sa orchestrator-sa -o jsonpath='{.secrets[0].name}') -o go-template='{{ .data."ca.crt" }}' | base64 --decode > ca.crt

# Build minimal kubeconfig
kubectl config --kubeconfig=sa.kubeconfig set-cluster $CLUSTER_NAME --server=$SERVER --certificate-authority=ca.crt
kubectl config --kubeconfig=sa.kubeconfig set-credentials orchestrator-sa --token="$TOKEN"
kubectl config --kubeconfig=sa.kubeconfig set-context orchestrator --cluster=$CLUSTER_NAME --user=orchestrator-sa
kubectl config --kubeconfig=sa.kubeconfig use-context orchestrator

# Run the app with the SA kubeconfig
export KUBECONFIG=$(pwd)/sa.kubeconfig
java -jar target/train-company-orchestrator-0.0.1-SNAPSHOT.jar
```

Use kubectl proxy as an alternative
-----------------------------------
If you don't want to provide cluster credentials to the app, you can run `kubectl proxy` locally and point the client's base URL to `http://127.0.0.1:8001`. This requires modifying the code to use a custom base path or setting the API client's base path before creating `CoreV1Api`.

