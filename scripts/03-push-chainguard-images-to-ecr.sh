#!/usr/bin/env bash
set -euo pipefail

# Pulls free Chainguard images, builds custom app images, and pushes them to ECR.
#
# This demonstrates the real-world pattern of staging images through a private
# registry before deploying to a Kubernetes cluster.
#
# Usage: ./scripts/03-push-chainguard-images-to-ecr.sh [AWS_REGION]

AWS_REGION="${1:-us-east-1}"
REPO_PREFIX="three-tier-app"
export AWS_PAGER=""
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

echo "==> Authenticating Docker to ECR (${ECR_REGISTRY})..."
aws ecr get-login-password --region "$AWS_REGION" | \
  docker login --username AWS --password-stdin "$ECR_REGISTRY"

PLATFORM="linux/amd64"

echo ""
echo "==> Building and pushing images (platform: ${PLATFORM})..."
echo "    (Chainguard base images will be pulled automatically during build)"
echo ""

# --- nginx ---
echo "--- nginx ---"
docker build --platform "${PLATFORM}" \
  -t "${ECR_REGISTRY}/${REPO_PREFIX}/nginx:latest" \
  -f "${PROJECT_ROOT}/app/nginx/Dockerfile" \
  "${PROJECT_ROOT}/app"
docker push "${ECR_REGISTRY}/${REPO_PREFIX}/nginx:latest"
echo ""

# --- frontend ---
echo "--- frontend ---"
docker build --platform "${PLATFORM}" \
  -t "${ECR_REGISTRY}/${REPO_PREFIX}/frontend:latest" \
  -f "${PROJECT_ROOT}/app/frontend/Dockerfile" \
  "${PROJECT_ROOT}/app/frontend"
docker push "${ECR_REGISTRY}/${REPO_PREFIX}/frontend:latest"
echo ""

# --- backend ---
echo "--- backend ---"
docker build --platform "${PLATFORM}" \
  -t "${ECR_REGISTRY}/${REPO_PREFIX}/backend:latest" \
  -f "${PROJECT_ROOT}/app/backend/Dockerfile" \
  "${PROJECT_ROOT}/app/backend"
docker push "${ECR_REGISTRY}/${REPO_PREFIX}/backend:latest"
echo ""

# --- postgres ---
echo "--- postgres ---"
docker build --platform "${PLATFORM}" \
  -t "${ECR_REGISTRY}/${REPO_PREFIX}/postgres:latest" \
  -f "${PROJECT_ROOT}/app/db/Dockerfile" \
  "${PROJECT_ROOT}/app/db"
docker push "${ECR_REGISTRY}/${REPO_PREFIX}/postgres:latest"
echo ""

echo "==> All images pushed to ECR successfully!"
echo ""
echo "    ${ECR_REGISTRY}/${REPO_PREFIX}/nginx:latest"
echo "    ${ECR_REGISTRY}/${REPO_PREFIX}/frontend:latest"
echo "    ${ECR_REGISTRY}/${REPO_PREFIX}/backend:latest"
echo "    ${ECR_REGISTRY}/${REPO_PREFIX}/postgres:latest"
echo ""
echo "==> Next step: wait for the EKS cluster to finish, then run ./scripts/04-deploy-app.sh"
