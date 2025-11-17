#!/usr/bin/env bash
set -euo pipefail

USE_SA=${1:-}
KUBECONFIG_PATH=${2:-}
PORT=${3:-8080}

echo "Building application..."
mvn -DskipTests package

if [[ "$USE_SA" == "sa" ]]; then
  echo "Generating service-account kubeconfig..."
  ./generate-sa-kubeconfig.sh train-orchestrator orchestrator-sa sa.kubeconfig
  export KUBECONFIG=$(pwd)/sa.kubeconfig
elif [[ -n "$KUBECONFIG_PATH" ]]; then
  echo "Using kubeconfig: $KUBECONFIG_PATH"
  export KUBECONFIG=$KUBECONFIG_PATH
fi

echo "Running application on port $PORT..."
java -jar target/train-company-orchestrator-0.0.1-SNAPSHOT.jar
