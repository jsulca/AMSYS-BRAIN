# Cliente: oterra

> Esqueleto creado el 2026-10-31 a partir de `git log`, `legacy/planes/PLAN-MULTICLIENTE.md` y
> `migracion/PENDIENTES-MIGRACION.md`. Completar el detalle al tocar la rama.

| Campo | Valor |
|---|---|
| Rama legacy | `oterra` |
| Último commit (revisado 2026-10-31) | `c01cd75 2026-09-13` (`origin/oterra`) |
| Commits propios / atrasados respecto a `main` | 30 / 122 |
| Divergencia | 🔴 Máxima (20 migraciones propias, 597 archivos, base de 2023) |
| Ola de migración | 4 (última) |
| Base de datos legacy | `amsys_v3_oterra` |
| Servidor / despliegue | Por documentar (sin claves) |
| Configuración en la plataforma | Pendiente (`D:\Documentos\Amsys\tools\clientes\`) |
| Estado de migración | Pendiente |

## Módulos y particularidades

`AREAS_IMPACTO` (Area, ImpactoProceso, AvisoPadre), `CONFORMIDAD_AVISO`, `TURNOS_PROGRAMACION`, `INDICADORES_CONFIABILIDAD`, `REPORTE_PDF_OT`, AvisoContador/PuntoMedida, `PROGRAMADO` comentado.

**Plan de mantenimiento**: igual que `main` desde el 2026-10-31 (commit `70d395b`, sin push). Antes: variante D (C + última sección con tareas) — ver `legacy/analisis/plan-mantenimiento-por-cliente.md` (revisado 2026-10-31).

## Pendientes

Módulos exclusivos de oterra (D-MC-04). Su versión de MTBF/MTTR es la base a revisar (D-MC-06). **La rama local `oterra` está atrasada** (`88854d6`, 2024-12-22) respecto a `origin/oterra`: hacer `git pull` antes de trabajar en ella.

## Bitácora

| Fecha | Qué |
|---|---|
| 2026-10-31 | Ficha creada (esqueleto) |
| 2026-10-31 | Plan de mantenimiento unificado con main (`70d395b`, sin push) |
