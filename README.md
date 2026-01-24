# Homelab Kubernetes Infrastructure

GitOps repository for disaster recovery and management of the homelab k3s cluster.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                        k3s Cluster                               │
│                    (golden-minas-tirith)                         │
├─────────────────────────────────────────────────────────────────┤
│  Secrets Layer                                                   │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │              Sealed Secrets Controller                    │   │
│  │   (Decrypts SealedSecrets from Git into K8s Secrets)     │   │
│  └──────────────────────────────────────────────────────────┘   │
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

## Secrets Management

This repo uses **Sealed Secrets** for secure GitOps secrets management:

- Secrets are encrypted with the cluster's public key
- Encrypted secrets (SealedSecrets) are stored in `sealed-secrets/`
- Only the cluster can decrypt them
- Safe to commit to Git

**CRITICAL**: The sealing key must be backed up for disaster recovery!
```bash
./bootstrap/backup-sealing-key.sh
# Encrypt and store the output securely (password manager, etc.)
```

## Directory Structure

```
homelab-k8s-infra/
├── bootstrap/              # Installation & recovery scripts
│   ├── install-k3s.sh     # k3s installation
│   ├── install-argocd.sh  # ArgoCD installation
│   ├── seal-secret.sh     # Seal a new secret
│   ├── backup-sealing-key.sh   # Backup the sealing key (CRITICAL!)
│   └── restore-sealing-key.sh  # Restore sealing key after DR
├── infrastructure/         # Infrastructure ArgoCD apps
│   ├── root-application.yaml  # App of Apps for infra
│   └── apps/
│       ├── sealed-secrets.yaml        # Sealed Secrets controller
│       ├── sealed-secrets-resources.yaml  # Deploy sealed secrets
│       ├── cert-manager.yaml
│       ├── cloudflare-tunnel.yaml
│       ├── datadog-operator.yaml
│       ├── datadog-agent.yaml
│       ├── minio-operator.yaml
│       ├── postgresql.yaml
│       └── tailscale-operator.yaml
├── applications/          # User applications ArgoCD apps
│   ├── root-application.yaml
│   └── apps/
│       ├── msfs-top-aircraft.yaml
│       ├── resume-website.yaml
│       └── vocab-app-staging.yaml
├── sealed-secrets/        # Encrypted secrets (SAFE for Git!)
│   ├── cloudflare-api.yaml
│   ├── datadog-secret.yaml
│   ├── postgresql.yaml
│   ├── msfs-secrets.yaml
│   ├── tailscale-operator-oauth.yaml
│   ├── vocab-app-ghcr-credentials.yaml
│   └── vocab-app-anthropic-secret.yaml
├── manifests/             # Raw Kubernetes manifests
│   └── datadog-agent.yaml
├── secrets-templates/     # Reference templates (for manual creation)
└── docs/
    └── DISASTER_RECOVERY.md
```

## Disaster Recovery Procedure

### Prerequisites
- Fresh Ubuntu 24.04 server
- SSH access
- GitHub CLI (`gh`) authenticated
- **Your encrypted sealing key backup** (sealed-secrets-key-backup.yaml.gpg)

### Step 1: Install k3s
```bash
git clone https://github.com/desponda/homelab-k8s-infra.git
cd homelab-k8s-infra/bootstrap
chmod +x *.sh
./install-k3s.sh
```

### Step 2: Install ArgoCD
```bash
./install-argocd.sh
```

### Step 3: Restore Sealing Key (CRITICAL!)
```bash
# Decrypt your sealing key backup
gpg -d /secure/location/sealed-secrets-key-backup.yaml.gpg > sealed-secrets-key-backup.yaml

# Restore it to the cluster
./restore-sealing-key.sh sealed-secrets-key-backup.yaml

# Securely delete the decrypted file
shred -u sealed-secrets-key-backup.yaml
```

### Step 4: Apply Root Applications
```bash
# Deploy infrastructure (includes sealed-secrets controller and all secrets)
kubectl apply -f ../infrastructure/root-application.yaml

# Wait for sealed-secrets and secrets to be ready
kubectl -n argocd wait --for=condition=healthy application/sealed-secrets --timeout=300s

# Deploy applications
kubectl apply -f ../applications/root-application.yaml
```

### Step 5: Verify
```bash
# Check ArgoCD applications
kubectl get applications -n argocd

# Verify secrets were decrypted
kubectl get secrets -A | grep -v 'default-token\|service-account'

# Check all pods
kubectl get pods -A
```

## Backup Procedures

### Sealing Key Backup (DO THIS ONCE, STORE SECURELY)
```bash
# Backup the sealing key - CRITICAL for disaster recovery!
./bootstrap/backup-sealing-key.sh

# Encrypt it
gpg -c sealed-secrets-key-backup.yaml

# Store sealed-secrets-key-backup.yaml.gpg in:
# - Password manager (1Password, Bitwarden, etc.)
# - Encrypted cloud storage
# - Offline backup

# Delete unencrypted version
shred -u sealed-secrets-key-backup.yaml
```

### Adding/Updating Secrets
With Sealed Secrets, you no longer need to backup secrets separately.
Just seal them and commit to Git:
```bash
# Create a new secret
kubectl create secret generic my-secret \
  --namespace my-ns \
  --from-literal=key=value \
  --dry-run=client -o yaml > /tmp/secret.yaml

# Seal it
./bootstrap/seal-secret.sh /tmp/secret.yaml sealed-secrets/my-secret.yaml

# Clean up and commit
rm /tmp/secret.yaml
git add sealed-secrets/my-secret.yaml
git commit -m "Add sealed secret"
git push
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
