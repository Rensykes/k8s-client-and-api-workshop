param(
    [string]$Namespace = "train-orchestrator",
    [switch]$PauseAtEnd = $true,
    [switch]$GenerateSAKubeconfig = $false,
    [string]$ServiceAccount = "orchestrator-sa",
    [string]$SAKubeconfigOutput = "..\train-company-orchestrator\sa.kubeconfig",
    [int]$DurationHours = 24
)

# Resolve the k8s root directory relative to this script so file references work
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$K8sRoot = (Resolve-Path (Join-Path $ScriptDir "..")).Path

Write-Host "Creating namespace: $Namespace"
kubectl apply -f "${K8sRoot}\infrastructure\namespace.yaml"

Write-Host "Applying RBAC resources..."
kubectl apply -f "${K8sRoot}\infrastructure\rbac.yaml"

Write-Host "Applying Postgres resources..."
kubectl apply -f "${K8sRoot}\infrastructure\postgres.yaml"

Write-Host "Applying PersistentVolume and PersistentVolumeClaim for reports..."
kubectl apply -f "${K8sRoot}\infrastructure\pv-hostpath.yaml"

# OPTIONAL:
Write-Host "Applying Ticketing Report Job and CronJob..."
kubectl apply -f "${K8sRoot}\ticketing-report-job.yaml"

Write-Host "Done. Verify with:"
Write-Host "  kubectl get ns $Namespace"
Write-Host "  kubectl -n $Namespace get sa,role,rolebinding,deploy,svc,pods"
Write-Host "  kubectl get pv,pvc -n $Namespace"
Write-Host "  kubectl get jobs,cronjobs -n $Namespace"
Write-Host ""
Write-Host "Port-forward the orchestrator service:"
Write-Host "  kubectl -n $Namespace port-forward svc/train-orchestrator-svc 8080:8080"
Write-Host ""
Write-Host "Port-forward PostgreSQL (if needed):"
Write-Host "  kubectl -n $Namespace port-forward svc/postgres-svc 5432:5432"

if ($GenerateSAKubeconfig) {
    Write-Host "Generating ServiceAccount kubeconfig using generate-sa-kubeconfig.ps1..."
    $genScript = Join-Path $K8sRoot "..\train-company-orchestrator\generate-sa-kubeconfig.ps1"
    if (Test-Path $genScript) {
        & $genScript -Namespace $Namespace -ServiceAccount $ServiceAccount -Output $SAKubeconfigOutput -DurationHours $DurationHours
        Write-Host "Generated kubeconfig: $SAKubeconfigOutput"
    }
    else {
        Write-Host "generate-sa-kubeconfig.ps1 not found at $genScript"
    }
}
if ($PauseAtEnd) {
    Write-Host ""
    Write-Host "Press Enter to exit..."
    Read-Host | Out-Null
}