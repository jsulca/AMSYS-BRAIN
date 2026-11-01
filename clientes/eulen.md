# Cliente: eulen

> Esqueleto creado el 2026-10-31 a partir de `git log`, `legacy/planes/PLAN-MULTICLIENTE.md` y
> `migracion/PENDIENTES-MIGRACION.md`. Completar el detalle al tocar la rama.

| Campo | Valor |
|---|---|
| Rama legacy | `eulen` |
| Último commit (revisado 2026-10-31) | `a91e656 2026-10-26` |
| Commits propios / atrasados respecto a `main` | 60 / 22 |
| Divergencia | 🟠 Alta (12 migraciones propias) |
| Ola de migración | 2 (con caja_arequipa) |
| Base de datos legacy | `amsys_v3_eulen` |
| Servidor / despliegue | Por documentar (sin claves) |
| Configuración en la plataforma | Pendiente (`D:\Documentos\Amsys\tools\clientes\`) |
| Estado de migración | Pendiente |

## Módulos y particularidades

`SOLICITUDES` (Cliente, CategoriaAviso, TipoSolicitudAviso, NotificacionAviso, correo), `ELIMINACION_LOGICA`, campos de Aviso `CorreoA, CopiaA, Solicitante, CodigoExterno, FechaPeticion`, formatos Excel propios. Cambios pedidos por UDEP (2026-10-17).

**Plan de mantenimiento**: igual que `main` desde el 2026-10-31 (commit `8bb1462`, sin push). Antes: variante A — ver `legacy/analisis/plan-mantenimiento-por-cliente.md` (revisado 2026-10-31).

## Pendientes

**Secretos versionados** en `AMSYS.WebAdmin/appsettings.json` (token SendGrid, SMTP): tarea MC-00, rotarlos.

## Bitácora

| Fecha | Qué |
|---|---|
| 2026-10-31 | Ficha creada (esqueleto) |
| 2026-10-31 | Plan de mantenimiento unificado con main (`8bb1462`, sin push) |
