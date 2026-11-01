# Cliente: rentanor (ex cliente)

> **Ex cliente desde el 2026-10-31.** Ramas `rentanor` borradas (local y `origin`) a pedido del propietario.
> Respaldo: `D:\Documentos\Alphamanufacturas\AMSYSespaldos-ramasentanor-itc-2026-10-31.bundle`
> (`rentanor` local `88a48c5`, `origin/rentanor` `5182a65`). Restaurar: `git fetch <bundle> rentanor:rentanor`.

> Esqueleto creado el 2026-10-31 a partir de `git log`, `legacy/planes/PLAN-MULTICLIENTE.md` y
> `migracion/PENDIENTES-MIGRACION.md`. Completar el detalle al tocar la rama.

| Campo | Valor |
|---|---|
| Rama legacy | `rentanor` |
| Último commit (revisado 2026-10-31) | `5182a65 2025-08-03` |
| Commits propios / atrasados respecto a `main` | 75 / 98 |
| Divergencia | 🔴 Muy alta (16 migraciones propias) |
| Ola de migración | 3 (con agchavin) |
| Base de datos legacy | `amsys_v3_rentanor` |
| Servidor / despliegue | Por documentar (sin claves) |
| Configuración en la plataforma | Pendiente (`D:\Documentos\Amsys\tools\clientes\`) |
| Estado de migración | Pendiente |

## Módulos y particularidades

`INDICADORES_CONFIABILIDAD`, `REPORTE_PDF_OT`, `ELIMINACION_LOGICA` (`BaseEntity`), Home idéntico a agchavin, campos de OT `CodigoEJB, HorasServicio, Kilometros, Liberado`, `ImagenCabecera/ImagenPie`.

**Plan de mantenimiento**: igual que `main` desde el 2026-10-31 (commit no publicado; está en el bundle). Antes: variante B (`!=` en contador) — ver `legacy/analisis/plan-mantenimiento-por-cliente.md` (revisado 2026-10-31).

## Pendientes

—

## Bitácora

| Fecha | Qué |
|---|---|
| 2026-10-31 | Ficha creada (esqueleto) |
| 2026-10-31 | Deja de ser cliente: ramas borradas, respaldo en bundle |
| 2026-10-31 | Plan de mantenimiento unificado con main (`88a48c5`, sin push) |
