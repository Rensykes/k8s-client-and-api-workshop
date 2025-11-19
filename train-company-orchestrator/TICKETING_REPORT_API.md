# Ticketing Report Job API

## Overview

The Train Company Orchestrator now provides REST API endpoints to programmatically create Kubernetes Jobs that generate ticketing reports. These endpoints leverage the Kubernetes Java Client to create jobs in the `train-orchestrator` namespace.

## Prerequisites

- Train Company Orchestrator running in Kubernetes with appropriate RBAC permissions
- `train-company-ticketing-report` Docker image available in the cluster
- PostgreSQL database accessible from the cluster
- `postgres-secret` Kubernetes secret (optional, for database credentials)

## API Endpoints

### 1. Create Report for Current Month

**Endpoint:** `POST /api/k8s/jobs/ticketing-report/current-month`

Creates a ticketing report job for the current month (from the 1st day to today).

**Example Request:**
```bash
curl -X POST http://localhost:8080/api/k8s/jobs/ticketing-report/current-month
```

**Example Response:**
```json
{
  "status": "created",
  "jobName": "ticketing-report-12345",
  "namespace": "train-orchestrator",
  "creationTimestamp": "2025-11-19T10:30:00Z",
  "period": "current-month"
}
```

### 2. Create Report for Previous Month

**Endpoint:** `POST /api/k8s/jobs/ticketing-report/previous-month`

Creates a ticketing report job for the entire previous month.

**Example Request:**
```bash
curl -X POST http://localhost:8080/api/k8s/jobs/ticketing-report/previous-month
```

**Example Response:**
```json
{
  "status": "created",
  "jobName": "ticketing-report-67890",
  "namespace": "train-orchestrator",
  "creationTimestamp": "2025-11-19T10:30:00Z",
  "period": "previous-month"
}
```

### 3. Create Report with Custom Date Range

**Endpoint:** `POST /api/k8s/jobs/ticketing-report`

Creates a ticketing report job with a custom date range. If no dates are provided, defaults to current month.

**Query Parameters:**
- `startDate` (optional): Start date in ISO format (YYYY-MM-DD)
- `endDate` (optional): End date in ISO format (YYYY-MM-DD)

**Example Request:**
```bash
curl -X POST "http://localhost:8080/api/k8s/jobs/ticketing-report?startDate=2025-01-01&endDate=2025-01-31"
```

**Example Response:**
```json
{
  "status": "created",
  "jobName": "ticketing-report-54321",
  "namespace": "train-orchestrator",
  "creationTimestamp": "2025-11-19T10:30:00Z"
}
```

**Error Response (Invalid Date Format):**
```json
{
  "error": "Invalid date format. Use YYYY-MM-DD format."
}
```

## Job Configuration

Each created job includes:

- **Image:** `train-company-ticketing-report:latest` (configurable in `TicketingReportJobService`)
- **Namespace:** `train-orchestrator`
- **Restart Policy:** `OnFailure`
- **Backoff Limit:** 3 retries
- **TTL After Finished:** 86400 seconds (24 hours)
- **Resource Requests:** 256Mi memory, 100m CPU
- **Resource Limits:** 512Mi memory, 500m CPU

### Environment Variables

Jobs are configured with the following environment variables:

- `DB_HOST`: `postgres` (PostgreSQL service name)
- `DB_PORT`: `5432`
- `DB_NAME`: `traindb`
- `DB_USER`: From `postgres-secret.username` (if available)
- `DB_PASSWORD`: From `postgres-secret.password` (if available)

## Monitoring Jobs

### List All Jobs
```bash
kubectl get jobs -n train-orchestrator
```

### View Job Details
```bash
kubectl describe job ticketing-report-12345 -n train-orchestrator
```

### View Job Logs
```bash
kubectl logs -n train-orchestrator job/ticketing-report-12345
```

### Delete a Job
```bash
kubectl delete job ticketing-report-12345 -n train-orchestrator
```

## Integration Examples

### PowerShell Script
```powershell
# Generate report for January 2025
$response = Invoke-RestMethod -Method Post -Uri "http://localhost:8080/api/k8s/jobs/ticketing-report?startDate=2025-01-01&endDate=2025-01-31"
Write-Host "Job created: $($response.jobName)"

# Check job status
kubectl get job $response.jobName -n train-orchestrator
```

### Bash Script
```bash
#!/bin/bash
# Generate report for current month
response=$(curl -s -X POST http://localhost:8080/api/k8s/jobs/ticketing-report/current-month)
jobName=$(echo $response | jq -r '.jobName')
echo "Job created: $jobName"

# Wait for job completion
kubectl wait --for=condition=complete --timeout=600s job/$jobName -n train-orchestrator
```

### Python Script
```python
import requests
import subprocess

# Create ticketing report job
response = requests.post(
    "http://localhost:8080/api/k8s/jobs/ticketing-report",
    params={"startDate": "2025-01-01", "endDate": "2025-01-31"}
)

if response.status_code == 200:
    job_data = response.json()
    job_name = job_data['jobName']
    print(f"Job created: {job_name}")
    
    # Monitor job status
    subprocess.run([
        "kubectl", "get", "job", job_name,
        "-n", "train-orchestrator", "-w"
    ])
```

## Architecture

### Service Layer

The `TicketingReportJobService` class handles:
- Kubernetes API client configuration
- Job specification creation
- Dynamic date range calculation
- Environment variable and secret management
- Resource allocation

### Controller Layer

The `KubeController` class exposes:
- RESTful endpoints for job creation
- Request validation and error handling
- Response formatting

## Security Considerations

1. **RBAC Permissions:** Ensure the service account has permissions to create jobs in the namespace
2. **Secret Management:** Database credentials are retrieved from Kubernetes secrets
3. **Resource Limits:** Jobs have defined resource limits to prevent cluster resource exhaustion
4. **TTL Cleanup:** Jobs are automatically cleaned up after 24 hours

## Troubleshooting

### Job Fails to Create

**Error:** "Forbidden: jobs.batch is forbidden"
**Solution:** Ensure the service account has proper RBAC permissions:
```bash
kubectl apply -f k8s/rbac.yaml
```

### Job Fails to Execute

**Check logs:**
```bash
kubectl logs -n train-orchestrator job/ticketing-report-XXXXX
```

**Common issues:**
- Database connection failure (check `postgres-secret`)
- Image pull failure (ensure image is available)
- Invalid date range (check job arguments)

### Image Not Found

**Solution:** Build and push the image:
```bash
cd train-company-ticketing-report
docker build -t train-company-ticketing-report:latest .
# For remote clusters, tag and push to registry
```

## Future Enhancements

- Add support for different output formats (CSV, PDF)
- Implement job status polling endpoint
- Add support for persistent volume claims for report storage
- Implement webhook notifications on job completion
- Add support for filtering by specific routes or stations
