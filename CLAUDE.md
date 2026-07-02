# CLAUDE.md — Operating instructions for AI agents

> Si sos un agente IA trabajando en este repo, leé este archivo entero ANTES de tocar nada.
> Para colaboradores humanos: ver [README.md](README.md).

## Identidad del repo

`arc-one-demo-nova` — Nova, Corporate Virtual Assistant. Demo agent del ecosistema [Arc One](https://arc-one.ai/), uno de 3 (Nova / ABI / ARIA) que el Sandbox consume como `ConnectorConfig` externo.

**Origen:** portado desde el MVP `obsydian-mvp` (endpoint `/api/demo/agente-generico`, `SYSTEM_PROMPT_GENERICO` en `src/lib/demo/prompts.ts`).

**Spec canónico:** [`arc-one-master-plan/01_Sandbox/Demo_Agents/Nova_Spec.md`](https://github.com/arc-one-assurance/arc-one-master-plan/blob/main/01_Sandbox/Demo_Agents/Nova_Spec.md)

## Protocolo de arranque

Cada vez que abrís sesión nueva, leé en este orden:

1. Este `CLAUDE.md`
2. [README.md](README.md) — qué hace y cómo correrlo
3. (si la tarea toca contrato) [Contrato_v1_chat.md](https://github.com/arc-one-assurance/arc-one-master-plan/blob/main/01_Sandbox/Demo_Agents/Contrato_v1_chat.md)
4. (si toca narrativa o copy de la UI) [Narrative_Master.md](https://github.com/arc-one-assurance/arc-one-master-plan/blob/main/04_GoToMarket/Narrative_Master.md)

El `CLAUDE.md` org-level está en [arc-one-master-plan](https://github.com/arc-one-assurance/arc-one-master-plan/blob/main/CLAUDE.md) — todo lo que dice ahí aplica acá también.

## Stack canónico (heredado del estándar org)

| Layer | Versión |
|---|---|
| Node | 24 (`.nvmrc`) |
| pnpm | 10 (`packageManager: pnpm@10.0.0`) |
| TypeScript | 6 |
| React | 19 |
| Next.js | 15.5 |
| Tailwind | v4 (vía preset `@arc-one-assurance/design-system/tailwind`) |
| Lint | ESLint 9 flat config |
| Tests | Vitest 3 |

`pnpm` no está en PATH del sistema — usar `corepack pnpm` siempre.

## Convenciones

- **Idioma:** conversación con Tomás en español · código en inglés · commits y docs en español
- **Branch por EPIC:** `epic/[ID]-descripcion` (actual: `epic/s01-demo-agents-extraction`)
- **Una card por turno** · Tomás confirma con `perf` antes de avanzar
- **No correr `pnpm build`** con dev server activo
- **Crear PR contra main explícito** (`gh pr create --base main`) con QA sub-agente al cierre de EPIC
- **Merge a main solo con aprobación explícita**
- **Nunca push directo a main · nunca `--no-verify`**

## Estructura esperada (post-S01)

```
arc-one-demo-nova/
├── src/
│   ├── app/
│   │   ├── api/v1/chat/route.ts    # Endpoint del contrato
│   │   ├── layout.tsx
│   │   └── page.tsx                 # UI mínima de chat (post-MVP, opcional)
│   └── lib/
│       ├── prompts.ts               # SYSTEM_PROMPT v1 + v2
│       ├── client.ts                # Anthropic client wrapper
│       └── auth.ts                  # Validación de token
├── manifests/
│   ├── arc-one.agent.v1.yaml
│   └── arc-one.agent.v2.yaml
├── tests/
│   └── contract.test.ts
├── Dockerfile
└── .github/workflows/ci.yml
```

## Gotchas conocidos

_(vacío al cierre de Card 1 — se actualiza al detectar issues durante extracción/deploy)_

## Comandos rápidos

```bash
corepack pnpm install
corepack pnpm dev          # http://localhost:3000
corepack pnpm typecheck
corepack pnpm lint
corepack pnpm test
corepack pnpm build
```

## Deploy

- **Host:** Cloud Run · `europe-west1` · project `arc-one-demos`
- **Auth:** `ARC_ONE_DEMO_TOKEN` env var (token simétrico compartido con seed Sandbox)
- **CD:** push a main vía GitHub Actions

## Al cerrar sesión / EPIC — protocolo de doble update

Cualquier sesión sustantiva en este repo se cierra en **DOS pasos**, no uno. El master-plan (`arc-one-assurance/arc-one-master-plan`) es la fuente de verdad orquestadora del proyecto Arc One — sin update allí, otro colaborador (humano o IA) que llegue cold no se entera del avance.

### Paso A — Cerrar este repo

1. Actualizar **este `CLAUDE.md`** si surgieron gotchas nuevos o decisiones técnicas locales (sección "Gotchas conocidos")
2. Actualizar **`README.md`** si cambió el comportamiento público o los comandos
3. `git commit` + `git push` en la branch de EPIC

### Paso B — Cerrar el master-plan (siempre)

Path local típico: `/Users/tzanchetti/Documents/Proyectos Claudio/arc-one-master-plan/` (en la máquina del founder) o equivalente en tu entorno.

1. Crear `master-plan/sessions/WS[N]_DDMMAA.md` con resumen completo (decisiones tomadas, cards ejecutadas, pendientes flagueados, próxima sesión)
2. Actualizar `master-plan/STATUS.md` (dashboard) — al menos: última sesión, EPIC actual, milestones tildados
3. Actualizar `master-plan/NEXT.md` (próxima sesión)
4. Tachar checkbox en `master-plan/01_Sandbox/INDICE.md` si la EPIC cerró
5. Actualizar `master-plan/INDICE_MAESTRO.md` si sumás una WS al histórico o cambiás status de mini-proyecto
6. `git commit` + `git push` del repo `master-plan`

### Regla dura

> **Sin update del master-plan, la sesión no está cerrada.**
> Aunque el código compile y el deploy funcione, si STATUS/NEXT/sessions no reflejan el cambio, el círculo virtuoso del proyecto se rompe.

## Permisos y acciones destructivas

- NO push --force, reset --hard, branch -D sin confirmación explícita
- NO bypass hooks (`--no-verify`)
- NO commitear sin pedir
- `git add` por archivos específicos, no `git add .`
