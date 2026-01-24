#!/bin/bash
set -euo pipefail

# Seal a Kubernetes Secret
# Usage: ./seal-secret.sh <input-secret.yaml> [output-sealed-secret.yaml]

export KUBECONFIG=${KUBECONFIG:-/etc/rancher/k3s/k3s.yaml}

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

echo "Sealing secret..."
kubeseal \
    --controller-name=sealed-secrets-controller \
    --controller-namespace=kube-system \
    --format yaml \
    < "$INPUT_FILE" \
    > "$OUTPUT_FILE"

echo "Sealed secret written to: $OUTPUT_FILE"
echo "This file is safe to commit to Git!"
