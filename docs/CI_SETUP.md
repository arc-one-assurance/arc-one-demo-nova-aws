# CI / GitHub Actions — Nova → Arc One (ws_demo_atlantico)

Registro de nuevas versiones vía push a `arc-one.agent.yaml` en `main` (workflow **Register with Arc One**).

El manifest incluye `agent_id: arc-agent-82f173be` del export de Arc One; el CI Gate lo usa para comparar drift contra la versión registrada.

## Prueba manual vía API (primera vez)

1. Creá token en el sandbox desplegado: login **demo analyst** → **Configuración → API Keys** → copiá `arc1_…` (solo se muestra una vez).
2. Configurá entorno local:

```bash
cp .env.ci.local.example .env.ci.local
# editar: ARC_ONE_API_BASE_URL=https://arc-one-sandbox.web.app + ARC_ONE_BEARER_TOKEN
```

3. Ejecutá (gate → dry-run → apply):

```bash
chmod +x scripts/register_version.sh
source .env.ci.local
./scripts/register_version.sh --dry-run   # solo validar
./scripts/register_version.sh             # publicar versión
```

Equivalente con CLI:

```bash
pip install git+https://github.com/arc-one-assurance/arc-one-manifest-tools@v1.0.0
arc-one-manifest register arc-one.agent.resolved.yaml --dry-run
# POST …/api/agentes/registro-completo?registrationIntent=version
```

**Reglas:**
- `registrationIntent=version` — el agente ya existe (match por `name: Nova` → `nombreCanonico: nova`).
- Si el contenido cambió respecto al export, **debe** subir `agent_version` (semver). Hoy: `1.0.0` en plataforma → `1.1.0` en repo.
- `agent_id` en el YAML es informativo para el CI Gate; la API no lo recibe en el body.

## Secrets (GitHub environment `arc-one-registration`)

| Secret | Descripción |
|--------|-------------|
| `ARC_ONE_API_BASE_URL` | URL de la API Arc One (local: `http://127.0.0.1:8000` · prod: Cloud Run sandbox API) |
| `ARC_ONE_BEARER_TOKEN` | Token `arc1_…` del workspace **Banco Atlántico** (actor: demo analyst) |
| `ARC_ONE_AGENT_ID` | **Opcional** · el manifest trae `agent_id: arc-agent-82f173be`; el gate lo lee del YAML |
| `ARC_ONE_REGISTRATION_OUTBOUND_TOKEN` | Bearer hacia Nova Cloud Run (`ARC_ONE_DEMO_TOKEN` del servicio Nova) |

`ARC_ONE_DEBUG_SUB` **no** usar contra API en modo Firebase/producción.

## Crear token `arc1_…` (ya soportado en sandbox)

1. Login como **demo analyst** (`demo.analyst@riesgo.bancoatlantico.demo`) en el sandbox.
2. **Configuración → API Keys → Crear token** (label p.ej. `nova-ci-github`).
3. Copiá el valor `arc1_…` **una sola vez** → secret `ARC_ONE_BEARER_TOKEN`.

> **⚠️ Prod vs local:** el token vive en la **base de datos del sandbox desplegado**
> (`ARC_ONE_API_BASE_URL`, p. ej. `https://arc-one-sandbox.web.app`). Un `arc1_…` generado
> contra `localhost:8000` **no sirve** en GitHub Actions.

Alternativa API (modo dev local):

```bash
curl -X POST -H "X-ArcOne-Debug-Sub: user_demo_arc_one" \
  -H "Content-Type: application/json" \
  http://127.0.0.1:8000/api/workspace/automation-tokens \
  -d '{"label":"nova-ci-github"}'
```

## Flujo local (antes del push)

```bash
pip install git+https://github.com/arc-one-assurance/arc-one-manifest-tools@v1.0.0

export ARC_ONE_API_BASE_URL=http://127.0.0.1:8000
export ARC_ONE_BEARER_TOKEN=arc1_…   # o ARC_ONE_DEBUG_SUB=user_demo_arc_one en dev

arc-one-manifest validate arc-one.agent.yaml
arc-one-manifest gate arc-one.agent.yaml
arc-one-manifest register arc-one.agent.yaml --dry-run
arc-one-manifest register arc-one.agent.yaml
```

## Nova Cloud Run — auth outbound

El endpoint `/api/v1/chat` exige `Authorization: Bearer <ARC_ONE_DEMO_TOKEN>`.

- En **registro CI**: pasar el mismo valor en `ARC_ONE_REGISTRATION_OUTBOUND_TOKEN` (se cifra en Arc One si `ARC_ONE_FERNET_KEY` está configurado).
- En **UI**: Configuración → API Keys → token outbound del agente Nova.

Campos del contrato: `input` / `output` (no `prompt` / `response`).
