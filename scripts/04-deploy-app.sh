#!/usr/bin/env bash
set -euo pipefail

# Deploys the three-tier application to EKS.
# Substitutes the ECR registry URI and allowed CIDRs into the Kubernetes manifests.
#
# Usage: ./scripts/04-deploy-app.sh [AWS_REGION]
#
# Environment variables:
#   ALLOWED_CIDRS  Comma-separated CIDRs for LoadBalancer access (e.g. "1.2.3.4/32,5.6.7.8/32")
#                  If not set, auto-detects your current public IP.

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

# Build the allowed CIDRs for the LoadBalancer
if [ -n "${ALLOWED_CIDRS:-}" ]; then
  IFS=',' read -ra CIDR_ARRAY <<< "$ALLOWED_CIDRS"
else
  MY_IP=$(curl -s --connect-timeout 5 https://checkip.amazonaws.com)
  if [ -z "$MY_IP" ]; then
    echo "ERROR: Could not detect your public IP. Set ALLOWED_CIDRS manually:"
    echo '    ALLOWED_CIDRS="1.2.3.4/32,5.6.7.8/32" ./scripts/04-deploy-app.sh'
    exit 1
  fi
  CIDR_ARRAY=("${MY_IP}/32")
  echo "==> Auto-detected your public IP: ${MY_IP}"
fi

# Format CIDRs as YAML list entries
CIDRS_YAML=""
for cidr in "${CIDR_ARRAY[@]}"; do
  cidr=$(echo "$cidr" | xargs)
  CIDRS_YAML="${CIDRS_YAML}    - ${cidr}\n"
done

echo "==> Deploying three-tier app to EKS..."
echo "    Cluster: $(kubectl config current-context)"
echo "    ECR Registry: ${ECR_REGISTRY}"
echo "    Allowed CIDRs: ${CIDR_ARRAY[*]}"
echo ""

# Apply namespace first
kubectl apply -f "${PROJECT_ROOT}/k8s/namespace.yaml"

# Generate manifests with the correct ECR registry URI and allowed CIDRs, then apply
for manifest in postgres.yaml backend.yaml frontend.yaml nginx.yaml; do
  echo "--- Applying ${manifest} ---"
  sed -e "s|{{ECR_REGISTRY}}|${ECR_REGISTRY}|g" \
      -e "s|{{ALLOWED_CIDRS}}|$(echo -e "$CIDRS_YAML")|g" \
    "${PROJECT_ROOT}/k8s/${manifest}" | kubectl apply -f -
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
