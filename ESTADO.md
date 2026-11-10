# Estado de los frentes

Última actualización: 2026-11-10 (plan de Administración unificada y BD de catálogos)

| Frente | Estado | Detalle |
|---|---|---|
| Nueva plataforma (`D:\Documentos\Amsys`) | NP-0 a NP-6 completas; falta prueba en navegador. Rama `feat/tecnico-y-plataforma` con trabajo sin commit (vistas de lista, tema) al 2026-10-31 | `plataforma/CURRENT-STATE.md` |
| Legacy `main` | Último commit `be8869b` (2026-10-16) | `legacy/CURRENT-STATE.md`, `clientes/main.md` |
| Legacy `agchavin` | Porte de la UI de `main` commiteado (`be90f45`, 2026-10-26); ~45 archivos sin commit (programación de OT, notificación de tareas); migración pendiente en el servidor. **Seguridad de `main` portada: commit `d527ecd` (publicado en origin); migraciones y datos de Seguridad aplicados en 10.2.1.2 el 2026-11-05, falta desplegar el código**. **Manual de usuario** estático en `wwwroot/manual/` (6 capítulos, 36 capturas; commit `4ea59bd` publicado, 2026-11-05) | `legacy/portes/PORTE-UI-MAIN-AGCHAVIN.md`, `legacy/portes/PORTE-SEGURIDAD-MAIN-AGCHAVIN.md`, `clientes/agchavin.md` |
| Legacy `eulen` | Cambios de UDEP (2026-10-17, 2026-10-26); secretos versionados por rotar (MC-00) | `clientes/eulen.md` |
| Legacy `oterra` | Pedido de 6 cambios (2026-11-05) implementado y **publicado** (`origin/oterra` en `d07e32d`). Falta prueba completa y despliegue. **Porte de Seguridad de `main`** en `seguridad-desde-main` (`5ff36be`, conserva `Usuario.AreaId`). **Probado 2026-11-08** en copia local (Docker, puerto 5433): migración OK, F9 provisional, pruebas HTTP OK. Corrección del filtro global en `d3adba0`. **Migración aplicada en 10.2.1.2 y probada OK por el propietario (2026-11-08). Unido a `oterra` y publicado (`origin/oterra` en `d3adba0`); rama `seguridad-desde-main` borrada.** Falta: perfiles y límites definitivos en 10.2.1.2 y despliegue | `legacy/planes/PLAN-OTERRA-PEDIDO-2026-11.md`, `legacy/portes/PORTE-SEGURIDAD-MAIN-OTERRA.md`, `clientes/oterra.md` |
| Migración de clientes | Ningún cliente migrado. Ola 1: ares, energiaycombustion, pyme. **itc y rentanor ya no son clientes** (ramas borradas 2026-10-31) | `migracion/clientes-olas.md`, `migracion/PENDIENTES-MIGRACION.md` |
| Plan de mantenimiento | **Unificado con main en las 9 ramas** (2026-10-31; itc y rentanor borradas), con mejoras; commits locales **sin push** | `legacy/analisis/plan-mantenimiento-por-cliente.md` |
| Administración unificada / BD de catálogos | PROPUESTA (2026-11-10): llevar el módulo de `main` a todas las ramas con campos extra opcionales, luego BD central de catálogos por `empresaid`. Pendientes decisiones DU-01…DU-07 | `legacy/planes/PLAN-ADMINISTRACION-UNIFICADA-Y-BD-CATALOGOS.md` |
| AMSYS-BRAIN | Creado el 2026-10-31; remoto privado `jsulca/AMSYS-BRAIN` (GitHub). Plan completo (2026-10-31) | `meta/PLAN-AMSYS-BRAIN.md` |
