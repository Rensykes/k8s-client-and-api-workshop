param(
    [string]$Namespace = "train-orchestrator"
)

Write-Host "Deleting deployment/service in namespace $Namespace..."
kubectl delete -f deployment.yaml --ignore-not-found

Write-Host "Deleting RBAC resources..."
kubectl delete -f rbac.yaml --ignore-not-found

Write-Host "Deleting namespace $Namespace..."
kubectl delete -f namespace.yaml --ignore-not-found

Write-Host "Cleanup complete."
