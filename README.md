# k8s-gitops-apps

Source of truth for everything that runs on the lab EKS cluster.
ArgoCD watches this repo and reconciles the cluster to match.

## Layout

```
apps/
├── aws-trivia/                      app: AWS quiz
│   ├── base/                        shared manifests
│   └── overlays/{dev,staging,prod}/ per-env tweaks
└── pokemon-battle/                  app: Pokemon battle game
    ├── base/
    └── overlays/{dev,staging,prod}/

infra/                               cluster-wide tools (values.yaml only —
│                                    Terraform installs them via Helm)
├── argocd/values.yaml
├── aws-lb-controller/values.yaml
└── external-dns/values.yaml

infra/argocd-apps/                   ArgoCD Application objects, picked up
                                     by the bootstrap App-of-Apps in
                                     eks-test-env/argocd_bootstrap.tf
```

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
