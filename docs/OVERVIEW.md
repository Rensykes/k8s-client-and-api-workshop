# Train Company Orchestrator - Complete System Overview

This document provides a comprehensive overview of the Train Company Orchestrator system, covering the ticketing report workflow, API integration, and persistent storage configuration.

---

## Table of Contents

1. [System Overview](#system-overview)
2. [Quick Start Guide](#quick-start-guide)
3. [Real-Time Dashboard](#real-time-dashboard)
4. [Architecture Components](#architecture-components)
5. [Storage Configuration](#storage-configuration)
6. [Generating Reports](#generating-reports)
7. [Accessing Reports](#accessing-reports)
8. [Scheduling Reports](#scheduling-reports)
9. [Troubleshooting](#troubleshooting)
10. [Complete Setup Guide](#complete-setup-guide)

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
┌──────────────────────────────────────────────────────────┐
│                   Kubernetes Cluster                      │
│                                                           │
│  ┌──────────────────┐      ┌───────────────────────┐    │
│  │ Ticketing Report │      │ Train Company         │    │
│  │ Job Pod          │      │ Orchestrator Pod      │    │
│  │                  │      │                       │    │
│  │  ┌────────────┐  │      │  ┌─────────────────┐ │    │
│  │  │ Python App │  │      │  │ Download         │ │    │
│  │  │ Writes     │  │      │  │ Endpoints        │ │    │
│  │  │ Report     │  │      │  │ - GET /reports   │ │    │
│  │  └─────┬──────┘  │      │  │ - GET /reports/  │ │    │
│  │        │         │      │  │   {file}         │ │    │
│  │        ▼         │      │  └────────┬─────────┘ │    │
│  │  /reports/*.xlsx │      │           │           │    │
│  └────────┼─────────┘      └───────────┼───────────┘    │
│           │                            │                │
│           └────────────┬───────────────┘                │
│                        ▼                                │
│          ┌──────────────────────────┐                   │
│          │ PersistentVolumeClaim    │                   │
│          │ ticketing-reports-pvc    │                   │
│          │ (5Gi, ReadWriteMany)     │                   │
│          └──────────────────────────┘                   │
│                        │                                │
│                        ▼                                │
│          ┌──────────────────────────┐                   │
│          │ PersistentVolume         │                   │
│          │ (hostPath on Windows)    │                   │
│          └──────────────────────────┘                   │
└──────────────────────────────────────────────────────────┘
                         │
                         ▼
           C:\Users\<username>\kubernetes-reports
```

### Key Features

- ✅ **Persistent storage** - Reports survive pod/job deletion
- ✅ **Download API** - REST endpoints to list and download reports
- ✅ **Shared access** - Both job pods and orchestrator can access the same storage
- ✅ **Windows file access** - Direct access to reports from Windows Explorer
- ✅ **Flexible date ranges** - Generate reports for any time period
- ✅ **Automated scheduling** - Monthly reports via CronJob

---

## Quick Start Guide

### Step 1: Build the Ticketing Report Container

```powershell
# From the workspace root
cd train-company-ticketing-report
docker build -t train-company-ticketing-report:latest .
cd ..
```

### Step 2: Rebuild and Deploy the Orchestrator

```powershell
# Build the updated orchestrator
cd train-company-orchestrator
.\mvnw clean package -DskipTests

# Build Docker image (if using containerized deployment)
docker build -t train-company-orchestrator:latest .

# Or run locally for testing
.\mvnw spring-boot:run
```

### Step 3: Set Up Storage

**Create the Windows directory:**

```powershell
New-Item -ItemType Directory -Path "$HOME\kubernetes-reports" -Force
```

**Deploy the PersistentVolume and PersistentVolumeClaim:**

```powershell
kubectl apply -f k8s/infrastructure/pv-hostpath.yaml
```

**Verify PVC is bound:**

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

### Step 4: Test the API Endpoints

#### Option A: Using the requests.http file in VS Code

1. Open `train-company-orchestrator/requests.http`
2. Install REST Client extension if not already installed
3. Click "Send Request" above any of the ticketing report endpoints

#### Option B: Using curl

```bash
# Create report for current month
curl -X POST http://localhost:8080/api/k8s/jobs/ticketing-report/current-month

# Create report for previous month
curl -X POST http://localhost:8080/api/k8s/jobs/ticketing-report/previous-month

# Create report for custom date range
curl -X POST "http://localhost:8080/api/k8s/jobs/ticketing-report?startDate=2025-01-01&endDate=2025-01-31"
```

#### Option C: Using PowerShell

```powershell
# Current month
Invoke-RestMethod -Method Post -Uri "http://localhost:8080/api/k8s/jobs/ticketing-report/current-month"

# Previous month
Invoke-RestMethod -Method Post -Uri "http://localhost:8080/api/k8s/jobs/ticketing-report/previous-month"

# Custom date range
Invoke-RestMethod -Method Post -Uri "http://localhost:8080/api/k8s/jobs/ticketing-report?startDate=2025-01-01&endDate=2025-01-31"
```

### Step 5: Verify the Job was Created

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

### Step 6: Access the Report

**Direct Windows File Access:**
```powershell
# List all reports
ls C:\Users\<your-username>\kubernetes-reports

# Open with Excel
Start-Process "C:\Users\<your-username>\kubernetes-reports\ticketing-report.xlsx"
```

**Via REST API:**
```powershell
# List available reports
curl.exe http://localhost:8080/api/k8s/reports

# Download specific report
curl.exe -o report.xlsx http://localhost:8080/api/k8s/reports/ticketing-report-2025-01.xlsx
```

---

## Real-Time Dashboard

## Real-Time Job Monitoring Dashboard

### Overview

The dashboard is a hands-on demonstration of how to leverage the Kubernetes API from a Java application. It provides a real-time web interface for monitoring Kubernetes job execution and managing report downloads, using WebSocket technology for live updates. This is a core part of the workshop, showing practical Kubernetes API integration.

### Key Features

- **Real-Time Job Monitoring**: See job status updates as they happen via WebSocket
- **Live Statistics**: Track running, succeeded, and failed jobs at a glance
- **One-Click Report Generation**: Create reports for current month, previous month, or custom date ranges
- **Report Download**: List and download all available Excel reports
- **Visual Status Indicators**: Color-coded badges and progress animations
- **Auto-Refresh**: Reports list refreshes automatically every 10 seconds
- **Responsive Design**: Beautiful gradient UI that works on all screen sizes

### Architecture

```
┌──────────────┐         WebSocket          ┌─────────────────┐
│              │◄──────────────────────────►│                 │
│   Browser    │         STOMP/SockJS       │  Spring Boot    │
│  Dashboard   │                             │  Orchestrator   │
│              │         REST API            │                 │
│              │◄──────────────────────────►│                 │
└──────────────┘                             └────────┬────────┘
                           │
                           │
                      ┌────────▼────────┐
                      │  JobStatusService│
                      │  (Polls K8s API) │
                      └────────┬────────┘
                           │
                           │
                      ┌────────▼────────┐
                      │  Kubernetes API  │
                      │  (Job Status)    │
                      └──────────────────┘
```

#### Technology Stack

**Backend**
- Spring Boot (Application framework)
- Spring WebSocket (WebSocket support with STOMP protocol)
- Kubernetes Java Client (Job monitoring and status retrieval)
- Spring Scheduling (Periodic job status polling every 2 seconds)

**Frontend**
- SockJS (WebSocket client library with fallback support)
- STOMP.js (Messaging protocol over WebSocket)
- Vanilla JavaScript (No framework dependencies)
- CSS3 (Modern gradients and animations)

### How It Works

1. **Job Created**: User triggers a report job via the dashboard or API.
2. **JobStatusService**: Starts monitoring the job using the Kubernetes Java Client.
3. **Scheduler**: Polls Kubernetes every 2 seconds for job status changes.
4. **WebSocket Broadcast**: Status changes are pushed to all connected browsers in real time.
5. **UI Update**: Dashboard updates automatically, showing job progress and results.

#### Example WebSocket Flow

```javascript
const socket = new SockJS('/ws-job-status');
const stompClient = Stomp.over(socket);
stompClient.subscribe('/topic/job-status', function (message) {
  const jobStatus = JSON.parse(message.body);
  updateJob(jobStatus);
});
```

#### Example Job Monitoring (Java)

```java
@Scheduled(fixedRate = 2000)
public void pollJobStatus() {
  // Check each monitored job
  messagingTemplate.convertAndSend("/topic/job-status", status);
}
```

### Dashboard Interface

- **Header**: Shows "📊 Ticketing Report Dashboard" and real-time connection status (🟢 Connected / 🔴 Disconnected)
- **Control Panel**: Quick-action buttons for current/previous month report, refresh
- **Active & Recent Jobs**: Statistics cards, job list with status badges, monitoring indicator, pod stats, progress bars
- **Available Reports**: List of Excel reports, download buttons, auto-refresh every 10 seconds
- **Empty States**: Friendly messages when no jobs/reports

#### Status Indicators

| Color | Status     | Meaning                  |
|-------|------------|--------------------------|
| 🟡    | RUNNING    | Job is executing         |
| 🟢    | SUCCEEDED  | Job completed successfully|
| 🔴    | FAILED     | Job failed               |
| 🔵    | PENDING    | Job waiting to start     |
| 🔵    | MONITORING | Live updates active      |

### API Endpoints Used

| Endpoint                                         | Method | Purpose                                 |
|--------------------------------------------------|--------|-----------------------------------------|
| `/ws-job-status`                                 | WS     | Real-time job status updates (STOMP/SockJS) |
| `/api/k8s/jobs/ticketing-report/current-month`    | POST   | Create current month report job         |
| `/api/k8s/jobs/ticketing-report/previous-month`   | POST   | Create previous month report job        |
| `/api/k8s/jobs/all`                              | GET    | Fetch all ticketing report jobs         |
| `/api/k8s/reports`                               | GET    | List available Excel reports            |
| `/api/k8s/reports/{filename}`                    | GET    | Download specific report                |


### Troubleshooting

| Problem                | Solution                                                      |
|------------------------|---------------------------------------------------------------|
| Dashboard won't load   | Check if Spring Boot is running at port 8080                  |
| Shows disconnected     | Refresh page; restart Spring Boot                             |
| Jobs not updating      | Verify connection status is green                             |
| No reports showing     | Click "Refresh All" or wait 10 seconds                       |

### Learning Outcomes: Kubernetes API in Practice

- **Kubernetes Java Client**: Learn how to interact with Kubernetes from Java, including job creation, status polling, and resource management.
- **WebSocket Integration**: See how real-time updates can be pushed from backend to frontend using STOMP/SockJS.
- **Persistent Storage**: Understand how to use PVCs and hostPath for sharing files between pods and accessing them from Windows.
- **RESTful API Design**: Practice building endpoints for job control and file download.
- **UI/UX for Monitoring**: Build a responsive dashboard that visualizes Kubernetes job activity in real time.

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

**Key Components**:

- **KubeController** - REST endpoints for job creation and report downloads
- **TicketingReportJobService** - Creates Kubernetes jobs with PVC mounts
- **ReportStorageService** - Accesses files in the PVC for downloads

**API Endpoints**:

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/k8s/jobs/ticketing-report/current-month` | POST | Generate report for current month (1st to today) |
| `/api/k8s/jobs/ticketing-report/previous-month` | POST | Generate report for previous month |
| `/api/k8s/jobs/ticketing-report?startDate=...&endDate=...` | POST | Generate report for custom date range |
| `/api/k8s/reports` | GET | List all available reports in PVC |
| `/api/k8s/reports/{filename}` | GET | Download a specific report |

**Expected Response (Job Creation)**:
```json
{
  "status": "created",
  "jobName": "ticketing-report-12345",
  "namespace": "train-orchestrator",
  "creationTimestamp": "2025-11-19T10:30:00Z",
  "period": "current-month",
  "startDate": "2025-01-01",
  "endDate": "2025-01-31"
}
```

**Expected Response (List Reports)**:
```json
{
  "reports": [
    "ticketing-report-2025-01-01-to-2025-01-31-12345.xlsx",
    "ticketing-report-2025-11-01-to-2025-11-19-67890.xlsx"
  ],
  "count": 2
}
```

### 3. Kubernetes Resources

**Location**: `k8s/infrastructure/`

**Key Resources**:

#### PersistentVolume & PersistentVolumeClaim
**File**: `k8s/infrastructure/pv-hostpath.yaml`

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
    - ReadWriteMany
  persistentVolumeReclaimPolicy: Retain
  hostPath:
    path: /run/desktop/mnt/host/c/Users/<username>/kubernetes-reports
    type: DirectoryOrCreate
```

**Why this path?** Docker Desktop on Windows only properly syncs certain paths. Using `/run/desktop/mnt/host/c/Users/...` ensures files are accessible from the Windows filesystem.

#### Job & CronJob
**File**: `k8s/infrastructure/ticketing-report-job.yaml`

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

#### Step 2: Update PV Configuration

Edit `k8s/infrastructure/pv-hostpath.yaml` and replace `<username>` with your Windows username:

```yaml
hostPath:
  path: /run/desktop/mnt/host/c/Users/<username>/kubernetes-reports
  type: DirectoryOrCreate
```

#### Step 3: Apply PV and PVC

```powershell
kubectl apply -f k8s/infrastructure/pv-hostpath.yaml
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

### Storage Class Considerations

**For local/development clusters**, use the hostPath PV as shown above.

**For production/cloud providers:**
- **AWS EKS:** Use EFS (Elastic File System) with the EFS CSI driver
- **Azure AKS:** Use Azure Files
- **GCP GKE:** Use Filestore

All support `ReadWriteMany` access mode required for shared storage.

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
  "status": "created",
  "namespace": "train-orchestrator",
  "creationTimestamp": "2025-11-19T10:30:00Z",
  "period": "custom",
  "startDate": "2025-01-01",
  "endDate": "2025-01-31"
}
```

### Method 2: Direct kubectl

Apply the Job manifest directly:

```powershell
kubectl apply -f k8s/infrastructure/ticketing-report-job.yaml
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
    "ticketing-report-2025-11-01-to-2025-11-19-67890.xlsx"
  ],
  "count": 2
}
```

#### Download Specific Report

```powershell
curl.exe -o report.xlsx http://localhost:8080/api/k8s/reports/ticketing-report-2025-01.xlsx
```

**How Download Works:**

When you request a report download:

1. **ReportStorageService** creates a temporary `busybox` pod
2. Pod mounts the same PVC (`ticketing-reports-pvc`)
3. Service executes `cat` command in the pod to read the file
4. File content is streamed back through the REST API
5. Temporary pod is deleted after download

This approach allows the orchestrator to access PVC contents without mounting the volume directly.

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

Edit `k8s/infrastructure/ticketing-report-job.yaml`:

```yaml
spec:
  # Run weekly on Mondays at 3 AM UTC
  schedule: "0 3 * * 1"
  
  # Run daily at midnight UTC
  schedule: "0 0 * * *"
  
  # Run on 15th of each month at 6 AM UTC
  schedule: "0 6 15 * *"
```

Apply changes:
```powershell
kubectl apply -f k8s/infrastructure/ticketing-report-job.yaml
```

---

## Troubleshooting

### Issue 1: "Connection refused"

**Symptoms**: Cannot reach the orchestrator API

**Solutions:**

```powershell
# Check if the app is running locally
curl http://localhost:8080/actuator/health

# Or in Kubernetes
kubectl get pods -n train-orchestrator
kubectl port-forward -n train-orchestrator svc/train-company-orchestrator 8080:8080
```

### Issue 2: "Forbidden: jobs.batch is forbidden"

**Symptoms**: Job creation fails with RBAC error

**Solution:** Ensure RBAC permissions are configured:
```bash
kubectl apply -f k8s/infrastructure/rbac.yaml
```

### Issue 3: Files Not Appearing in Windows

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

### Issue 4: Job Fails with Database Connection Error

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

### Issue 5: PVC Pending

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
kubectl apply -f k8s/infrastructure/pv-hostpath.yaml
```

### Issue 6: Empty or Incomplete Reports

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

### Issue 7: Job Timeout

**Symptoms**: Job takes too long and gets terminated

**Solutions**:

Increase job timeout in `k8s/infrastructure/ticketing-report-job.yaml`:
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
    cpu: "500m"
  limits:
    memory: "1Gi"
    cpu: "1000m"
```

### Issue 8: Download Returns Empty File

**Symptoms**: Downloaded Excel file is 0 bytes or corrupted

**Possible causes**:
1. Job hasn't completed yet - check `kubectl get jobs`
2. Report wasn't written - check job logs
3. Filename mismatch - verify with `GET /reports` endpoint

### Issue 9: Access Pod Timeout

**Symptoms**: Download fails with "Pod did not become ready in time"

**Solutions**:
1. Increase timeout in `ReportStorageService.waitForPodReady()`
2. Check if cluster can pull `busybox:1.36` image
3. Verify PVC is properly bound

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

# Build the image
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

Edit `k8s/infrastructure/pv-hostpath.yaml` and replace `<username>` with your Windows username:

```yaml
hostPath:
  path: /run/desktop/mnt/host/c/Users/<username>/kubernetes-reports
```

#### 4. Apply PV and PVC

```powershell
kubectl apply -f k8s/infrastructure/pv-hostpath.yaml
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
kubectl apply -f k8s/infrastructure/ticketing-report-job.yaml
```

#### 7. Build and Deploy Orchestrator

```powershell
cd train-company-orchestrator

# Build
.\mvnw clean package -DskipTests

# Build Docker image
docker build -t train-company-orchestrator:latest .

# Run locally (for testing)
.\mvnw spring-boot:run

# Or deploy to Kubernetes
kubectl apply -f ../k8s/infrastructure/train-company-orchestrator.yaml
```

#### 8. Test Report Generation

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

#### 9. Verify File in Windows

```powershell
ls C:\Users\<your-username>\kubernetes-reports
```

You should see: `ticketing-report.xlsx`

#### 10. Open Report

```powershell
Start-Process "C:\Users\<your-username>\kubernetes-reports\ticketing-report.xlsx"
```

---

## Advanced Configuration

### Increase Storage Size

Edit the PVC before creating it:

```yaml
spec:
  resources:
    requests:
      storage: 20Gi  # Increase from 1Gi/5Gi
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

### Clean Up Old Reports

```powershell
# Create a temporary pod to access PVC
kubectl run -n train-orchestrator pvc-cleanup --image=busybox:1.36 --restart=Never --rm -i --tty -- /bin/sh

# Inside the pod:
ls /reports
rm /reports/old-report.xlsx
exit
```

---

## Security Considerations

1. **Path Traversal Protection:** The download endpoint validates filenames to prevent `../` attacks
2. **RBAC:** Ensure service account has permissions to create/delete pods
3. **Network Policies:** Consider restricting access to the download endpoints
4. **Authentication:** Add authentication/authorization to the REST endpoints in production
5. **Secrets Management:** Use Kubernetes secrets or external secret managers for database credentials

---

## Performance Tips

1. **Keep reports small:** Archive old reports periodically
2. **Monitor PVC usage:** Use `kubectl get pvc` to check capacity
3. **Limit concurrent downloads:** Heavy downloads create temporary pods
4. **Consider object storage:** For production, S3/MinIO may be more efficient than PVC
5. **Optimize queries:** Index database columns used in report queries

---

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
         Excel Report Generated → PVC
              ↓
         HTTP GET → ReportStorageService
              ↓
         Temporary Pod Access → Stream File
              ↓
         Download Complete
```

---