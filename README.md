# k8s-gitops-apps

Source of truth for everything that runs on the lab EKS cluster.
ArgoCD watches this repo and reconciles the cluster to match.

## Layout

```
apps/
├── _charts/
│   └── proxy-service/               shared Helm chart for proxy-* services
│                                    (deployment, service, ingress)
├── aws-trivia/                      app: AWS quiz (Kustomize)
│   ├── base/
│   └── overlays/{dev,staging,prod}/
├── pokemon-battle/                  app: Pokemon battle (Kustomize)
│   ├── base/
│   └── overlays/{dev,staging,prod}/
└── proxy-{auth,billing,checkout,inventory,notifications,orders,payments}/
    └── values/{dev,staging,prod}.yaml   per-env values, consume the
                                         shared _charts/proxy-service chart

infra/                               cluster-wide tools and stacks
├── argocd/values.yaml               ArgoCD itself (installed by Terraform)
├── aws-lb-controller/values.yaml    AWS LB Controller (installed by Terraform)
├── external-dns/values.yaml         ExternalDNS (installed by Terraform)
└── monitoring/                      Prom + Grafana — installed by GitHub
    ├── prometheus/                  Actions (NOT ArgoCD), Helm-based.
    │   ├── Chart.yaml + templates/
    │   └── {dev,staging,prod}-values.yaml
    ├── grafana/
    │   ├── Chart.yaml + templates/
    │   └── {dev,staging,prod}-values.yaml
    ├── kube-state-metrics/values.yaml   upstream community chart
    └── node-exporter/values.yaml        upstream community chart

infra/argocd-apps/                   ArgoCD Application objects, picked up
                                     by the bootstrap App-of-Apps in
                                     eks-test-env/argocd_bootstrap.tf

.github/workflows/
└── monitoring-deploy.yml            CI for the monitoring stack (Helm)
```

## Two delivery models, on purpose

Mirrors the DigiCert pattern — different categories of workload, different
delivery mechanisms.

| What | How | Why |
|---|---|---|
| Application services (proxy-*, trivia, pokemon) | **ArgoCD** | Continuous reconciliation, drift visible, Git is the source of truth. |
| Cluster-wide monitoring (Prom, Grafana, exporters) | **GitHub Actions + Helm** | Cluster-level infra installed once per env; treated as platform Day-1 setup, not application Day-2 reconciliation. |

If you only had ArgoCD, you would lose the answer to "why didn't you also put
monitoring in ArgoCD?". Keeping both side by side makes the trade-off real.

## Sync policy by environment (proxy-* services)

| Env | `automated.prune` | `automated.selfHeal` | Net effect |
|---|---|---|---|
| dev | true | true | Drift auto-corrected; resources removed from Git auto-deleted from cluster. |
| staging | false | true | Drift auto-corrected, but pruning is manual. Reduces blast radius if Git is wrong. |
| prod | n/a (no `automated`) | n/a | Manual sync only. Promotion is an intentional click. |

This is the "start conservative in higher envs" pattern — see `infra/argocd-apps/proxy-services-{env}.yaml`.

## How a change reaches the cluster

1. Edit a file under `apps/<app>/overlays/<env>/`.
2. Push to `main`.
3. ArgoCD polls every 3 min (or you trigger refresh) and detects drift.
4. ArgoCD applies the change. Health and sync status are visible in the
   ArgoCD UI (port-forward `kubectl -n argocd port-forward svc/argocd-server 8080:443`).

For the trivia app, CI in [`aws-trivia-game`](https://github.com/yurykuvaev/aws-trivia-game)
auto-bumps the dev overlay's image tag on every successful build. Promotion
to staging/prod is manual (PR copying the tag).

Same flow for [`pokemon-battle`](https://github.com/yurykuvaev/pokemon-battle).

## Bootstrap

`infra/argocd-apps/` does not need to be applied by hand. Terraform in
[`eks-test-env`](https://github.com/yurykuvaev/eks-test-env) creates a
single ArgoCD `Application` named `bootstrap` that points here — ArgoCD
walks the directory and creates one Application per file (App-of-Apps).
