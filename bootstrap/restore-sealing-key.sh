#!/bin/bash
set -euo pipefail

# Restore Sealed Secrets Controller Key
# Run this BEFORE applying sealed secrets after disaster recovery

export KUBECONFIG=${KUBECONFIG:-/etc/rancher/k3s/k3s.yaml}

KEY_BACKUP_FILE="${1:-sealed-secrets-key-backup.yaml}"

if [[ ! -f "$KEY_BACKUP_FILE" ]]; then
    echo "Error: Key backup file not found: $KEY_BACKUP_FILE"
    echo ""
    echo "Usage: $0 <path-to-key-backup.yaml>"
    echo ""
    echo "If you have an encrypted backup:"
    echo "  gpg -d sealed-secrets-key-backup.yaml.gpg > sealed-secrets-key-backup.yaml"
    exit 1
fi

echo "=== Restoring Sealed Secrets Controller Key ==="
echo "This will allow the cluster to decrypt existing sealed secrets."
echo ""

# Apply the key backup
kubectl apply -f "$KEY_BACKUP_FILE"

# Restart the controller to pick up the key
echo "Restarting sealed-secrets controller..."
kubectl rollout restart deployment sealed-secrets-controller -n kube-system
kubectl rollout status deployment sealed-secrets-controller -n kube-system

echo ""
echo "Key restored successfully!"
echo "The controller can now decrypt sealed secrets created with this key."
