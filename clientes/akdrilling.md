# Cliente: akdrilling

> Esqueleto creado el 2026-10-31 a partir de `git log`, `legacy/planes/PLAN-MULTICLIENTE.md` y
> `migracion/PENDIENTES-MIGRACION.md`. Completar el detalle al tocar la rama.

| Campo | Valor |
|---|---|
| Rama legacy | `akdrilling` |
| Último commit (revisado 2026-10-31) | `637bbb0 2026-10-16` |
| Commits propios / atrasados respecto a `main` | 4 / 2 |
| Divergencia | 🟢 Baja (rama nueva del 2026-10-11, desde `main`) |
| Ola de migración | Sin asignar |
| Base de datos legacy | `amsys_v3_akdrilling` (según `appsettings` de la rama, 2026-11-19) |
| Servidor / despliegue | Por documentar (sin claves) |
| Configuración en la plataforma | Pendiente (`D:\Documentos\Amsys\tools\clientes\`) |
| Estado de migración | Pendiente |

## Módulos y particularidades

Carga masiva de datos y ajuste de permisos (commits del 2026-10-15).

**Material.NroParte** (2026-11-16): campo propio de akdrilling, texto opcional de máx. 100 (`material.nroparte varchar(100)`). En los modales Nuevo/Editar, en la lista (debajo de la descripción) y como filtro. Migración `20261116161935_Material_AgregarNroParte`; script `legacy/portes/sql/akdrilling-Material_AgregarNroParte.sql` (idempotente, sólo esta migración; antes debe estar aplicada `Administracion_Superconjunto`).

**Plan de mantenimiento**: igual que `main` desde el 2026-10-31 (commit `2b4cef5`, sin push). Antes: variante A — ver `legacy/analisis/plan-mantenimiento-por-cliente.md` (revisado 2026-10-31).

## Pendientes

No aparece en PLAN-MULTICLIENTE ni en PENDIENTES-MIGRACION (es posterior). Le faltan 2 commits de `main`.

## Bitácora

| Fecha | Qué |
|---|---|
| 2026-10-31 | Ficha creada (esqueleto) |
| 2026-10-31 | Plan de mantenimiento unificado con main (`2b4cef5`, sin push) |
| 2026-11-10 | Módulo de Administración = main (`f70a89a`, cherry-pick de la Fase 0, sin push); migración `Administracion_Superconjunto` por aplicar en servidor |
| 2026-11-10 | Relación del material (DU-04) sincronizada (`ec3685d`, sin push) |
| 2026-11-16 | Campo `NroParte` en Material (máx. 100): migración `Material_AgregarNroParte` + script SQL; commit `6751607` (sin push); sin probar en navegador ni aplicar en servidor |
| 2026-11-16 | Vista previa del comportamiento del plan (paginada, sólo posiciones con ejecución, «Veces en el ciclo», sugerencia de divisor común) = main: cherry-pick de `0d9fb5a` → `f0d07b5` (sin push). Compila; sin prueba en navegador |
