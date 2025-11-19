# PVC-Based Report Storage and Download Setup

## Overview

The ticketing report system now uses **PersistentVolumeClaim (PVC)** for report storage, enabling:
- ✅ **Persistent storage** - Reports survive pod/job deletion
- ✅ **Download API** - REST endpoints to list and download reports
- ✅ **Shared access** - Both job pods and orchestrator can access the same storage

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                   Kubernetes Cluster                             │
│                                                                  │
│  ┌──────────────────┐      ┌────────────────────────────────┐  │
│  │ Ticketing Report │      │ Train Company Orchestrator     │  │
│  │ Job Pod          │      │ Pod                            │  │
│  │                  │      │                                │  │
│  │  ┌────────────┐  │      │  ┌──────────────────────────┐ │  │
│  │  │ Python App │  │      │  │ Download Endpoints       │ │  │
│  │  │ Writes     │  │      │  │ - GET /reports           │ │  │
│  │  │ Report     │  │      │  │ - GET /reports/{file}    │ │  │
│  │  └─────┬──────┘  │      │  └───────────┬──────────────┘ │  │
│  │        │         │      │              │                │  │
│  │        ▼         │      │              ▼                │  │
│  │  /reports/*.xlsx │      │  Creates temp pod to read    │  │
│  └────────┼─────────┘      └──────────────┼───────────────┘  │
│           │                               │                   │
│           └───────────┬───────────────────┘                   │
│                       ▼                                       │
│          ┌─────────────────────────┐                          │
│          │ PersistentVolumeClaim   │                          │
│          │ ticketing-reports-pvc   │                          │
│          │ (5Gi, ReadWriteMany)    │                          │
│          └─────────────────────────┘                          │
│                                                                │
└─────────────────────────────────────────────────────────────────┘
```

## Step 1: Deploy the PersistentVolumeClaim

**Create the PVC first** (before running any jobs):

```powershell
kubectl apply -f k8s/ticketing-report-pvc.yaml
```

**Verify PVC is bound:**

```powershell
kubectl get pvc -n train-orchestrator
```

Expected output:
```
NAME                     STATUS   VOLUME                                     CAPACITY   ACCESS MODES
ticketing-reports-pvc    Bound    pvc-xxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx     5Gi        RWX
```

> **Note:** If STATUS shows `Pending`, your cluster may need a StorageClass with `ReadWriteMany` support. For development, you can use the commented-out PersistentVolume section in the YAML (hostPath-based).

## Step 2: Deploy the Orchestrator

The orchestrator now includes:
- `TicketingReportJobService` - Creates jobs with PVC mounts
- `ReportStorageService` - Accesses files in the PVC
- `KubeController` - New download endpoints

**Build and deploy:**

```powershell
cd train-company-orchestrator

# Build
.\mvnw clean package -DskipTests

# Run locally (for testing)
.\mvnw spring-boot:run

# Or deploy to Kubernetes
kubectl apply -f ../k8s/deployment.yaml
```

## Step 3: Create a Report Job

Use the REST API to create a job:

```powershell
# Current month
Invoke-RestMethod -Method Post -Uri "http://localhost:8080/api/k8s/jobs/ticketing-report/current-month"

# Custom date range
Invoke-RestMethod -Method Post -Uri "http://localhost:8080/api/k8s/jobs/ticketing-report?startDate=2025-01-01&endDate=2025-01-31"
```

**Response:**
```json
{
  "status": "created",
  "jobName": "ticketing-report-12345",
  "namespace": "train-orchestrator",
  "creationTimestamp": "2025-11-19T10:30:00Z",
  "period": "current-month"
}
```

## Step 4: Monitor Job Execution

```powershell
# Watch job status
kubectl get jobs -n train-orchestrator -w

# View job logs
kubectl logs -n train-orchestrator job/ticketing-report-12345

# Check for completion
kubectl get job ticketing-report-12345 -n train-orchestrator -o jsonpath='{.status.succeeded}'
```

## Step 5: List Available Reports

```powershell
# Using PowerShell
$reports = Invoke-RestMethod -Method Get -Uri "http://localhost:8080/api/k8s/reports"
$reports.reports

# Using curl
curl -X GET http://localhost:8080/api/k8s/reports
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

## Step 6: Download a Report

```powershell
# Using PowerShell
Invoke-WebRequest -Uri "http://localhost:8080/api/k8s/reports/ticketing-report-2025-01-01-to-2025-01-31-12345.xlsx" -OutFile "report.xlsx"

# Using curl
curl -X GET "http://localhost:8080/api/k8s/reports/ticketing-report-2025-01-01-to-2025-01-31-12345.xlsx" -o report.xlsx
```

The file will be downloaded to your local machine as `report.xlsx`.

## How Download Works

When you request a report download:

1. **ReportStorageService** creates a temporary `busybox` pod
2. Pod mounts the same PVC (`ticketing-reports-pvc`)
3. Service executes `cat` command in the pod to read the file
4. File content is streamed back through the REST API
5. Temporary pod is deleted after download

This approach allows the orchestrator to access PVC contents without mounting the volume directly.

## Troubleshooting

### PVC Stuck in Pending

**Problem:** `kubectl get pvc` shows `STATUS: Pending`

**Solutions:**

1. **Check StorageClass:**
   ```powershell
   kubectl get storageclass
   ```
   Ensure you have a StorageClass that supports `ReadWriteMany` (RWX).

2. **For local/development clusters**, use the hostPath PV (uncomment in `ticketing-report-pvc.yaml`):
   ```yaml
   apiVersion: v1
   kind: PersistentVolume
   metadata:
     name: ticketing-reports-pv
   spec:
     capacity:
       storage: 5Gi
     accessModes:
       - ReadWriteMany
     persistentVolumeReclaimPolicy: Retain
     hostPath:
       path: /mnt/data/ticketing-reports
       type: DirectoryOrCreate
   ```

3. **For cloud providers:**
   - **AWS EKS:** Use EFS (Elastic File System) with the EFS CSI driver
   - **Azure AKS:** Use Azure Files
   - **GCP GKE:** Use Filestore

### Job Fails with "PVC not found"

**Problem:** Job pod shows error: `persistentvolumeclaim "ticketing-reports-pvc" not found`

**Solution:** Deploy the PVC first:
```powershell
kubectl apply -f k8s/ticketing-report-pvc.yaml
```

### Download Returns Empty File

**Problem:** Downloaded Excel file is 0 bytes or corrupted

**Possible causes:**
1. Job hasn't completed yet - check `kubectl get jobs`
2. Report wasn't written - check job logs
3. Filename mismatch - verify with `GET /reports` endpoint

### Access Pod Timeout

**Problem:** Download fails with "Pod did not become ready in time"

**Solutions:**
1. Increase timeout in `ReportStorageService.waitForPodReady()`
2. Check if cluster can pull `busybox:1.36` image
3. Verify PVC is properly bound

## Advanced Configuration

### Increase Storage Size

Edit the PVC before creating it:

```yaml
spec:
  resources:
    requests:
      storage: 20Gi  # Increase from 5Gi
```

### Change Storage Class

Specify a particular StorageClass:

```yaml
spec:
  storageClassName: fast-storage  # Your StorageClass name
```

### Custom Report Path

Modify constants in `TicketingReportJobService.java` and `ReportStorageService.java`:

```java
private static final String REPORTS_PATH = "/custom/path";
```

## Clean Up

### Delete Old Reports Manually

```powershell
# Create a temporary pod to access PVC
kubectl run -n train-orchestrator pvc-cleanup --image=busybox:1.36 --restart=Never --rm -i --tty -- /bin/sh

# Inside the pod:
ls /reports
rm /reports/old-report.xlsx
exit
```

### Delete All Resources

```powershell
# Delete jobs
kubectl delete jobs -n train-orchestrator -l app=ticketing-report

# Delete PVC (WARNING: Deletes all stored reports!)
kubectl delete -f k8s/ticketing-report-pvc.yaml
```

## Security Considerations

1. **Path Traversal Protection:** The download endpoint validates filenames to prevent `../` attacks
2. **RBAC:** Ensure service account has permissions to create/delete pods
3. **Network Policies:** Consider restricting access to the download endpoints
4. **Authentication:** Add authentication/authorization to the REST endpoints in production

## Performance Tips

1. **Keep reports small:** Archive old reports periodically
2. **Monitor PVC usage:** Use `kubectl get pvc` to check capacity
3. **Limit concurrent downloads:** Heavy downloads create temporary pods
4. **Consider object storage:** For production, S3/MinIO may be more efficient

## Next Steps

- Set up automated report archival (move old reports to S3)
- Add authentication/authorization to download endpoints
- Implement report retention policies
- Add Prometheus metrics for storage usage
- Create a web UI for report management
