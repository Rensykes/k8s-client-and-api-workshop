# train-company-orchestrator — local run helpers

This project contains helper scripts to build and run the Spring Boot service locally.

Files added
- `run-local.ps1` — PowerShell: builds the project and runs the jar. Supports `-KubeconfigPath` to specify a custom kubeconfig.
- `run-local.sh` — Bash equivalent. Usage: `./run-local.sh [kubeconfig-path] [port]`

ServiceAccount kubeconfig generation has been moved to `k8s/script/setup.ps1` (menu option 4).

Examples

PowerShell: run locally with default kubeconfig
```powershell
cd train-company-orchestrator
.\run-local.ps1
```

PowerShell: run locally using a specific kubeconfig
```powershell
cd train-company-orchestrator
.\run-local.ps1 -KubeconfigPath "path\to\kubeconfig"
```

Bash: run locally using an explicit kubeconfig
```bash
cd train-company-orchestrator
./run-local.sh $HOME/.kube/config 8080
```

Notes
- The scripts assume `kubectl` is installed for generating ServiceAccount kubeconfigs.
- To generate a ServiceAccount kubeconfig, run `k8s/script/setup.ps1` and choose option 4.
- Do not commit tokens or kubeconfig files to source control.
