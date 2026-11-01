# Olas de migración de clientes a la nueva plataforma

Fuente: `legacy/planes/PLAN-MULTICLIENTE.md` §6 y `plataforma/ROADMAP.md`. Revisado el 2026-10-31.

| Ola | Clientes | Motivo | Estado |
|---|---|---|---|
| 1 | `ares`, `energiaycombustion`, `pyme` | 0–1 migraciones propias; branding, dashboard, plantillas | Pendiente |
| 2 | `eulen`, `caja_arequipa` | Comparten base y el módulo `SOLICITUDES`; se migran juntos | Pendiente |
| 3 | `agchavin` | Indicadores y reportes de plan | Pendiente |
| 4 | `oterra` | Base de 2023, 122 commits atrás de `main`, la mayor lógica propia. Último | Pendiente |
| — | `akdrilling` | Rama nueva (2026-10-11), casi igual a `main`. **Ola por decidir** (candidata a la 1) | Sin asignar |

Para la ola 1, lo previo está en `migracion/PENDIENTES-MIGRACION.md` (contar qué usan de verdad en sus bases
`amsys_v3_*`; confirmar si existen las bases de ares, energiaycombustion y pyme en el servidor).

Ex clientes (no se migran): `itc`, `rentanor` (2026-10-31, `clientes/ex/`).

Al migrar un cliente: actualizar su ficha (`clientes/<cliente>.md`, "Estado de migración" y bitácora), esta tabla y
`ESTADO.md`.
