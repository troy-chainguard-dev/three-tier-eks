#!/usr/bin/env bash
set -euo pipefail

# Creates an EKS cluster using eksctl with a minimal configuration suitable
# for this demo. Uses a config file for reproducibility.
#
# Prerequisites: eksctl, aws cli (authenticated)
# Usage: ./scripts/01-create-eks-cluster.sh [AWS_REGION]

AWS_REGION="${1:-us-east-1}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CLUSTER_CONFIG="${PROJECT_ROOT}/eksctl-cluster.yaml"

if ! command -v eksctl &>/dev/null; then
  echo "ERROR: eksctl is not installed. Install it from https://eksctl.io/"
  exit 1
fi

echo "==> Creating EKS cluster from ${CLUSTER_CONFIG}..."
echo "    Region: ${AWS_REGION}"
echo "    This typically takes 15-20 minutes."
echo ""

eksctl create cluster -f "$CLUSTER_CONFIG"

echo ""
echo "==> Cluster created! Verifying connectivity..."
kubectl get nodes
echo ""
echo "==> While this was building, you should have already run:"
echo "    ./scripts/02-create-ecr-repos.sh"
echo "    ./scripts/03-push-chainguard-images-to-ecr.sh"
echo ""
echo "==> Next step: run ./scripts/04-deploy-app.sh"
