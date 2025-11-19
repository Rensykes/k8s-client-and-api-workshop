param(
    [string]$Namespace = "train-orchestrator",
    [switch]$PauseAtEnd = $true
)

# Resolve the k8s root directory relative to this script so file references work
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$K8sRoot = (Resolve-Path (Join-Path $ScriptDir "..")).Path

Write-Host "Deleting Ticketing Report Job and CronJob..."
kubectl delete -f "${K8sRoot}\ticketing-report-job.yaml" --ignore-not-found
Write-Host "Deleting Jobs created by the Spring Boot app (ticketing-report and sleep jobs)..."
# delete jobs with label app=ticketing-report and any sleep-job-* jobs
kubectl delete jobs -n $Namespace -l app=ticketing-report --ignore-not-found || Write-Host "No ticketing-report jobs found"
kubectl get jobs -n $Namespace --no-headers | Where-Object { $_ -match '^sleep-job-' } | ForEach-Object { $name = ($_ -split '\s+')[0]; kubectl delete job $name -n $Namespace --ignore-not-found }

Write-Host "Deleting PersistentVolumeClaim and PersistentVolume..."
kubectl delete -f "${K8sRoot}\infrastructure\pv-hostpath.yaml" --ignore-not-found

Write-Host "Deleting Postgres resources..."
kubectl delete -f "${K8sRoot}\infrastructure\postgres.yaml" --ignore-not-found

Write-Host "Deleting deployment/service in namespace $Namespace..."
kubectl delete -f "${K8sRoot}\infrastructure\deployment.yaml" --ignore-not-found

Write-Host "Deleting RBAC resources..."
kubectl delete -f "${K8sRoot}\infrastructure\rbac.yaml" --ignore-not-found

Write-Host "Deleting namespace $Namespace..."
kubectl delete -f "${K8sRoot}\infrastructure\namespace.yaml" --ignore-not-found

Write-Host "Cleanup complete."
Write-Host "Note: Report files in your local filesystem (C:\Users\<username>\kubernetes-reports) are preserved."
if ($PauseAtEnd) {
    Write-Host ""
    Write-Host "Press Enter to exit..."
    Read-Host | Out-Null
}
# Optionally remove generated SA kubeconfig
$saKubeconfigPath = Join-Path $K8sRoot "..\train-company-orchestrator\sa.kubeconfig"
if (Test-Path $saKubeconfigPath) {
    try {
        Remove-Item $saKubeconfigPath -Force
        Write-Host "Removed generated SA kubeconfig: $saKubeconfigPath"
    }
    catch {
        $err = $_.Exception.Message
        Write-Host "Failed to remove $($saKubeconfigPath): $err"
    }
}
