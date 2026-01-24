#!/bin/bash
set -euo pipefail

# k3s Installation Script for Homelab
# This script installs k3s with the same configuration as the original golden-minas-tirith server

echo "=== Installing k3s ==="

# Install k3s (single node, no traefik - we use cloudflare tunnel instead)
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server \
  --disable traefik \
  --write-kubeconfig-mode 644" sh -

# Wait for k3s to be ready
echo "Waiting for k3s to be ready..."
sleep 10

# Set up kubeconfig
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $(id -u):$(id -g) ~/.kube/config
export KUBECONFIG=~/.kube/config

# Verify installation
echo "=== Verifying k3s installation ==="
kubectl get nodes
kubectl get pods -A

echo "=== k3s installation complete ==="
echo ""
echo "Next steps:"
echo "1. Run ./install-argocd.sh to install ArgoCD"
echo "2. Create secrets using templates in ../secrets-templates/"
echo "3. Apply the root application: kubectl apply -f ../infrastructure/root-application.yaml"
