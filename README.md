# Nova BBVA — AWS ECS Fargate

Nova read-only bancario para la **PoC BBVA** (`ws_bbva_poc` en Arc One). Mismo contrato que Nova GCP:

`POST /api/v1/chat` → `{ "input": "..." }` → `{ "output": "..." }`

**No toca** `demo@bbva.assurance.demo` ni el Nova en GCP (`ws_demo_bbva`).

---

## Prerrequisitos

1. **Cuenta AWS** con tarjeta ([aws.amazon.com](https://aws.amazon.com))
2. **AWS CLI** + **Docker** en tu Mac
3. **`ANTHROPIC_API_KEY`**
4. En Arc One: login como `tecnico@bbva.assurance.demo` → mint token `arc1_…` (Configuración → API Keys)

---

## Setup AWS (una vez)

```bash
aws configure          # Access Key del usuario IAM
export AWS_REGION=eu-west-1
export ANTHROPIC_API_KEY=sk-ant-...

chmod +x scripts/aws/*.sh
./scripts/aws/bootstrap.sh
```

Crea: ECR, ECS cluster, ALB, target group, security groups, roles IAM, `.aws-bootstrap/env.sh`.

> **App Runner no disponible** en cuentas nuevas → usamos **ECS Fargate + ALB** (mismo Dockerfile, URL estable vía DNS del load balancer).

---

## Deploy ECS

```bash
source .aws-bootstrap/env.sh
./scripts/aws/deploy.sh
```

Copiá la URL que imprime (ej. `http://nova-bbva-aws-xxx.eu-west-1.elb.amazonaws.com/api/v1/chat`).

El ALB usa **HTTP** (sin certificado propio). Para HTTPS en producción: CloudFront delante del ALB o ACM + dominio.

---

## Registro en Arc One (`ws_bbva_poc`)

```bash
cp .env.ci.local.example .env.ci.local
# Editar: ARC_ONE_BEARER_TOKEN=arc1_… (minteado como tecnico@)
#         AWS_SERVICE_URL=http://nova-bbva-aws-xxx.eu-west-1.elb.amazonaws.com

source .env.ci.local
./scripts/register_version.sh --dry-run
./scripts/register_version.sh
```

Tras el **primer** registro, pegá el `agent_id` que devuelve Arc One en `arc-one.agent.yaml` (para CI Gate en versiones futuras).

---

## GitHub Actions (opcional)

Secrets en el repo + environment `arc-one-registration`:

| Secret / var | Uso |
|--------------|-----|
| `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` | Deploy ECS |
| `AWS_REGION` | `eu-west-1` |
| `ANTHROPIC_API_KEY` | Build/deploy |
| `AWS_SERVICE_URL` | URL base del ALB (registro Arc One) |
| `ARC_ONE_API_BASE_URL` | `https://arc-one-sandbox.web.app` |
| `ARC_ONE_BEARER_TOKEN` | Token `arc1_…` de `tecnico@` |
| `ARC_ONE_REGISTRATION_OWNER_USER_ID` | Firebase UID de tecnico |

- **`Deploy AWS`** — `.github/workflows/deploy-aws.yml` (manual)
- **`Register with Arc One`** — push a `arc-one.agent.yaml` en `main`

El usuario IAM `arc-one-deploy` necesita permisos sobre ECS, ECR, ELB, EC2 (SG/VPC read), IAM (roles), CloudWatch Logs.

---

## Smoke test

```bash
curl -s -X POST 'http://YOUR-ALB-DNS/api/v1/chat' \
  -H 'Content-Type: application/json' \
  -d '{"input":"Hola, ¿podés consultar mi saldo?"}'
```

---

## Repo hermano

| Repo | Cloud | Workspace Arc One |
|------|-------|-------------------|
| `arc-one-demo-nova` | GCP Cloud Run | `ws_demo_bbva` (demo interna) |
| **`arc-one-demo-nova-aws`** | **AWS ECS Fargate** | **`ws_bbva_poc`** |
