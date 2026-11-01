# Estado de los frentes

Última actualización: 2026-10-31 (seguridad agchavin publicada; análisis del plan por cliente)

| Frente | Estado | Detalle |
|---|---|---|
| Nueva plataforma (`D:\Documentos\Amsys`) | NP-0 a NP-6 completas; falta prueba en navegador. Rama `feat/tecnico-y-plataforma` con trabajo sin commit (vistas de lista, tema) al 2026-10-31 | `plataforma/CURRENT-STATE.md` |
| Legacy `main` | Último commit `be8869b` (2026-10-16) | `legacy/CURRENT-STATE.md`, `clientes/main.md` |
| Legacy `agchavin` | Porte de la UI de `main` commiteado (`be90f45`, 2026-10-26); ~45 archivos sin commit (programación de OT, notificación de tareas); migración pendiente en el servidor. **Seguridad de `main` portada: commit `d527ecd` (publicado en origin), migración solo en localhost** | `legacy/portes/PORTE-UI-MAIN-AGCHAVIN.md`, `legacy/portes/PORTE-SEGURIDAD-MAIN-AGCHAVIN.md`, `clientes/agchavin.md` |
| Legacy `eulen` | Cambios de UDEP (2026-10-17, 2026-10-26); secretos versionados por rotar (MC-00) | `clientes/eulen.md` |
| Migración de clientes | Ningún cliente migrado. Ola 1: ares, energiaycombustion, pyme. **itc y rentanor ya no son clientes** (ramas borradas 2026-10-31) | `migracion/clientes-olas.md`, `migracion/PENDIENTES-MIGRACION.md` |
| Plan de mantenimiento | **Unificado con main en las 9 ramas** (2026-10-31; itc y rentanor borradas), con mejoras; commits locales **sin push** | `legacy/analisis/plan-mantenimiento-por-cliente.md` |
| AMSYS-BRAIN | Creado el 2026-10-31; remoto privado `jsulca/AMSYS-BRAIN` (GitHub). Plan completo (2026-10-31) | `meta/PLAN-AMSYS-BRAIN.md` |
