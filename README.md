# Nova BBVA — AWS ECS Fargate

Nova read-only bancario para la **PoC BBVA** (`ws_bbva_poc` en Arc One).

`POST /api/v1/chat` → `{ "input": "..." }` → `{ "output": "..." }`

**Guía hands-on para el equipo BBVA:** [`docs/GUIA_BBVA.md`](docs/GUIA_BBVA.md)

---

## Quick links

| Recurso | Link |
|---------|------|
| Arc One Sandbox | https://arc-one-sandbox.web.app |
| Agente (chat AWS) | http://nova-bbva-aws-267727640.eu-west-1.elb.amazonaws.com/api/v1/chat |
| agent_id | `arc-agent-cea1bba9` |

**Login PoC:** `tecnico@bbva.assurance.demo` / `BBVAPoC_2026`

---

## Flujo PoC (manifest → nueva versión)

1. Branch → editar `arc-one.agent.yaml` (bump `agent_version` + cambio material)
2. **Pull Request** → workflow **Manifest PR Preview** (CI Gate + dry-run + comentario)
3. **Merge** → workflow **Register with Arc One** publica la versión en `ws_bbva_poc`
4. Verificar en Arc One UI → lanzar assurance Pack 00

---

## Archivo clave: `arc-one.agent.yaml`

- `agent_id`: `arc-agent-cea1bba9` (no cambiar)
- `agent_version`: semver — **obligatorio bump** si cambia contenido material
- `connector.endpointUrl`: placeholder `__AWS_SERVICE_URL__` (CI lo resuelve)

---

## Workflows

| Workflow | Trigger |
|----------|---------|
| **CI** | push / PR |
| **Manifest PR Preview** | PR que toca manifest |
| **Register with Arc One** | merge manifest en `main` |
| **Deploy AWS** | manual (maintainers) |

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

---

## Maintainers (infra AWS / secrets)

Ver [`docs/CI_SETUP.md`](docs/CI_SETUP.md) · secrets en environment `arc-one-registration`.
