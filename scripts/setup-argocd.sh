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
# Step 5: Choose Access Method
# ============================================================================
echo ""
echo "==============================================" 
echo "How would you like to access ArgoCD?"
echo "==============================================" 
echo ""
echo "  1) Port Forwarding (Local Development)"
echo "     - Best for: Local testing, development"
echo "     - Access via: https://localhost:8080"
echo ""
echo "  2) LoadBalancer (Cloud/Production)"
echo "     - Best for: Cloud environments (AWS, GCP, Azure, DigitalOcean)"
echo "     - Access via: External IP assigned by cloud provider"
echo ""
echo "  3) NodePort (Alternative External Access)"
echo "     - Best for: On-premise clusters, bare-metal"
echo "     - Access via: <NodeIP>:<NodePort>"
echo ""
echo "  4) Skip - I'll configure access later"
echo ""

read -p "Enter your choice (1-4): " ACCESS_CHOICE
echo ""

case $ACCESS_CHOICE in
    1)
        # Port Forwarding
        print_info "Starting port forwarding on localhost:8080..."
        print_info "Press Ctrl+C to stop"
        echo ""
        echo "==============================================" 
        echo "  ArgoCD UI: https://localhost:8080"
        echo "  Username:  admin"
        echo "  Password:  $ARGOCD_PASSWORD"
        echo "==============================================" 
        echo ""
        kubectl port-forward svc/argocd-server -n argocd 8080:443
        ;;
    2)
        # LoadBalancer
        print_info "Configuring ArgoCD server as LoadBalancer..."
        kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'
        echo ""
        print_status "LoadBalancer configured!"
        echo ""
        echo "Waiting for external IP assignment..."
        echo "(This may take 1-2 minutes depending on your cloud provider)"
        echo ""
        
        # Wait for external IP with timeout
        TIMEOUT=120
        ELAPSED=0
        while [ $ELAPSED -lt $TIMEOUT ]; do
            EXTERNAL_IP=$(kubectl get svc argocd-server -n argocd -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
            EXTERNAL_HOSTNAME=$(kubectl get svc argocd-server -n argocd -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null)
            
            if [ -n "$EXTERNAL_IP" ]; then
                echo ""
                echo "==============================================" 
                print_status "External IP assigned!"
                echo ""
                echo "  ArgoCD UI: https://$EXTERNAL_IP"
                echo "  Username:  admin"
                echo "  Password:  $ARGOCD_PASSWORD"
                echo "==============================================" 
                break
            elif [ -n "$EXTERNAL_HOSTNAME" ]; then
                echo ""
                echo "==============================================" 
                print_status "External hostname assigned!"
                echo ""
                echo "  ArgoCD UI: https://$EXTERNAL_HOSTNAME"
                echo "  Username:  admin"
                echo "  Password:  $ARGOCD_PASSWORD"
                echo "==============================================" 
                break
            fi
            
            sleep 5
            ELAPSED=$((ELAPSED + 5))
            echo -n "."
        done
        
        if [ -z "$EXTERNAL_IP" ] && [ -z "$EXTERNAL_HOSTNAME" ]; then
            echo ""
            print_warning "External IP not yet assigned. Check status with:"
            echo "  kubectl get svc argocd-server -n argocd"
        fi
        ;;
    3)
        # NodePort
        print_info "Configuring ArgoCD server as NodePort..."
        kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "NodePort"}}'
        echo ""
        print_status "NodePort configured!"
        echo ""
        
        # Get the assigned NodePort
        NODE_PORT=$(kubectl get svc argocd-server -n argocd -o jsonpath='{.spec.ports[?(@.name=="https")].nodePort}')
        NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="ExternalIP")].address}' 2>/dev/null)
        
        if [ -z "$NODE_IP" ]; then
            NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
        fi
        
        echo "==============================================" 
        echo "  ArgoCD UI: https://$NODE_IP:$NODE_PORT"
        echo "  Username:  admin"
        echo "  Password:  $ARGOCD_PASSWORD"
        echo ""
        echo "  (If external IP not accessible, use internal IP or node hostname)"
        echo "==============================================" 
        ;;
    4|*)
        # Skip
        echo ""
        print_status "Setup complete!"
        echo ""
        echo "To access ArgoCD later, run one of these commands:"
        echo ""
        echo "  Port Forward:"
        echo "    kubectl port-forward svc/argocd-server -n argocd 8080:443"
        echo ""
        echo "  LoadBalancer:"
        echo "    kubectl patch svc argocd-server -n argocd -p '{\"spec\": {\"type\": \"LoadBalancer\"}}'"
        echo ""
        echo "  NodePort:"
        echo "    kubectl patch svc argocd-server -n argocd -p '{\"spec\": {\"type\": \"NodePort\"}}'"
        echo ""
        ;;
esac
