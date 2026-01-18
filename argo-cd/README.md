# ArgoCD Configuration for OpenTelemetry Demo

This folder contains ArgoCD manifests to deploy the OpenTelemetry Demo application using GitOps.

## Files

| File | Description |
|------|-------------|
| `application.yaml` | Main ArgoCD Application - deploys all services |
| `project.yaml` | ArgoCD Project with access controls (optional) |

## Quick Start

### Prerequisites
- ArgoCD installed on your cluster
- Access to the manifests repo: `cloudenochcsis/opentelemetry-k8s-manifests`

### Deploy

```bash
# Apply the ArgoCD Application
kubectl apply -f argo-cd/application.yaml

# (Optional) Apply the Project first for access controls
kubectl apply -f argo-cd/project.yaml
kubectl apply -f argo-cd/application.yaml
```

### Verify

```bash
# Check application status
argocd app get opentelemetry-demo

# Or via kubectl
kubectl get applications -n argocd
```

## Configuration

The Application is configured with:
- **Source**: `https://github.com/cloudenochcsis/opentelemetry-k8s-manifests.git`
- **Path**: `k8s-manifests` (all subdirectories)
- **Target Namespace**: `otel-demo`
- **Sync Policy**: Automated with self-heal and prune

## How GitOps Works

1. CI pipeline builds new image → pushes to Docker Hub
2. CI updates image tag in `opentelemetry-k8s-manifests` repo
3. ArgoCD detects the change in Git
4. ArgoCD automatically syncs the new image to the cluster
