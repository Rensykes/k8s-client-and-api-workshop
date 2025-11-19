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

function Invoke-Provisioning {
    Write-Host "Creating namespace: $Namespace"
    kubectl apply -f "${K8sRoot}\infrastructure\namespace.yaml"

    Write-Host "Applying RBAC resources..."
    kubectl apply -f "${K8sRoot}\infrastructure\rbac.yaml"

    Write-Host "Applying Postgres resources..."
    kubectl apply -f "${K8sRoot}\infrastructure\postgres.yaml"

    Write-Host "Applying PersistentVolume and PersistentVolumeClaim for reports..."
    kubectl apply -f "${K8sRoot}\infrastructure\pv-hostpath.yaml"

    # OPTIONAL:
    # Write-Host "Applying Ticketing Report Job and CronJob..."
    # kubectl apply -f "${K8sRoot}\infrastructure\ticketing-report-job.yaml"

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
    Write-Host ""
    Write-Host "Provisioning complete."
}

function Build-DockerImage {
    param(
        [string]$ContextPath,
        [string]$ImageTag
    )

    if (-not (Test-Path $ContextPath)) {
        Write-Host "Context path not found: $ContextPath" -ForegroundColor Red
        return 1
    }

    Write-Host "Building Docker image '$ImageTag' from '$ContextPath'..." -ForegroundColor Cyan
    Push-Location $ContextPath
    docker build -t $ImageTag .
    $exit = $LASTEXITCODE
    Pop-Location

    if ($exit -ne 0) {
        Write-Host "Docker build failed for $ImageTag" -ForegroundColor Red
        return $exit
    }

    Write-Host "Docker image built: $ImageTag" -ForegroundColor Green
    return 0
}

function Show-Menu {
    Clear-Host
    Write-Host "Interactive setup - choose an option:`n"
    Write-Host "1) Provision k8s infrastructure"
    Write-Host "2) Build train-company-ticketing-report image"
    Write-Host "3) Build train-company-orchestrator image"
    Write-Host "4) Generate ServiceAccount kubeconfig (optional)"
    Write-Host "5) Exit"
    Write-Host ""
}

while ($true) {
    Show-Menu
    $choice = Read-Host "Enter choice (1-5)"
    switch ($choice) {
        '1' {
            Invoke-Provisioning
            Start-Sleep -Seconds 1
            Read-Host "Press Enter to return to menu..." | Out-Null
        }
        '2' {
            $ctx = Join-Path $K8sRoot "..\train-company-ticketing-report"
            if (-not (Test-Path $ctx)) { $ctx = Join-Path $ScriptDir "..\..\train-company-ticketing-report" }
            Build-DockerImage -ContextPath $ctx -ImageTag "train-company-ticketing-report:latest"
            Read-Host "Press Enter to return to menu..." | Out-Null
        }
        '3' {
            $ctx = Join-Path $K8sRoot "..\train-company-orchestrator"
            if (-not (Test-Path $ctx)) { $ctx = Join-Path $ScriptDir "..\..\train-company-orchestrator" }
            Build-DockerImage -ContextPath $ctx -ImageTag "train-company-orchestrator:latest"
            Read-Host "Press Enter to return to menu..." | Out-Null
        }
        '4' {
            if (Test-Path (Join-Path $K8sRoot "..\train-company-orchestrator\generate-sa-kubeconfig.ps1")) {
                & (Join-Path $K8sRoot "..\train-company-orchestrator\generate-sa-kubeconfig.ps1") -Namespace $Namespace -ServiceAccount $ServiceAccount -Output $SAKubeconfigOutput -DurationHours $DurationHours
            }
            else { Write-Host "generate-sa-kubeconfig.ps1 not found." -ForegroundColor Yellow }
            Read-Host "Press Enter to return to menu..." | Out-Null
        }
        '5' {
            break
        }
        default {
            Write-Host "Invalid choice: $choice" -ForegroundColor Yellow
            Start-Sleep -Seconds 1
        }
    }
}

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