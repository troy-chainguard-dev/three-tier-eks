#!/usr/bin/env bash
set -euo pipefail

# Deploys the three-tier application to EKS.
# Substitutes the ECR registry URI into the Kubernetes manifests and applies them.
#
# Usage: ./scripts/04-deploy-app.sh [AWS_REGION]

AWS_REGION="${1:-us-east-1}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
export AWS_PAGER=""

# Verify kubectl can reach the cluster before doing anything
if ! kubectl cluster-info &>/dev/null; then
  echo "ERROR: kubectl cannot connect to a cluster."
  echo ""
  echo "If you used script 01 to create a cluster, eksctl should have configured kubectl automatically."
  echo ""
  echo "If you're using an existing EKS cluster, update your kubeconfig first:"
  echo "    aws eks update-kubeconfig --name <CLUSTER_NAME> --region ${AWS_REGION}"
  echo ""
  echo "Available clusters in ${AWS_REGION}:"
  aws eks list-clusters --region "$AWS_REGION" --query 'clusters[]' --output table 2>/dev/null || echo "    (could not list clusters)"
  exit 1
fi

AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

echo "==> Deploying three-tier app to EKS..."
echo "    Cluster: $(kubectl config current-context)"
echo "    ECR Registry: ${ECR_REGISTRY}"
echo ""

# Apply namespace first
kubectl apply -f "${PROJECT_ROOT}/k8s/namespace.yaml"

# Generate manifests with the correct ECR registry URI and apply
for manifest in postgres.yaml backend.yaml frontend.yaml nginx.yaml; do
  echo "--- Applying ${manifest} ---"
  sed "s|{{ECR_REGISTRY}}|${ECR_REGISTRY}|g" "${PROJECT_ROOT}/k8s/${manifest}" | kubectl apply -f -
done

echo ""
echo "==> Waiting for deployments to be ready..."
kubectl -n three-tier-app wait --for=condition=available deployment --all --timeout=300s

echo ""
echo "==> Deployment complete! Getting service info..."
echo ""
kubectl -n three-tier-app get pods
echo ""
kubectl -n three-tier-app get svc

echo ""
echo "==> To access the app, get the nginx LoadBalancer URL:"
echo '    kubectl -n three-tier-app get svc nginx -o jsonpath="{.status.loadBalancer.ingress[0].hostname}"'
echo ""
echo "    Note: DNS propagation for the ELB may take a few minutes."
