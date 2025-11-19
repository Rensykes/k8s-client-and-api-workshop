#!/usr/bin/env pwsh

# Test script for Ticketing Report Job API

$baseUrl = "http://localhost:8080"
$namespace = "train-orchestrator"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Ticketing Report Job API Test Script" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check if the orchestrator is running
Write-Host "[1/5] Checking if orchestrator is running..." -ForegroundColor Yellow
try {
    $health = Invoke-RestMethod -Uri "$baseUrl/actuator/health" -ErrorAction Stop
    Write-Host "✓ Orchestrator is healthy: $($health.status)" -ForegroundColor Green
} catch {
    Write-Host "✗ Orchestrator is not responding. Please start it first." -ForegroundColor Red
    Write-Host "  Run: .\mvnw spring-boot:run" -ForegroundColor Yellow
    exit 1
}
Write-Host ""

# Test 1: Current Month Report
Write-Host "[2/5] Creating report for current month..." -ForegroundColor Yellow
try {
    $response = Invoke-RestMethod -Method Post -Uri "$baseUrl/api/k8s/jobs/ticketing-report/current-month" -ErrorAction Stop
    Write-Host "✓ Job created successfully!" -ForegroundColor Green
    Write-Host "  Job Name: $($response.jobName)" -ForegroundColor White
    Write-Host "  Namespace: $($response.namespace)" -ForegroundColor White
    Write-Host "  Period: $($response.period)" -ForegroundColor White
    $currentMonthJob = $response.jobName
} catch {
    Write-Host "✗ Failed to create current month report" -ForegroundColor Red
    Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red
}
Write-Host ""

# Wait a bit before next request
Start-Sleep -Seconds 2

# Test 2: Previous Month Report
Write-Host "[3/5] Creating report for previous month..." -ForegroundColor Yellow
try {
    $response = Invoke-RestMethod -Method Post -Uri "$baseUrl/api/k8s/jobs/ticketing-report/previous-month" -ErrorAction Stop
    Write-Host "✓ Job created successfully!" -ForegroundColor Green
    Write-Host "  Job Name: $($response.jobName)" -ForegroundColor White
    Write-Host "  Namespace: $($response.namespace)" -ForegroundColor White
    Write-Host "  Period: $($response.period)" -ForegroundColor White
    $previousMonthJob = $response.jobName
} catch {
    Write-Host "✗ Failed to create previous month report" -ForegroundColor Red
    Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red
}
Write-Host ""

# Wait a bit before next request
Start-Sleep -Seconds 2

# Test 3: Custom Date Range
Write-Host "[4/5] Creating report for custom date range (2025-01-01 to 2025-01-31)..." -ForegroundColor Yellow
try {
    $response = Invoke-RestMethod -Method Post -Uri "$baseUrl/api/k8s/jobs/ticketing-report?startDate=2025-01-01&endDate=2025-01-31" -ErrorAction Stop
    Write-Host "✓ Job created successfully!" -ForegroundColor Green
    Write-Host "  Job Name: $($response.jobName)" -ForegroundColor White
    Write-Host "  Namespace: $($response.namespace)" -ForegroundColor White
    $customRangeJob = $response.jobName
} catch {
    Write-Host "✗ Failed to create custom range report" -ForegroundColor Red
    Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red
}
Write-Host ""

# Test 4: Invalid Date Format (should fail)
Write-Host "[5/5] Testing error handling with invalid date format..." -ForegroundColor Yellow
try {
    $response = Invoke-RestMethod -Method Post -Uri "$baseUrl/api/k8s/jobs/ticketing-report?startDate=invalid&endDate=2025-01-31" -ErrorAction Stop
    Write-Host "✗ Should have failed with invalid date format!" -ForegroundColor Red
} catch {
    if ($_.Exception.Response.StatusCode -eq 400) {
        Write-Host "✓ Correctly rejected invalid date format" -ForegroundColor Green
    } else {
        Write-Host "✗ Unexpected error: $($_.Exception.Message)" -ForegroundColor Red
    }
}
Write-Host ""

# Summary
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# Check if kubectl is available
try {
    kubectl version --client --output=json | Out-Null
    $kubectlAvailable = $true
} catch {
    $kubectlAvailable = $false
}

if ($kubectlAvailable) {
    Write-Host ""
    Write-Host "Jobs in namespace '$namespace':" -ForegroundColor Yellow
    kubectl get jobs -n $namespace -l app=ticketing-report
    Write-Host ""
    
    Write-Host "To view logs for a specific job, run:" -ForegroundColor Yellow
    if ($currentMonthJob) {
        Write-Host "  kubectl logs -n $namespace job/$currentMonthJob" -ForegroundColor White
    }
    if ($previousMonthJob) {
        Write-Host "  kubectl logs -n $namespace job/$previousMonthJob" -ForegroundColor White
    }
    if ($customRangeJob) {
        Write-Host "  kubectl logs -n $namespace job/$customRangeJob" -ForegroundColor White
    }
    Write-Host ""
    
    Write-Host "To delete a job, run:" -ForegroundColor Yellow
    Write-Host "  kubectl delete job <job-name> -n $namespace" -ForegroundColor White
} else {
    Write-Host ""
    Write-Host "kubectl is not available. Install it to manage jobs in Kubernetes." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Testing Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
