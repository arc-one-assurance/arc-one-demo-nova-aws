#!/usr/bin/env bash
# Build Docker image, push to ECR, deploy to ECS Fargate behind ALB.
#
# Usage:
#   source .aws-bootstrap/env.sh   # after bootstrap.sh
#   export ANTHROPIC_API_KEY=...   # only if not using Secrets Manager
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
CLUSTER_NAME="${ECS_CLUSTER_NAME:-nova-bbva-aws}"
SERVICE_NAME="${ECS_SERVICE_NAME:-nova-bbva-aws}"
EXEC_ROLE_ARN="${ECS_EXECUTION_ROLE_ARN:?Run scripts/aws/bootstrap.sh first}"
TASK_ROLE_ARN="${ECS_TASK_ROLE_ARN:?Run scripts/aws/bootstrap.sh first}"
TG_ARN="${TARGET_GROUP_ARN:?Run scripts/aws/bootstrap.sh first}"
ECS_SG_ID="${ECS_SECURITY_GROUP_ID:?Run scripts/aws/bootstrap.sh first}"
ECS_SUBNETS="${ECS_SUBNETS:?Run scripts/aws/bootstrap.sh first}"
LOG_GROUP="${ECS_LOG_GROUP:-/ecs/${SERVICE_NAME}}"
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

export AGENT_VERSION
export ANTHROPIC_SECRET_ARN="${ANTHROPIC_SECRET_ARN:-}"
export ANTHROPIC_API_KEY="${ANTHROPIC_API_KEY:-}"
# Prefer explicit deploy-time API key over Secrets Manager (evita key stale en SM).
if [ -n "${ANTHROPIC_API_KEY}" ]; then
  unset ANTHROPIC_SECRET_ARN
fi
export IMAGE
export EXEC_ROLE_ARN
export TASK_ROLE_ARN
export LOG_GROUP
export AWS_REGION

TASK_DEF_JSON="$(python3 - <<'PY'
import json, os

container = {
    "name": "nova",
    "image": os.environ["IMAGE"],
    "essential": True,
    "portMappings": [{"containerPort": 8080, "protocol": "tcp"}],
    "environment": [{"name": "ARC_ONE_AGENT_VERSION", "value": os.environ["AGENT_VERSION"]}],
    "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
            "awslogs-group": os.environ["LOG_GROUP"],
            "awslogs-region": os.environ["AWS_REGION"],
            "awslogs-stream-prefix": "ecs",
        },
    },
}

if os.environ.get("ANTHROPIC_API_KEY", "").strip():
    container["environment"].append(
        {"name": "ANTHROPIC_API_KEY", "value": os.environ["ANTHROPIC_API_KEY"].strip()}
    )
elif os.environ.get("ANTHROPIC_SECRET_ARN"):
    container["secrets"] = [
        {
            "name": "ANTHROPIC_API_KEY",
            "valueFrom": os.environ["ANTHROPIC_SECRET_ARN"],
        }
    ]

task_def = {
    "family": "nova-bbva-aws",
    "networkMode": "awsvpc",
    "requiresCompatibilities": ["FARGATE"],
    "cpu": "1024",
    "memory": "2048",
    "executionRoleArn": os.environ["EXEC_ROLE_ARN"],
    "taskRoleArn": os.environ["TASK_ROLE_ARN"],
    "containerDefinitions": [container],
}

print(json.dumps(task_def))
PY
)"

echo "→ Registering task definition..."
TASK_DEF_ARN="$(aws ecs register-task-definition \
  --cli-input-json "${TASK_DEF_JSON}" \
  --region "${AWS_REGION}" \
  --query 'taskDefinition.taskDefinitionArn' --output text)"
echo "  ${TASK_DEF_ARN}"

SUBNET_LIST="$(echo "${ECS_SUBNETS}" | tr ' ' ',')"

SERVICE_STATUS="$(aws ecs describe-services \
  --cluster "${CLUSTER_NAME}" \
  --services "${SERVICE_NAME}" \
  --region "${AWS_REGION}" \
  --query 'services[0].status' --output text 2>/dev/null || echo "MISSING")"

if [ "${SERVICE_STATUS}" = "MISSING" ] || [ "${SERVICE_STATUS}" = "None" ] || [ -z "${SERVICE_STATUS}" ]; then
  echo "→ Creating ECS service ${SERVICE_NAME}..."
  aws ecs create-service \
    --cluster "${CLUSTER_NAME}" \
    --service-name "${SERVICE_NAME}" \
    --task-definition "${TASK_DEF_ARN}" \
    --desired-count 1 \
    --launch-type FARGATE \
    --platform-version LATEST \
    --network-configuration "awsvpcConfiguration={subnets=[${SUBNET_LIST}],securityGroups=[${ECS_SG_ID}],assignPublicIp=ENABLED}" \
    --load-balancers "targetGroupArn=${TG_ARN},containerName=nova,containerPort=8080" \
    --health-check-grace-period-seconds 120 \
    --region "${AWS_REGION}" >/dev/null
else
  echo "→ Updating ECS service ${SERVICE_NAME}..."
  aws ecs update-service \
    --cluster "${CLUSTER_NAME}" \
    --service "${SERVICE_NAME}" \
    --task-definition "${TASK_DEF_ARN}" \
    --force-new-deployment \
    --region "${AWS_REGION}" >/dev/null
fi

echo "→ Waiting for service to stabilize (may take 3–5 min)..."
aws ecs wait services-stable \
  --cluster "${CLUSTER_NAME}" \
  --services "${SERVICE_NAME}" \
  --region "${AWS_REGION}"

ALB_DNS="${ALB_DNS:-$(aws elbv2 describe-load-balancers --names nova-bbva-aws --region "${AWS_REGION}" \
  --query 'LoadBalancers[0].DNSName' --output text 2>/dev/null || true)}"
BASE="http://${ALB_DNS}"

echo ""
echo "✅ Deploy complete"
echo "   Service URL: ${BASE}"
echo "   Chat endpoint: ${BASE}/api/v1/chat"
echo ""
echo "Smoke test:"
echo "  curl -s -X POST '${BASE}/api/v1/chat' -H 'Content-Type: application/json' -d '{\"input\":\"Hola\"}'"
echo ""
echo "Update arc-one.agent.yaml / AWS_SERVICE_URL to:"
echo "  ${BASE}"
