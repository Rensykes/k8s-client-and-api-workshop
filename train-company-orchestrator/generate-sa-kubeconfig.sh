#!/usr/bin/env bash
set -euo pipefail

NAMESPACE=${1:-train-orchestrator}
SERVICE_ACCOUNT=${2:-orchestrator-sa}
OUTPUT=${3:-sa.kubeconfig}
DURATION_HOURS=${4:-24}

echo "Creating token for $SERVICE_ACCOUNT in namespace $NAMESPACE..."
kubectl -n "$NAMESPACE" create token "$SERVICE_ACCOUNT" --duration=${DURATION_HOURS}h > sa.token
TOKEN=$(cat sa.token)

echo "Fetching cluster server and ca..."
SERVER=$(kubectl config view -o jsonpath='{.clusters[0].cluster.server}')
CLUSTER_NAME=$(kubectl config view -o jsonpath='{.clusters[0].name}')

SECRET_NAME=$(kubectl -n "$NAMESPACE" get sa "$SERVICE_ACCOUNT" -o jsonpath='{.secrets[0].name}')
kubectl get secret -n "$NAMESPACE" "$SECRET_NAME" -o go-template='{{ .data."ca.crt" }}' | base64 --decode > ca.crt

kubectl config --kubeconfig=$OUTPUT set-cluster $CLUSTER_NAME --server=$SERVER --certificate-authority=ca.crt
kubectl config --kubeconfig=$OUTPUT set-credentials $SERVICE_ACCOUNT --token="$TOKEN"
kubectl config --kubeconfig=$OUTPUT set-context orchestrator --cluster=$CLUSTER_NAME --user=$SERVICE_ACCOUNT
kubectl config --kubeconfig=$OUTPUT use-context orchestrator

echo "Wrote $OUTPUT"
