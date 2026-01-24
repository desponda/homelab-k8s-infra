#!/bin/bash
set -euo pipefail

# Backup Sealed Secrets Controller Key
# CRITICAL: Without this key, you cannot decrypt sealed secrets after disaster recovery!
# Store this backup securely (password manager, encrypted backup, etc.)

export KUBECONFIG=${KUBECONFIG:-/etc/rancher/k3s/k3s.yaml}

OUTPUT_FILE="${1:-sealed-secrets-key-backup.yaml}"

echo "=== Backing up Sealed Secrets Controller Key ==="
echo "CRITICAL: Store this file securely - it's the master key for all sealed secrets!"
echo ""

# Backup the sealing key
kubectl get secret -n kube-system -l sealedsecrets.bitnami.com/sealed-secrets-key -o yaml > "$OUTPUT_FILE"

echo "Key backed up to: $OUTPUT_FILE"
echo ""
echo "IMPORTANT: Encrypt this file before storing!"
echo "  gpg -c $OUTPUT_FILE"
echo ""
echo "Then store sealed-secrets-key-backup.yaml.gpg in a secure location."
echo "Delete the unencrypted file: rm $OUTPUT_FILE"
