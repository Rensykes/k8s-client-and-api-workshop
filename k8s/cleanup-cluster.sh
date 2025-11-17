#!/usr/bin/env bash
set -euo pipefail

NAMESPACE=${1:-train-orchestrator}

echo "Deleting deployment/service in namespace $NAMESPACE..."
kubectl delete -f deployment.yaml --ignore-not-found || true

echo "Deleting RBAC resources..."
kubectl delete -f rbac.yaml --ignore-not-found || true

echo "Deleting namespace $NAMESPACE..."
kubectl delete -f namespace.yaml --ignore-not-found || true

echo "Cleanup complete."
