# Train Company Orchestrator — Kubernetes Setup Scripts

This folder contains scripts to provision, build, deploy, and clean up the Kubernetes resources for the `train-company-orchestrator` application.

Files:
- `script/setup.ps1` — Interactive PowerShell menu to provision infrastructure, build Docker images, deploy applications, generate ServiceAccount kubeconfigs, and cleanup resources.
- `infrastructure/` — Kubernetes manifests for namespace, RBAC, PostgreSQL, PersistentVolumes, and deployments.

Quick Usage

**Interactive Setup (Recommended)**

Run the interactive menu script:

```powershell
cd k8s/script
.\setup.ps1
```

Menu options:
1. Provision k8s infrastructure (namespace, RBAC, PostgreSQL, PV/PVC)
2. Build train-company-ticketing-report image
3. Build and deploy train-company-orchestrator image
4. Generate ServiceAccount kubeconfig
5. Cleanup provisioned resources
6. Exit

**Manual Steps**

1. Build the JAR and Docker image:

```powershell
cd train-company-orchestrator
mvn -DskipTests package
docker build -t train-company-orchestrator:latest .
```

If using `minikube`:

```powershell
minikube image load train-company-orchestrator:latest
```

2. Create cluster resources:

```powershell
cd ../k8s
kubectl apply -f infrastructure/namespace.yaml
kubectl apply -f infrastructure/rbac.yaml
kubectl apply -f infrastructure/postgres.yaml
kubectl apply -f infrastructure/pv-hostpath.yaml
```

3. Deploy the application:

```powershell
kubectl apply -f infrastructure/train-company-orchestrator.yaml
```

4. Port-forward and test:

```powershell
kubectl -n train-orchestrator port-forward svc/train-orchestrator-svc 8080:8080
curl http://localhost:8080/api/k8s/pods/raw
```

PostgreSQL Port-Forward
-----------------------------------------------------------

Forward the PostgreSQL service to access it locally:

```powershell
kubectl -n train-orchestrator port-forward svc/postgres-svc 5432:5432
psql "host=localhost port=5432 user=postgres dbname=traindb password=mysecretpassword"
```

Testing Endpoints
-----------------

Trigger a sleep Job:

```powershell
curl -X POST "http://localhost:8080/api/k8s/jobs/sleep?seconds=60"
```

Cleanup
-------

Use the interactive script (option 5) or manually delete resources:

```powershell
cd k8s
kubectl delete -f infrastructure/train-company-orchestrator.yaml
kubectl delete -f infrastructure/postgres.yaml
kubectl delete -f infrastructure/pv-hostpath.yaml
kubectl delete -f infrastructure/rbac.yaml
kubectl delete -f infrastructure/namespace.yaml
```

Run Locally (Outside Kubernetes)
---------------------------------------------

Run the Spring Boot app locally and have it talk to the Kubernetes cluster using your kubeconfig.

**Option 1: Use default kubeconfig**

```powershell
cd train-company-orchestrator
mvn -DskipTests package
java -jar target\train-company-orchestrator-0.0.1-SNAPSHOT.jar
```

**Option 2: Use ServiceAccount kubeconfig (least-privileged)**

Generate the ServiceAccount kubeconfig using the setup script (menu option 4), then:

```powershell
$env:KUBECONFIG = "path\to\sa.kubeconfig"
cd train-company-orchestrator
java -jar target\train-company-orchestrator-0.0.1-SNAPSHOT.jar
```

Test endpoints:

```powershell
curl http://localhost:8080/api/k8s/pods/raw
curl -X POST "http://localhost:8080/api/k8s/jobs/sleep?seconds=60"
```

When To Use A ServiceAccount Kubeconfig
--------------------------------------

- **Optional for local development:** your default kubeconfig already allows the app to authenticate with the cluster; a ServiceAccount kubeconfig is not required unless you want to restrict permissions.
- **Use it to test least-privilege behavior:** if you want to verify the application works with the same RBAC rules you apply to pods in-cluster, run the app with a ServiceAccount kubeconfig.
- **Good for demos and CI:** use a short-lived ServiceAccount token for reproducible demos or automated pipelines without relying on a personal admin kubeconfig.

Security notes:

- Treat generated kubeconfigs as secrets (they contain bearer tokens). Remove them when finished.
- Use short durations on tokens and restrict the ServiceAccount RBAC to the minimum required.

Troubleshooting
- Ensure `kubectl` is configured correctly: `kubectl config current-context`
- Check pod status: `kubectl -n train-orchestrator get pods`
- View logs: `kubectl -n train-orchestrator logs -l app=train-orchestrator --tail=50`
- If using minikube, ensure images are loaded: `minikube image ls`

