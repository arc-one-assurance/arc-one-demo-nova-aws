# CLAUDE.md — arc-one-demo-nova-aws

Repo **público PoC BBVA**: agente Nova en AWS ECS Fargate + puente Arc One (`ws_bbva_poc`).

## Identidad

- **Agente:** Nova BBVA read-only · `arc-agent-cea1bba9`
- **Contrato chat:** `POST /api/v1/chat` → `{ input }` → `{ output }`
- **Manifest:** `arc-one.agent.yaml` (único archivo de contrato Arc One)
- **Puente CI:** [arc-one-manifest-tools](https://github.com/arc-one-assurance/arc-one-manifest-tools) `@v1.0.1` — **no** duplicar scripts Python acá

## Estructura relevante

```
arc-one-demo-nova-aws/
├── arc-one.agent.yaml
├── .github/
│   ├── workflows/manifest-pr-preview.yml    # ~15 líneas → reusable workflow
│   ├── workflows/register-with-arc-one.yml
│   └── scripts/patch-manifest-connector.sh
├── scripts/aws/                             # solo infra (maintainers)
├── src/app/api/v1/chat/route.ts
└── docs/GUIA_BBVA.md
```

**No existe** carpeta `manifests/` ni scripts de registro Python — obsoleto.

## Docs

| Audiencia | Doc |
|-----------|-----|
| BBVA (hands-on PoC) | `docs/GUIA_BBVA.md` |
| Cualquier empresa (integrar repo existente) | [CONECTAR_TU_REPO.md](https://github.com/arc-one-assurance/arc-one-manifest-tools/blob/main/docs/CONECTAR_TU_REPO.md) |
| Maintainers secrets/deploy | `docs/CI_SETUP.md` |

## Comandos

```bash
corepack pnpm install
corepack pnpm dev
corepack pnpm typecheck && corepack pnpm lint && corepack pnpm test
```

## Reglas

- No hardcodear URL del ALB en manifest (`__AWS_SERVICE_URL__`)
- Bump `agent_version` si cambia contenido material
- No commitear `.env.ci.local` / `.env.aws.local`
