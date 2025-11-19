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

function Invoke-Cleanup {
    Write-Host "Deleting Ticketing Report Job and CronJob..." -ForegroundColor Yellow
    kubectl delete -f "${K8sRoot}\infrastructure\ticketing-report-job.yaml" --ignore-not-found
    
    Write-Host "Deleting Jobs created by the Spring Boot app (ticketing-report and sleep jobs)..." -ForegroundColor Yellow
    kubectl delete jobs -n $Namespace -l app=ticketing-report --ignore-not-found
    kubectl get jobs -n $Namespace --no-headers | Where-Object { $_ -match '^sleep-job-' } | ForEach-Object { 
        $name = ($_ -split '\s+')[0]
        kubectl delete job $name -n $Namespace --ignore-not-found 
    }

    Write-Host "Deleting PersistentVolumeClaim and PersistentVolume..." -ForegroundColor Yellow
    kubectl delete -f "${K8sRoot}\infrastructure\pv-hostpath.yaml" --ignore-not-found

    Write-Host "Deleting Postgres resources..." -ForegroundColor Yellow
    kubectl delete -f "${K8sRoot}\infrastructure\postgres.yaml" --ignore-not-found

    Write-Host "Deleting deployment/service in namespace $Namespace..." -ForegroundColor Yellow
    kubectl delete -f "${K8sRoot}\infrastructure\train-company-orchestrator.yaml" --ignore-not-found

    Write-Host "Deleting RBAC resources..." -ForegroundColor Yellow
    kubectl delete -f "${K8sRoot}\infrastructure\rbac.yaml" --ignore-not-found

    Write-Host "Deleting namespace $Namespace..." -ForegroundColor Yellow
    kubectl delete -f "${K8sRoot}\infrastructure\namespace.yaml" --ignore-not-found

    Write-Host "Cleanup complete." -ForegroundColor Green
    Write-Host "Note: Report files in your local filesystem (C:\Users\<username>\kubernetes-reports) are preserved."
    
    # Optionally remove generated SA kubeconfig
    $saKubeconfigPath = Join-Path $K8sRoot "..\train-company-orchestrator\sa.kubeconfig"
    if (Test-Path $saKubeconfigPath) {
        try {
            Remove-Item $saKubeconfigPath -Force
            Write-Host "Removed generated SA kubeconfig: $saKubeconfigPath" -ForegroundColor Green
        }
        catch {
            Write-Host "Failed to remove $($saKubeconfigPath): $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

# When to use a ServiceAccount kubeconfig (optional):
# - Not required for local development: your default kubeconfig (KUBECONFIG or ~/.kube/config)
#   already provides credentials and network access to the API server. The app will use
#   those credentials when run locally.
# - Use a ServiceAccount kubeconfig to test least-privilege behavior, reproduce the
#   in-cluster ServiceAccount permissions, or run demos/CI with non-personal credentials.
# - Generated kubeconfigs contain bearer tokens: treat them as secrets and use short
#   durations. The setup script includes a helper (menu option 4) to create a token-based
#   kubeconfig for the `orchestrator-sa` ServiceAccount.
#
# Example (one-time):
#   $env:KUBECONFIG = 'path\\to\\sa.kubeconfig'
#   java -jar ../train-company-orchestrator/target/train-company-orchestrator-0.0.1-SNAPSHOT.jar
function New-ServiceAccountKubeconfig {
    param(
        [string]$Namespace = "train-orchestrator",
        [string]$ServiceAccount = "orchestrator-sa",
        [string]$OutputPath = "..\train-company-orchestrator\sa.kubeconfig",
        [int]$DurationHours = 24,
        [switch]$ExportToSession = $false
    )

    Write-Host "=== Generating ServiceAccount Kubeconfig ===" -ForegroundColor Cyan
    Write-Host "Namespace: $Namespace" -ForegroundColor Gray
    Write-Host "ServiceAccount: $ServiceAccount" -ForegroundColor Gray
    Write-Host "Token Duration: ${DurationHours}h" -ForegroundColor Gray
    Write-Host ""

    # Ensure namespace exists
    $nsExists = kubectl get namespace $Namespace --ignore-not-found 2>$null
    if (-not $nsExists) {
        Write-Host "Namespace '$Namespace' not found. Creating..." -ForegroundColor Yellow
        kubectl create namespace $Namespace
    }

    # Ensure ServiceAccount exists
    $saExists = kubectl -n $Namespace get sa $ServiceAccount --ignore-not-found 2>$null
    if (-not $saExists) {
        Write-Host "ServiceAccount '$ServiceAccount' not found. Creating..." -ForegroundColor Yellow
        kubectl -n $Namespace create sa $ServiceAccount
    }

    # Create token
    Write-Host "Creating token for ServiceAccount..." -ForegroundColor Cyan
    $tokenFile = New-TemporaryFile
    try {
        kubectl -n $Namespace create token $ServiceAccount --duration=${DurationHours}h | Out-File -FilePath $tokenFile -Encoding ascii
        $token = (Get-Content $tokenFile -Raw).Trim()
        
        if ([string]::IsNullOrWhiteSpace($token)) {
            throw "Failed to create token - empty token received"
        }

        # Get cluster information
        Write-Host "Fetching cluster server and CA..." -ForegroundColor Cyan
        $server = kubectl config view -o jsonpath='{.clusters[0].cluster.server}'
        $clusterName = kubectl config view -o jsonpath='{.clusters[0].name}'
        $caBase64 = kubectl config view -o jsonpath='{.clusters[0].cluster.certificate-authority-data}'
        
        if ([string]::IsNullOrEmpty($caBase64)) {
            throw "No certificate-authority-data found in current kubeconfig"
        }

        # Write CA certificate
        $caBytes = [System.Convert]::FromBase64String($caBase64)
        $caCrtPath = Join-Path $ScriptDir "ca.crt"
        [System.IO.File]::WriteAllBytes($caCrtPath, $caBytes)

        # Resolve output path
        $fullOutputPath = Join-Path $K8sRoot $OutputPath
        $outputDir = Split-Path -Parent $fullOutputPath
        if (-not (Test-Path $outputDir)) {
            New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
        }

        # Build kubeconfig
        Write-Host "Building kubeconfig file..." -ForegroundColor Cyan
        kubectl config --kubeconfig=$fullOutputPath set-cluster $clusterName --server=$server --certificate-authority=$caCrtPath --embed-certs=true | Out-Null
        kubectl config --kubeconfig=$fullOutputPath set-credentials $ServiceAccount --token="$token" | Out-Null
        kubectl config --kubeconfig=$fullOutputPath set-context orchestrator --cluster=$clusterName --user=$ServiceAccount --namespace=$Namespace | Out-Null
        kubectl config --kubeconfig=$fullOutputPath use-context orchestrator | Out-Null

        # Cleanup temp files
        Remove-Item $tokenFile -Force -ErrorAction SilentlyContinue
        Remove-Item $caCrtPath -Force -ErrorAction SilentlyContinue

        Write-Host ""
        Write-Host "=== Kubeconfig Generated Successfully ===" -ForegroundColor Green
        Write-Host "Location: $fullOutputPath" -ForegroundColor Green
        Write-Host ""
        Write-Host "=== How to Use This Kubeconfig ===" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Option 1: Use with kubectl commands (one-time):" -ForegroundColor Yellow
        Write-Host "  kubectl --kubeconfig=`"$fullOutputPath`" get pods -n $Namespace" -ForegroundColor White
        Write-Host ""
        Write-Host "Option 2: Set as environment variable (current session):" -ForegroundColor Yellow
        Write-Host "  `$env:KUBECONFIG = `"$fullOutputPath`"" -ForegroundColor White
        Write-Host "  kubectl get pods -n $Namespace" -ForegroundColor White
        Write-Host ""
        Write-Host "Option 3: Set KUBECONFIG before running mvn spring-boot:run:" -ForegroundColor Yellow
        Write-Host "  `$env:KUBECONFIG = `"$fullOutputPath`"" -ForegroundColor White
        Write-Host "  cd ..\train-company-orchestrator" -ForegroundColor White
        Write-Host "  mvn spring-boot:run" -ForegroundColor White
        Write-Host ""
        Write-Host "Note: This token expires in ${DurationHours} hours" -ForegroundColor Magenta
        Write-Host "Note: The ServiceAccount has limited RBAC permissions (only what's defined in rbac.yaml)" -ForegroundColor Magenta
        Write-Host ""

        # Offer to export the generated kubeconfig into the current PowerShell session
        $doExport = $false
        if ($ExportToSession) {
            $doExport = $true
        }
        else {
            try {
                $answer = Read-Host "Export kubeconfig to current session as `$env:KUBECONFIG ? (Y/n)"
                if ([string]::IsNullOrWhiteSpace($answer) -or $answer -match '^(y|Y)') { $doExport = $true }
            }
            catch {
                # Non-interactive session: skip export
                $doExport = $false
            }
        }

        if ($doExport) {
            $env:KUBECONFIG = $fullOutputPath
            Write-Host "Exported environment variable: `\$env:KUBECONFIG = $fullOutputPath" -ForegroundColor Green
            Write-Host "(This only affects the current PowerShell session)" -ForegroundColor Gray
        }
    }
    catch {
        Write-Host "Error generating kubeconfig: $($_.Exception.Message)" -ForegroundColor Red
        # Cleanup on error
        Remove-Item $tokenFile -Force -ErrorAction SilentlyContinue
        Remove-Item $caCrtPath -Force -ErrorAction SilentlyContinue
        throw
    }
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
    Write-Host "2) Generate ServiceAccount kubeconfig (optional)"
    Write-Host "3) Build train-company-ticketing-report image"
    Write-Host "4) Build train-company-orchestrator image"
    Write-Host "5) Cleanup provisioned resources"
    Write-Host "6) Exit"
    Write-Host ""
}

while ($true) {
    Show-Menu
    $choice = Read-Host "Enter choice (1-6)"
    switch ($choice) {
        '1' {
            Invoke-Provisioning
            Start-Sleep -Seconds 1
            Read-Host "Press Enter to return to menu..." | Out-Null
        }
        '2' {
            New-ServiceAccountKubeconfig -Namespace $Namespace -ServiceAccount $ServiceAccount -OutputPath $SAKubeconfigOutput -DurationHours $DurationHours
            Read-Host "Press Enter to return to menu..." | Out-Null
        }
        '3' {
            $ctx = Join-Path $K8sRoot "..\train-company-ticketing-report"
            if (-not (Test-Path $ctx)) { $ctx = Join-Path $ScriptDir "..\..\train-company-ticketing-report" }
            Build-DockerImage -ContextPath $ctx -ImageTag "train-company-ticketing-report:latest"
            Read-Host "Press Enter to return to menu..." | Out-Null
        }
        '4' {
            $ctx = Join-Path $K8sRoot "..\train-company-orchestrator"
            if (-not (Test-Path $ctx)) { $ctx = Join-Path $ScriptDir "..\..\train-company-orchestrator" }
            Build-DockerImage -ContextPath $ctx -ImageTag "train-company-orchestrator:latest"
            if ($LASTEXITCODE -eq 0) {
                Write-Host "Deploying train-company-orchestrator to Kubernetes..." -ForegroundColor Cyan
                kubectl apply -f "${K8sRoot}\infrastructure\train-company-orchestrator.yaml"
                Write-Host "Deployment applied. Verify with:" -ForegroundColor Green
                Write-Host "  kubectl -n $Namespace get deploy,svc,pods"
                Write-Host "  kubectl -n $Namespace logs -l app=train-orchestrator --tail=50"
            }
            else {
                Write-Host "Skipping deployment due to build failure." -ForegroundColor Red
            }
            Read-Host "Press Enter to return to menu..." | Out-Null
        }
        '5' {
            Invoke-Cleanup
            Read-Host "Press Enter to return to menu..." | Out-Null
        }
        '6' {
            Exit 0
        }
        default {
            Write-Host "Invalid choice: $choice" -ForegroundColor Yellow
            Start-Sleep -Seconds 1
        }
    }
}

if ($GenerateSAKubeconfig) {
    Write-Host "Generating ServiceAccount kubeconfig..."
    New-ServiceAccountKubeconfig -Namespace $Namespace -ServiceAccount $ServiceAccount -OutputPath $SAKubeconfigOutput -DurationHours $DurationHours
}
if ($PauseAtEnd) {
    Write-Host ""
    Write-Host "Press Enter to exit..."
    Read-Host | Out-Null
}