# CI / GitHub — Nova BBVA AWS → Arc One

Documentación para **maintainers** (secrets, deploy, registro local).

Guía para integrar Arc One en **cualquier repo existente** (compartible):  
[Conectar tu repo a Arc One](https://github.com/arc-one-assurance/arc-one-manifest-tools/blob/main/docs/CONECTAR_TU_REPO.md)

Guía hands-on PoC BBVA: [`GUIA_BBVA.md`](./GUIA_BBVA.md)

---

## Environment `arc-one-registration`

| Secret | Descripción |
|--------|-------------|
| `ARC_ONE_API_BASE_URL` | `https://arc-one-sandbox.web.app` |
| `ARC_ONE_BEARER_TOKEN` | Token `arc1_…` de `tecnico@bbva.assurance.demo` |
| `ARC_ONE_AGENT_ID` | Opcional · YAML trae `arc-agent-cea1bba9` |
| `ARC_ONE_REGISTRATION_OWNER_USER_ID` | UID Firebase del técnico (opcional) |
| `AWS_SERVICE_URL` | Base URL del ALB ECS **sin** `/api/v1/chat` |

También a nivel repo (deploy): `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `ANTHROPIC_API_KEY`.

---

## Crear token Arc One

1. Login `tecnico@bbva.assurance.demo` en [Arc One Sandbox](https://arc-one-sandbox.web.app)
2. **Configuración → API Keys → Crear token**
3. Copiar `arc1_…` → secret `ARC_ONE_BEARER_TOKEN` (solo se muestra una vez)

El token debe crearse en el sandbox desplegado (`ARC_ONE_API_BASE_URL`), no en localhost.

---

## Registro local (debug)

```bash
cp .env.ci.local.example .env.ci.local
# completar ARC_ONE_* y AWS_SERVICE_URL

pip install git+https://github.com/arc-one-assurance/arc-one-manifest-tools@v1.0.1
source .env.ci.local

arc-one-manifest validate arc-one.agent.yaml
chmod +x .github/scripts/patch-manifest-connector.sh
AWS_SERVICE_URL="$AWS_SERVICE_URL" .github/scripts/patch-manifest-connector.sh \
  arc-one.agent.yaml arc-one.agent.resolved.yaml
arc-one-manifest gate arc-one.agent.resolved.yaml
arc-one-manifest register arc-one.agent.resolved.yaml --dry-run
# arc-one-manifest register arc-one.agent.resolved.yaml   # publicar
```

---

## Workflows

| Workflow | Trigger |
|----------|---------|
| **Manifest PR Preview** | PR → `arc-one.agent.yaml` |
| **Register with Arc One** | merge manifest en `main` |
| **Deploy AWS** | manual |
| **CI** | push / PR |

Motor: [arc-one-manifest-tools `@v1.0.1`](https://github.com/arc-one-assurance/arc-one-manifest-tools)

---

## Deploy AWS (maintainers)

```bash
# GitHub Actions → Deploy AWS (manual)
# o local:
source .env.aws.local
./scripts/aws/bootstrap.sh   # primera vez
./scripts/aws/deploy.sh
```

Tras deploy, actualizar `AWS_SERVICE_URL` en el environment si cambió el ALB.
