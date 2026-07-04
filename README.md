# Nova BBVA — AWS ECS Fargate

Nova read-only bancario para la **PoC BBVA** (`ws_bbva_poc` en Arc One).

`POST /api/v1/chat` → `{ "input": "..." }` → `{ "output": "..." }`

| Doc | Para quién |
|-----|------------|
| [`docs/GUIA_BBVA.md`](docs/GUIA_BBVA.md) | Equipo BBVA — flujo PR → merge → nueva versión |
| [Conectar tu repo a Arc One](https://github.com/arc-one-assurance/arc-one-manifest-tools/blob/main/docs/CONECTAR_TU_REPO.md) | Cualquier empresa — qué agregar a un repo **existente** |
| [`docs/CI_SETUP.md`](docs/CI_SETUP.md) | Maintainers — secrets y deploy AWS |

---

## Puente Arc One

Validación, CI Gate y registro: **[arc-one-manifest-tools](https://github.com/arc-one-assurance/arc-one-manifest-tools)** `@v1.0.1`.

Este repo contiene solo:

- `arc-one.agent.yaml` — contrato del agente
- `.github/scripts/patch-manifest-connector.sh` — resuelve URL del ALB en CI
- Dos workflows finos que delegan en el motor compartido

---

## Quick links

| Recurso | Link |
|---------|------|
| Arc One Sandbox | https://arc-one-sandbox.web.app |
| Agente (chat AWS) | http://nova-bbva-aws-267727640.eu-west-1.elb.amazonaws.com/api/v1/chat |
| agent_id | `arc-agent-cea1bba9` |

**Login PoC:** `tecnico@bbva.assurance.demo` / `BBVAPoC_2026`

---

## Flujo PoC

1. Branch → editar `arc-one.agent.yaml` (bump `agent_version` + cambio material)
2. **Pull Request** → **Manifest PR Preview**
3. **Merge** → **Register with Arc One** publica en `ws_bbva_poc`

---

## Workflows

| Workflow | Trigger | Motor |
|----------|---------|-------|
| **CI** | push / PR | typecheck, lint, test, build |
| **Manifest PR Preview** | PR manifest | arc-one-manifest-tools `@v1.0.1` |
| **Register with Arc One** | merge manifest | idem |
| **Deploy AWS** | manual | infra ECS |

---

## Smoke test

```bash
curl -s -X POST 'http://nova-bbva-aws-267727640.eu-west-1.elb.amazonaws.com/api/v1/chat' \
  -H 'Content-Type: application/json' \
  -d '{"input":"Hola, ¿qué podés hacer?"}'
```

---

## Repo hermano

| Repo | Cloud | Workspace |
|------|-------|-----------|
| `arc-one-demo-nova` | GCP Cloud Run | `ws_demo_bbva` |
| **`arc-one-demo-nova-aws`** | **AWS ECS** | **`ws_bbva_poc`** |
