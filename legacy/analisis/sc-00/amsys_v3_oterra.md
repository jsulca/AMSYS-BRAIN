# SC-00 · `amsys_v3_oterra` (10.2.1.2) — 2026-11-19

Ejecutado con `legacy/analisis/sc-00-diagnostico-empresas.sql` + referencias cruzadas, en transacción de sólo
lectura. Plan: `legacy/planes/PLAN-SEGURIDAD-CENTRAL.md`.

## Empresas

| id | Empresa | Vence | Usuarios (activos / límite) | Filas | OT | Avisos | Equipos | Planes | Última actividad |
|---|---|---|---|---|---|---|---|---|---|
| 1 | OTERRA | 2027-07-20 | 46 (45 / 100) | 5 504 | 329 | 1 846 | 961 | 164 | 2026-11-11 |
| 2 | TEST-OTERRA | — | 1 (1 / 2) | 24 | 2 | 2 | 2 | 0 | 2026-10-15 |

TEST-OTERRA (creada 2026-10-13) es de pruebas: 1 usuario (cuenta de soporte de Alphamanufacturas, rol
ADMINISTRADOR ALPHA, id 47) y 24 filas. **Aislada**: ninguna FK ni log cruza entre las empresas 1 y 2.

## Usuarios y roles

- Correos repetidos dentro de OTERRA (usuarios duplicados, el segundo sin datos propios):
  - `paolo.jara@` → 16 (2 avisos) y 45 (sin avisos ni OT), ambos activos.
  - `maria.paredes@` → 13 (55 avisos) y 46 (inactivo, sin datos).
  - `prueba@` → 25 (ADMINISTRADOR CLIENTE, 1 aviso) y 44 (GENERADOR AVISOS, sin datos): cuentas de prueba.
- 6 roles, todos con usuarios: SUPER ADMINISTRADOR (1), ADMINISTRADOR ALPHA (2: el de la 1 y el de la 2),
  ADMINISTRADOR CLIENTE (4), GERENTE/JEFE (1), GESTION MANTTO. (7), GENERADOR AVISOS (32).
- Sin permisos ni filas huérfanas. Ids máximos: empresa 2, usuario 47, rol 6, organización 59.

## Propuesta (pendiente de confirmar)

| Conservar | Limpiar | Opcional |
|---|---|---|
| 1 OTERRA | 2 TEST-OTERRA (con su usuario 47) | Usuarios duplicados sin datos 45 y 46; cuentas de prueba 25/44 (la 25 tiene 1 aviso: reasignar) |
