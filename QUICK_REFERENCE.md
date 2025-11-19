# Quick Reference: Report Storage & Download

## 🚀 Deploy PVC Storage

```powershell
# Automated deployment
.\deploy-pvc-storage.ps1

# Or manually
kubectl apply -f k8s/ticketing-report-pvc.yaml
kubectl get pvc -n train-orchestrator
```

## 🔨 Build & Run Orchestrator

```powershell
cd train-company-orchestrator
.\mvnw clean package -DskipTests
.\mvnw spring-boot:run
```

## 📊 Create Reports

```powershell
# Current month
Invoke-RestMethod -Method Post -Uri "http://localhost:8080/api/k8s/jobs/ticketing-report/current-month"

# Previous month
Invoke-RestMethod -Method Post -Uri "http://localhost:8080/api/k8s/jobs/ticketing-report/previous-month"

# Custom dates
Invoke-RestMethod -Method Post -Uri "http://localhost:8080/api/k8s/jobs/ticketing-report?startDate=2025-01-01&endDate=2025-01-31"
```

## 📥 Download Reports

```powershell
# List all reports
$reports = Invoke-RestMethod -Uri "http://localhost:8080/api/k8s/reports"
$reports.reports

# Download a specific report
Invoke-WebRequest -Uri "http://localhost:8080/api/k8s/reports/<filename>.xlsx" -OutFile "report.xlsx"
```

## 🔍 Monitor

```powershell
# Watch jobs
kubectl get jobs -n train-orchestrator -w

# View job logs
kubectl logs -n train-orchestrator job/<job-name>

# Check PVC usage
kubectl get pvc -n train-orchestrator
```

## 🧹 Cleanup

```powershell
# Delete old jobs
kubectl delete jobs -n train-orchestrator -l app=ticketing-report --field-selector status.successful=1

# Delete all (including reports!)
kubectl delete -f k8s/ticketing-report-pvc.yaml
```

## 🔗 Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/k8s/jobs/ticketing-report/current-month` | Create report for current month |
| POST | `/api/k8s/jobs/ticketing-report/previous-month` | Create report for previous month |
| POST | `/api/k8s/jobs/ticketing-report?startDate=...&endDate=...` | Create report for custom dates |
| GET | `/api/k8s/reports` | List all available reports |
| GET | `/api/k8s/reports/{filename}` | Download specific report |

## 📚 Documentation

- **Complete Guide:** `PVC_REPORT_STORAGE_GUIDE.md`
- **Implementation Details:** `IMPLEMENTATION_SUMMARY.md`
- **API Tests:** `train-company-orchestrator/requests.http`
