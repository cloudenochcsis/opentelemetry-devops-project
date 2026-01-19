#!/bin/bash
# ============================================================================
# OpenTelemetry Demo - Kubernetes Cleanup Script
# ============================================================================
# This script removes all OpenTelemetry demo resources from the cluster
# Run with: ./cleanup-k8s.sh
# ============================================================================

set -e

echo "=============================================="
echo "OpenTelemetry Demo - Kubernetes Cleanup"
echo "=============================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print status
print_status() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

# Confirm before proceeding
echo "This script will remove:"
echo "  - ArgoCD Application (opentelemetry-demo)"
echo "  - otel-demo namespace and all resources"
echo "  - Ingress in default namespace"
echo "  - cert-manager (optional)"
echo "  - ArgoCD (optional)"
echo "  - NGINX Ingress Controller (optional)"
echo ""
read -p "Are you sure you want to continue? (y/N) " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cleanup cancelled."
    exit 0
fi

echo ""
echo "Starting cleanup..."
echo ""

# ============================================================================
# 1. Remove ArgoCD Application
# ============================================================================
echo "Step 1: Removing ArgoCD Application..."
if kubectl get application opentelemetry-demo -n argocd &>/dev/null; then
    # Remove finalizer to allow deletion
    kubectl patch application opentelemetry-demo -n argocd --type json \
        -p '[{"op": "remove", "path": "/metadata/finalizers"}]' 2>/dev/null || true
    kubectl delete application opentelemetry-demo -n argocd --timeout=60s 2>/dev/null || true
    print_status "ArgoCD Application removed"
else
    print_warning "ArgoCD Application not found (already removed)"
fi

# ============================================================================
# 2. Remove otel-demo namespace
# ============================================================================
echo ""
echo "Step 2: Removing otel-demo namespace..."
if kubectl get namespace otel-demo &>/dev/null; then
    kubectl delete all --all -n otel-demo --timeout=120s 2>/dev/null || true
    kubectl delete configmap --all -n otel-demo 2>/dev/null || true
    kubectl delete secret --all -n otel-demo 2>/dev/null || true
    kubectl delete serviceaccount --all -n otel-demo 2>/dev/null || true
    kubectl delete pvc --all -n otel-demo 2>/dev/null || true
    kubectl delete namespace otel-demo --timeout=120s 2>/dev/null || true
    print_status "otel-demo namespace removed"
else
    print_warning "otel-demo namespace not found (already removed)"
fi

# ============================================================================
# 3. Remove Ingress from default namespace
# ============================================================================
echo ""
echo "Step 3: Removing Ingress from default namespace..."
if kubectl get ingress opentelemetry-demo-ingress -n default &>/dev/null; then
    kubectl delete ingress opentelemetry-demo-ingress -n default 2>/dev/null || true
    print_status "Ingress removed from default namespace"
else
    print_warning "Ingress not found in default namespace"
fi

# ============================================================================
# 4. Remove cert-manager (optional)
# ============================================================================
echo ""
read -p "Remove cert-manager? (y/N) " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Removing cert-manager..."
    kubectl delete -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.4/cert-manager.yaml 2>/dev/null || true
    kubectl delete namespace cert-manager --timeout=120s 2>/dev/null || true
    print_status "cert-manager removed"
else
    print_warning "Skipping cert-manager removal"
fi

# ============================================================================
# 5. Remove NGINX Ingress Controller (optional)
# ============================================================================
echo ""
read -p "Remove NGINX Ingress Controller? (y/N) " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Removing NGINX Ingress Controller..."
    kubectl delete -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.2/deploy/static/provider/cloud/deploy.yaml 2>/dev/null || true
    kubectl delete namespace ingress-nginx --timeout=120s 2>/dev/null || true
    print_status "NGINX Ingress Controller removed"
else
    print_warning "Skipping NGINX Ingress Controller removal"
fi

# ============================================================================
# 6. Remove ArgoCD (optional)
# ============================================================================
echo ""
read -p "Remove ArgoCD completely? (y/N) " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Removing ArgoCD..."
    kubectl delete -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml 2>/dev/null || true
    kubectl delete namespace argocd --timeout=120s 2>/dev/null || true
    print_status "ArgoCD removed"
else
    print_warning "Skipping ArgoCD removal"
fi

# ============================================================================
# Summary
# ============================================================================
echo ""
echo "=============================================="
echo "Cleanup Complete!"
echo "=============================================="
echo ""
echo "Remaining namespaces:"
kubectl get namespaces
echo ""
print_status "All specified resources have been removed."
