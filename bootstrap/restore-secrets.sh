#!/bin/bash
set -euo pipefail

# Secret Restoration Script
# This script helps restore secrets from a backup file
# NEVER commit actual secrets to git!

SECRETS_BACKUP_FILE="${1:-secrets-backup.yaml}"

if [[ ! -f "$SECRETS_BACKUP_FILE" ]]; then
    echo "Error: Secrets backup file not found: $SECRETS_BACKUP_FILE"
    echo ""
    echo "Usage: $0 <path-to-secrets-backup.yaml>"
    echo ""
    echo "To create a backup of current secrets (store securely, NEVER in git):"
    echo "  kubectl get secrets --all-namespaces -o yaml > secrets-backup.yaml"
    echo ""
    echo "For manual secret creation, see templates in ../secrets-templates/"
    exit 1
fi

echo "=== Restoring Secrets ==="
echo "WARNING: This will overwrite existing secrets!"
read -p "Continue? (y/N) " -n 1 -r
echo

if [[ $REPLY =~ ^[Yy]$ ]]; then
    kubectl apply -f "$SECRETS_BACKUP_FILE"
    echo "Secrets restored successfully!"
else
    echo "Aborted."
fi
