# Disaster Recovery Guide

This document provides detailed procedures for recovering the homelab k3s cluster from various failure scenarios.

## Recovery Scenarios

### Scenario 1: Complete Server Loss

If the entire server is lost and you need to start from scratch:

#### Prerequisites
- New server with Ubuntu 24.04 LTS
- At least 16GB RAM, 4 CPU cores, 100GB storage
- Network configured with static IP (ideally same as before: 192.168.0.60)
- SSH access
- Your encrypted secrets backup file

#### Recovery Steps

1. **Clone this repository**
   ```bash
   git clone https://github.com/desponda/homelab-k8s-infra.git
   cd homelab-k8s-infra
   ```

2. **Install k3s**
   ```bash
   cd bootstrap
   chmod +x *.sh
   ./install-k3s.sh
   ```

3. **Install ArgoCD**
   ```bash
   ./install-argocd.sh
   ```

4. **Restore secrets**
   ```bash
   # Decrypt your backup
   gpg -d /secure/location/secrets-backup.yaml.gpg > secrets-backup.yaml

   # Restore all secrets
   ./restore-secrets.sh secrets-backup.yaml

   # Securely delete decrypted file
   shred -u secrets-backup.yaml
   ```

5. **Bootstrap infrastructure**
   ```bash
   kubectl apply -f ../infrastructure/root-application.yaml
   ```

6. **Wait for infrastructure**
   ```bash
   # Watch ArgoCD sync
   watch kubectl get applications -n argocd

   # Or wait for specific apps
   kubectl -n argocd wait --for=condition=healthy application/cert-manager --timeout=300s
   kubectl -n argocd wait --for=condition=healthy application/cloudflare-tunnel --timeout=300s
   ```

7. **Deploy applications**
   ```bash
   kubectl apply -f ../applications/root-application.yaml
   ```

8. **Restore database backups** (if needed)
   - See "Database Restoration" section below

### Scenario 2: Corrupt k3s Installation

If k3s is corrupted but the server is intact:

1. **Uninstall k3s**
   ```bash
   /usr/local/bin/k3s-uninstall.sh
   ```

2. **Clean up residual data** (optional, destroys all data)
   ```bash
   sudo rm -rf /var/lib/rancher
   ```

3. **Follow steps 2-8 from Scenario 1**

### Scenario 3: ArgoCD Issues

If ArgoCD is misconfigured or broken:

1. **Reinstall ArgoCD**
   ```bash
   helm uninstall argocd -n argocd
   ./bootstrap/install-argocd.sh
   ```

2. **Re-apply root applications**
   ```bash
   kubectl apply -f infrastructure/root-application.yaml
   kubectl apply -f applications/root-application.yaml
   ```

### Scenario 4: Single Application Recovery

If a single application needs recovery:

1. **Delete and let ArgoCD recreate**
   ```bash
   # Delete the ArgoCD application
   kubectl delete application <app-name> -n argocd

   # ArgoCD will automatically recreate it from the git repo
   ```

2. **Or force a hard refresh**
   ```bash
   argocd app sync <app-name> --force --prune
   ```

## Database Restoration

### PostgreSQL (Shared Database)

1. **Stop applications using the database**
   ```bash
   kubectl scale deployment -n msfs-top-charts --all --replicas=0
   ```

2. **Restore from backup**
   ```bash
   # Copy backup to pod
   kubectl cp postgres-backup.sql postgresql/postgresql-0:/tmp/

   # Restore
   kubectl exec -n postgresql postgresql-0 -- \
     psql -U postgres -f /tmp/postgres-backup.sql
   ```

3. **Restart applications**
   ```bash
   kubectl scale deployment -n msfs-top-charts --all --replicas=1
   ```

### Vocab App PostgreSQL

The vocab-app has its own PostgreSQL instance with automated backups:

```bash
# Check backup PVC
kubectl get pvc -n vocab-app-staging vocab-app-staging-postgres-backup-pvc

# Access backup files
kubectl exec -n vocab-app-staging vocab-app-staging-postgres-0 -- ls /backups/
```

## Cloudflare Tunnel Recovery

If the Cloudflare tunnel needs to be recreated:

1. **Delete old tunnel in Cloudflare dashboard**
   - Go to Cloudflare Zero Trust > Networks > Tunnels
   - Delete the existing tunnel

2. **Create new tunnel**
   - Create a new tunnel with the same name
   - Get the new tunnel token

3. **Update secret**
   ```bash
   kubectl delete secret cloudflare-api -n cloudflare-tunnel
   kubectl apply -f secrets-templates/cloudflare-tunnel-secret.yaml
   ```

4. **Restart tunnel controller**
   ```bash
   kubectl rollout restart deployment -n cloudflare-tunnel
   ```

## Tailscale Recovery

1. **Revoke old device in Tailscale admin**
   - Go to Tailscale admin console
   - Remove the old operator device

2. **Create new OAuth client** (if needed)
   - Go to Tailscale Settings > OAuth clients
   - Create new client with required scopes

3. **Update secret**
   ```bash
   kubectl delete secret operator-oauth -n tailscale
   kubectl apply -f secrets-templates/tailscale-secret.yaml
   ```

## Verification Checklist

After recovery, verify:

- [ ] All pods are running: `kubectl get pods -A`
- [ ] ArgoCD applications are synced: `kubectl get applications -n argocd`
- [ ] Public sites accessible via Cloudflare
  - [ ] dresponda.com
  - [ ] msfstop.dresponda.com
  - [ ] vocab-staging.dresponda.com
- [ ] ArgoCD accessible via Tailscale
- [ ] Datadog receiving metrics
- [ ] Database connections working

## Preventive Measures

### Regular Backups
Set up automated off-site backups:

```bash
# Add to crontab
0 4 * * * kubectl get secrets --all-namespaces -o yaml | gpg -c > /backup/secrets-$(date +\%Y\%m\%d).yaml.gpg
```

### Monitoring
- Datadog alerts configured for pod crashes
- Disk usage monitoring (currently at 78%)

### Documentation
- Keep this repo updated when making changes
- Document any manual configuration not captured in git
