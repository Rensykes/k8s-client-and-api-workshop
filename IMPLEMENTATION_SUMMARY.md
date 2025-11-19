# Implementation Summary: PVC Storage + Download API

## What Was Implemented

### 1. Persistent Storage (PVC)
✅ **Created:** `k8s/ticketing-report-pvc.yaml`
- 5Gi PersistentVolumeClaim with ReadWriteMany access
- Shared between job pods and orchestrator
- Reports survive pod deletion

✅ **Updated:** Job manifests and service code
- `TicketingReportJobService.java` - Creates jobs with PVC mounts
- `k8s/ticketing-report-job.yaml` - Static manifests use PVC
- Filenames include date range and timestamp to prevent conflicts

### 2. Download REST API
✅ **Created:** `ReportStorageService.java`
- Lists all Excel reports in PVC storage
- Downloads specific reports by filename
- Creates temporary pods to access PVC contents
- Automatic cleanup of temporary pods

✅ **Updated:** `KubeController.java`
- `GET /api/k8s/reports` - List available reports
- `GET /api/k8s/reports/{filename}` - Download specific report

### 3. Documentation & Scripts
✅ **Created:**
- `PVC_REPORT_STORAGE_GUIDE.md` - Comprehensive deployment guide
- `deploy-pvc-storage.ps1` - Automated deployment script
- Updated `requests.http` with download examples

## New API Endpoints

### List Reports
```http
GET http://localhost:8080/api/k8s/reports
```

**Response:**
```json
{
  "reports": [
    "ticketing-report-2025-01-01-to-2025-01-31-12345.xlsx",
    "ticketing-report-2025-11-01-to-2025-11-19-67890.xlsx"
  ],
  "count": 2
}
```

### Download Report
```http
GET http://localhost:8080/api/k8s/reports/ticketing-report-2025-01-01-to-2025-01-31-12345.xlsx
```

**Response:** Binary Excel file download

## Quick Start

### Deploy PVC
```powershell
.\deploy-pvc-storage.ps1
```

### Rebuild Orchestrator
```powershell
cd train-company-orchestrator
.\mvnw clean package -DskipTests
.\mvnw spring-boot:run
```

### Create a Report
```powershell
Invoke-RestMethod -Method Post -Uri "http://localhost:8080/api/k8s/jobs/ticketing-report/current-month"
```

### List & Download Reports
```powershell
# List
$reports = Invoke-RestMethod -Uri "http://localhost:8080/api/k8s/reports"
$reports.reports

# Download first report
$filename = $reports.reports[0]
Invoke-WebRequest -Uri "http://localhost:8080/api/k8s/reports/$filename" -OutFile "report.xlsx"
```

## Files Created/Modified

### New Files
1. `k8s/ticketing-report-pvc.yaml` - PVC manifest
2. `train-company-orchestrator/src/main/java/.../ReportStorageService.java` - Download service
3. `PVC_REPORT_STORAGE_GUIDE.md` - Deployment guide
4. `deploy-pvc-storage.ps1` - Deployment script

### Modified Files
1. `train-company-orchestrator/src/main/java/.../TicketingReportJobService.java`
   - Added PVC_NAME and REPORTS_PATH constants
   - Changed volume from emptyDir to PVC
   - Generate unique filenames with date range
   - Add filename to job annotations

2. `train-company-orchestrator/src/main/java/.../KubeController.java`
   - Added ReportStorageService dependency
   - Added GET /reports endpoint
   - Added GET /reports/{filename} endpoint

3. `k8s/ticketing-report-job.yaml`
   - Changed both Job and CronJob to use PVC

4. `train-company-orchestrator/requests.http`
   - Added report list and download examples

## Architecture Flow

### Report Creation
```
User → POST /jobs/ticketing-report
  → TicketingReportJobService creates Job
  → Job Pod writes to PVC:/reports/ticketing-report-*.xlsx
  → Report persists in PVC
```

### Report Download
```
User → GET /reports
  → ReportStorageService creates temp busybox pod
  → Temp pod mounts PVC
  → Execute 'ls' in temp pod
  → Return file list
  → Delete temp pod

User → GET /reports/{filename}
  → ReportStorageService creates temp busybox pod
  → Temp pod mounts PVC
  → Execute 'cat {filename}' in temp pod
  → Stream file content to user
  → Delete temp pod
```

## Testing

Run the automated test:
```powershell
.\train-company-orchestrator\test-ticketing-api.ps1
```

Or use the REST Client in VS Code:
1. Open `train-company-orchestrator/requests.http`
2. Click "Send Request" on any endpoint

## Security Notes

✅ **Path Traversal Protection:** Filename validation prevents `../` attacks
✅ **Temporary Pods:** Auto-cleanup prevents resource leaks
✅ **Binary Streaming:** Files streamed directly, not loaded into memory

⚠️ **Production Recommendations:**
- Add authentication/authorization to download endpoints
- Implement rate limiting for downloads
- Add audit logging
- Consider S3/MinIO for large-scale deployments

## Troubleshooting

### PVC Pending
```powershell
kubectl get pvc -n train-orchestrator
kubectl describe pvc ticketing-reports-pvc -n train-orchestrator
```

See `PVC_REPORT_STORAGE_GUIDE.md` for StorageClass solutions.

### Download Timeout
Increase timeout in `ReportStorageService.waitForPodReady()` or check cluster image pull speed.

### Job Not Using PVC
Rebuild the orchestrator after changes:
```powershell
.\mvnw clean package -DskipTests
```

## Next Steps

Consider implementing:
- [ ] Report expiration/cleanup policy
- [ ] Direct S3 upload from Python job
- [ ] Web UI for report management
- [ ] Prometheus metrics for storage usage
- [ ] Email notification on report completion
