## Resumen

<!-- ¿Qué cambia en el manifest y por qué? -->

## Tipo de cambio

- [ ] **Manifest** — nueva versión del agente Nova BBVA AWS (PoC)
- [ ] Código del agente (runtime / prompt en código)
- [ ] Infra AWS / CI
- [ ] Documentación

## Checklist manifest (PoC BBVA)

- [ ] Editaste `arc-one.agent.yaml`
- [ ] Subiste `agent_version` (semver) si el contenido cambió de verdad
- [ ] **No** hardcodeaste la URL del ALB (`connector` usa `__AWS_SERVICE_URL__`)
- [ ] El workflow **Manifest PR Preview** pasó (CI Gate + dry-run)
- [ ] Revisaste el comentario automático del bot en este PR

## Después del merge

- [ ] Verificar nueva versión en [Arc One Sandbox](https://arc-one-sandbox.web.app) (login `tecnico@bbva.assurance.demo`, workspace BBVA PoC)
- [ ] (Opcional) Lanzar campaña Pack 00

Guía completa: [`docs/GUIA_BBVA.md`](docs/GUIA_BBVA.md)
