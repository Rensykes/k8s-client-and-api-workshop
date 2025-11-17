param(
    [string]$Namespace = "train-orchestrator",
    [string]$ServiceAccount = "orchestrator-sa",
    [string]$Output = "sa.kubeconfig",
    [int]$DurationHours = 24
)

Set-StrictMode -Version Latest

Write-Host "Creating token for ServiceAccount $ServiceAccount in namespace $Namespace..."
$tokenFile = New-TemporaryFile
$nsExists = kubectl get namespace $Namespace --ignore-not-found
if (-not $nsExists) {
    Write-Host "Namespace $Namespace not found. Creating..."
    kubectl create namespace $Namespace
}

# Create token
# Ensure ServiceAccount exists
$saExists = kubectl -n $Namespace get sa $ServiceAccount --ignore-not-found
if (-not $saExists) {
    Write-Host "ServiceAccount $ServiceAccount not found. Creating..."
    kubectl -n $Namespace create sa $ServiceAccount
}

# Create token
kubectl -n $Namespace create token $ServiceAccount --duration=${DurationHours}h | Out-File -FilePath $tokenFile -Encoding ascii
$token = Get-Content $tokenFile -Raw

Write-Host "Fetching cluster server and CA..."
$server = kubectl config view -o jsonpath='{.clusters[0].cluster.server}'
$clusterName = kubectl config view -o jsonpath='{.clusters[0].name}'

Write-Host "Fetching cluster server and CA from current kubeconfig..."
$server = kubectl config view -o jsonpath='{.clusters[0].cluster.server}'
$clusterName = kubectl config view -o jsonpath='{.clusters[0].name}'
$caBase64 = kubectl config view -o jsonpath='{.clusters[0].cluster.certificate-authority-data}'
if ([string]::IsNullOrEmpty($caBase64)) {
    throw "No certificate-authority-data found in current kubeconfig"
}
$caBytes = [System.Convert]::FromBase64String($caBase64)
[System.IO.File]::WriteAllBytes('ca.crt', $caBytes)

kubectl config --kubeconfig=$Output set-cluster $clusterName --server=$server --certificate-authority=ca.crt
kubectl config --kubeconfig=$Output set-credentials $ServiceAccount --token="$token"
kubectl config --kubeconfig=$Output set-context orchestrator --cluster=$clusterName --user=$ServiceAccount
kubectl config --kubeconfig=$Output use-context orchestrator

Write-Host "Wrote $Output"
