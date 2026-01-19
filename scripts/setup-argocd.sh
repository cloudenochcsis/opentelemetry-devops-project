#!/bin/bash
# ============================================================================
# ArgoCD Setup Script
# ============================================================================
# This script installs and configures ArgoCD on a Kubernetes cluster
# Run with: ./setup-argocd.sh
# ============================================================================

set -e

echo "=============================================="
echo "ArgoCD Setup Script"
echo "=============================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

print_info() {
    echo -e "${BLUE}[i]${NC} $1"
}

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    print_error "kubectl is not installed. Please install kubectl first."
    exit 1
fi

# Check cluster connection
if ! kubectl cluster-info &> /dev/null; then
    print_error "Cannot connect to Kubernetes cluster. Please check your kubeconfig."
    exit 1
fi

print_status "Connected to Kubernetes cluster"
echo ""

# ============================================================================
# Step 1: Create ArgoCD Namespace
# ============================================================================
echo "Step 1: Creating ArgoCD namespace..."
if kubectl get namespace argocd &>/dev/null; then
    print_warning "ArgoCD namespace already exists"
else
    kubectl create namespace argocd
    print_status "ArgoCD namespace created"
fi

# ============================================================================
# Step 2: Install ArgoCD
# ============================================================================
echo ""
echo "Step 2: Installing ArgoCD..."
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
print_status "ArgoCD manifests applied"

# ============================================================================
# Step 3: Wait for ArgoCD pods to be ready
# ============================================================================
echo ""
echo "Step 3: Waiting for ArgoCD pods to be ready..."
echo "         This may take 1-3 minutes..."

# Wait for deployment to be available
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd 2>/dev/null || {
    print_warning "Timeout waiting for argocd-server. Checking pod status..."
}

# Show pod status
echo ""
echo "ArgoCD Pod Status:"
kubectl get pods -n argocd
echo ""

# ============================================================================
# Step 4: Extract Initial Admin Password
# ============================================================================
echo "Step 4: Extracting initial admin password..."
echo ""

# Wait a moment for the secret to be created
sleep 5

if kubectl get secret argocd-initial-admin-secret -n argocd &>/dev/null; then
    ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
    print_status "Initial admin password extracted"
    echo ""
    echo "=============================================="
    echo -e "${GREEN}ArgoCD Installation Complete!${NC}"
    echo "=============================================="
    echo ""
    echo -e "  ${BLUE}Username:${NC} admin"
    echo -e "  ${BLUE}Password:${NC} $ARGOCD_PASSWORD"
    echo ""
    echo "=============================================="
else
    print_warning "Initial admin secret not found yet. You can extract it later with:"
    echo ""
    echo '  kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d'
    echo ""
fi

# ============================================================================
# Step 5: Access Instructions
# ============================================================================
echo ""
echo "To access ArgoCD UI:"
echo ""
echo "  Option 1: Port Forwarding (Local Development)"
echo "  ─────────────────────────────────────────────"
echo "  kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo "  Then open: https://localhost:8080"
echo ""
echo "  Option 2: LoadBalancer (Cloud/Production)"
echo "  ─────────────────────────────────────────────"
echo "  kubectl patch svc argocd-server -n argocd -p '{\"spec\": {\"type\": \"LoadBalancer\"}}'"
echo "  kubectl get svc argocd-server -n argocd"
echo ""
echo "  Option 3: NodePort"
echo "  ─────────────────────────────────────────────"
echo "  kubectl patch svc argocd-server -n argocd -p '{\"spec\": {\"type\": \"NodePort\"}}'"
echo "  kubectl get svc argocd-server -n argocd"
echo ""

# ============================================================================
# Optional: Start Port Forwarding
# ============================================================================
read -p "Start port forwarding now? (y/N) " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    print_info "Starting port forwarding on localhost:8080..."
    print_info "Press Ctrl+C to stop"
    echo ""
    echo "  ArgoCD UI: https://localhost:8080"
    echo "  Username:  admin"
    echo "  Password:  $ARGOCD_PASSWORD"
    echo ""
    kubectl port-forward svc/argocd-server -n argocd 8080:443
else
    echo ""
    print_status "Setup complete! Run the port-forward command when ready to access the UI."
fi
