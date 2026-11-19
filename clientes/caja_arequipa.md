# Cliente: caja_arequipa

> Esqueleto creado el 2026-10-31 a partir de `git log`, `legacy/planes/PLAN-MULTICLIENTE.md` y
> `migracion/PENDIENTES-MIGRACION.md`. Completar el detalle al tocar la rama.

| Campo | Valor |
|---|---|
| Rama legacy | `caja_arequipa` |
| Último commit (revisado 2026-10-31) | `71c3f47 2026-05-20` |
| Commits propios / atrasados respecto a `main` | 43 / 22 |
| Divergencia | 🟠 Alta (15 migraciones propias) |
| Ola de migración | 2 (con eulen) |
| Base de datos legacy | `amsys_v3_caja_arequipa` |
| Servidor / despliegue | Por documentar (sin claves) |
| Configuración en la plataforma | Pendiente (`D:\Documentos\Amsys\tools\clientes\`) |
| Estado de migración | Pendiente |

## Módulos y particularidades

`SOLICITUDES` (idéntico a eulen), `ELIMINACION_LOGICA`, `CALIFICACION_OT`, `FERIADOS`, campo `OT.FinProgramado`, estados renombrados (`ABIERTO/CERRADO/CANCELADO`, `CIERRE_PARCIAL`).

**Plan de mantenimiento**: igual que `main` desde el 2026-10-31 (commit `d17a18c`, sin push). Antes: variante A — ver `legacy/analisis/plan-mantenimiento-por-cliente.md` (revisado 2026-10-31).

## Pendientes

Decisión abierta D-MC-03: confirmar si los estados renombrados equivalen a los canónicos.

## Bitácora

| Fecha | Qué |
|---|---|
| 2026-10-31 | Ficha creada (esqueleto) |
| 2026-10-31 | Plan de mantenimiento unificado con main (`d17a18c`, sin push) |
| 2026-11-10 | Módulo de Administración = main (sin push; migración `Administracion_DesdeMain`, script en `legacy/portes/sql/caja_arequipa-Administracion_DesdeMain.sql`). Detalle: `legacy/portes/PORTE-ADMINISTRACION-MAIN-PYME-EULEN-CAJA-OTERRA.md` |
| 2026-11-16 | Vista previa del comportamiento del plan desde main `0d9fb5a` → `f89ab60` (sin push): nuevo partial `_Comportamiento.cshtml`; Ver y Asignar dejan la tabla inline (que pintaba todas las posiciones) y usan el partial. Sin la vista previa en vivo de Nuevo/Editar (acción `Comportamiento` de main no portada). Compila; sin prueba en navegador |
| 2026-11-19 | **Limpieza de empresas en 10.2.1.2** (`amsys_v3_caja_arequipa`, plan `legacy/planes/PLAN-SEGURIDAD-CENTRAL.md` S-2): sólo queda la empresa 6 EULEN CAJA AREQUIPA; borradas 1 RIPLEY, 3 INTCOMEX, 4 DHL, 5 ALPHAMANUFACTURAS, 7 UDEP y 8 HUAWEI con sus 33 usuarios (incluidos los 2 de soporte). 27 OT y sus logs pasan al usuario 1. Respaldo previo en `backupsmsys_v3_caja_arequipa_10.2.1.2_antes-limpieza-SC02_20261119.dump` |
