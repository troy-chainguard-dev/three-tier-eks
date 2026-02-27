#!/usr/bin/env bash
set -euo pipefail

# Creates ECR repositories for each component of the three-tier app.
# Usage: ./scripts/02-create-ecr-repos.sh [AWS_REGION]

AWS_REGION="${1:-us-east-1}"
REPO_PREFIX="three-tier-app"
export AWS_PAGER=""

REPOS=(
  "${REPO_PREFIX}/nginx"
  "${REPO_PREFIX}/frontend"
  "${REPO_PREFIX}/backend"
  "${REPO_PREFIX}/postgres"
)

echo "==> Creating ECR repositories in ${AWS_REGION}..."

for repo in "${REPOS[@]}"; do
  if aws ecr describe-repositories --repository-names "$repo" --region "$AWS_REGION" &>/dev/null; then
    echo "    [exists] $repo"
  else
    aws ecr create-repository \
      --repository-name "$repo" \
      --region "$AWS_REGION" \
      --image-scanning-configuration scanOnPush=true \
      --encryption-configuration encryptionType=AES256 \
      --output text --query 'repository.repositoryUri'
    echo "    [created] $repo"
  fi
done

AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo ""
echo "==> ECR repositories ready. Your registry URI is:"
echo "    ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
echo ""
echo "==> Next step: run ./scripts/03-push-chainguard-images-to-ecr.sh"
