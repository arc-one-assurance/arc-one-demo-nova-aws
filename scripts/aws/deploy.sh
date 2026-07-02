#!/usr/bin/env bash
# Build Docker image, push to ECR, create or update App Runner service.
#
# Usage:
#   source .aws-bootstrap/env.sh   # after bootstrap.sh
#   export ANTHROPIC_API_KEY=...   # only if not using Secrets Manager via instance role
#   ./scripts/aws/deploy.sh
#
# Optional: ARC_ONE_AGENT_VERSION=1.0.0 (default)

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

if [ -f "${ROOT}/.aws-bootstrap/env.sh" ]; then
  # shellcheck disable=SC1091
  source "${ROOT}/.aws-bootstrap/env.sh"
fi
if [ -f "${ROOT}/.env.aws.local" ]; then
  set -a
  # shellcheck disable=SC1091
  source "${ROOT}/.env.aws.local"
  set +a
fi

AWS_REGION="${AWS_REGION:-eu-west-1}"
AWS_ACCOUNT_ID="${AWS_ACCOUNT_ID:-$(aws sts get-caller-identity --query Account --output text)}"
ECR_REPO_NAME="${ECR_REPO_NAME:-arc-one/nova-bbva-aws}"
ECR_URI="${ECR_URI:-${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO_NAME}}"
SERVICE_NAME="${APP_RUNNER_SERVICE_NAME:-nova-bbva-aws}"
ACCESS_ROLE_ARN="${APP_RUNNER_ACCESS_ROLE_ARN:?Run scripts/aws/bootstrap.sh first}"
INSTANCE_ROLE_ARN="${APP_RUNNER_INSTANCE_ROLE_ARN:?Run scripts/aws/bootstrap.sh first}"
ANTHROPIC_SECRET_ARN="${ANTHROPIC_SECRET_ARN:-}"
if [ -z "${ANTHROPIC_SECRET_ARN}" ] && [ -z "${ANTHROPIC_API_KEY:-}" ]; then
  echo "Set ANTHROPIC_API_KEY for deploy (Secrets Manager not configured)." >&2
  exit 1
fi
AGENT_VERSION="${ARC_ONE_AGENT_VERSION:-1.0.0}"

TAG="$(git rev-parse --short HEAD 2>/dev/null || echo local)-$(date +%Y%m%d%H%M)"
IMAGE="${ECR_URI}:${TAG}"

echo "→ Building ${IMAGE}"
docker build -t "${IMAGE}" .

echo "→ ECR login"
aws ecr get-login-password --region "${AWS_REGION}" | docker login --username AWS --password-stdin "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

echo "→ Pushing image"
docker push "${IMAGE}"

RUNTIME_ENV='[{"Name":"ARC_ONE_AGENT_VERSION","Value":"'"${AGENT_VERSION}"'"}]'
RUNTIME_SECRETS='[{"Name":"ANTHROPIC_API_KEY","Value":"'"${ANTHROPIC_SECRET_ARN}"'"}]'

if [ -n "${ANTHROPIC_API_KEY:-}" ]; then
  RUNTIME_ENV='[
    {"Name":"ARC_ONE_AGENT_VERSION","Value":"'"${AGENT_VERSION}"'"},
    {"Name":"ANTHROPIC_API_KEY","Value":"'"${ANTHROPIC_API_KEY}"'"}
  ]'
  RUNTIME_SECRETS='[]'
  IMAGE_CONFIG='"RuntimeEnvironmentVariables": '"${RUNTIME_ENV}"
else
  IMAGE_CONFIG='"RuntimeEnvironmentVariables": '"${RUNTIME_ENV}"', "RuntimeEnvironmentSecrets": '"${RUNTIME_SECRETS}"
fi

SERVICE_ARN="$(aws apprunner list-services --region "${AWS_REGION}" \
  --query "ServiceSummaryList[?ServiceName=='${SERVICE_NAME}'].ServiceArn | [0]" --output text 2>/dev/null || true)"

if [ -z "${SERVICE_ARN}" ] || [ "${SERVICE_ARN}" = "None" ]; then
  echo "→ Creating App Runner service ${SERVICE_NAME}..."
  SERVICE_ARN="$(aws apprunner create-service \
    --service-name "${SERVICE_NAME}" \
    --region "${AWS_REGION}" \
    --source-configuration "{
      \"AuthenticationConfiguration\": {
        \"AccessRoleArn\": \"${ACCESS_ROLE_ARN}\"
      },
      \"AutoDeploymentsEnabled\": false,
      \"ImageRepository\": {
        \"ImageIdentifier\": \"${IMAGE}\",
        \"ImageRepositoryType\": \"ECR\",
        \"ImageConfiguration\": {
          \"Port\": \"8080\",
          ${IMAGE_CONFIG}
        }
      }
    }" \
    --instance-configuration "{
      \"Cpu\": \"1024\",
      \"Memory\": \"2048\",
      \"InstanceRoleArn\": \"${INSTANCE_ROLE_ARN}\"
    }" \
    --health-check-configuration "{
      \"Protocol\": \"HTTP\",
      \"Path\": \"/api/v1/chat\",
      \"Interval\": 10,
      \"Timeout\": 5,
      \"HealthyThreshold\": 1,
      \"UnhealthyThreshold\": 3
    }" \
    --query ServiceArn --output text)"
  echo "  Created: ${SERVICE_ARN}"
else
  echo "→ Updating App Runner service ${SERVICE_NAME}..."
  aws apprunner update-service \
    --service-arn "${SERVICE_ARN}" \
    --region "${AWS_REGION}" \
    --source-configuration "{
      \"AuthenticationConfiguration\": {
        \"AccessRoleArn\": \"${ACCESS_ROLE_ARN}\"
      },
      \"AutoDeploymentsEnabled\": false,
      \"ImageRepository\": {
        \"ImageIdentifier\": \"${IMAGE}\",
        \"ImageRepositoryType\": \"ECR\",
        \"ImageConfiguration\": {
          \"Port\": \"8080\",
          ${IMAGE_CONFIG}
        }
      }
    }" \
    --instance-configuration "{
      \"Cpu\": \"1024\",
      \"Memory\": \"2048\",
      \"InstanceRoleArn\": \"${INSTANCE_ROLE_ARN}\"
    }" >/dev/null
fi

echo "→ Waiting for service to be running..."
for _ in $(seq 1 60); do
  STATUS="$(aws apprunner describe-service --service-arn "${SERVICE_ARN}" --region "${AWS_REGION}" \
    --query "Service.Status" --output text)"
  URL="$(aws apprunner describe-service --service-arn "${SERVICE_ARN}" --region "${AWS_REGION}" \
    --query "Service.ServiceUrl" --output text)"
  echo "  status=${STATUS} url=https://${URL}"
  if [ "${STATUS}" = "RUNNING" ]; then
    break
  fi
  sleep 10
done

URL="$(aws apprunner describe-service --service-arn "${SERVICE_ARN}" --region "${AWS_REGION}" \
  --query "Service.ServiceUrl" --output text)"
BASE="https://${URL}"

echo ""
echo "✅ Deploy complete"
echo "   Service URL: ${BASE}"
echo "   Chat endpoint: ${BASE}/api/v1/chat"
echo ""
echo "Smoke test:"
echo "  curl -s -X POST '${BASE}/api/v1/chat' -H 'Content-Type: application/json' -d '{\"input\":\"Hola\"}'"
echo ""
echo "Update arc-one.agent.yaml connector.endpointUrl to:"
echo "  ${BASE}/api/v1/chat"
