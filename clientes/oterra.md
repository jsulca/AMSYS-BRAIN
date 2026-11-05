# Cliente: oterra

> Esqueleto creado el 2026-10-31 a partir de `git log`, `legacy/planes/PLAN-MULTICLIENTE.md` y
> `migracion/PENDIENTES-MIGRACION.md`. Completar el detalle al tocar la rama.

| Campo | Valor |
|---|---|
| Rama legacy | `oterra` |
| Último commit (revisado 2026-11-05) | `d07e32d 2026-11-05` (`origin/oterra`) |
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

**Pedido del cliente (2026-11-05)**: 6 cambios (Excel de equipos con repuestos, persistencia de filtros en avisos, activos por defecto en equipos y materiales, relación del material, árbol que conserva su estado). Plan en `legacy/planes/PLAN-OTERRA-PEDIDO-2026-11.md`.

Módulos exclusivos de oterra (D-MC-04). Su versión de MTBF/MTTR es la base a revisar (D-MC-06). Al 2026-11-05 la rama `oterra` está en `d07e32d`, publicada en `origin`.

## Bitácora

| Fecha | Qué |
|---|---|
| 2026-10-31 | Ficha creada (esqueleto) |
| 2026-10-31 | Plan de mantenimiento unificado con main (`70d395b`, sin push) |
| 2026-11-05 | Plan del pedido de 6 cambios (`legacy/planes/PLAN-OTERRA-PEDIDO-2026-11.md`), sin implementar |
| 2026-11-05 | P3 (equipos activos por defecto) y P5 (materiales conservan página tras guardar), sin commit |
| 2026-11-05 | Commits P3 `b170b26`, P5 `5a70a2d` (sin push); P4 (materiales activos + relación) implementado sin commit |
| 2026-11-05 | Pedido completo: P4 `9a87ed6`, P2 `7030a25`, P6 `934b9e2`, P1 `e6e923c` (sin push). Falta prueba completa y push |
| 2026-11-05 | Push de `oterra` (`c01cd75..d07e32d`): plan de mantenimiento unificado + pedido de 6 cambios |
