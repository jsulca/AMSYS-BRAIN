# SC-00 · `amsys_v3_agchavin` (10.2.1.2) — 2026-11-19

Ejecutado con `legacy/analisis/sc-00-diagnostico-empresas.sql` en transacción de sólo lectura.
Plan: `legacy/planes/PLAN-SEGURIDAD-CENTRAL.md`. Nota: el `appsettings.Development.json` de la rama apunta a
localhost; esto es la BD del servidor.

## Resultado: una sola empresa, nada que limpiar a nivel de empresa

| id | Empresa | Plan | Vence | Límite usuarios | Usuarios (activos) | Filas | OT | Avisos | Equipos | Planes | Última actividad |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | AyG Chavin | 0 | 2027-02-14 | 21 | 10 (6) | 16 338 | 12 886 | 807 | 342 | 179 | 2026-11-19 |

- Sin filas huérfanas por `empresaid`, sin permisos huérfanos.
- Roles: SUPER ADMIN (1 usuario: la cuenta de Alphamanufacturas), ADMINISTRADOR (8), TECNICO (1). Todos en uso.
- 4 usuarios inactivos (ids 3, 4, 7, 8).
- Correo repetido: `mantenimiento@` en los usuarios 8 (inactivo) y 9 (activo). Bloquea un correo único global (S-6).
- Ids máximos: empresa 1, usuario 11, rol 3, organización 1.

## Limpieza menor posible (pendiente de decisión)

- Usuario 8 (inactivo, correo repetido con el 9): borrarlo o cambiarle el correo. Antes hay que reasignar lo que
  tenga a su nombre (mismo script SC-02, adaptado a usuarios).
- Usuarios inactivos 3, 4, 7: conservar (historial) salvo decisión contraria.
