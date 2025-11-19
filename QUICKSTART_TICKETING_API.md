# Quick Start: Ticketing Report Job API

## Step 1: Build the Ticketing Report Container

```powershell
# From the workspace root
cd train-company-ticketing-report
docker build -t train-company-ticketing-report:latest .
cd ..
```

## Step 2: Rebuild and Deploy the Orchestrator

```powershell
# Build the updated orchestrator
cd train-company-orchestrator
.\mvnw clean package -DskipTests

# Build Docker image (if using containerized deployment)
docker build -t train-company-orchestrator:latest .

# Or run locally for testing
.\mvnw spring-boot:run
```

## Step 3: Test the API Endpoints

### Option A: Using the requests.http file in VS Code

1. Open `train-company-orchestrator/requests.http`
2. Install REST Client extension if not already installed
3. Click "Send Request" above any of the new ticketing report endpoints

### Option B: Using curl

```bash
# Create report for current month
curl -X POST http://localhost:8080/api/k8s/jobs/ticketing-report/current-month

# Create report for previous month
curl -X POST http://localhost:8080/api/k8s/jobs/ticketing-report/previous-month

# Create report for custom date range
curl -X POST "http://localhost:8080/api/k8s/jobs/ticketing-report?startDate=2025-01-01&endDate=2025-01-31"
```

### Option C: Using PowerShell

```powershell
# Current month
Invoke-RestMethod -Method Post -Uri "http://localhost:8080/api/k8s/jobs/ticketing-report/current-month"

# Previous month
Invoke-RestMethod -Method Post -Uri "http://localhost:8080/api/k8s/jobs/ticketing-report/previous-month"

# Custom date range
Invoke-RestMethod -Method Post -Uri "http://localhost:8080/api/k8s/jobs/ticketing-report?startDate=2025-01-01&endDate=2025-01-31"
```

## Step 4: Verify the Job was Created

```bash
# List all jobs in the namespace
kubectl get jobs -n train-orchestrator

# Check specific job status
kubectl get job ticketing-report-XXXXX -n train-orchestrator

# View job logs
kubectl logs -n train-orchestrator job/ticketing-report-XXXXX

# Watch job status
kubectl get jobs -n train-orchestrator -w
```

## Expected Response

```json
{
  "status": "created",
  "jobName": "ticketing-report-12345",
  "namespace": "train-orchestrator",
  "creationTimestamp": "2025-11-19T10:30:00Z",
  "period": "current-month"
}
```

## Troubleshooting

### Issue: "Connection refused"
**Solution:** Ensure the orchestrator is running:
```powershell
# Check if the app is running locally
curl http://localhost:8080/actuator/health

# Or in Kubernetes
kubectl get pods -n train-orchestrator
kubectl port-forward -n train-orchestrator svc/train-company-orchestrator 8080:8080
```

### Issue: "Forbidden: jobs.batch is forbidden"
**Solution:** Ensure RBAC permissions are configured:
```bash
kubectl apply -f k8s/rbac.yaml
```

### Issue: Job created but fails to run
**Solution:** Check the job logs and events:
```bash
kubectl describe job ticketing-report-XXXXX -n train-orchestrator
kubectl logs -n train-orchestrator job/ticketing-report-XXXXX
```

Common causes:
- Image not available in the cluster
- Database credentials missing
- Network connectivity issues to PostgreSQL

## Architecture Flow

```
HTTP POST → KubeController
              ↓
         TicketingReportJobService
              ↓
         Kubernetes Job API
              ↓
         Job Pod Created
              ↓
         Python Report Script Runs
              ↓
         Excel Report Generated
```

## Files Modified/Created

### New Files:
- `train-company-orchestrator/src/main/java/io/bytebakehouse/train/company/orchestrator/service/TicketingReportJobService.java`
- `train-company-orchestrator/TICKETING_REPORT_API.md`
- `train-company-ticketing-report/Dockerfile`
- `train-company-ticketing-report/.dockerignore`
- `k8s/ticketing-report-job.yaml`

### Modified Files:
- `train-company-orchestrator/src/main/java/io/bytebakehouse/train/company/orchestrator/controller/KubeController.java`
- `train-company-orchestrator/requests.http`
- `train-company-ticketing-report/README.md`
