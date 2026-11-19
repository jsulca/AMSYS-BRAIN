# SC-00 · `amsys_v3_caja_arequipa` (10.2.1.2) — 2026-11-19

Ejecutado con `legacy/analisis/sc-00-diagnostico-empresas.sql` en transacción de sólo lectura
(`default_transaction_read_only=on`). Plan: `legacy/planes/PLAN-SEGURIDAD-CENTRAL.md`.
Sin correos ni nombres de personas a propósito (se consultan en la BD).

## Empresas

| id | Empresa | Plan | Vence | Usuarios (activos) | Filas totales | OT | Avisos | Equipos | Última actividad |
|---|---|---|---|---|---|---|---|---|---|
| 6 | EULEN CAJA AREQUIPA | 1 | 2027-10-05 | 154 (154) | 28 411 | 8 456 | 9 130 | 667 | 2026-11-19 |
| 5 | ALPHAMANUFACTURAS | 0 | 2027-03-15 | 2 (2) | 42 | 2 | 14 | 3 | 2026-05-19 |
| 1 | EULEN RIPLEY | 0 | — | 10 (9) | 83 | 0 | 0 | 0 | 2025-09-19 |
| 3 | EULEN INTCOMEX | 0 | — | 6 (6) | 154 | 0 | 0 | 0 | 2025-09-17 |
| 4 | EULEN DHL | 1 | 2025-11-25 | 9 (9) | 47 | 0 | 0 | 0 | 2025-08-15 |
| 7 | EULEN UDEP | 1 | — | 1 (1) | 4 | 0 | 0 | 0 | — |
| 8 | EULEN HUAWEI | 1 | 2025-09-30 | 5 (5) | 12 | 0 | 0 | 0 | — |

Las empresas 1, 3, 4, 7 y 8 sólo tienen usuarios y catálogos (socios de negocio, categorías y tipos de
solicitud de aviso, clientes, adjuntos, sistemas, un feriado). Parecen heredadas de cuando la rama se bifurcó
de `eulen` (2025-02-01). **Por confirmar** si son las mismas empresas que viven en `amsys_v3_eulen`.

## Referencias cruzadas (lo que impide borrar a ciegas)

Usuarios de **ALPHAMANUFACTURAS (5)** aparecen en datos reales de Caja Arequipa:

| Tabla | Columna | Filas |
|---|---|---|
| `ordentrabajo` | `usuarioid` | 29 (27 son OT de la empresa 6) |
| `ordentrabajolog` | `usuarioid` | 36 |
| `avisolog` | `usuarioid` | 68 |
| `aviso` | `usuarioid` | 12 |
| `historialmovimiento` | `usuarioid` | 2 |
| `usuarioorganizacion` | `usuarioid` | 5 |

Ninguna fila de la empresa 6 referencia usuarios de las empresas 1, 3, 4, 7 u 8.

FK en la BD: 47 hacia `empresa` y 19 hacia `usuario`. EF crea las FK obligatorias con `ON DELETE CASCADE`:
**borrar un usuario de la empresa 5 podría borrar en cascada OT reales de Caja Arequipa**. Antes de borrar
la empresa 5, mover sus usuarios a la empresa 6 (o a un usuario de soporte de la 6).

## Usuarios y roles

- 187 usuarios: 154 de la empresa 6 (145 con rol AGENCIA), 33 del resto.
- Correos repetidos dentro de la empresa 6: 3 correos con 2 usuarios cada uno (ids 34/45, 98/150, 43/137).
- 10 roles (globales a la BD). Tras limpiar quedarían sin usuarios: JEFE DE OPERACIONES (3), SUPERVISOR
  ESPECIALISTA EN INDECI (5), SUPERVISOR DE MANTENIMIENTO (6), TICKETS (8), TÉCNICO - EULEN (9). La empresa 6
  usa ADMINISTRADOR (1), SUPER ADMINISTRADOR (7), AGENCIA (10) y CLIENTE (11); PLANNER DE MANTENIMIENTO (4)
  sólo lo usan las empresas 1, 3 y 4.
- Permisos huérfanos: ninguno.
- Ids máximos: empresa 8, usuario 188, rol 11, organización 311.

## Propuesta de limpieza (pendiente de confirmar por el propietario)

| Conservar | Limpiar | Cuidado |
|---|---|---|
| 6 EULEN CAJA AREQUIPA | 1, 3, 4, 7, 8 (sin referencias desde la 6) | 5 ALPHAMANUFACTURAS: mover antes sus 2 usuarios de soporte a la 6; luego borrar sus 14 avisos, 2 OT, 3 equipos y 4 ubicaciones de prueba |

Roles 3, 5, 6, 8, 9 (y 4 si nadie de la 6 lo usa) se pueden borrar después. Los 3 correos repetidos se
revisan aparte (¿cuentas duplicadas de una misma agencia?).
