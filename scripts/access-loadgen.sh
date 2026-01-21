#!/bin/bash
# ============================================================================
# Access Load Generator (Locust) with correct external host
# ============================================================================
# This script port-forwards Locust and prints the correct external Host URL
# for the frontend proxy LoadBalancer.
# ============================================================================

set -euo pipefail

NAMESPACE="otel-demo"
LOADGEN_SVC="opentelemetry-demo-loadgenerator"
FRONTEND_PROXY_SVC="opentelemetry-demo-frontendproxy"
LOCAL_PORT=8089
REMOTE_PORT=8089

if ! command -v kubectl &> /dev/null; then
  echo "kubectl not found. Install kubectl first."
  exit 1
fi

if ! kubectl get namespace "$NAMESPACE" &>/dev/null; then
  echo "Namespace '$NAMESPACE' not found."
  exit 1
fi

EXTERNAL_IP=$(kubectl get svc "$FRONTEND_PROXY_SVC" -n "$NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)
EXTERNAL_HOSTNAME=$(kubectl get svc "$FRONTEND_PROXY_SVC" -n "$NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true)

if [ -n "$EXTERNAL_IP" ]; then
  FRONTEND_URL="http://$EXTERNAL_IP:8080"
elif [ -n "$EXTERNAL_HOSTNAME" ]; then
  FRONTEND_URL="http://$EXTERNAL_HOSTNAME:8080"
else
  FRONTEND_URL="<EXTERNAL_LB_NOT_ASSIGNED>"
fi

echo "=================================================="
echo "Locust UI: http://localhost:${LOCAL_PORT}"
echo "Set Locust Host to: ${FRONTEND_URL}"
echo "=================================================="

cleanup() {
  echo ""
  echo "Stopping port-forward..."
  kill "$PF_PID" 2>/dev/null || true
  exit 0
}
trap cleanup SIGINT SIGTERM

kubectl port-forward svc/$LOADGEN_SVC -n $NAMESPACE ${LOCAL_PORT}:${REMOTE_PORT} &>/dev/null &
PF_PID=$!

wait $PF_PID
