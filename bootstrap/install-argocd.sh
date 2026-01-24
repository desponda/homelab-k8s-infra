#!/bin/bash
set -euo pipefail

# ArgoCD Installation Script
# Installs ArgoCD using Helm and configures it for GitOps

ARGOCD_VERSION="9.3.4"
NAMESPACE="argocd"

echo "=== Installing ArgoCD ==="

# Create namespace
kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -

# Add Argo Helm repo
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

# Install ArgoCD
helm upgrade --install argocd argo/argo-cd \
  --namespace ${NAMESPACE} \
  --version ${ARGOCD_VERSION} \
  --wait

# Wait for ArgoCD to be ready
echo "Waiting for ArgoCD to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n ${NAMESPACE}

# Get initial admin password
echo ""
echo "=== ArgoCD Installation Complete ==="
echo ""
echo "Initial admin password:"
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
echo ""
echo ""
echo "To access ArgoCD UI (port-forward):"
echo "  kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo ""
echo "Next steps:"
echo "1. Create required secrets (see ../secrets-templates/)"
echo "2. Apply the root application to bootstrap all infrastructure:"
echo "   kubectl apply -f ../infrastructure/root-application.yaml"
