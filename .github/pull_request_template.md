<!--
PR Template — arc-one-demo-nova

Recordá: el master-plan (arc-one-assurance/arc-one-master-plan) es la fuente de
verdad orquestadora del proyecto. Si esta PR cierra una EPIC o cambia status
del proyecto, hay update obligatorio allí también.

Detalle del protocolo: ver sección "Al cerrar sesión / EPIC" en CLAUDE.md.
-->

## Resumen

<!-- 2-3 líneas: qué hace este cambio y por qué -->

## Tipo de cambio

- [ ] feat (nueva funcionalidad)
- [ ] fix (bug fix)
- [ ] refactor (cambio interno sin afectar comportamiento)
- [ ] docs (solo documentación)
- [ ] test (solo tests)
- [ ] chore / ci (build, deps, infra)

## Checklist técnico

- [ ] `corepack pnpm typecheck` ✅
- [ ] `corepack pnpm lint` ✅
- [ ] `corepack pnpm test` ✅ (X/Y passing)
- [ ] `corepack pnpm build` ✅
- [ ] No hay secretos hardcodeados ni `.env*` trackeados
- [ ] Si cambió el comportamiento público o los comandos, `README.md` actualizado
- [ ] Si surgieron gotchas o decisiones técnicas locales, `CLAUDE.md` actualizado

## Master-plan (sección crítica)

> El master-plan es la fuente de verdad orquestadora. Si esta PR **cierra una EPIC** o **mueve un milestone**, los siguientes updates son obligatorios.

- [ ] **N/A** — esta PR no cierra EPIC ni mueve milestones
- [ ] **Cierre de EPIC / milestone:**
  - [ ] `master-plan/STATUS.md` actualizado (última sesión, EPIC actual, milestones tildados)
  - [ ] `master-plan/NEXT.md` actualizado (próxima sesión definida)
  - [ ] `master-plan/01_Sandbox/INDICE.md` con checkbox tachado si aplica
  - [ ] `master-plan/INDICE_MAESTRO.md` si sumaste WS al histórico
  - [ ] `master-plan/sessions/WSN_DDMMAA.md` creado con resumen completo
  - [ ] PR del master-plan abierto / mergeado en paralelo (link: ___)

## Smoke test (si aplica)

<!-- Para cambios que afectan el endpoint público, pegar respuesta del curl -->

```
curl https://nova-51168969386.europe-west1.run.app/api/v1/chat
```
