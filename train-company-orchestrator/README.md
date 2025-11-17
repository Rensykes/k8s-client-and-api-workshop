# train-company-orchestrator — local run helpers

This project contains helper scripts to build and run the Spring Boot service locally and to generate a minimal kubeconfig that uses a ServiceAccount token for least-privileged access.

Files added
- `run-local.ps1` — PowerShell: builds the project and runs the jar. Supports `-UseServiceAccount` to auto-generate `sa.kubeconfig` and set `KUBECONFIG` before running.
- `run-local.sh` — Bash equivalent. Usage: `./run-local.sh [sa] [kubeconfig-path] [port]` where `sa` tells the script to generate `sa.kubeconfig` and use it.
- `generate-sa-kubeconfig.ps1` — PowerShell helper to create a minimal kubeconfig for an existing ServiceAccount in a namespace. Writes `sa.kubeconfig` by default.
- `generate-sa-kubeconfig.sh` — Bash equivalent.

Examples

PowerShell: run locally with default kubeconfig
```powershell
cd train-company-orchestrator
.\run-local.ps1
```

PowerShell: run locally using the ServiceAccount kubeconfig
```powershell
cd train-company-orchestrator
.\run-local.ps1 -UseServiceAccount
```

Bash: run locally using an explicit kubeconfig
```bash
cd train-company-orchestrator
./run-local.sh '' $HOME/.kube/config 8080
```

Bash: generate SA kubeconfig and run using it
```bash
cd train-company-orchestrator
./run-local.sh sa
```

Notes
- The scripts assume `kubectl` is installed and you have cluster admin rights to create tokens and read secrets when generating `sa.kubeconfig`.
- The generated kubeconfig is intended for local demos — do not commit tokens to source control.
