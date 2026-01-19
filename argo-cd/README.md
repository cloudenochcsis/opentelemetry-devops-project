# ArgoCD Configuration for OpenTelemetry Demo

This folder contains ArgoCD manifests to deploy the OpenTelemetry Demo application using GitOps.

## Files

| File | Description |
|------|-------------|
| `application.yaml` | ArgoCD Application - deploys from **external** manifests repo |
| `application-local.yaml` | ArgoCD Application - deploys from **this** repo's `kubernetes/` folder |
| `project.yaml` | ArgoCD Project with access controls (optional) |

## Quick Start

### Prerequisites

- ArgoCD installed on your cluster (use `scripts/setup-argocd.sh`)
- Kubernetes cluster access configured

### Option 1: Deploy from Local Manifests (Recommended)

Use this when you want to deploy manifests from this repository:

```bash
kubectl apply -f argo-cd/application-local.yaml
```

This deploys from: `opentelemetry-devops-project/kubernetes/`

### Option 2: Deploy from External Manifests Repo

Use this for the dual-repo GitOps workflow:

```bash
kubectl apply -f argo-cd/application.yaml
```

This deploys from: `opentelemetry-k8s-manifests/k8s-manifests/`

## Verify Deployment

```bash
# Check application status
kubectl get applications -n argocd

# Watch pods come up
kubectl get pods -n otel-demo -w

# Using ArgoCD CLI
argocd app get opentelemetry-demo-local  # or opentelemetry-demo
```

## Configuration Comparison

| Setting | Local (`application-local.yaml`) | External (`application.yaml`) |
|---------|----------------------------------|-------------------------------|
| **App Name** | `opentelemetry-demo-local` | `opentelemetry-demo` |
| **Source Repo** | `opentelemetry-devops-project` | `opentelemetry-k8s-manifests` |
| **Path** | `kubernetes/` | `k8s-manifests/` |
| **Namespace** | `otel-demo` | `otel-demo` |
| **Auto Sync** | Yes (prune + self-heal) | Yes (prune + self-heal) |

## How GitOps Works

### Local Manifests Flow
1. Make changes to `kubernetes/` folder
2. Commit and push to this repo
3. ArgoCD detects the change
4. ArgoCD syncs the changes to the cluster

### External Manifests Flow (Dual-Repo)
1. CI pipeline builds new image → pushes to Docker Hub
2. CI updates image tag in `opentelemetry-k8s-manifests` repo
3. ArgoCD detects the change in the external repo
4. ArgoCD automatically syncs the new image to the cluster

## Cleanup

To remove the ArgoCD application and all deployed resources:

```bash
# Remove finalizer and delete (for local app)
kubectl patch application opentelemetry-demo-local -n argocd --type json \
  -p '[{"op": "remove", "path": "/metadata/finalizers"}]'
kubectl delete application opentelemetry-demo-local -n argocd

# Or use the cleanup script
./scripts/cleanup-k8s.sh
```

## Observability Stack

The deployment includes these observability components:

| Component | Service | Access |
|-----------|---------|--------|
| **Jaeger** | `opentelemetry-demo-jaeger-query:16686` | `kubectl port-forward svc/opentelemetry-demo-jaeger-query 16686:16686 -n otel-demo` |
| **Grafana** | `opentelemetry-demo-grafana:80` | `kubectl port-forward svc/opentelemetry-demo-grafana 3000:80 -n otel-demo` |
| **Prometheus** | `opentelemetry-demo-prometheus-server:9090` | `kubectl port-forward svc/opentelemetry-demo-prometheus-server 9090:9090 -n otel-demo` |
