#!/usr/bin/env bash
set -euo pipefail

# Tears down the three-tier app and optionally the EKS cluster.
#
# Usage: ./scripts/05-cleanup.sh [AWS_REGION]
#        ./scripts/05-cleanup.sh [AWS_REGION] --delete-cluster
#        ./scripts/05-cleanup.sh [AWS_REGION] --delete-all    (cluster + ECR repos)

AWS_REGION="${1:-us-east-1}"
DELETE_CLUSTER="${2:-}"
REPO_PREFIX="three-tier-app"
export AWS_PAGER=""
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "==> Removing Kubernetes resources..."
kubectl delete namespace three-tier-app --ignore-not-found
echo "    Namespace deleted."

if [[ "$DELETE_CLUSTER" == "--delete-cluster" || "$DELETE_CLUSTER" == "--delete-all" ]]; then
  echo ""
  echo "==> Deleting EKS cluster (this takes ~10 minutes)..."
  eksctl delete cluster -f "${PROJECT_ROOT}/eksctl-cluster.yaml" --disable-nodegroup-eviction
  echo "    Cluster deleted."
fi

if [[ "$DELETE_CLUSTER" == "--delete-all" ]]; then
  echo ""
  echo "==> Deleting ECR repositories..."
  for repo in nginx frontend backend postgres; do
    echo "    Deleting ${REPO_PREFIX}/${repo}..."
    aws ecr delete-repository \
      --repository-name "${REPO_PREFIX}/${repo}" \
      --region "$AWS_REGION" \
      --force 2>/dev/null || echo "    (not found, skipping)"
  done
  echo "    ECR repositories deleted."
fi

echo ""
echo "==> Cleanup complete!"
