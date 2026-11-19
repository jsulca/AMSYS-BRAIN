# Cliente: pyme

> Esqueleto creado el 2026-10-31 a partir de `git log`, `legacy/planes/PLAN-MULTICLIENTE.md` y
> `migracion/PENDIENTES-MIGRACION.md`. Completar el detalle al tocar la rama.

| Campo | Valor |
|---|---|
| Rama legacy | `pyme` |
| Último commit (revisado 2026-10-31) | `22b6e13 2025-05-12` |
| Commits propios / atrasados respecto a `main` | 7 / 21 |
| Divergencia | 🟢 Baja (costos OT, reporte de costo, plantillas Excel) |
| Ola de migración | 1 |
| Base de datos legacy | `amsys_v3_pyme` (según `appsettings` de la rama, 2026-11-19) |
| Servidor / despliegue | Por documentar (sin claves) |
| Configuración en la plataforma | Pendiente (`D:\Documentos\Amsys\tools\clientes\`) |
| Estado de migración | Pendiente |

## Módulos y particularidades

Cliente PanaService. `COSTOS_OT_AVANZADO`, `logoPanaService.jpg`, plantillas Excel. Tiene `if (EmpresaId == X)` en código.

**Plan de mantenimiento**: igual que `main` desde el 2026-10-31 (commit `729aaa4`, sin push). Antes: variante A — ver `legacy/analisis/plan-mantenimiento-por-cliente.md` (revisado 2026-10-31).

## Pendientes

—

## Bitácora

| Fecha | Qué |
|---|---|
| 2026-10-31 | Ficha creada (esqueleto) |
| 2026-10-31 | Plan de mantenimiento unificado con main (`729aaa4`, sin push) |
| 2026-11-10 | Módulo de Administración = main (sin push; migración `Administracion_DesdeMain`, script en `legacy/portes/sql/pyme-Administracion_DesdeMain.sql`). Detalle: `legacy/portes/PORTE-ADMINISTRACION-MAIN-PYME-EULEN-CAJA-OTERRA.md` |
| 2026-11-16 | Vista previa del comportamiento del plan desde main `0d9fb5a` → `dedbb1c` (sin push): nuevo partial `_Comportamiento.cshtml`; Ver y Asignar dejan la tabla inline (que pintaba todas las posiciones) y usan el partial. Sin la vista previa en vivo de Nuevo/Editar (acción `Comportamiento` de main no portada). Compila; sin prueba en navegador |
