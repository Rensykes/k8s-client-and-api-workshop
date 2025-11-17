#!/usr/bin/env bash
set -euo pipefail

NAMESPACE=${1:-train-orchestrator}

echo "Creating namespace: $NAMESPACE"
kubectl apply -f namespace.yaml

echo "Applying RBAC resources..."
kubectl apply -f rbac.yaml

echo "Applying Postgres resources..."
kubectl apply -f postgres.yaml

echo "Done. Verify with: kubectl get ns $NAMESPACE && kubectl -n $NAMESPACE get sa,role,rolebinding"

echo "Done. You can port-forward the service locally:"
echo "kubectl -n $NAMESPACE port-forward svc/train-orchestrator-svc 8080:8080"