# SC-00 · `amsys_v3_eulen` (10.2.1.2) — 2026-11-19

Ejecutado con `legacy/analisis/sc-00-diagnostico-empresas.sql` + consultas de referencias cruzadas, todo en
transacción de sólo lectura. Plan: `legacy/planes/PLAN-SEGURIDAD-CENTRAL.md`.

**BD multiempresa de verdad**: cada empresa es un cliente de Eulen (facility management). No se limpia "todo
menos una".

## Empresas

| id | Empresa | Vence | Usuarios (activos / límite) | Filas | OT | Avisos | Equipos | Última actividad | Lectura |
|---|---|---|---|---|---|---|---|---|---|
| 1 | EULEN RIPLEY | — | 12 (11 / 40) | 22 842 | 4 711 | 6 817 | 6 495 | 2026-11-18 | Real, activa |
| 9 | EULEN PUCP | 2027-06-30 | 14 (14 / 15) | 17 514 | 1 534 | 2 009 | 2 527 | 2026-11-19 | Real, activa |
| 7 | EULEN UDEP | — | 18 (18 / 18) | 16 047 | 1 909 | 2 644 | 8 482 | 2026-11-19 | Real, activa |
| 8 | EULEN HUAWEI | 2027-11-15 | 12 (12 / 12) | 170 | 2 | 2 | 122 | 2026-11-12 | Real, empezando |
| 10 | EULEN SURA | — | 5 (5 / 5) | 956 | 100 | 29 | 281 | 2026-10-28 | Real |
| 4 | EULEN DHL | 2026-12-05 | 11 (11 / 20) | 1 074 | 10 | 30 | 685 | 2026-06-02 | Poco uso; decidir |
| 3 | EULEN INTCOMEX | — | 6 (6 / 10) | 848 | 96 | 170 | 267 | 2026-02-19 | Sin uso desde feb.; decidir |
| 6 | EULEN CAJA AREQUIPA | — | 148 (141 / 150) | 1 815 | 60 | 302 | 667 | 2025-09-22 | **Copia antigua** |
| 5 | ALPHAMANUFACTURAS | 2027-02-15 | 2 (2 / 5) | 92 | 5 | 33 | 6 | 2026-06-07 | Pruebas |

## Empresa 6 = copia antigua de Caja Arequipa

Datos del 2025-09-10 al 2025-09-22 (cuando Caja pasó a su propia BD). Comparado por código con
`amsys_v3_caja_arequipa`: los 58 códigos de OT distintos, los 302 avisos y los 667 equipos **ya están** allí.
Sus 141 usuarios AGENCIA siguen activos pero el rol AGENCIA no tiene páginas en esta BD; sus 3 administradores
y 4 clientes están inactivos. Ningún dato de otra empresa referencia filas de la 5 ni de la 6.

## Referencias cruzadas

- Dos cuentas de soporte de Alphamanufacturas se **mueven de empresa en empresa** (cambiando `usuario.empresaid`)
  para operar: usuario 1 (SUPER ADMINISTRADOR, hoy en la 10) y usuario 3 (hoy en la 8). Son autores de avisos,
  OT, logs y renovaciones en casi todas las empresas. En la central (S-6) esto debe ser un rol de soporte con
  acceso a varias empresas, no un cambio de `empresaid`.
- INTCOMEX (3) tiene 1 OT y 4 materiales que apuntan a catálogos de RIPLEY (1): taller, tipo de mantenimiento,
  plan, prioridad y unidades de medida. Es el defecto de escritura entre empresas (AD-02/03) en datos viejos.

## Usuarios y roles

- 228 usuarios. Correos repetidos: los mismos 3 de agencias de Caja (empresa 6) que en `amsys_v3_caja_arequipa`.
- 11 roles globales (incluye CLIENTE - HUAWEI). AGENCIA (141 usuarios) y CLIENTE (4) sólo los usa la 6.
- Permisos huérfanos: ninguno. Ids máximos: empresa 10, usuario 229, rol 12, organización 368.

## Propuesta de limpieza (pendiente de confirmar)

| Conservar | Limpiar | Decidir |
|---|---|---|
| 1 RIPLEY, 7 UDEP, 8 HUAWEI, 9 PUCP, 10 SURA | 6 CAJA AREQUIPA (copia), 5 ALPHAMANUFACTURAS (pruebas) | 3 INTCOMEX, 4 DHL |

Tras limpiar la 6, los roles AGENCIA y CLIENTE quedan sin usuarios. El script SC-02 hay que adaptarlo para
conservar **varias** empresas (hoy verifica una sola).
