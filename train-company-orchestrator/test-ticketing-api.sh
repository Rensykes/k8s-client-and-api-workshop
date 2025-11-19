#!/bin/bash

# Test script for Ticketing Report Job API

BASE_URL="http://localhost:8080"
NAMESPACE="train-orchestrator"

echo "========================================"
echo "Ticketing Report Job API Test Script"
echo "========================================"
echo ""

# Check if the orchestrator is running
echo "[1/5] Checking if orchestrator is running..."
if curl -s -f "$BASE_URL/actuator/health" > /dev/null; then
    echo "✓ Orchestrator is healthy"
else
    echo "✗ Orchestrator is not responding. Please start it first."
    echo "  Run: ./mvnw spring-boot:run"
    exit 1
fi
echo ""

# Test 1: Current Month Report
echo "[2/5] Creating report for current month..."
response=$(curl -s -X POST "$BASE_URL/api/k8s/jobs/ticketing-report/current-month")
if [ $? -eq 0 ]; then
    echo "✓ Job created successfully!"
    echo "$response" | jq '.'
    currentMonthJob=$(echo "$response" | jq -r '.jobName')
else
    echo "✗ Failed to create current month report"
fi
echo ""

sleep 2

# Test 2: Previous Month Report
echo "[3/5] Creating report for previous month..."
response=$(curl -s -X POST "$BASE_URL/api/k8s/jobs/ticketing-report/previous-month")
if [ $? -eq 0 ]; then
    echo "✓ Job created successfully!"
    echo "$response" | jq '.'
    previousMonthJob=$(echo "$response" | jq -r '.jobName')
else
    echo "✗ Failed to create previous month report"
fi
echo ""

sleep 2

# Test 3: Custom Date Range
echo "[4/5] Creating report for custom date range (2025-01-01 to 2025-01-31)..."
response=$(curl -s -X POST "$BASE_URL/api/k8s/jobs/ticketing-report?startDate=2025-01-01&endDate=2025-01-31")
if [ $? -eq 0 ]; then
    echo "✓ Job created successfully!"
    echo "$response" | jq '.'
    customRangeJob=$(echo "$response" | jq -r '.jobName')
else
    echo "✗ Failed to create custom range report"
fi
echo ""

# Test 4: Invalid Date Format (should fail)
echo "[5/5] Testing error handling with invalid date format..."
response=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/k8s/jobs/ticketing-report?startDate=invalid&endDate=2025-01-31")
http_code=$(echo "$response" | tail -n1)
if [ "$http_code" -eq 400 ]; then
    echo "✓ Correctly rejected invalid date format"
else
    echo "✗ Unexpected response code: $http_code"
fi
echo ""

# Summary
echo "========================================"
echo "Summary"
echo "========================================"

# Check if kubectl is available
if command -v kubectl &> /dev/null; then
    echo ""
    echo "Jobs in namespace '$NAMESPACE':"
    kubectl get jobs -n $NAMESPACE -l app=ticketing-report
    echo ""
    
    echo "To view logs for a specific job, run:"
    [ -n "$currentMonthJob" ] && echo "  kubectl logs -n $NAMESPACE job/$currentMonthJob"
    [ -n "$previousMonthJob" ] && echo "  kubectl logs -n $NAMESPACE job/$previousMonthJob"
    [ -n "$customRangeJob" ] && echo "  kubectl logs -n $NAMESPACE job/$customRangeJob"
    echo ""
    
    echo "To delete a job, run:"
    echo "  kubectl delete job <job-name> -n $NAMESPACE"
else
    echo ""
    echo "kubectl is not available. Install it to manage jobs in Kubernetes."
fi

echo ""
echo "========================================"
echo "Testing Complete!"
echo "========================================"
