# FastAPI Demo GitOps with ArgoCD

This repository contains the GitOps configuration for deploying FastAPI application using **ArgoCD** and **Helm**. The application is automatically synced from this repository to the Kubernetes cluster.

Source Application Repository: https://github.com/Pjain047/fastapi-demo

---

## 🚀 Quick Start Commands

### 1. Create/Deploy the Application
```bash
kubectl apply -f argocd/application.yaml
```
**What it does:** Creates an ArgoCD Application resource that tells ArgoCD to sync the Helm chart from this repository to your cluster.

### 2. View Application in ArgoCD
```bash
kubectl get application -n argocd
kubectl describe application fastapi-demo -n argocd
```
**What it does:** Lists all ArgoCD applications and shows detailed information about the fastapi-demo application deployment status.

### 3. Delete Application
```bash
kubectl delete application fastapi-demo -n argocd
```
**What it does:** Deletes the ArgoCD Application resource. Note: With `selfHeal: true`, if you delete the deployment, ArgoCD will recreate it automatically from the Helm chart.

### 4. Sync Application Manually (if needed)
```bash
argocd app sync fastapi-demo
```
**What it does:** Forces ArgoCD to pull the latest changes from GitHub and apply them to the cluster immediately.

---

## 📋 ArgoCD Application.yaml Explained

The `argocd/application.yaml` file defines how ArgoCD manages your deployment:

```yaml
apiVersion: argoproj.io/v1alpha1          # ArgoCD API version
kind: Application                          # Kubernetes resource type

metadata:
  name: fastapi-demo                       # Name of the application in ArgoCD
  namespace: argocd                        # ArgoCD runs in the argocd namespace

spec:
  project: default                         # ArgoCD project (default is permissive)

  source:
    repoURL: https://github.com/Pjain047/fastapi-demo-gitops  # Git repository URL
    targetRevision: main                   # Git branch/tag to track for changes
    path: helm/fastapi-demo                # Path to Helm chart in the repo

  destination:
    server: https://kubernetes.default.svc # Target Kubernetes cluster (this cluster)
    namespace: fastapi-demo                # Namespace where app will be deployed

  syncPolicy:
    automated:
      prune: true                          # Delete resources if removed from Git (cleanup)
      selfHeal: true                       # Automatically sync if manual changes detected
    syncOptions:
      - CreateNamespace=true               # Auto-create the namespace if it doesn't exist
```

---

## ⚙️ Helm Chart Configuration

### Key Values (values.yaml)

| Parameter | Value | Explanation |
|-----------|-------|-------------|
| `replicaCount` | 3 | Number of pod replicas running simultaneously |
| `image.repository` | prashantjain047/fastapi-demo | Docker image to deploy |
| `image.tag` | latest | Docker image version |
| `service.type` | NodePort | Service type (NodePort = accessible via Node IP) |
| `service.port` | 80 | External port |
| `service.targetPort` | 8000 | Container port (FastAPI app runs on 8000) |
| `resources.requests.cpu` | 100m | Minimum CPU allocated to each pod |
| `resources.requests.memory` | 128Mi | Minimum memory allocated to each pod |
| `resources.limits.cpu` | 500m | Maximum CPU each pod can use |
| `resources.limits.memory` | 512Mi | Maximum memory each pod can use |
| `hpa.enabled` | true | Enable Horizontal Pod Autoscaler (auto-scale based on metrics) |
| `hpa.minReplicas` | 2 | Minimum pods during low load |
| `hpa.maxReplicas` | 5 | Maximum pods during high load |
| `hpa.targetCPUUtilizationPercentage` | 50% | Scale up when CPU usage > 50% |
| `hpa.targetMemoryUtilizationPercentage` | 50% | Scale up when memory usage > 50% |

### Environment Configuration
- **ENVIRONMENT**: minikube
- **APP_VERSION**: 1.1.0
- **APP_NAME**: FastAPI Demo With Task Management API
- **LOG_LEVEL**: DEBUG

---

## 🔧 Kubernetes Templates Explanation

### 1. **deployment.yaml**
- Defines how many pod replicas to run
- Configures container image, ports, and environment variables
- Sets resource requests/limits for CPU and memory
- Includes health checks (liveness & readiness probes on `/health` endpoint)

### 2. **hpa.yaml** (Horizontal Pod Autoscaler)
- Automatically scales pods based on CPU and memory metrics
- Requires `metrics-server` to be installed in the cluster
- Scales between min (2) and max (5) replicas

### 3. **service.yaml**
- Exposes the application to the network
- Type: NodePort (accessible via `<NodeIP>:NodePort`)

### 4. **configmap.yaml**
- Stores non-sensitive configuration (environment variables)
- Mounted as environment variables in containers

### 5. **secret.yaml**
- Stores sensitive data (credentials, API keys)
- Base64 encoded for basic security

### 6. **namespace.yaml**
- Creates the `fastapi-demo` namespace for the application

---

## ⚠️ Current Issues & Fixes

### Issue: HPA Metrics Errors
**Error shown in ArgoCD:**
```
FailedGetResourceMetric: failed to get cpu utilization: unable to get metrics for resource cpu
FailedComputeMetricsRe: invalid metrics (2 invalid out of 2)
```

**Root Cause:** The Kubernetes cluster doesn't have `metrics-server` installed. HPA needs metrics-server to collect CPU/memory data.

**Fix Option 1: Install Metrics Server** (Recommended)
```bash
# Install metrics-server for Minikube
minikube addons enable metrics-server

# Verify it's running
kubectl get deployment metrics-server -n kube-system
kubectl get pods -n kube-system | grep metrics-server
```

**Fix Option 2: Disable HPA Temporarily**
Edit `helm/fastapi-demo/values.yaml`:
```yaml
hpa:
  enabled: false  # Change from true to false
```
Then re-sync:
```bash
argocd app sync fastapi-demo
```

---

## 🔄 How GitOps Works

1. **You make changes** to `helm/fastapi-demo/values.yaml` in this Git repo
2. **ArgoCD watches** the GitHub repository every 3 minutes (default)
3. **ArgoCD detects changes** and automatically applies them to the cluster
4. **With `selfHeal: true`**, any manual kubectl changes are overridden to match Git

To test: Edit `values.yaml` → Push to main → Watch ArgoCD sync automatically

---

## 📊 Monitoring & Debugging

### Check ArgoCD Application Status
```bash
kubectl get application fastapi-demo -n argocd
kubectl describe application fastapi-demo -n argocd
```

### View Pod Status
```bash
kubectl get pods -n fastapi-demo
kubectl logs -f deployment/fastapi-demo -n fastapi-demo
```

### Access the Application
```bash
# Get NodePort
kubectl get svc -n fastapi-demo

# Access via: http://<NodeIP>:<NodePort>
```

---

## 🛠️ Useful Commands Reference

| Command | Purpose |
|---------|---------|
| `kubectl apply -f argocd/application.yaml` | Create ArgoCD application |
| `argocd app list` | List all ArgoCD applications |
| `argocd app sync fastapi-demo` | Manually sync application |
| `argocd app wait fastapi-demo` | Wait for app to sync |
| `kubectl get hpa -n fastapi-demo` | Check HPA status |
| `kubectl top nodes` | View node resource usage |
| `kubectl top pods -n fastapi-demo` | View pod resource usage |

---

## 📝 Notes

- ArgoCD stores its configuration in the `argocd` namespace
- Application is deployed to the `fastapi-demo` namespace (created automatically)
- All configuration is version-controlled in Git (infrastructure as code)
- Changes via `kubectl edit` will be overridden by ArgoCD's selfHeal feature