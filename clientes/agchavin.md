# Cliente: agchavin

> Esqueleto creado el 2026-10-31 a partir de `git log`, `legacy/planes/PLAN-MULTICLIENTE.md` y
> `migracion/PENDIENTES-MIGRACION.md`. Completar el detalle al tocar la rama.

| Campo | Valor |
|---|---|
| Rama legacy | `agchavin` |
| Último commit (revisado 2026-10-31) | `be90f45 2026-10-26` |
| Commits propios / atrasados respecto a `main` | 79 / 82 |
| Divergencia | 🔴 Muy alta (10 migraciones propias) |
| Ola de migración | 3 (con rentanor) |
| Base de datos legacy | `amsys_v3_agchavin` |
| Servidor / despliegue | Por documentar (sin claves) |
| Configuración en la plataforma | Pendiente (`D:\Documentos\Amsys\tools\clientes\`) |
| Estado de migración | Pendiente |

## Módulos y particularidades

`INDICADORES_CONFIABILIDAD` (incluye indicador mundial, `IndicadorGrupo`), `REPORTE_PDF_OT`, Home idéntico a rentanor, campo `Equipo.Orden`.

**Plan de mantenimiento**: igual que `main` desde el 2026-10-31 (commit `5b9825d`, publicado). Antes: variante C (factor siempre en contador, posición absoluta) — ver `legacy/analisis/plan-mantenimiento-por-cliente.md` (revisado 2026-10-31).

## Pendientes

Porte de la UI de `main` hecho el 2026-10-26 (`legacy/portes/PORTE-UI-MAIN-AGCHAVIN.md`). Migración `20261020022722_VistaLista_Crear_Almacen_AgregarActivo` aplicada en localhost el 2026-10-30; **falta en el servidor 10.2.1.2 / producción**. Al 2026-10-31 hay ~45 archivos modificados sin commit en la rama (programación de OT, notificación de tareas, migración `20261030152417_OrdenTrabajo_AgregarProgramacion`).

## Bitácora

| Fecha | Qué |
|---|---|
| 2026-10-31 | Ficha creada (esqueleto) |
| 2026-10-31 | Plan de mantenimiento unificado con main (`5b9825d`, publicado) |
| 2026-10-31 | Porte de Seguridad de `main` (SG-01…25), commit `d527ecd` (publicado en origin), probado en navegador, migración `20261101015429_Seguridad_PortarDesdeMain` aplicada en localhost (no en servidor); rol de instalación `SUPER ADMIN`: `legacy/portes/PORTE-SEGURIDAD-MAIN-AGCHAVIN.md` |
