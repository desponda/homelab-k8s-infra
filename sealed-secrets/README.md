# Sealed Secrets

This directory contains encrypted Kubernetes secrets that are safe to store in Git.

## How Sealed Secrets Work

1. **Encryption**: Secrets are encrypted using the cluster's public key
2. **Storage**: Encrypted secrets (SealedSecrets) are stored in Git
3. **Decryption**: Only the Sealed Secrets controller in the cluster can decrypt them
4. **Deployment**: ArgoCD applies SealedSecrets, controller decrypts them into regular Secrets

## Current Sealed Secrets

| File | Namespace | Description |
|------|-----------|-------------|
| cloudflare-api.yaml | cloudflare-tunnel | Cloudflare API credentials |
| datadog-secret.yaml | datadog | Datadog API/App keys |
| tailscale-operator-oauth.yaml | tailscale | Tailscale OAuth credentials |
| postgresql.yaml | postgresql | PostgreSQL password |
| msfs-secrets.yaml | msfs-top-charts | MSFS app secrets |
| vocab-app-ghcr-credentials.yaml | vocab-app-staging | GitHub Container Registry auth |
| vocab-app-anthropic-secret.yaml | vocab-app-staging | Anthropic API key |

## Adding a New Sealed Secret

```bash
# Create the secret (don't apply it)
kubectl create secret generic my-secret \
  --namespace my-namespace \
  --from-literal=key=value \
  --dry-run=client -o yaml > /tmp/my-secret.yaml

# Seal it
./bootstrap/seal-secret.sh /tmp/my-secret.yaml sealed-secrets/my-secret.yaml

# Clean up
rm /tmp/my-secret.yaml

# Commit to git
git add sealed-secrets/my-secret.yaml
git commit -m "Add sealed secret for my-secret"
git push
```

## Updating an Existing Sealed Secret

```bash
# Re-create the secret with new values
kubectl create secret generic existing-secret \
  --namespace existing-namespace \
  --from-literal=key=new-value \
  --dry-run=client -o yaml > /tmp/existing-secret.yaml

# Re-seal it (will overwrite)
./bootstrap/seal-secret.sh /tmp/existing-secret.yaml sealed-secrets/existing-secret.yaml

# Clean up and commit
rm /tmp/existing-secret.yaml
git add sealed-secrets/existing-secret.yaml
git commit -m "Update sealed secret"
git push
```

## Disaster Recovery

**CRITICAL**: The sealing key must be backed up separately!

Without the sealing key, sealed secrets cannot be decrypted after rebuilding the cluster.

### Backup the Sealing Key
```bash
./bootstrap/backup-sealing-key.sh
# Encrypt and store the output securely
```

### Restore the Sealing Key (before applying sealed secrets)
```bash
./bootstrap/restore-sealing-key.sh sealed-secrets-key-backup.yaml
```

## Namespace-Scoped Secrets

Sealed secrets are scoped to their original namespace. A sealed secret created for
namespace `foo` can only be decrypted into namespace `foo`. This is a security feature.

If you need to move a secret to a different namespace, you must re-seal it.
