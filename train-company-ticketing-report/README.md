# Train Company Ticketing Report

A lightweight reporting utility that connects to the same PostgreSQL database used by the orchestrator service and exports a consolidated ticketing report to Excel.

## Prerequisites

- Python 3.11+
- Access to the PostgreSQL database seeded by the Flyway migration

## Setup

```powershell
cd train-company-ticketing-report
python -m venv .venv
. .venv\Scripts\Activate.ps1
pip install -r requirements.txt
```

Create a `.env` file (or provide environment variables directly):

```
DB_HOST=localhost
DB_PORT=5432
DB_NAME=traindb
DB_USER=postgres
DB_PASSWORD=mysecretpassword
```

### Connecting to Postgres in Kubernetes

If Postgres is running inside your Kubernetes cluster, port-forward it to localhost and point the `.env` values at the forwarded port. Example (PowerShell):

```powershell
# Forward the postgres service to local port 5432
kubectl -n train-orchestrator port-forward svc/postgres 5432:5432

# Then run the report (in another shell)
.\.venv\Scripts\python.exe main.py --start-date 2025-01-01 --end-date 2025-01-31 --output ticketing-report.xlsx
```

If local port 5432 is occupied, forward to a different local port and update `DB_PORT` in your `.env`, e.g. `kubectl -n train-orchestrator port-forward svc/postgres 15432:5432` and set `DB_PORT=15432`.


## Usage

```powershell
python main.py --start-date 2025-01-01 --end-date 2025-01-31 --output ticketing-report.xlsx
```

Arguments:

- `--start-date` (inclusive, ISO date). Defaults to the 1st day of the current month.
- `--end-date` (inclusive). Defaults to today.
- `--output` path for the Excel file. Defaults to `ticketing-report.xlsx` in the working directory.

The generated workbook contains a single sheet named **TicketingReport** with one row per ticket, enriched with booking, passenger, trip, and payment insights for downstream analytics.

## Containerization & Kubernetes/OpenShift Deployment

### Building the Container Image

Build the Docker image locally:

```powershell
# PowerShell
.\build-and-deploy.ps1

# Or build manually
docker build -t train-company-ticketing-report:latest .
```

```bash
# Linux/macOS
./build-and-deploy.sh

# Or build manually
docker build -t train-company-ticketing-report:latest .
```

### Pushing to a Registry (Optional)

If deploying to a remote Kubernetes/OpenShift cluster, push to your container registry:

```powershell
docker tag train-company-ticketing-report:latest your-registry/train-company-ticketing-report:latest
docker push your-registry/train-company-ticketing-report:latest
```

Update the image reference in `k8s/ticketing-report-job.yaml` to match your registry URL.

### Running as a Kubernetes Job

The `k8s/ticketing-report-job.yaml` manifest contains both a one-time Job and a CronJob for scheduled execution.

**One-time Job:**
```powershell
kubectl apply -f ../k8s/ticketing-report-job.yaml
kubectl get jobs -n train-orchestrator
kubectl logs -n train-orchestrator job/ticketing-report-job
```

**CronJob (Monthly on the 1st at 2 AM UTC):**
```powershell
# CronJob is automatically created with the manifest
kubectl get cronjobs -n train-orchestrator
kubectl get jobs -n train-orchestrator  # View jobs created by the CronJob
```

### Environment Variables

The Job/CronJob uses these environment variables (configured in the YAML):

- `DB_HOST`: PostgreSQL host (defaults to `postgres` service)
- `DB_PORT`: PostgreSQL port (defaults to `5432`)
- `DB_NAME`: Database name (defaults to `traindb`)
- `DB_USER`: Database username (from `postgres-secret` if available)
- `DB_PASSWORD`: Database password (from `postgres-secret` if available)

### Customizing the Report Date Range

Edit the `args` section in the Job manifest to customize dates:

```yaml
args:
- "--start-date"
- "2025-01-01"
- "--end-date"
- "2025-01-31"
- "--output"
- "/reports/ticketing-report.xlsx"
```

### Running Locally with Docker

```powershell
docker run --rm \
  -e DB_HOST=host.docker.internal \
  -e DB_PORT=5432 \
  -e DB_NAME=traindb \
  -e DB_USER=postgres \
  -e DB_PASSWORD=mysecretpassword \
  -v ${PWD}/reports:/reports \
  train-company-ticketing-report:latest \
  --start-date 2025-01-01 --end-date 2025-01-31
```
