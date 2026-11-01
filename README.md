# AMSYS-BRAIN

Conocimiento de AMSYS (negocio, clientes, legacy, nueva plataforma y migración) en un solo repositorio,
separado del código. Los repositorios de código solo tienen un `CLAUDE.md` corto que apunta aquí.

- Legacy: `D:\Documentos\Alphamanufacturas\AMSYS\AMSYS` (ASP.NET Core MVC, una rama por cliente, GitHub `jsulca/AMSYS`).
- Nueva plataforma: `D:\Documentos\Amsys` (.NET 10, Minimal API + Blazor, `Amsys.slnx`).

Creado el 2026-10-31 siguiendo `meta/PLAN-AMSYS-BRAIN.md`. Las rutas dentro de los documentos son **relativas a la
raíz de este repositorio** (p. ej. `negocio/BUSINESS-RULES.md`).

## Estructura

| Carpeta | Contenido |
|---|---|
| `ESTADO.md` | Tablero corto: en qué está cada frente y dónde seguir |
| `negocio/` | Contexto del sistema, modelo de dominio, reglas de negocio, flujos (Aviso, OT) |
| `clientes/` | Una ficha por rama del legacy (`_plantilla.md` para nuevas; `ex/` para los que dejaron de ser clientes) |
| `legacy/` | Arquitectura y estado del legacy, `ramas.md`, `planes/` (PLAN-UX-*, MULTICLIENTE), `portes/`, `analisis/` (md, sql, csv), `tareas/` (MNT-NNN) |
| `plataforma/` | Arquitectura, estado, decisiones, roadmap y `tareas/` (con capturas) de la nueva plataforma. Historial git traído de `D:\Documentos\Amsys` |
| `migracion/` | Plan de la nueva plataforma, pendientes de migración, olas por cliente |
| `meta/` | Planes sobre este propio repositorio |

Fuera de aquí, a propósito: `D:\Documentos\Amsys\docs\design\` (exportador y pantallas para Claude Design; se
regeneran desde la app, son herramienta del código).

## Qué leer antes de cada tipo de trabajo

| Trabajo | Leer |
|---|---|
| Nueva plataforma | `plataforma/README.md`, `plataforma/CURRENT-STATE.md`, `plataforma/DECISIONS.md` |
| Legacy, cualquier rama | `legacy/README.md`, `legacy/CURRENT-STATE.md`, `legacy/ramas.md`, `clientes/<rama actual>.md` |
| Portar algo de `main` a un cliente | además `legacy/portes/` (porte previo como modelo) |
| Reglas de negocio / comportamiento | `negocio/BUSINESS-RULES.md`, `negocio/flujos/workflow.md`, `negocio/flujos/orders.md` |
| Migrar un cliente a la plataforma | `migracion/PENDIENTES-MIGRACION.md`, `migracion/clientes-olas.md`, `clientes/<cliente>.md` |

## Reglas de uso

1. **Una sola fuente**: nada de conocimiento en carpetas `ai/` de los repos de código.
2. **Fechas absolutas** (AAAA-MM-DD) y, si algo depende del código, **rama y commit** (p. ej. "agchavin, sin commit al
   2026-10-30").
3. Tras cada avance: actualizar el `CURRENT-STATE.md` del frente y `ESTADO.md`; las decisiones van en
   `plataforma/DECISIONS.md` (o en el plan del legacy que corresponda).
4. Fichas de cliente al día cuando se toque su rama (bitácora al final de cada ficha).
5. **Sin secretos**: ni contraseñas, ni tokens, ni cadenas de conexión. Solo dónde están (user-secrets, servidor).
6. Commit del cerebro al final de cada sesión de trabajo.
7. Documentación en español.
