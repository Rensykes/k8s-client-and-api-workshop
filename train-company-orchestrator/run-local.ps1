param(
    [switch]$UseServiceAccount,
    [string]$KubeconfigPath = "",
    [int]$Port = 8080
)

Set-StrictMode -Version Latest

Push-Location (Split-Path -Path $MyInvocation.MyCommand.Path -Parent)
Pop-Location

Write-Host "Building application..."
mvn -DskipTests package

if ($UseServiceAccount) {
    Write-Host "Generating service-account kubeconfig..."
    $script = Join-Path (Split-Path -Path $MyInvocation.MyCommand.Path -Parent) 'generate-sa-kubeconfig.ps1'
    & $script -Namespace 'train-orchestrator' -ServiceAccount 'orchestrator-sa' -Output 'sa.kubeconfig'
    $env:KUBECONFIG = (Join-Path (Get-Location) 'sa.kubeconfig')
} elseif ($KubeconfigPath -ne '') {
    Write-Host "Using kubeconfig: $KubeconfigPath"
    $env:KUBECONFIG = $KubeconfigPath
}

Write-Host "Running application (port $Port)..."
java -jar target\train-company-orchestrator-0.0.1-SNAPSHOT.jar
