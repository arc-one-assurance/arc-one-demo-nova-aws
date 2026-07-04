#!/usr/bin/env bash
# One-time AWS bootstrap for Nova BBVA on ECS Fargate + ALB.
#
# Prerequisites:
#   - AWS account + `aws configure` (IAM user with admin or PowerUser for first run)
#   - Docker installed locally (for first manual deploy) OR use GitHub Actions after this
#
# Usage:
#   export AWS_REGION=eu-west-1
#   export ANTHROPIC_API_KEY=sk-ant-...
#   ./scripts/aws/bootstrap.sh

set -euo pipefail

AWS_REGION="${AWS_REGION:-eu-west-1}"
CLUSTER_NAME="${ECS_CLUSTER_NAME:-nova-bbva-aws}"
SERVICE_NAME="${ECS_SERVICE_NAME:-nova-bbva-aws}"
ECR_REPO="${ECR_REPO_NAME:-arc-one/nova-bbva-aws}"
SECRET_NAME="${ANTHROPIC_SECRET_NAME:-arc-one/nova-bbva-aws/anthropic-api-key}"
ALB_NAME="${ALB_NAME:-nova-bbva-aws}"
TG_NAME="${TARGET_GROUP_NAME:-nova-bbva-aws-tg}"
LOG_GROUP="/ecs/${SERVICE_NAME}"

if ! command -v aws >/dev/null 2>&1; then
  echo "Install AWS CLI: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html" >&2
  exit 1
fi

ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
ECR_URI="${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO}"

echo "Account: ${ACCOUNT_ID} · Region: ${AWS_REGION}"
echo "ECR: ${ECR_URI}"
echo "ECS: ${CLUSTER_NAME} / ${SERVICE_NAME}"
echo ""

# ── ECR ──────────────────────────────────────────────────────────────────────
if ! aws ecr describe-repositories --repository-names "${ECR_REPO}" --region "${AWS_REGION}" >/dev/null 2>&1; then
  echo "→ Creating ECR repository ${ECR_REPO}..."
  aws ecr create-repository \
    --repository-name "${ECR_REPO}" \
    --image-scanning-configuration scanOnPush=true \
    --region "${AWS_REGION}" >/dev/null
else
  echo "→ ECR repository ${ECR_REPO} already exists"
fi

# ── Secrets Manager (optional) ───────────────────────────────────────────────
SECRET_ARN=""
if ! aws secretsmanager describe-secret --secret-id "${SECRET_NAME}" --region "${AWS_REGION}" >/dev/null 2>&1; then
  if [ -n "${ANTHROPIC_API_KEY:-}" ]; then
    echo "→ Creating secret ${SECRET_NAME}..."
    if aws secretsmanager create-secret \
      --name "${SECRET_NAME}" \
      --secret-string "${ANTHROPIC_API_KEY}" \
      --region "${AWS_REGION}" >/dev/null 2>&1; then
      SECRET_ARN="$(aws secretsmanager describe-secret --secret-id "${SECRET_NAME}" --region "${AWS_REGION}" --query ARN --output text)"
    else
      echo "→ Secrets Manager unavailable — deploy will use ANTHROPIC_API_KEY env var"
    fi
  else
    echo "→ Skipping Secrets Manager (pass ANTHROPIC_API_KEY at deploy time)"
  fi
else
  echo "→ Secret ${SECRET_NAME} already exists"
  if [ -n "${ANTHROPIC_API_KEY:-}" ]; then
    aws secretsmanager put-secret-value \
      --secret-id "${SECRET_NAME}" \
      --secret-string "${ANTHROPIC_API_KEY}" \
      --region "${AWS_REGION}" >/dev/null
  fi
  SECRET_ARN="$(aws secretsmanager describe-secret --secret-id "${SECRET_NAME}" --region "${AWS_REGION}" --query ARN --output text)"
fi

# ── ECS cluster ──────────────────────────────────────────────────────────────
if ! aws ecs describe-clusters --clusters "${CLUSTER_NAME}" --region "${AWS_REGION}" \
  --query "clusters[?status=='ACTIVE'].clusterName | [0]" --output text 2>/dev/null | grep -q "${CLUSTER_NAME}"; then
  echo "→ Creating ECS cluster ${CLUSTER_NAME}..."
  aws ecs create-cluster --cluster-name "${CLUSTER_NAME}" --region "${AWS_REGION}" >/dev/null
else
  echo "→ ECS cluster ${CLUSTER_NAME} already exists"
fi

# ── CloudWatch logs ──────────────────────────────────────────────────────────
if ! aws logs describe-log-groups --log-group-name-prefix "${LOG_GROUP}" --region "${AWS_REGION}" \
  --query "logGroups[?logGroupName=='${LOG_GROUP}'].logGroupName | [0]" --output text | grep -q "${LOG_GROUP}"; then
  echo "→ Creating log group ${LOG_GROUP}..."
  aws logs create-log-group --log-group-name "${LOG_GROUP}" --region "${AWS_REGION}"
else
  echo "→ Log group ${LOG_GROUP} already exists"
fi

# ── IAM: task execution role (ECR pull + logs) ───────────────────────────────
EXEC_ROLE_NAME="${ECS_EXECUTION_ROLE:-NovaBbvaEcsExecutionRole}"
if ! aws iam get-role --role-name "${EXEC_ROLE_NAME}" >/dev/null 2>&1; then
  echo "→ Creating ECS execution role ${EXEC_ROLE_NAME}..."
  aws iam create-role \
    --role-name "${EXEC_ROLE_NAME}" \
    --assume-role-policy-document '{
      "Version": "2012-10-17",
      "Statement": [{
        "Effect": "Allow",
        "Principal": { "Service": "ecs-tasks.amazonaws.com" },
        "Action": "sts:AssumeRole"
      }]
    }' >/dev/null
  aws iam attach-role-policy \
    --role-name "${EXEC_ROLE_NAME}" \
    --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy
  if [ -n "${SECRET_ARN}" ]; then
    aws iam put-role-policy \
      --role-name "${EXEC_ROLE_NAME}" \
      --policy-name NovaBbvaSecretsRead \
      --policy-document "$(cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": ["secretsmanager:GetSecretValue"],
    "Resource": "${SECRET_ARN}"
  }]
}
EOF
)"
  fi
  sleep 10
else
  echo "→ ECS execution role ${EXEC_ROLE_NAME} already exists"
fi
EXEC_ROLE_ARN="$(aws iam get-role --role-name "${EXEC_ROLE_NAME}" --query Role.Arn --output text)"

# ── IAM: task role (runtime — optional, reserved for future use) ─────────────
TASK_ROLE_NAME="${ECS_TASK_ROLE:-NovaBbvaEcsTaskRole}"
if ! aws iam get-role --role-name "${TASK_ROLE_NAME}" >/dev/null 2>&1; then
  echo "→ Creating ECS task role ${TASK_ROLE_NAME}..."
  aws iam create-role \
    --role-name "${TASK_ROLE_NAME}" \
    --assume-role-policy-document '{
      "Version": "2012-10-17",
      "Statement": [{
        "Effect": "Allow",
        "Principal": { "Service": "ecs-tasks.amazonaws.com" },
        "Action": "sts:AssumeRole"
      }]
    }' >/dev/null
  sleep 5
else
  echo "→ ECS task role ${TASK_ROLE_NAME} already exists"
fi
TASK_ROLE_ARN="$(aws iam get-role --role-name "${TASK_ROLE_NAME}" --query Role.Arn --output text)"

# ── Default VPC + subnets ────────────────────────────────────────────────────
VPC_ID="$(aws ec2 describe-vpcs --filters Name=isDefault,Values=true --region "${AWS_REGION}" \
  --query 'Vpcs[0].VpcId' --output text)"
if [ -z "${VPC_ID}" ] || [ "${VPC_ID}" = "None" ]; then
  echo "No default VPC found in ${AWS_REGION}. Create a VPC with public subnets first." >&2
  exit 1
fi
SUBNET_IDS="$(aws ec2 describe-subnets --filters Name=vpc-id,Values="${VPC_ID}" --region "${AWS_REGION}" \
  --query 'Subnets[*].SubnetId' --output text | tr '\t' ' ')"
SUBNET_ARRAY=(${SUBNET_IDS})
if [ "${#SUBNET_ARRAY[@]}" -lt 2 ]; then
  echo "Need at least 2 subnets in default VPC for ALB." >&2
  exit 1
fi
echo "→ Using default VPC ${VPC_ID} · subnets: ${SUBNET_IDS}"

# ── Security groups ──────────────────────────────────────────────────────────
ALB_SG_NAME="nova-bbva-aws-alb-sg"
ECS_SG_NAME="nova-bbva-aws-ecs-sg"

ALB_SG_ID="$(aws ec2 describe-security-groups --filters "Name=group-name,Values=${ALB_SG_NAME}" "Name=vpc-id,Values=${VPC_ID}" \
  --region "${AWS_REGION}" --query 'SecurityGroups[0].GroupId' --output text 2>/dev/null || true)"
if [ -z "${ALB_SG_ID}" ] || [ "${ALB_SG_ID}" = "None" ]; then
  echo "→ Creating ALB security group..."
  ALB_SG_ID="$(aws ec2 create-security-group \
    --group-name "${ALB_SG_NAME}" \
    --description "Nova BBVA ALB" \
    --vpc-id "${VPC_ID}" \
    --region "${AWS_REGION}" \
    --query GroupId --output text)"
  aws ec2 authorize-security-group-ingress \
    --group-id "${ALB_SG_ID}" \
    --protocol tcp --port 80 --cidr 0.0.0.0/0 \
    --region "${AWS_REGION}" >/dev/null
else
  echo "→ ALB security group ${ALB_SG_NAME} already exists"
fi

ECS_SG_ID="$(aws ec2 describe-security-groups --filters "Name=group-name,Values=${ECS_SG_NAME}" "Name=vpc-id,Values=${VPC_ID}" \
  --region "${AWS_REGION}" --query 'SecurityGroups[0].GroupId' --output text 2>/dev/null || true)"
if [ -z "${ECS_SG_ID}" ] || [ "${ECS_SG_ID}" = "None" ]; then
  echo "→ Creating ECS task security group..."
  ECS_SG_ID="$(aws ec2 create-security-group \
    --group-name "${ECS_SG_NAME}" \
    --description "Nova BBVA ECS tasks" \
    --vpc-id "${VPC_ID}" \
    --region "${AWS_REGION}" \
    --query GroupId --output text)"
  aws ec2 authorize-security-group-ingress \
    --group-id "${ECS_SG_ID}" \
    --protocol tcp --port 8080 \
    --source-group "${ALB_SG_ID}" \
    --region "${AWS_REGION}" >/dev/null
else
  echo "→ ECS security group ${ECS_SG_NAME} already exists"
fi

# ── Application Load Balancer ────────────────────────────────────────────────
ALB_ARN="$(aws elbv2 describe-load-balancers --names "${ALB_NAME}" --region "${AWS_REGION}" \
  --query 'LoadBalancers[0].LoadBalancerArn' --output text 2>/dev/null || true)"
if [ -z "${ALB_ARN}" ] || [ "${ALB_ARN}" = "None" ]; then
  echo "→ Creating ALB ${ALB_NAME}..."
  ALB_ARN="$(aws elbv2 create-load-balancer \
    --name "${ALB_NAME}" \
    --type application \
    --scheme internet-facing \
    --subnets ${SUBNET_IDS} \
    --security-groups "${ALB_SG_ID}" \
    --region "${AWS_REGION}" \
    --query 'LoadBalancers[0].LoadBalancerArn' --output text)"
  echo "  Waiting for ALB to become active..."
  aws elbv2 wait load-balancer-available --load-balancer-arns "${ALB_ARN}" --region "${AWS_REGION}"
else
  echo "→ ALB ${ALB_NAME} already exists"
fi
ALB_DNS="$(aws elbv2 describe-load-balancers --load-balancer-arns "${ALB_ARN}" --region "${AWS_REGION}" \
  --query 'LoadBalancers[0].DNSName' --output text)"

# ── Target group ─────────────────────────────────────────────────────────────
TG_ARN="$(aws elbv2 describe-target-groups --names "${TG_NAME}" --region "${AWS_REGION}" \
  --query 'TargetGroups[0].TargetGroupArn' --output text 2>/dev/null || true)"
if [ -z "${TG_ARN}" ] || [ "${TG_ARN}" = "None" ]; then
  echo "→ Creating target group ${TG_NAME}..."
  TG_ARN="$(aws elbv2 create-target-group \
    --name "${TG_NAME}" \
    --protocol HTTP \
    --port 8080 \
    --vpc-id "${VPC_ID}" \
    --target-type ip \
    --health-check-protocol HTTP \
    --health-check-path "/api/v1/chat" \
    --health-check-interval-seconds 30 \
    --healthy-threshold-count 2 \
    --unhealthy-threshold-count 3 \
    --region "${AWS_REGION}" \
    --query 'TargetGroups[0].TargetGroupArn' --output text)"
else
  echo "→ Target group ${TG_NAME} already exists"
fi

# ── ALB listener (HTTP 80) ───────────────────────────────────────────────────
LISTENER_ARN="$(aws elbv2 describe-listeners --load-balancer-arn "${ALB_ARN}" --region "${AWS_REGION}" \
  --query 'Listeners[?Port==`80`].ListenerArn | [0]' --output text 2>/dev/null || true)"
if [ -z "${LISTENER_ARN}" ] || [ "${LISTENER_ARN}" = "None" ]; then
  echo "→ Creating ALB listener (HTTP 80)..."
  aws elbv2 create-listener \
    --load-balancer-arn "${ALB_ARN}" \
    --protocol HTTP \
    --port 80 \
    --default-actions "Type=forward,TargetGroupArn=${TG_ARN}" \
    --region "${AWS_REGION}" >/dev/null
else
  echo "→ ALB listener already exists"
fi

mkdir -p "$(dirname "$0")/../../.aws-bootstrap"
cat > "$(dirname "$0")/../../.aws-bootstrap/env.sh" <<EOF
# Generated by scripts/aws/bootstrap.sh — source before deploy
export AWS_REGION=${AWS_REGION}
export AWS_ACCOUNT_ID=${ACCOUNT_ID}
export ECR_REPO_NAME=${ECR_REPO}
export ECR_URI=${ECR_URI}
export ECS_CLUSTER_NAME=${CLUSTER_NAME}
export ECS_SERVICE_NAME=${SERVICE_NAME}
export ECS_EXECUTION_ROLE_ARN=${EXEC_ROLE_ARN}
export ECS_TASK_ROLE_ARN=${TASK_ROLE_ARN}
export ECS_SUBNETS="${SUBNET_IDS}"
export ECS_SECURITY_GROUP_ID=${ECS_SG_ID}
export ALB_ARN=${ALB_ARN}
export ALB_DNS=${ALB_DNS}
export TARGET_GROUP_ARN=${TG_ARN}
export ANTHROPIC_SECRET_ARN=${SECRET_ARN}
export ANTHROPIC_SECRET_NAME=${SECRET_NAME}
export ECS_LOG_GROUP=${LOG_GROUP}
export AWS_SERVICE_URL=http://${ALB_DNS}
EOF

echo ""
echo "✅ Bootstrap complete. Saved .aws-bootstrap/env.sh"
echo ""
echo "Service URL (HTTP): http://${ALB_DNS}"
echo "Chat endpoint:      http://${ALB_DNS}/api/v1/chat"
echo ""
echo "Next:"
echo "  1. source .aws-bootstrap/env.sh"
echo "  2. ./scripts/aws/deploy.sh"
echo "  3. Mint Arc One token as tecnico@bbva → register (see README)"
echo ""
echo "Note: ALB uses HTTP. For HTTPS add CloudFront or ACM + custom domain."
