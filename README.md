# Homelab Kubernetes Infrastructure

GitOps repository for disaster recovery and management of the homelab k3s cluster.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                        k3s Cluster                               │
│                    (golden-minas-tirith)                         │
├─────────────────────────────────────────────────────────────────┤
│  Infrastructure Layer (managed by root-infrastructure app)       │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────────────────┐ │
│  │ cert-manager │ │   Tailscale  │ │  Cloudflare Tunnel       │ │
│  │              │ │   Operator   │ │  Ingress Controller      │ │
│  └──────────────┘ └──────────────┘ └──────────────────────────┘ │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────────────────┐ │
│  │   Datadog    │ │    MinIO     │ │      PostgreSQL          │ │
│  │   Operator   │ │   Operator   │ │   (Shared Database)      │ │
│  └──────────────┘ └──────────────┘ └──────────────────────────┘ │
├─────────────────────────────────────────────────────────────────┤
│  Application Layer (managed by root-applications app)            │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────────────────┐ │
│  │ Resume       │ │ MSFS Top     │ │    Vocab App             │ │
│  │ Website      │ │ Aircraft     │ │    (Staging)             │ │
│  └──────────────┘ └──────────────┘ └──────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

## Directory Structure

```
homelab-k8s-infra/
├── bootstrap/              # Installation scripts
│   ├── install-k3s.sh     # k3s installation
│   ├── install-argocd.sh  # ArgoCD installation
│   └── restore-secrets.sh # Secret restoration helper
├── infrastructure/         # Infrastructure ArgoCD apps
│   ├── root-application.yaml  # App of Apps for infra
│   └── apps/              # Individual infra apps
│       ├── cert-manager.yaml
│       ├── cloudflare-tunnel.yaml
│       ├── datadog-operator.yaml
│       ├── datadog-agent.yaml
│       ├── minio-operator.yaml
│       ├── postgresql.yaml
│       └── tailscale-operator.yaml
├── applications/          # User applications ArgoCD apps
│   ├── root-application.yaml  # App of Apps for user apps
│   └── apps/
│       ├── msfs-top-aircraft.yaml
│       ├── resume-website.yaml
│       └── vocab-app-staging.yaml
├── manifests/             # Raw Kubernetes manifests
│   └── datadog-agent.yaml
├── secrets-templates/     # Secret templates (NO ACTUAL SECRETS)
│   ├── README.md
│   ├── cloudflare-tunnel-secret.yaml
│   ├── datadog-secret.yaml
│   ├── ghcr-credentials.yaml
│   ├── msfs-secrets.yaml
│   ├── postgresql-secret.yaml
│   └── tailscale-secret.yaml
└── docs/
    └── DISASTER_RECOVERY.md
```

## Disaster Recovery Procedure

### Prerequisites
- Fresh Ubuntu 24.04 server
- SSH access
- GitHub CLI (`gh`) authenticated
- Your encrypted secrets backup

### Step 1: Install k3s
```bash
cd bootstrap
chmod +x *.sh
./install-k3s.sh
```

### Step 2: Install ArgoCD
```bash
./install-argocd.sh
```

### Step 3: Restore Secrets
```bash
# From encrypted backup
gpg -d /path/to/secrets-backup.yaml.gpg > secrets-backup.yaml
./restore-secrets.sh secrets-backup.yaml
rm secrets-backup.yaml

# Or create secrets manually from templates
kubectl apply -f ../secrets-templates/cloudflare-tunnel-secret.yaml
# ... (see secrets-templates/README.md for order)
```

### Step 4: Apply Root Applications
```bash
# Deploy infrastructure
kubectl apply -f ../infrastructure/root-application.yaml

# Wait for infrastructure to be ready
kubectl -n argocd wait --for=condition=healthy application/cert-manager --timeout=300s

# Deploy applications
kubectl apply -f ../applications/root-application.yaml
```

### Step 5: Verify
```bash
# Check ArgoCD applications
kubectl get applications -n argocd

# Check all pods
kubectl get pods -A
```

## Backup Procedures

### Secrets Backup (DO REGULARLY)
```bash
# Export secrets
kubectl get secrets --all-namespaces \
  -l '!kubernetes.io/service-account-token' \
  -o yaml > secrets-backup.yaml

# Encrypt
gpg -c secrets-backup.yaml

# Store secrets-backup.yaml.gpg securely (NOT in git!)
rm secrets-backup.yaml
```

### Database Backup
The cluster has automated backups configured:
- PostgreSQL: CronJob runs at 2 AM daily
- MinIO: CronJob runs at 3 AM daily

For manual backup:
```bash
# PostgreSQL
kubectl exec -n postgresql postgresql-0 -- \
  pg_dumpall -U postgres > postgres-backup.sql

# Copy backup PVCs data off-cluster periodically
```

## Adding New Applications

1. Create an ArgoCD Application manifest in `applications/apps/`
2. Push to main branch
3. ArgoCD will automatically sync the new application

## Modifying Infrastructure

1. Edit the relevant file in `infrastructure/apps/`
2. Push to main branch
3. ArgoCD will automatically sync the changes

## External Dependencies

This cluster depends on:
- **GitHub** - Application source code repositories
- **Cloudflare** - DNS and tunnel infrastructure
- **Tailscale** - Private VPN network
- **Datadog** - Monitoring (optional)
- **ghcr.io** - Container image registry

## Domains Managed

| Domain | Service |
|--------|---------|
| dresponda.com | Resume Website |
| msfstop.dresponda.com | MSFS Top Aircraft |
| vocab-staging.dresponda.com | Vocab App (Staging) |
| checklists.dresponda.com | PDF Checklists |
| argocd.long-trench.ts.net | ArgoCD (Tailscale) |

## Troubleshooting

### ArgoCD Not Syncing
```bash
# Check application status
argocd app get <app-name>

# Force refresh
argocd app refresh <app-name>

# Check for sync errors
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller
```

### Cloudflare Tunnel Not Working
1. Verify secret exists: `kubectl get secret -n cloudflare-tunnel cloudflare-api`
2. Check tunnel status in Cloudflare dashboard
3. Check controller logs: `kubectl logs -n cloudflare-tunnel -l app.kubernetes.io/name=cloudflare-tunnel-ingress-controller`

### Missing Secrets
Check `secrets-templates/README.md` for the order and requirements of each secret.
