# Plan – Limpiar, ordenar y centralizar Seguridad en una sola BD

> **Estado**: PROPUESTA. Fase S-0 lista para ejecutar (SQL de diagnóstico); el resto espera las decisiones `DS-C-NN` (§6).
> **Fecha**: 2026-11-19 · **Base del análisis**: `akdrilling` `6242251` (Seguridad idéntica a `main`) · **Prefijo**: `SC-NN`
> **Ramas vigentes**: main, akdrilling, agchavin, caja_arequipa, eulen, oterra, pyme

Objetivo del propietario: dejar de administrar usuarios, empresas y licencias **BD por BD**. Orden acordado:

1. **Limpiar**: en cada BD queda sólo la empresa (o empresas) que sirve; el resto se borra con sus datos.
2. **Ordenar**: Seguridad con el mismo código y los mismos datos de base en todas las ramas; ids sin choques.
3. **Centralizar**: empresas, licencias y usuarios (y después roles y permisos) en una BD común.

Relacionado: `legacy/planes/PLAN-ADMINISTRACION-UNIFICADA-Y-BD-CATALOGOS.md` (Parte B: mismo problema con los
catálogos), `legacy/planes/PLAN-MULTICLIENTE.md`, `legacy/planes/PLAN-UX-SEGURIDAD.md` (SG-01…25),
`legacy/portes/PORTE-SEGURIDAD-MAIN-*.md`.

---

## 1. Cómo está hoy (medido en el código el 2026-11-19)

- **Una rama = una BD = una cadena de conexión** (`ConnectionStrings:AMSYS_PG`). Dentro de cada BD puede haber
  **varias empresas** (p. ej. caja_arequipa), de las que normalmente sólo una es la real.
- Seguridad vive dentro de cada BD en 18 tablas: `empresa`, `configuracion`, `limitacion`, `renovacion`, `usuario`,
  `usuarioorganizacion`, `rol`, `rolpagina`, `rolmenu`, `rolelemento`, `rolestadoaviso`, `rolestadoordentrabajo`,
  `pagina`, `menu`, `elemento`, `organizacion`, `seguridadlog`, `alerta`.
- Versión de Seguridad por rama: **nueva (SG-01…25)** en main, akdrilling, agchavin (`d527ecd`) y oterra
  (`d3adba0`, con `Usuario.AreaId`); **antigua** en caja_arequipa, eulen y pyme (~80 archivos de diferencia).
- Dependencias de las tablas operativas:
  - 51 entidades con `EmpresaId`.
  - 23 con `UsuarioId`/`AfectadoId` (OT, Aviso, logs, notas de entrada/salida, notificaciones, paradas, listas…).
  - 4 con `OrganizacionId` (Equipo, Ubicación, Aviso, OT).
  - `Usuario` → `Empleado` y `Adjunto` (foto), que son datos del cliente; en oterra también → `Area`.
- `Rol` **no tiene `EmpresaId`**: un rol vale para toda la BD. `Pagina`/`Menu`/`Elemento` describen el código de
  cada rama (distinto en cada una). `RolEstadoOrdenTrabajo`/`RolEstadoAviso` dependen de los estados del cliente.
- Login (`AccountController.cs:75-76`): busca el correo en la BD local y comprueba ahí el vencimiento del usuario
  y de la empresa. `FiltroSession` revalida `TokenWeb` en cada petición.

## 2. Mapa de cadenas de conexión (sin claves)

Tomado de `AMSYS.WebAdmin/appsettings*.json` de cada rama el 2026-11-19. Las claves están en esos archivos
(versionadas en git: ver MC-00); aquí no se copian.

| Rama | BD | Servidor en `Development` | Servidor en `appsettings.json` (producción) |
|---|---|---|---|
| main | `amsys_v3_demo` | 10.2.1.2 | localhost |
| akdrilling | `amsys_v3_akdrilling` | 10.2.1.2 | localhost |
| agchavin | `amsys_v3_agchavin` | localhost (10.2.1.2 comentada) | localhost |
| caja_arequipa | `amsys_v3_caja_arequipa` | 10.2.1.2 | localhost |
| eulen | `amsys_v3_eulen` | 10.2.1.2 | **10.2.1.2** |
| oterra | `amsys_v3_oterra` | 10.2.1.2 | localhost |
| pyme | `amsys_v3_pyme` | 10.2.1.2 | localhost |

Usuario `postgres` en todas. En producción la app apunta a `localhost`: la web corre en el mismo servidor que la
BD (por confirmar si es 10.2.1.2 u otro).

**Hallazgos**:
- `AMSYS.WebAPI/appsettings.json` (agchavin, caja_arequipa, eulen, pyme) apunta a `amsys` en localhost y tiene una
  cadena `AMSYS_SQL` a un SQL Server externo (`site4now`) con clave versionada. Parece abandonado: confirmar y
  rotar (MC-00).
- Las fichas `clientes/akdrilling.md` y `clientes/pyme.md` decían «BD sin confirmar»: según la rama son
  `amsys_v3_akdrilling` y `amsys_v3_pyme`.

## 3. Qué va a la BD central y qué se queda

| Central | Se queda en cada BD |
|---|---|
| `empresa`, `configuracion`, `limitacion`, `renovacion` (licencia) | `organizacion`, `usuarioorganizacion` (el árbol lo usan equipos y OT) |
| `usuario` (identidad: correo, clave, activo, vencimiento, tokens) | `empleado`, foto (`adjunto`), `area` de oterra |
| `seguridadlog` (accesos y cambios) | `alerta` (operativa) |
| `rol` + permisos — **etapa 2** (requiere `Rol.EmpresaId` y un juego de páginas común) | Copia de lectura de `empresa`, `usuario`, `rol` para que FK e `Include` sigan funcionando |

## 4. Problemas de fondo y propuesta

1. **No hay FK entre bases.** Cada BD de cliente necesita seguir viendo `empresa`/`usuario`/`rol`.
   Propuesta: como todas las BD están en el mismo servidor, **`postgres_fdw`**: en cada BD, tablas foráneas o
   vistas sobre la central filtradas por las empresas de esa instalación. Alternativa: la app copia la fila a la
   BD del cliente al guardar en la central (más simple, riesgo de desincronización).
   *No sirve replicación lógica con filtro*: el `WHERE` en publicaciones es de PostgreSQL 15 y el servidor es
   13.7 (afecta también a BC-07 del plan de catálogos).
2. **Ids que chocan** (`empresa.id = 1` y `usuario.id = 1` en todas las BD). Propuesta: **renumerar por rango**
   en cada BD (cliente N → N × 10 000 + id) con un script que pone `ON UPDATE CASCADE` en las FK, actualiza y
   deja las FK como estaban. Son pocas filas en `empresa`/`usuario`; el costo es reescribir las columnas
   `empresaid`/`usuarioid` de las tablas grandes (ventana de mantenimiento). Así la central y las copias usan
   los mismos ids sin tabla de mapeo.
3. **Correos repetidos entre BD** (cuentas del propietario o de soporte). Propuesta: correo único en la central;
   las cuentas de soporte pasan a un rol de instalación que puede entrar a cualquier empresa.
4. **A qué instalación entra cada usuario.** `empresa` gana `instancia` (código de la rama); cada instalación
   lee su código de `appsettings` y sólo acepta usuarios de sus empresas. El login valida contra la central.

## 5. Fases

| Fase | Qué | Detalle |
|---|---|---|
| **S-0** | Diagnóstico (sólo lectura) | `legacy/analisis/sc-00-diagnostico-empresas.sql` en cada BD del §2: empresas y licencia, filas por empresa en todas las tablas con `empresaid`, última actividad, usuarios, correos repetidos, roles, permisos huérfanos, ids máximos. Resultados en `legacy/analisis/sc-00/<bd>.md`. El propietario marca **qué empresa sirve** en cada BD (§7) |
| **S-1** | Respaldo | `pg_dump -Fc` de cada BD antes de tocar nada (convención de nombres de `clientes/agchavin.md`) |
| **S-2** | Limpieza por BD | Script por BD, generado desde el grafo de FK (`pg_constraint`, recorrido recursivo desde `empresa`), que borra en orden hijos → padres todo lo de las empresas descartadas, más filas huérfanas y permisos huérfanos. Se prueba primero en una copia local (Docker) y se compara con el informe de S-0 |
| **S-3** | Seguridad nueva en caja_arequipa, eulen y pyme | Portar SG-01…25 de `main` (modelo: `legacy/portes/PORTE-SEGURIDAD-MAIN-AGCHAVIN.md`). Requisito para que todas las BD tengan las mismas 18 tablas |
| **S-4** | Ordenar ids | Renumeración por rangos (§4.2) en cada BD limpia, con respaldo y prueba en copia |
| **S-5** | Licencias centrales | BD central con `empresa`, `configuracion`, `limitacion`, `renovacion` (+ `instancia`). Un solo panel de empresas y renovaciones. Cada instalación lee la licencia de la central al iniciar sesión |
| **S-6** | Usuarios centrales | `usuario` y `seguridadlog` en la central; copia de lectura en cada BD (§4.1); login contra la central |
| **S-7** | Roles y permisos centrales | `Rol.EmpresaId`; páginas/menús/elementos como superconjunto de todas las ramas, activados por empresa (como DU-02 del plan de catálogos) |

## 6. Decisiones del propietario

| Id | Pregunta | Opciones | Recomendación |
|---|---|---|---|
| `DS-C-01` | Alcance de la centralización | a) Licencias + usuarios · b) además roles y permisos desde el inicio | **a**, roles en S-7 |
| `DS-C-02` | Ids | a) Renumerar por rangos · b) Llave compuesta `(instancia, id)` | **a** |
| `DS-C-03` | Correo | a) Único global · b) Mismo correo en varias empresas, elige al entrar | **a** |
| `DS-C-04` | Dónde vive la central | a) BD nueva del legacy en 10.2.1.2 · b) La de la nueva plataforma | Igual que `DU-07` |
| `DS-C-05` | Copia local | a) `postgres_fdw` · b) Copia desde la app | **a** |

## 7. Empresas a conservar por BD (lo llena el propietario tras S-0)

| BD | Empresa(s) que sirven (id – nombre) | Empresas a limpiar | Fecha |
|---|---|---|---|
| `amsys_v3_demo` | | | |
| `amsys_v3_akdrilling` | | | |
| `amsys_v3_agchavin` | 1 – AyG Chavin (única) | Ninguna. Sólo revisar el correo repetido de los usuarios 8/9 (`sc-00/amsys_v3_agchavin.md`) | 2026-11-19 |
| `amsys_v3_caja_arequipa` | 6 – EULEN CAJA AREQUIPA | 1, 3, 4, 5, 7, 8 — **limpiadas** (incluidos los 2 usuarios de soporte de la 5; su autoría en la 6 pasó al usuario 1) | 2026-11-19 |
| `amsys_v3_eulen` | 1 RIPLEY, 3 INTCOMEX, 4 DHL, 7 UDEP, 8 HUAWEI, 9 PUCP, 10 SURA | 6 CAJA AREQUIPA y 5 ALPHAMANUFACTURAS — **limpiadas** | 2026-11-19 |
| `amsys_v3_oterra` | 1 OTERRA | 2 TEST-OTERRA y usuarios duplicados 45 y 46 — **limpiados**. Quedan las cuentas de prueba 25/44 (`prueba@`), por decisión | 2026-11-19 |
| `amsys_v3_pyme` | | | |

## 8. Registro de avance

| Fecha | Qué |
|---|---|
| 2026-11-19 | Análisis del módulo, mapa de cadenas de conexión, plan y SQL de diagnóstico S-0 |
| 2026-11-19 | S-0 ejecutado en `amsys_v3_caja_arequipa` (sólo lectura): 7 empresas, sólo la 6 es real; usuarios de la 5 (soporte) figuran en 27 OT de la 6 → no borrar en cascada. Resultado en `legacy/analisis/sc-00/amsys_v3_caja_arequipa.md` |
| 2026-11-19 | **S-2 aplicado en `amsys_v3_caja_arequipa` (10.2.1.2)** con `legacy/portes/sql/caja_arequipa-SC02-limpieza-empresas.sql` (ensayo con ROLLBACK y luego COMMIT). Respaldo previo `D:\Documentos\Alphamanufacturas\AMSYSackupsmsys_v3_caja_arequipa_10.2.1.2_antes-limpieza-SC02_20261119.dump`. Borradas 6 empresas y 33 usuarios, 420 filas en total; reasignadas al usuario 1: 27 OT, 30 `ordentrabajolog`, 54 `avisolog`. Verificado: empresa 6 con sus 28 411 filas, 0 huérfanas en todas las FK. Roles sin usuarios (3, 4, 5, 6, 8, 9) **no** se borraron |
| 2026-11-19 | S-0 en `amsys_v3_agchavin`: una sola empresa (AyG Chavin), sin huérfanas; 1 correo repetido (usuarios 8 inactivo / 9) |
| 2026-11-19 | S-0 en `amsys_v3_eulen`: BD multiempresa real (9 empresas). La 6 es copia de sep. 2025 de Caja (todo ya está en su BD); la 5 son pruebas. Las cuentas de soporte cambian de `empresaid` para operar en cada empresa |
| 2026-11-19 | **S-2 aplicado en `amsys_v3_eulen` (10.2.1.2)** con `legacy/portes/sql/eulen-SC02-limpieza-empresas.sql` (versión multiempresa: conserva toda empresa fuera de la lista; ensayo + COMMIT). Decisión del propietario: borrar sólo 6 y 5; INTCOMEX y DHL se conservan. Respaldo previo `D:\Documentos\Alphamanufacturas\AMSYSackupsmsys_v3_eulen_10.2.1.2_antes-limpieza-SC02_20261119.dump`. Borrados 150 usuarios, 65 OT, 335 avisos, 673 equipos, 2 708 `usuarioorganizacion`, entre otros; sin reasignaciones. Verificado: las 7 empresas conservadas con sus 59 521 filas, 0 huérfanas. Roles AGENCIA y CLIENTE quedan sin usuarios (no borrados) |
| 2026-11-19 | S-0 en `amsys_v3_oterra`: OTERRA + TEST-OTERRA (pruebas, sin referencias cruzadas); 3 correos repetidos (usuarios duplicados y de prueba) |
| 2026-11-19 | **S-2 aplicado en `amsys_v3_oterra` (10.2.1.2)** con `legacy/portes/sql/oterra-SC02-limpieza-empresas.sql` (añade el parámetro `usuarios_borrar` para usuarios sueltos de empresas conservadas). Borrados: empresa 2 TEST-OTERRA (24 filas + logs/detalle) y usuarios 45, 46 y 47 (59 `usuarioorganizacion`); sin reasignaciones. Respaldo previo `D:\Documentos\Alphamanufacturas\AMSYSackupsmsys_v3_oterra_10.2.1.2_antes-limpieza-SC02_20261119.dump`. Verificado: OTERRA 5 502 filas (5 504 − 2 usuarios), 0 huérfanas; quedan 44 usuarios, 329 OT, 1 846 avisos |
