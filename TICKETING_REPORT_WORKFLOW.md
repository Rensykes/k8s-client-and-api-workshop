# Ticketing Report Workflow - Complete Chain Documentation

This document describes the complete end-to-end workflow for generating, storing, and accessing ticketing reports in the Train Company Orchestrator system.

---

## Table of Contents

1. [System Overview](#system-overview)
2. [Architecture Components](#architecture-components)
3. [Storage Configuration](#storage-configuration)
4. [Generating Reports](#generating-reports)
5. [Accessing Reports](#accessing-reports)
6. [Scheduling Reports](#scheduling-reports)
7. [Troubleshooting](#troubleshooting)
8. [Complete Setup Guide](#complete-setup-guide)

---

## System Overview

The ticketing report system provides a complete solution for generating Excel-based analytics reports from the PostgreSQL database. The workflow consists of:

1. **Report Generation**: Python-based job that queries the database and creates Excel reports
2. **Storage**: Kubernetes PersistentVolume using hostPath for Windows accessibility
3. **API Access**: Spring Boot endpoints for triggering jobs and downloading reports
4. **Scheduling**: CronJob for automated monthly report generation

### Data Flow

```
┌─────────────────┐
│   Spring Boot   │──┐
│  Orchestrator   │  │ 1. API Request (POST)
│                 │  │
└─────────────────┘  │
                     ▼
              ┌──────────────────┐
              │  Kubernetes Job  │
              │   (Python App)   │──┐
              └──────────────────┘  │ 2. Query Database
                                    │
                     ┌──────────────▼──────┐
                     │   PostgreSQL DB     │
                     │   (traindb)         │
                     └─────────────────────┘
                                    │
                     ┌──────────────▼──────┐
                     │  Generate Excel     │
                     │  Report             │
                     └─────────────────────┘
                                    │
                     ┌──────────────▼──────┐
                     │  PersistentVolume   │
                     │  /reports/          │
                     └─────────────────────┘
                                    │
              ┌─────────────────────┴─────────────────────┐
              │                                           │
              ▼                                           ▼
    ┌──────────────────┐                    ┌──────────────────────┐
    │  Kubernetes Pod  │                    │  Windows File System │
    │  (API Download)  │                    │  C:\Users\...\       │
    └──────────────────┘                    │  kubernetes-reports  │
                                            └──────────────────────┘
```

---

## Architecture Components

### 1. Report Generator (Python Application)

**Location**: `train-company-ticketing-report/`

**Purpose**: Queries PostgreSQL database and generates Excel reports with ticketing data.

**Key Files**:
- `main.py` - Entry point with CLI argument parsing
- `train_company_ticketing_report/report_service.py` - Database query and Excel generation logic
- `train_company_ticketing_report/config.py` - Database connection configuration
- `requirements.txt` - Python dependencies (pandas, openpyxl, psycopg2-binary, etc.)
- `Dockerfile` - Container image definition

**Features**:
- Flexible date range filtering
- Enriched data joins (bookings, passengers, trips, payments)
- Excel output with formatted columns
- Environment-based configuration

### 2. Spring Boot Orchestrator API

**Location**: `train-company-orchestrator/`

**Purpose**: Provides REST API to trigger report jobs and download generated reports.

**Key Endpoints**:

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/k8s/jobs/ticketing-report/current-month` | POST | Generate report for current month (1st to today) |
| `/api/k8s/jobs/ticketing-report/previous-month` | POST | Generate report for previous month |
| `/api/k8s/jobs/ticketing-report?startDate=...&endDate=...` | POST | Generate report for custom date range |
| `/api/k8s/reports` | GET | List all available reports in PVC |
| `/api/k8s/reports/{filename}` | GET | Download a specific report |

### 3. Kubernetes Resources

**Location**: `k8s/`

**Key Resources**:

#### PersistentVolume & PersistentVolumeClaim
**File**: `k8s/pv-hostpath.yaml`

```yaml
# PersistentVolume using hostPath
apiVersion: v1
kind: PersistentVolume
metadata:
  name: ticketing-reports-pv-hostpath
spec:
  capacity:
    storage: 1Gi
  accessModes:
    - ReadWriteOnce
  storageClassName: hostpath-local
  hostPath:
    # Docker Desktop mount path for Windows access
    path: /run/desktop/mnt/host/c/Users/<username>/kubernetes-reports
    type: DirectoryOrCreate
```

**Why this path?** Docker Desktop on Windows only properly syncs certain paths. Using `/run/desktop/mnt/host/c/Users/...` ensures files are accessible from the Windows filesystem.

#### Job & CronJob
**File**: `k8s/ticketing-report-job.yaml`

**One-Time Job**: Runs immediately when applied
**CronJob**: Runs monthly on the 1st at 2 AM UTC (`0 2 1 * *`)

Both use:
- Volume mount at `/reports` connected to PVC
- Database credentials from `postgres-secret` (optional)
- Configurable date ranges via args
- Resource limits (512Mi memory, 500m CPU)

---

## Storage Configuration

### PersistentVolume Setup

The storage system uses Kubernetes PersistentVolumes with hostPath binding to make files accessible from Windows.

#### Step 1: Create Windows Directory

```powershell
New-Item -ItemType Directory -Path "$HOME\kubernetes-reports" -Force
```

This creates: `C:\Users\<your-username>\kubernetes-reports`

#### Step 2: Apply PV and PVC

```powershell
kubectl apply -f k8s/pv-hostpath.yaml
```

Verify binding:
```powershell
kubectl get pv,pvc -n train-orchestrator
```

Expected output:
```
NAME                                      CAPACITY   STATUS   CLAIM
persistentvolume/ticketing-reports-pv...  1Gi        Bound    train-orchestrator/ticketing-reports-pvc

NAME                                      STATUS   VOLUME
persistentvolumeclaim/ticketing-reports.. Bound    ticketing-reports-pv-hostpath
```

#### Important Notes

**✅ Correct Path Format**:
```yaml
path: /run/desktop/mnt/host/c/Users/franc/kubernetes-reports
```

**❌ Incorrect Path Format** (won't sync to Windows):
```yaml
path: /host_mnt/c/dev/ws/kubernetes-api-workshop/reports
```

**Why?** Docker Desktop on Windows has specific mount points that properly sync with the host filesystem. The `/run/desktop/mnt/host/` prefix is required for proper bidirectional sync.

---

## Generating Reports

### Method 1: Via REST API (Recommended)

The Spring Boot orchestrator provides convenient endpoints to trigger report generation.

#### Generate Current Month Report

```powershell
curl.exe -X POST http://localhost:8080/api/k8s/jobs/ticketing-report/current-month
```

#### Generate Previous Month Report

```powershell
curl.exe -X POST http://localhost:8080/api/k8s/jobs/ticketing-report/previous-month
```

#### Generate Custom Date Range Report

```powershell
curl.exe -X POST "http://localhost:8080/api/k8s/jobs/ticketing-report?startDate=2025-01-01&endDate=2025-01-31"
```

**Response Example**:
```json
{
  "jobName": "ticketing-report-12345",
  "namespace": "train-orchestrator",
  "status": "Created",
  "startDate": "2025-01-01",
  "endDate": "2025-01-31"
}
```

### Method 2: Direct kubectl

Apply the Job manifest directly:

```powershell
kubectl apply -f k8s/ticketing-report-job.yaml
```

Check job status:
```powershell
kubectl get jobs -n train-orchestrator
kubectl logs -n train-orchestrator job/ticketing-report-job
```

### Method 3: Local Python Execution

For development/testing without Kubernetes:

```powershell
cd train-company-ticketing-report

# Activate virtual environment
.\.venv\Scripts\Activate.ps1

# Set environment variables
$env:DB_HOST = "localhost"
$env:DB_PORT = "5432"
$env:DB_NAME = "traindb"
$env:DB_USER = "postgres"
$env:DB_PASSWORD = "mysecretpassword"

# Run report
python main.py --start-date 2025-01-01 --end-date 2025-01-31 --output report.xlsx
```

**Note**: For in-cluster PostgreSQL, port-forward first:
```powershell
kubectl -n train-orchestrator port-forward svc/postgres-svc 5432:5432
```

---

## Accessing Reports

### Method 1: Direct Windows File Access (Recommended)

After a job completes successfully, the report is immediately available in Windows:

```powershell
# List all reports
ls C:\Users\<your-username>\kubernetes-reports

# Open with Excel
Start-Process "C:\Users\<your-username>\kubernetes-reports\ticketing-report.xlsx"
```

### Method 2: Via REST API Download

#### List Available Reports

```powershell
curl.exe http://localhost:8080/api/k8s/reports
```

**Response Example**:
```json
{
  "reports": [
    "ticketing-report-2025-01-01-to-2025-01-31-12345.xlsx",
    "ticketing-report-2025-11.xlsx"
  ],
  "count": 2
}
```

#### Download Specific Report

```powershell
curl.exe -o report.xlsx http://localhost:8080/api/k8s/reports/ticketing-report-2025-01.xlsx
```

### Method 3: Via kubectl cp

Copy directly from the PVC using a temporary pod:

```powershell
# Create pod with PVC mounted
kubectl run file-extractor --image=busybox --restart=Never -n train-orchestrator `
  --overrides='{"spec":{"containers":[{"name":"extractor","image":"busybox","command":["sleep","300"],"volumeMounts":[{"name":"report-volume","mountPath":"/reports"}]}],"volumes":[{"name":"report-volume","persistentVolumeClaim":{"claimName":"ticketing-reports-pvc"}}]}}'

# Wait for pod to be ready
Start-Sleep -Seconds 5

# Copy file
kubectl cp train-orchestrator/file-extractor:/reports/ticketing-report.xlsx ./ticketing-report.xlsx

# Cleanup
kubectl delete pod file-extractor -n train-orchestrator
```

---

## Scheduling Reports

### Automated Monthly Reports

The CronJob automatically generates reports on the 1st of each month at 2 AM UTC.

#### Check CronJob Status

```powershell
kubectl get cronjobs -n train-orchestrator
```

#### View CronJob-Generated Jobs

```powershell
kubectl get jobs -n train-orchestrator -l app=ticketing-report
```

#### Manually Trigger CronJob

```powershell
kubectl create job --from=cronjob/ticketing-report-cronjob manual-report-$(Get-Random) -n train-orchestrator
```

#### Customize Schedule

Edit `k8s/ticketing-report-job.yaml`:

```yaml
spec:
  # Run weekly on Mondays at 3 AM UTC
  schedule: "0 3 * * 1"
  
  # Or run daily at midnight UTC
  # schedule: "0 0 * * *"
  
  # Or run on the 15th of each month at 6 AM UTC
  # schedule: "0 6 15 * *"
```

Apply changes:
```powershell
kubectl apply -f k8s/ticketing-report-job.yaml
```

---

## Troubleshooting

### Issue 1: Files Not Appearing in Windows

**Symptoms**: Job completes successfully, but files aren't visible in `C:\Users\...\kubernetes-reports`

**Diagnosis**:
```powershell
# Check if file exists in Kubernetes volume
kubectl run debug-pod --image=busybox --restart=Never -n train-orchestrator `
  --overrides='{"spec":{"containers":[{"name":"debug","image":"busybox","command":["sleep","300"],"volumeMounts":[{"name":"report-volume","mountPath":"/reports"}]}],"volumes":[{"name":"report-volume","persistentVolumeClaim":{"claimName":"ticketing-reports-pvc"}}]}}'

kubectl exec debug-pod -n train-orchestrator -- ls -la /reports

# Cleanup
kubectl delete pod debug-pod -n train-orchestrator
```

**Solution**: Verify PV uses correct path:
```yaml
hostPath:
  path: /run/desktop/mnt/host/c/Users/<username>/kubernetes-reports
```

Not:
```yaml
hostPath:
  path: /host_mnt/c/... # Wrong prefix
```

### Issue 2: Job Fails with Database Connection Error

**Symptoms**: Job pods show `Error` or `CrashLoopBackOff` status

**Diagnosis**:
```powershell
kubectl get pods -n train-orchestrator -l app=ticketing-report
kubectl logs <pod-name> -n train-orchestrator
```

**Common Causes**:
1. PostgreSQL service not running
2. Incorrect database credentials
3. Network policy blocking access

**Solutions**:

Check PostgreSQL:
```powershell
kubectl get pods -n train-orchestrator -l app=postgres
kubectl logs -n train-orchestrator deployment/postgres
```

Verify secret:
```powershell
kubectl get secret postgres-secret -n train-orchestrator -o yaml
```

Test connectivity from a debug pod:
```powershell
kubectl run db-test --rm -it --image=postgres:15 -n train-orchestrator -- psql -h postgres-svc -U postgres -d traindb
```

### Issue 3: PVC Pending

**Symptoms**: PVC stuck in `Pending` status

**Diagnosis**:
```powershell
kubectl describe pvc ticketing-reports-pvc -n train-orchestrator
```

**Common Causes**:
1. PV not created
2. StorageClass mismatch
3. Access mode incompatibility

**Solutions**:

Ensure PV exists:
```powershell
kubectl get pv ticketing-reports-pv-hostpath
```

Check binding:
```powershell
kubectl get pv,pvc -n train-orchestrator
```

Recreate if needed:
```powershell
kubectl delete pvc ticketing-reports-pvc -n train-orchestrator --force --grace-period=0
kubectl delete pv ticketing-reports-pv-hostpath --force --grace-period=0
kubectl apply -f k8s/pv-hostpath.yaml
```

### Issue 4: Empty or Incomplete Reports

**Symptoms**: Excel file generated but has no data or partial data

**Diagnosis**:
```powershell
kubectl logs <job-pod-name> -n train-orchestrator
```

**Common Causes**:
1. No data in database for the date range
2. Date range parameters incorrect
3. Database migration not run

**Solutions**:

Verify data exists:
```powershell
kubectl -n train-orchestrator port-forward svc/postgres-svc 5432:5432

# In another terminal
psql -h localhost -U postgres -d traindb
SELECT COUNT(*) FROM tickets;
SELECT MIN(created_at), MAX(created_at) FROM tickets;
```

Check Flyway migrations:
```powershell
psql -h localhost -U postgres -d traindb
SELECT * FROM flyway_schema_history;
```

### Issue 5: Job Timeout

**Symptoms**: Job takes too long and gets terminated

**Solutions**:

Increase job timeout in `k8s/ticketing-report-job.yaml`:
```yaml
spec:
  activeDeadlineSeconds: 600  # 10 minutes (default: none)
  backoffLimit: 3
```

Increase resource limits:
```yaml
resources:
  requests:
    memory: "512Mi"
    cpu: "200m"
  limits:
    memory: "1Gi"
    cpu: "1000m"
```

---

## Complete Setup Guide

### Prerequisites

- ✅ Kubernetes cluster running (Docker Desktop, minikube, etc.)
- ✅ kubectl configured and connected
- ✅ Namespace `train-orchestrator` created
- ✅ PostgreSQL deployed and accessible
- ✅ Database seeded with Flyway migrations

### Step-by-Step Setup

#### 1. Build Report Generator Image

```powershell
cd train-company-ticketing-report

# PowerShell
.\build-and-deploy.ps1

# Or manually
docker build -t train-company-ticketing-report:latest .
```

For minikube:
```powershell
minikube image load train-company-ticketing-report:latest
```

#### 2. Create Windows Directory

```powershell
New-Item -ItemType Directory -Path "$HOME\kubernetes-reports" -Force
```

#### 3. Update PV Configuration

Edit `k8s/pv-hostpath.yaml` and replace `<username>` with your Windows username:

```yaml
hostPath:
  path: /run/desktop/mnt/host/c/Users/<username>/kubernetes-reports
```

#### 4. Apply PV and PVC

```powershell
kubectl apply -f k8s/pv-hostpath.yaml
```

Verify:
```powershell
kubectl get pv,pvc -n train-orchestrator
```

Both should show `Bound` status.

#### 5. Create Database Secret (if not exists)

```powershell
kubectl create secret generic postgres-secret -n train-orchestrator `
  --from-literal=username=postgres `
  --from-literal=password=mysecretpassword
```

#### 6. Deploy Job and CronJob

```powershell
kubectl apply -f k8s/ticketing-report-job.yaml
```

#### 7. Test Report Generation

Via API:
```powershell
# Ensure orchestrator is running (port-forward if needed)
kubectl -n train-orchestrator port-forward svc/train-orchestrator-svc 8080:8080

# Trigger report
curl.exe -X POST http://localhost:8080/api/k8s/jobs/ticketing-report/current-month
```

Via kubectl:
```powershell
kubectl get jobs -n train-orchestrator
kubectl logs -n train-orchestrator job/ticketing-report-job
```

#### 8. Verify File in Windows

```powershell
ls C:\Users\<your-username>\kubernetes-reports
```

You should see: `ticketing-report.xlsx`

#### 9. Open Report

```powershell
Start-Process "C:\Users\<your-username>\kubernetes-reports\ticketing-report.xlsx"
```

---

## Summary

This workflow provides a complete, production-ready system for generating and accessing ticketing reports:

- **Generation**: Python job queries PostgreSQL and creates Excel reports
- **Storage**: PersistentVolume with Windows-accessible hostPath
- **Access**: Direct file access, REST API downloads, or kubectl cp
- **Automation**: CronJob for scheduled monthly reports
- **Monitoring**: Kubernetes job logs and API endpoints

For additional details, see:
- [Train Company Ticketing Report README](train-company-ticketing-report/README.md)
- [Kubernetes Setup Guide](k8s/README.md)
- [Orchestrator API Documentation](train-company-orchestrator/README.md)
- [API Endpoint Reference](train-company-orchestrator/requests.http)
