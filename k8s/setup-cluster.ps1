param(
    [string]$Namespace = "train-orchestrator"
)

Write-Host "Creating namespace: $Namespace"
kubectl apply -f namespace.yaml

Write-Host "Applying RBAC resources..."
kubectl apply -f rbac.yaml

Write-Host "Applying Postgres resources..."
kubectl apply -f postgres.yaml

Write-Host "Applying Postgres resources..."
kubectl apply -f postgres.yaml

Write-Host "Done. Verify with: kubectl get ns,$Namespace and kubectl -n $Namespace get sa,role,rolebinding,deploy,svc,pods"

Write-Host "Done. You can port-forward the service locally:"
Write-Host "kubectl -n $Namespace port-forward svc/train-orchestrator-svc 8080:8080"