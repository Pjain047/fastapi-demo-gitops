# FastAPI Demo — GitOps Repository

This repository is the **GitOps source of truth** for deploying the FastAPI Demo application onto Kubernetes using **Argo CD** and **Helm**. Every change pushed to this repo is automatically reconciled into the cluster.

> **Application source code** (the FastAPI app itself) lives in a separate repo:
> https://github.com/Pjain047/fastapi-demo

---

## 🎯 Why this project exists

This repo demonstrates a **production-style GitOps workflow** on a local Minikube cluster:

- **Declarative deployments** — the entire app state is described as code (Helm chart) and stored in Git.
- **Automated reconciliation** — Argo CD continuously watches this repo and applies changes; manual `kubectl` edits are auto-corrected (`selfHeal`).
- **Modern traffic management** — uses the Kubernetes **Gateway API** (`Gateway` + `HTTPRoute`) instead of the legacy Ingress resource.
- **Observability built-in** — a `ServiceMonitor` wires the app's `/metrics` endpoint into Prometheus for scraping and Grafana dashboards.

The goal: a realistic, end-to-end example of how a service goes from Git → cluster → monitored traffic.

---

## 🏗️ What it does (architecture)

```
                ┌─────────────────────────────────────────────┐
                │                 Git (this repo)              │
                │        helm/fastapi-demo (Helm chart)        │
                └───────────────────┬─────────────────────────┘
                                    │  Argo CD polls & syncs
                                    ▼
┌──────────┐   HTTP    ┌────────────────────────────────────────────┐
│  Client  │ ────────► │  Gateway (NGINX Gateway Fabric)            │
└──────────┘           │   └── HTTPRoute ──► Service ──► Pods (xN)  │
                       │        fastapi-demo namespace               │
                       └───────────────────┬────────────────────────┘
                                           │  /metrics scraped
                                           ▼
                                  ┌─────────────────┐
                                  │  Prometheus +    │  (kube-prometheus-stack,
                                  │  Grafana         │   monitoring namespace)
                                  └─────────────────┘
```

1. **Argo CD** applies the Helm chart from `helm/fastapi-demo`.
2. The app runs as a **Deployment** (auto-scaled by an **HPA**).
3. A **Gateway** + **HTTPRoute** (Gateway API) expose the app on `http://fastapi-demo.127.0.0.1.nip.io` via the **NGINX Gateway Fabric** controller.
4. A **ServiceMonitor** tells Prometheus to scrape `/metrics`; Grafana visualizes request rates, latency, and errors.

---

## 📁 Repository layout & file details

```
fastapi-demo-gitops/
├── README.md                        ← you are here
├── argocd/
│   └── application.yaml             ← Argo CD Application: tells Argo CD what to
│                                      sync (repo, path, branch) and where
│                                      (cluster, namespace), with automated
│                                      prune + selfHeal policy.
└── helm/
    └── fastapi-demo/                ← the Helm chart for the app
        ├── Chart.yaml               ← chart metadata (name, version, appVersion)
        ├── values.yaml              ← all tunable config (replicas, image, resources,
        │                              HPA, serviceMonitor, ingress, gateway)
        └── templates/
            ├── _helpers.tpl         ← shared template helpers: name/fullname,
            │                              common labels, selector labels, namespace
            ├── namespace.yaml       ← the fastapi-demo Namespace
            ├── deployment.yaml      ← app Pods: image, env from configmap/secret,
            │                              resources, liveness/readiness probes
            ├── service.yaml         ← Cluster-internal Service (port 80 → 8000),
            │                              labeled so the ServiceMonitor can find it
            ├── hpa.yaml             ← HorizontalPodAutoscaler: CPU/memory based
            │                              scaling (min 2, max 5)
            ├── configmap.yaml       ← non-sensitive env config (APP_NAME, LOG_LEVEL,
            │                              METRICS_ENABLED, ...)
            ├── secret.yaml          ← sensitive config (base64 credentials/keys)
            ├── servicemonitoring.yaml ← Prometheus ServiceMonitor: selects the
            │                              Service by label, scrapes /metrics
            ├── ingress.yaml         ← legacy Ingress (DISABLED — kept for reference;
            │                              ingress.enabled: false)
            ├── gateway.yaml         ← Gateway API: the Gateway (listener on the host,
            │                              gatewayClassName nginx)
            └── httproute.yaml       ← Gateway API: the HTTPRoute that binds the
                                           hostname to the Service backend (ACTIVE path)
```

### File-by-file purpose

| File | Kind(s) it creates | What it does |
|------|--------------------|--------------|
| [argocd/application.yaml](argocd/application.yaml) | Argo CD `Application` | Registers this repo with Argo CD; enables automated sync, `prune`, `selfHeal`, and `CreateNamespace`. |
| [helm/fastapi-demo/Chart.yaml](helm/fastapi-demo/Chart.yaml) | Helm chart metadata | Chart name/version and the application version. |
| [helm/fastapi-demo/values.yaml](helm/fastapi-demo/values.yaml) | — (config) | Single place to tune replicas, image, resources, HPA, ServiceMonitor, and the Gateway/Ingress host. |
| [templates/_helpers.tpl](helm/fastapi-demo/templates/_helpers.tpl) | — (helpers) | Reusable template functions for consistent naming, labeling, and namespace selection. |
| [templates/namespace.yaml](helm/fastapi-demo/templates/namespace.yaml) | `Namespace` | Creates the `fastapi-demo` namespace. |
| [templates/deployment.yaml](helm/fastapi-demo/templates/deployment.yaml) | `Deployment` | Runs the app containers with probes and resource limits. |
| [templates/service.yaml](helm/fastapi-demo/templates/service.yaml) | `Service` | Stable internal endpoint for the pods; the routing + metrics target. |
| [templates/hpa.yaml](helm/fastapi-demo/templates/hpa.yaml) | `HorizontalPodAutoscaler` | Scales pods on CPU/memory. |
| [templates/configmap.yaml](helm/fastapi-demo/templates/configmap.yaml) | `ConfigMap` | Non-sensitive environment variables. |
| [templates/secret.yaml](helm/fastapi-demo/templates/secret.yaml) | `Secret` | Sensitive environment variables (base64). |
| [templates/servicemonitoring.yaml](helm/fastapi-demo/templates/servicemonitoring.yaml) | `ServiceMonitor` | Prometheus scrape config for `/metrics`. |
| [templates/ingress.yaml](helm/fastapi-demo/templates/ingress.yaml) | `Ingress` | **Disabled** legacy path (`ingress.enabled: false`). |
| [templates/gateway.yaml](helm/fastapi-demo/templates/gateway.yaml) | `Gateway` | **Active** Gateway API listener: opens port 80 for the host via the `nginx` GatewayClass. |
| [templates/httproute.yaml](helm/fastapi-demo/templates/httproute.yaml) | `HTTPRoute` | **Active** route: binds the hostname to the Service backend (this is what actually forwards traffic). |

---

## 🔀 Ingress vs Gateway API

This project uses the **Gateway API** (the successor to Ingress):

- `gateway.enabled: true`, `ingress.enabled: false` in [values.yaml](helm/fastapi-demo/values.yaml).
- `GatewayClass: nginx` is provided by **NGINX Gateway Fabric** (installed separately, not by this chart).
- The app is reachable at **`http://fastapi-demo.127.0.0.1.nip.io`** — a [nip.io](https://nip.io) hostname that resolves to `127.0.0.1`, so **no local hosts-file edits are needed**.

The legacy `ingress.yaml` template is kept in the chart but disabled, so you can flip back if ever needed.

---

## ⚙️ Key configuration (values.yaml)

| Parameter | Value | Explanation |
|-----------|-------|-------------|
| `replicaCount` | 3 | Baseline pod replicas |
| `image.repository` | prashantjain047/fastapi-demo | Container image |
| `image.tag` | latest | Image tag |
| `service.type` | NodePort | Service exposure type |
| `service.port` / `targetPort` | 80 / 8000 | Service port → container port |
| `hpa.enabled` | true | Enable autoscaling |
| `hpa.minReplicas` / `maxReplicas` | 2 / 5 | Scaling bounds |
| `hpa.targetCPU/MemoryUtilizationPercentage` | 50 | Scale-up thresholds |
| `serviceMonitor.enabled` | true | Create the Prometheus ServiceMonitor |
| `gateway.enabled` | true | **Active** — create Gateway + HTTPRoute |
| `gateway.gatewayClassName` | nginx | Matches the NGINX Gateway Fabric GatewayClass |
| `gateway.host` | fastapi-demo.127.0.0.1.nip.io | Public hostname (resolves to 127.0.0.1) |
| `ingress.enabled` | false | Legacy Ingress disabled |

---

## 🚀 Quick start

### Deploy / register the app with Argo CD
```bash
kubectl apply -f argocd/application.yaml
```

### Check sync status
```bash
kubectl get application -n argocd
kubectl describe application fastapi-demo -n argocd
```

### Force a sync (if you don't want to wait for auto-sync)
```bash
argocd app sync fastapi-demo
```

### Access the app
```bash
# Requires the Gateway data-plane to be reachable (see "Accessing the Gateway" below)
curl http://fastapi-demo.127.0.0.1.nip.io/health
```

### Delete the app
```bash
kubectl delete application fastapi-demo -n argocd
```

---

## 🌐 Accessing the Gateway on Minikube

The NGINX Gateway Fabric exposes a `LoadBalancer` service. On Minikube, an external IP is only assigned while a tunnel is running:

```bash
minikube tunnel        # keep this running in a separate terminal (may need admin)
```

Then browse to `http://fastapi-demo.127.0.0.1.nip.io`.

**Without a tunnel**, the gateway's data-plane is still reachable from inside the cluster:

```bash
kubectl run tmp --rm -i --restart=Never --image=curlimages/curl -n fastapi-demo -- \
  sh -c "curl -s -H 'Host: fastapi-demo.127.0.0.1.nip.io' http://fastapi-demo-nginx.fastapi-demo.svc.cluster.local/health"
```

---

## 📊 Monitoring

The chart creates a `ServiceMonitor`, so once Prometheus (kube-prometheus-stack) is configured to watch all namespaces, the app's `/metrics` is scraped automatically. Useful queries:

```promql
# Request rate by handler
sum by (handler) (rate(http_requests_total{namespace="fastapi-demo"}[2m]))

# p95 latency
histogram_quantile(0.95, sum by (le, handler) (rate(http_request_duration_seconds_bucket{namespace="fastapi-demo"}[2m])))

# Error ratio (%)
100 * sum(rate(http_requests_total{namespace="fastapi-demo",status=~"[45]xx"}[2m]))
    / sum(rate(http_requests_total{namespace="fastapi-demo"}[2m]))
```

---

## 🔄 How GitOps works here

1. Edit `helm/fastapi-demo/values.yaml` (or any template) and **push to `main`**.
2. Argo CD detects the change (poll ~3 min, or trigger a manual sync).
3. Argo CD applies the rendered manifests to the `fastapi-demo` namespace.
4. With `selfHeal: true`, any out-of-band `kubectl` edits are reverted to match Git.
5. With `prune: true`, resources removed from Git are deleted from the cluster.

**Try it:** bump `replicaCount`, push, and watch the pods scale in Argo CD.

---

## ⚠️ Prerequisites

- A running Kubernetes cluster (this project targets **Minikube**).
- **Argo CD** installed in the `argocd` namespace.
- **Gateway API CRDs** installed (`gatewayclasses`, `gateways`, `httproutes`, ...).
- **NGINX Gateway Fabric** installed (provides the `nginx` GatewayClass).
- **kube-prometheus-stack** (Prometheus + Grafana) for the ServiceMonitor to take effect.

These cluster-level components are installed by the companion setup script in the app repo (`fastapi-demo/scripts/setup-devops-lab.ps1`).
