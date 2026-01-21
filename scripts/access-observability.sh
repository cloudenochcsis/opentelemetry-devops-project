
#!/bin/bash
# ============================================================================
# Access Observability Stack Script
# ============================================================================
# This script provides access to the OpenTelemetry Demo observability stack:
# - Grafana (Dashboards & Visualization)
# - Prometheus (Metrics)
# - Jaeger (Distributed Tracing)
# - Frontend Proxy (Single entry point)
#
# Run with: ./access-observability.sh
# ============================================================================

set -e

echo "=============================================="
echo "OpenTelemetry Demo - Observability Stack"
echo "=============================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
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
# Check if otel-demo namespace exists
# ============================================================================
if ! kubectl get namespace otel-demo &>/dev/null; then
    print_error "Namespace 'otel-demo' not found. Please deploy the OpenTelemetry Demo first."
    exit 1
fi

# ============================================================================
# Check observability stack status
# ============================================================================
echo "Checking observability stack status..."
echo ""

check_service() {
    local name=$1
    local service=$2
    local namespace=$3
    
    if kubectl get svc "$service" -n "$namespace" &>/dev/null; then
        echo -e "  ${GREEN}●${NC} $name"
        return 0
    else
        echo -e "  ${RED}○${NC} $name (not found)"
        return 1
    fi
}

FRONTEND_PROXY_AVAILABLE=false
GRAFANA_AVAILABLE=false
PROMETHEUS_AVAILABLE=false
JAEGER_AVAILABLE=false

check_service "Frontend Proxy" "opentelemetry-demo-frontendproxy" "otel-demo" && FRONTEND_PROXY_AVAILABLE=true
check_service "Grafana" "opentelemetry-demo-grafana" "otel-demo" && GRAFANA_AVAILABLE=true
check_service "Prometheus" "opentelemetry-demo-prometheus-server" "otel-demo" && PROMETHEUS_AVAILABLE=true
check_service "Jaeger" "opentelemetry-demo-jaeger-query" "otel-demo" && JAEGER_AVAILABLE=true

echo ""

# ============================================================================
# Choose Access Method
# ============================================================================
echo "=============================================="
echo "How would you like to access the observability stack?"
echo "=============================================="
echo ""
echo "  1) Frontend Proxy (Recommended - Single Entry Point)"
echo "     - Access all services via one port"
echo "     - Best for: Quick access, development"
echo ""
echo "  2) LoadBalancer (Cloud/Production)"
echo "     - Expose Frontend Proxy with external IP"
echo "     - Best for: Cloud environments"
echo ""
echo "  3) NodePort (Alternative External Access)"  
echo "     - Expose Frontend Proxy on node port"
echo "     - Best for: On-premise, bare-metal"
echo ""
echo "  4) Individual Services (Port Forward Each)"
echo "     - Forward each service to a different local port"
echo "     - Best for: Debugging specific services"
echo ""
echo "  5) Skip - Show access commands only"
echo ""

read -p "Enter your choice (1-5): " ACCESS_CHOICE
echo ""

case $ACCESS_CHOICE in
    1)
        # Frontend Proxy Port Forwarding
        if [ "$FRONTEND_PROXY_AVAILABLE" = false ]; then
            print_error "Frontend Proxy service not found!"
            exit 1
        fi
        
        print_info "Starting Frontend Proxy port forwarding on localhost:8088..."
        print_info "Also forwarding Prometheus directly on localhost:9090..."
        print_info "Also forwarding Load Generator directly on localhost:8089..."
        print_info "Press Ctrl+C to stop"
        echo ""
        echo "=============================================="
        echo -e "${CYAN}Observability Stack Access URLs:${NC}"
        echo "=============================================="
        echo ""
        echo "  Frontend Demo:    http://localhost:8088"
        echo "  Grafana:          http://localhost:8088/grafana"
        echo "  Jaeger UI:        http://localhost:8088/jaeger/ui"
        echo "  Prometheus:       http://localhost:9090"
        echo "  Feature Flags:    http://localhost:8088/feature"
        echo "  Load Generator:   http://localhost:8089"
        echo "                   (Set Host to http://localhost:8088)"
        echo ""
        echo "=============================================="
        echo -e "  ${BLUE}Grafana Credentials:${NC}"
        echo "    Username: admin"
        echo "    Password: admin"
        echo "=============================================="
        echo ""
        
        # Start Prometheus port forward in background
        kubectl port-forward svc/opentelemetry-demo-prometheus-server -n otel-demo 9090:9090 &>/dev/null &
        PROM_PID=$!

        # Start Load Generator port forward in background
        kubectl port-forward svc/opentelemetry-demo-loadgenerator -n otel-demo 8089:8089 &>/dev/null &
        LOADGEN_PID=$!
        
        # Cleanup function
        cleanup() {
            echo ""
            print_info "Stopping port forwards..."
            kill $PROM_PID 2>/dev/null || true
            kill $LOADGEN_PID 2>/dev/null || true
            exit 0
        }
        trap cleanup SIGINT SIGTERM
        
        # Start Frontend Proxy port forward in foreground
        kubectl port-forward svc/opentelemetry-demo-frontendproxy -n otel-demo 8088:8080
        ;;
    2)
        # LoadBalancer
        if [ "$FRONTEND_PROXY_AVAILABLE" = false ]; then
            print_error "Frontend Proxy service not found!"
            exit 1
        fi
        
        print_info "Configuring Frontend Proxy as LoadBalancer..."
        kubectl patch svc opentelemetry-demo-frontendproxy -n otel-demo -p '{"spec": {"type": "LoadBalancer"}}'
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
            EXTERNAL_IP=$(kubectl get svc opentelemetry-demo-frontendproxy -n otel-demo -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
            EXTERNAL_HOSTNAME=$(kubectl get svc opentelemetry-demo-frontendproxy -n otel-demo -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null)
            
            if [ -n "$EXTERNAL_IP" ]; then
                BASE_URL="http://$EXTERNAL_IP"
                break
            elif [ -n "$EXTERNAL_HOSTNAME" ]; then
                BASE_URL="http://$EXTERNAL_HOSTNAME"
                break
            fi
            
            sleep 5
            ELAPSED=$((ELAPSED + 5))
            echo -n "."
        done
        
        if [ -n "$BASE_URL" ]; then
            echo ""
            echo ""
            echo "=============================================="
            print_status "External IP/Hostname assigned!"
            echo ""
            echo -e "${CYAN}Observability Stack Access URLs:${NC}"
            echo "=============================================="
            echo ""
            echo "  Frontend Demo:    $BASE_URL"
            echo "  Grafana:          $BASE_URL/grafana"
            echo "  Jaeger UI:        $BASE_URL/jaeger/ui"
            echo "  Prometheus:       (use port-forward: kubectl port-forward svc/opentelemetry-demo-prometheus-server -n otel-demo 9090:9090)"
            echo "  Feature Flags:    $BASE_URL/feature"
            echo "  Load Generator:   $BASE_URL/loadgen"
            echo ""
            echo "=============================================="
            echo -e "  ${BLUE}Grafana Credentials:${NC}"
            echo "    Username: admin"
            echo "    Password: admin"
            echo "=============================================="
        else
            echo ""
            print_warning "External IP not yet assigned. Check status with:"
            echo "  kubectl get svc opentelemetry-demo-frontendproxy -n otel-demo"
        fi
        ;;
    3)
        # NodePort
        if [ "$FRONTEND_PROXY_AVAILABLE" = false ]; then
            print_error "Frontend Proxy service not found!"
            exit 1
        fi
        
        print_info "Configuring Frontend Proxy as NodePort..."
        kubectl patch svc opentelemetry-demo-frontendproxy -n otel-demo -p '{"spec": {"type": "NodePort"}}'
        echo ""
        print_status "NodePort configured!"
        echo ""
        
        # Get the assigned NodePort
        NODE_PORT=$(kubectl get svc opentelemetry-demo-frontendproxy -n otel-demo -o jsonpath='{.spec.ports[0].nodePort}')
        NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="ExternalIP")].address}' 2>/dev/null)
        
        if [ -z "$NODE_IP" ]; then
            NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
        fi
        
        BASE_URL="http://$NODE_IP:$NODE_PORT"
        
        echo "=============================================="
        echo -e "${CYAN}Observability Stack Access URLs:${NC}"
        echo "=============================================="
        echo ""
        echo "  Frontend Demo:    $BASE_URL"
        echo "  Grafana:          $BASE_URL/grafana"
        echo "  Jaeger UI:        $BASE_URL/jaeger/ui"
        echo "  Prometheus:       (use port-forward: kubectl port-forward svc/opentelemetry-demo-prometheus-server -n otel-demo 9090:9090)"
        echo "  Feature Flags:    $BASE_URL/feature"
        echo "  Load Generator:   $BASE_URL/loadgen"
        echo ""
        echo "=============================================="
        echo -e "  ${BLUE}Grafana Credentials:${NC}"
        echo "    Username: admin"
        echo "    Password: admin"
        echo ""
        echo "  (If external IP not accessible, use internal IP or node hostname)"
        echo "=============================================="
        ;;
    4)
        # Individual Services Port Forwarding
        print_info "Starting port forwarding for individual services..."
        echo ""
        echo "This will open multiple port forwards in the background."
        echo ""
        
        # Create a cleanup function
        cleanup() {
            echo ""
            print_info "Stopping all port forwards..."
            pkill -f "kubectl port-forward.*otel-demo" 2>/dev/null || true
            print_status "All port forwards stopped."
            exit 0
        }
        trap cleanup SIGINT SIGTERM
        
        # Start port forwards in background
        if [ "$GRAFANA_AVAILABLE" = true ]; then
            kubectl port-forward svc/opentelemetry-demo-grafana -n otel-demo 3000:80 &>/dev/null &
            echo -e "  ${GREEN}●${NC} Grafana:    http://localhost:3000"
        fi
        
        if [ "$PROMETHEUS_AVAILABLE" = true ]; then
            kubectl port-forward svc/opentelemetry-demo-prometheus-server -n otel-demo 9090:9090 &>/dev/null &
            echo -e "  ${GREEN}●${NC} Prometheus: http://localhost:9090"
        fi
        
        if [ "$JAEGER_AVAILABLE" = true ]; then
            kubectl port-forward svc/opentelemetry-demo-jaeger-query -n otel-demo 16686:16686 &>/dev/null &
            echo -e "  ${GREEN}●${NC} Jaeger:     http://localhost:16686"
        fi
        
        if [ "$FRONTEND_PROXY_AVAILABLE" = true ]; then
            kubectl port-forward svc/opentelemetry-demo-frontendproxy -n otel-demo 8088:8080 &>/dev/null &
            echo -e "  ${GREEN}●${NC} Frontend:   http://localhost:8088"
        fi
        
        echo ""
        echo "=============================================="
        echo -e "  ${BLUE}Grafana Credentials:${NC}"
        echo "    Username: admin"
        echo "    Password: admin"
        echo "=============================================="
        echo ""
        print_info "Press Ctrl+C to stop all port forwards"
        echo ""
        
        # Wait for interrupt
        wait
        ;;
    5|*)
        # Skip - Show commands only
        echo ""
        print_status "Access Commands Reference"
        echo ""
        echo "=============================================="
        echo "Frontend Proxy (Recommended - All Services)"
        echo "=============================================="
        echo ""
        echo "  Port Forward:"
        echo "    kubectl port-forward svc/opentelemetry-demo-frontendproxy -n otel-demo 8088:8080"
        echo ""
        echo "  LoadBalancer:"
        echo "    kubectl patch svc opentelemetry-demo-frontendproxy -n otel-demo -p '{\"spec\": {\"type\": \"LoadBalancer\"}}'"
        echo ""
        echo "  NodePort:"
        echo "    kubectl patch svc opentelemetry-demo-frontendproxy -n otel-demo -p '{\"spec\": {\"type\": \"NodePort\"}}'"
        echo ""
        echo "=============================================="
        echo "Individual Services"
        echo "=============================================="
        echo ""
        echo "  Grafana (port 3000):"
        echo "    kubectl port-forward svc/opentelemetry-demo-grafana -n otel-demo 3000:80"
        echo ""
        echo "  Prometheus (port 9090):"
        echo "    kubectl port-forward svc/opentelemetry-demo-prometheus-server -n otel-demo 9090:9090"
        echo ""
        echo "  Jaeger (port 16686):"
        echo "    kubectl port-forward svc/opentelemetry-demo-jaeger-query -n otel-demo 16686:16686"
        echo ""
        echo "=============================================="
        echo "Access URLs (when using Frontend Proxy)"
        echo "=============================================="
        echo ""
        echo "  Frontend Demo:    http://localhost:8088"
        echo "  Grafana:          http://localhost:8088/grafana"
        echo "  Jaeger UI:        http://localhost:8088/jaeger/ui"
        echo "  Prometheus:       http://localhost:9090 (requires separate port-forward)"
        echo "  Feature Flags:    http://localhost:8088/feature"
        echo "  Load Generator:   http://localhost:8088/loadgen"
        echo ""
        echo "=============================================="
        echo -e "  ${BLUE}Grafana Credentials:${NC}"
        echo "    Username: admin"
        echo "    Password: admin"
        echo "=============================================="
        ;;
esac
