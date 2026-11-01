# Plan: crear AMSYS-BRAIN

Estado: **plan, sin ejecutar** (2026-10-31).

## Objetivo

Un repositorio git propio, `D:\Documentos\AMSYS-BRAIN`, con todo el conocimiento de AMSYS (negocio, clientes,
legacy, nueva plataforma, migración). Los repositorios de código solo guardan un `CLAUDE.md` corto que apunta al
cerebro.

**Por qué fuera del código** (acordado en la conversación del 2026-10-31):
- El legacy tiene una rama por cliente (11). Si los documentos viven en el repositorio, cambian con cada `checkout`
  o divergen entre ramas. Hoy `ai/` del legacy está **sin versionar** en todas las ramas: no se pierde al cambiar
  de rama, pero tampoco tiene historial ni respaldo.
- Las reglas de negocio, las diferencias por cliente y la migración sirven al legacy **y** al nuevo Amsys, y hoy
  están repartidas entre los dos `ai/`.
- Las decisiones cambian a otro ritmo que el código.

**Lo que cuesta:** cerebro y código no se versionan juntos. Regla: lo que dependa del código se anota con fecha y
rama/commit (p. ej. "agchavin, sin commit al 2026-10-30").

## Inventario de partida

| Origen | Contenido | Versionado |
|---|---|---|
| Legacy `D:\Documentos\Alphamanufacturas\AMSYS\AMSYS\ai\` (~1 MB) | ARCHITECTURE, BUSINESS-RULES, DOMAIN-MODEL, DOMAIN-MODE (vacío), SYSTEM-CONTEXT, CURRENT-STATE, README, PLAN-MULTICLIENTE, PLAN-NUEVA-PLATAFORMA, 7 PLAN-UX-*, PORTE-UI-MAIN-AGCHAVIN, `analysis/` (md + sql + csv), `tasks/` MNT-001…048, `completed/` | No (en ninguna rama) |
| Nueva plataforma `D:\Documentos\Amsys\ai\` (~26 MB) | ARCHITECTURE, CURRENT-STATE, DECISIONS, PENDIENTES-MIGRACION, README, ROADMAP, `tareas/` (NT-01, UI-01 + capturas), `claude-design/` (exportador + pantallas/capturas ignoradas + resultados) | Sí (33 commits) |
| `D:\Documentos\Amsys\CLAUDE.md` | Apunta a `ai/README.md`, `ai/CURRENT-STATE.md`, `ai/DECISIONS.md` | Sí |
| Legacy `CLAUDE.md` | No existe | — |
| Memoria de Claude | `amsys-nueva-plataforma.md` apunta a `D:\Documentos\Amsys\ai\CURRENT-STATE.md` | — |
| Referencias en código | Solo un comentario en `tests/Amsys.Web.Tests/AmsysTokensTests.cs` (ruta a `amsys-tokens.css`) | — |

Ramas del legacy (clientes): agchavin, akdrilling, ares, caja_arequipa, energiaycombustion, eulen, itc, main,
oterra, pyme, rentanor. Configuración de clientes en la nueva plataforma: `tools/clientes/` (amsys, demo, _plantilla).

## Estructura propuesta

```
AMSYS-BRAIN/
  README.md              ← índice, reglas de uso (qué leer antes de cada tipo de trabajo, cómo anotar)
  ESTADO.md              ← tablero corto: en qué está cada frente y enlace a su CURRENT-STATE
  negocio/               ← SYSTEM-CONTEXT, BUSINESS-RULES, DOMAIN-MODEL, flujos (analysis/workflow, orders)
  clientes/
    _plantilla.md
    agchavin.md, akdrilling.md, …  ← rama legacy, último commit, módulos que usa, particularidades,
                                      datos del servidor (sin claves), ola de migración, estado
  legacy/
    ARCHITECTURE.md, CURRENT-STATE.md
    ramas.md             ← cómo se trabaja por rama, qué se porta desde main y cómo
    planes/              ← PLAN-UX-*, PLAN-MULTICLIENTE
    portes/              ← PORTE-UI-MAIN-AGCHAVIN (y futuros portes por cliente)
    analisis/            ← analysis/*.md, *.sql, *.csv
    tareas/              ← MNT-001…048 (+ completed/)
  plataforma/
    ARCHITECTURE.md, CURRENT-STATE.md, DECISIONS.md, ROADMAP.md
    tareas/              ← NT-01, UI-01, … con sus capturas
  migracion/
    PLAN-NUEVA-PLATAFORMA.md, PENDIENTES-MIGRACION.md
    clientes-olas.md     ← orden de migración por cliente (ola 1 … oterra al final)
```

`claude-design/` de la nueva plataforma: **se queda en `D:\Documentos\Amsys`** (por ejemplo en `docs/design/`) porque
`exportar.mjs` regenera pantallas y capturas desde la app; es herramienta del código, no conocimiento. El cerebro
solo enlaza a ella. *(Decisión a confirmar al ejecutar.)*

## Pasos

### 0. Preparación
1. Confirmar que no hay trabajo a medio guardar en ninguno de los dos `ai/` (en el legacy hay cambios sin commit del
   código, pero `ai/` no se versiona; en Amsys hay `ai/CURRENT-STATE.md` y `ai/DECISIONS.md` modificados →
   commitearlos antes).
2. Copia de seguridad: comprimir los dos `ai/` en el scratchpad.

### 1. Crear el repositorio
1. `D:\Documentos\AMSYS-BRAIN` + `git init` (rama `main`).
2. `.gitignore` (temporales, `*.zip`, capturas regenerables) y `.gitattributes` (`*.md text eol=lf`,
   imágenes binarias).
3. README.md y ESTADO.md iniciales. Commit inicial.

### 2. Traer el contenido de la nueva plataforma **con historial**
Para no perder los 33 commits de `ai/`:
- `git subtree split -P ai` en `D:\Documentos\Amsys` → rama temporal → `git subtree add` (o `pull`) en el cerebro
  bajo `plataforma/`, excluyendo después `claude-design/` (que se mueve dentro de Amsys).
- Alternativa más simple si el historial no importa: copiar y anotar en el commit "historial en
  D:\Documentos\Amsys hasta <commit>". *(Decisión a confirmar.)*

### 3. Traer el contenido del legacy
Copiar (no tiene historial) según la estructura de arriba. `DOMAIN-MODE.md` (vacío) no se trae.

### 4. Reorganizar y unificar
1. Mover lo común a `negocio/` y `migracion/`. Si hay dos versiones del mismo tema (p. ej. ARCHITECTURE del legacy y
   de la plataforma), quedan separadas en su carpeta; reglas de negocio duplicadas se unifican en
   `negocio/BUSINESS-RULES.md` y se indica a qué sistema aplica cada una.
2. Crear `clientes/<rama>.md` para las 11 ramas, a partir de `git log`, PLAN-MULTICLIENTE y PENDIENTES-MIGRACION.
   **Sin contraseñas ni cadenas de conexión** (solo "dónde están").
3. Corregir rutas internas: buscar `ai/` en todos los `.md` y reemplazarlas por la ruta nueva dentro del cerebro.
4. Commit.

### 5. Dejar los puentes en los repositorios de código
- **Nueva plataforma** (`D:\Documentos\Amsys`):
  - Quitar `ai/` (salvo `claude-design`, movido a `docs/design/`, y ajustar el comentario de
    `AmsysTokensTests.cs` y las rutas de `exportar.mjs`/`.gitignore`).
  - `CLAUDE.md`: "Antes de trabajar, lee `D:\Documentos\AMSYS-BRAIN\README.md` y
    `plataforma/CURRENT-STATE.md`; al terminar, actualiza `plataforma/CURRENT-STATE.md` y `DECISIONS.md`".
  - Compilar y correr tests. Commit.
- **Legacy**:
  - Quitar `ai/` (ya está en el cerebro).
  - Crear `CLAUDE.md` puente **sin versionar**, igual para todas las ramas: lee el README del cerebro,
    `legacy/CURRENT-STATE.md` y `clientes/<rama actual>.md`; al terminar, actualiza esos archivos.
  - Añadir `CLAUDE.md`, `ai/` y `.idea/` a `.git/info/exclude` (local, no se commitea, vale para todas las ramas).

### 6. Configurar Claude Code
- En `~/.claude/settings.json` (usuario, sirve para los dos proyectos):
  `permissions.additionalDirectories: ["D:\\Documentos\\AMSYS-BRAIN"]`.
- Actualizar la memoria: `amsys-nueva-plataforma.md` → apuntar a `AMSYS-BRAIN\plataforma\CURRENT-STATE.md`, y
  nueva memoria `amsys-brain` (dónde está, qué se anota y dónde).

### 7. Respaldo remoto
Repositorio **privado** (GitHub/Azure DevOps, el que use la empresa) y `git push`. *(Decisión a confirmar: dónde.)*

### 8. Verificación
- Abrir una sesión nueva en cada proyecto y comprobar que Claude lee el cerebro sin pedir permisos.
- `grep -r "ai/"` en el cerebro y en los dos repos: sin rutas rotas.
- Cambiar de rama en el legacy (`git checkout main` y volver): el `CLAUDE.md` puente sigue ahí y `git status` limpio
  de `ai/`/`CLAUDE.md`.
- Revisar que no se subió ningún secreto (`grep -ri "password\|pwd=\|clave"`).

## Reglas de uso (irán en el README del cerebro)

1. **Una sola fuente**: nada de conocimiento en los `ai/` de los repos de código.
2. **Fechas absolutas** y, si depende del código, rama y commit.
3. Tras cada avance: actualizar el `CURRENT-STATE.md` del frente y `ESTADO.md`; decisiones en `DECISIONS.md`.
4. Fichas de cliente al día cuando se toque su rama.
5. Sin secretos: solo dónde están (user-secrets, servidor).
6. Commit del cerebro al final de cada sesión de trabajo.

## Decisiones pendientes (resolver al ejecutar)

| # | Pregunta | Recomendación |
|---|---|---|
| 1 | ¿Conservar el historial git de `ai/` de la plataforma? | Sí, con `git subtree` |
| 2 | ¿`claude-design` al cerebro o se queda en Amsys? | Se queda en Amsys (`docs/design/`) |
| 3 | ¿Dónde va el remoto privado? | El servicio que ya usa el legacy (`origin`) |
| 4 | ¿Fichas de las 11 ramas ahora o poco a poco? | Esqueleto de las 11 ahora; detalle al tocar cada una |
