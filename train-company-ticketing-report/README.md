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
