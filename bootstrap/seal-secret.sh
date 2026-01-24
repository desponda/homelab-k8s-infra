#!/bin/bash
set -euo pipefail

# Seal a Kubernetes Secret
# Usage: ./seal-secret.sh <input-secret.yaml> [output-sealed-secret.yaml]
#
# Works with or without cluster access:
# - With cluster access: fetches cert from cluster
# - Without cluster access: uses sealed-secrets-pub-cert.pem from repo

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
PUB_CERT="$REPO_ROOT/sealed-secrets-pub-cert.pem"

INPUT_FILE="${1:-}"
OUTPUT_FILE="${2:-}"

if [[ -z "$INPUT_FILE" ]]; then
    echo "Usage: $0 <input-secret.yaml> [output-sealed-secret.yaml]"
    echo ""
    echo "Examples:"
    echo "  # Seal an existing secret file"
    echo "  $0 my-secret.yaml my-sealed-secret.yaml"
    echo ""
    echo "  # Create and seal a secret in one step"
    echo "  kubectl create secret generic my-secret \\"
    echo "    --namespace my-namespace \\"
    echo "    --from-literal=password=supersecret \\"
    echo "    --dry-run=client -o yaml | $0 /dev/stdin my-sealed-secret.yaml"
    exit 1
fi

if [[ -z "$OUTPUT_FILE" ]]; then
    # Default output: replace .yaml with -sealed.yaml
    OUTPUT_FILE="${INPUT_FILE%.yaml}-sealed.yaml"
fi

# Try cluster first, fall back to cert file
if kubectl cluster-info &>/dev/null; then
    echo "Sealing secret (using cluster)..."
    kubeseal \
        --controller-name=sealed-secrets-controller \
        --controller-namespace=kube-system \
        --format yaml \
        < "$INPUT_FILE" \
        > "$OUTPUT_FILE"
elif [[ -f "$PUB_CERT" ]]; then
    echo "Sealing secret (using public cert - no cluster access)..."
    kubeseal \
        --cert "$PUB_CERT" \
        --format yaml \
        < "$INPUT_FILE" \
        > "$OUTPUT_FILE"
else
    echo "Error: No cluster access and public cert not found at $PUB_CERT"
    echo "Run this from a machine with cluster access, or fetch the cert first:"
    echo "  kubeseal --fetch-cert --controller-name=sealed-secrets-controller --controller-namespace=kube-system > $PUB_CERT"
    exit 1
fi

echo "Sealed secret written to: $OUTPUT_FILE"
echo "This file is safe to commit to Git!"
