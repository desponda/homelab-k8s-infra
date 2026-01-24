# Secrets Templates

These templates show the structure of secrets required for the homelab cluster.

**NEVER commit actual secret values to git!**

## Restoration Order

When restoring the cluster, create secrets in this order:

1. **cloudflare-tunnel-secret.yaml** - Required for ingress to work
2. **tailscale-secret.yaml** - Required for private access to ArgoCD
3. **datadog-secret.yaml** - Required for monitoring
4. **postgresql-secret.yaml** - Required before PostgreSQL deployment
5. **msfs-secrets.yaml** - Required for MSFS Top Charts app
6. **ghcr-credentials.yaml** - Required for pulling private images

## Creating Secrets

### Option 1: From Templates
```bash
# Edit each template with actual values
vim cloudflare-tunnel-secret.yaml

# Apply (after editing)
kubectl apply -f cloudflare-tunnel-secret.yaml
```

### Option 2: From Encrypted Backup
If you have an encrypted backup of secrets:
```bash
# Decrypt your backup
gpg -d secrets-backup.yaml.gpg > secrets-backup.yaml

# Apply
kubectl apply -f secrets-backup.yaml

# Remove decrypted file
rm secrets-backup.yaml
```

## Backing Up Secrets

To backup current secrets (store securely, NOT in git):
```bash
# Export all secrets
kubectl get secrets --all-namespaces -o yaml > secrets-backup.yaml

# Encrypt with GPG
gpg -c secrets-backup.yaml

# Remove unencrypted file
rm secrets-backup.yaml

# Store secrets-backup.yaml.gpg in a secure location (password manager, etc)
```

## Vocab App Secrets

The vocab-app has additional secrets that are generated via PreSync hooks:
- `vocab-app-database-secret` - Auto-generated if not exists
- `vocab-app-jwt-secret` - Auto-generated if not exists
- `vocab-app-minio-secret` - Auto-generated if not exists
- `vocab-app-anthropic-secret` - Must be manually created with Anthropic API key

For the Anthropic secret:
```bash
kubectl create secret generic vocab-app-anthropic-secret \
  --namespace vocab-app-staging \
  --from-literal=anthropic-api-key="<YOUR_ANTHROPIC_API_KEY>"
```
