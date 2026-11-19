# Cliente: main

> Esqueleto creado el 2026-10-31 a partir de `git log`, `legacy/planes/PLAN-MULTICLIENTE.md` y
> `migracion/PENDIENTES-MIGRACION.md`. Completar el detalle al tocar la rama.

| Campo | Valor |
|---|---|
| Rama legacy | `main` |
| Último commit (revisado 2026-10-31) | `be8869b 2026-10-16` |
| Commits propios / atrasados respecto a `main` | 0 / 0 |
| Divergencia | — (producto base) |
| Ola de migración | — |
| Base de datos legacy | `amsys` |
| Servidor / despliegue | Por documentar (sin claves) |
| Configuración en la plataforma | Pendiente (`D:\Documentos\Amsys\tools\clientes\`) |
| Estado de migración | Pendiente |

## Módulos y particularidades

Producto base del legacy. Recibe las mejoras de UX (`legacy/planes/PLAN-UX-*.md`) y las tareas MNT.

**Plan de mantenimiento**: igual que `main` desde el 2026-10-31 (commit `8bc50b6 + 5d228c9`, sin push). Antes: variante A (referencia) — ver `legacy/analisis/plan-mantenimiento-por-cliente.md` (revisado 2026-10-31).

## Pendientes

Referencia para los portes a las ramas de cliente (ver `legacy/ramas.md`).

## Bitácora

| Fecha | Qué |
|---|---|
| 2026-10-31 | Ficha creada (esqueleto) |
| 2026-10-31 | Plan de mantenimiento unificado con main (`8bc50b6 + 5d228c9`, sin push) |
| 2026-11-10 | Fase 0 del plan de Administración unificada (`634f165`, sin push): campos opcionales de Prioridad/Material/Adjunto, 7 catálogos opcionales, `BaseEntity`, migración `Administracion_Superconjunto`. Bug corregido: el precio del material se perdía al crearlo |
| 2026-11-10 | DU-04: relación del material con equipos, secciones y OT, traída del pedido P4 de oterra (`4a89abe`, sin push) |
| 2026-11-16 | Vista previa del comportamiento del plan (`_Comportamiento.cshtml`, transversal): por defecto sólo posiciones con ejecución (interruptor para ver las vacías; borde punteado = vacías ocultas), paginación de 60 columnas en el cliente, límite de 1 000 → 10 000 posiciones, columna «Veces en el ciclo» (0 en rojo = la tapa siempre una sección de mayor nivel) y sugerencia no bloqueante de intervalo mayor cuando las secciones tienen divisor común. Ej.: 1 HR con 12/24/50/100/500 → 3 000 posiciones, 300 con ejecución (5 páginas). Sólo vista: no cambia la generación de OT. Compila; commit `0d9fb5a` (sin push); sin prueba en navegador (sin BD local). Portado a las 6 ramas el mismo día: akdrilling `f0d07b5` (cherry-pick), agchavin `a1e2ac6`, caja_arequipa `f89ab60`, eulen `e0e05a5`, pyme `dedbb1c`, oterra `6e5c71c` (en estas 5, Ver/Asignar pasan de tabla inline al partial; sin vista previa en vivo en Nuevo/Editar) |
| 2026-11-16 | **10.2.1.2 (`amsys_v3_demo`, BD de Development de `main`)**: aplicada `20261110145523_Administracion_Superconjunto` (era la única pendiente; ya no queda ninguna). Respaldo previo `pg_dump -Fc` (pg_dump 17 de DBeaver): `D:\Documentos\Alphamanufacturas\AMSYSackupsmsys_v3_demo_10.2.1.2_antes-Administracion_Superconjunto_20261116_1217.dump` (115 tablas con datos) |
