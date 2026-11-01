# Estado actual

## Fase
`ANALYSIS` — **completada**. Ninguna tarea implementada todavía.

## Última actualización
2026-08-29

## Estado
Análisis exhaustivo del módulo de Mantenimiento finalizado. Documentación de dominio, reglas de
negocio, arquitectura, workflow, permisos y UX/UI completa. **49 tareas** de mejora en `/ai/tasks`,
todas en estado `PENDING`.

**3 de las 16 decisiones de negocio están resueltas** (`D-02`, `D-03`, `D-05`) y aplicadas a la
documentación y a las tareas afectadas. Quedan 13 pendientes, más 2 sub-preguntas nuevas
(`D-03b`, `D-05b`) surgidas de las respuestas.

**No se ha modificado ningún archivo fuera de `/ai`.**

---

## Análisis completado

| Área | Documento | Estado |
|------|-----------|--------|
| Contexto del sistema | `SYSTEM-CONTEXT.md` | ✅ (preexistente, revisado) |
| Modelo de dominio | `DOMAIN-MODEL.md` | ✅ (preexistente, ampliado) |
| Reglas de negocio | `BUSINESS-RULES.md` | ✅ 58 reglas (2 nuevas por `D-03`) |
| Arquitectura | `ARCHITECTURE.md` | ✅ |
| Entidades y procesos | `analysis/orders.md` | ✅ |
| Workflow y estados | `analysis/workflow.md` | ✅ |
| Permisos y seguridad | `analysis/permissions.md` | ✅ 11 vulnerabilidades |
| UX / UI | `analysis/ux.md` | ✅ 18 hallazgos UX + 7 UI |
| Tareas de mejora | `tasks/MNT-001` … `MNT-048`, más `MNT-008b` | ✅ 49 tareas |

### Alcance verificado en código
- 10 proyectos de la solución, 31 controladores del área `Gestion`, 55 repositorios, 35 lógicas.
- 120 archivos de entidades en `Gestion`, 55 configuraciones EF, 79 migraciones.
- ~9 500 líneas de vistas Razor del módulo revisadas.
- Ambas APIs (`AMSYS.WebAdmin/Api` y `AMSYS.WebAPI`).

---

## Análisis pendiente

Requiere **acceso a datos de producción**, no disponible en esta fase:

1. Inventario de la tabla `pagina` para el área `Gestion` — bloquea el diseño de `MNT-001`.
2. Auditoría de `rolestadoordentrabajo` / `rolestadoaviso` — bloquea `MNT-002`.
3. Duplicados de asignaciones `(plan, objeto técnico)` — bloquea `MNT-010` y `MNT-017`.
   *(Los duplicados de **códigos** ya no bloquean nada: `D-03` los declara admisibles.)*
4. Referencias cruzadas entre empresas — bloquea `MNT-022`.
5. Planes con `CantidadPosiciones = 0` y asignaciones fuera de rango — `MNT-012`, `MNT-016`.
6. Ubicaciones asignadas a planes por contador — `MNT-009`.
7. Volúmenes reales (secciones por hoja de ruta, órdenes por previsualización) — `MNT-023`, `MNT-030`.
8. Avisos desincronizados con sus órdenes — `MNT-007`.
9. Uso real de las sub-órdenes de trabajo — `MNT-033`.

Áreas fuera del alcance acordado, no analizadas: módulos `Logistica`, `Administracion`, `Seguridad`
(sólo lo que toca a Mantenimiento), `Dashboard`, y el proyecto `BackupPG`.

---

## Problemas identificados

**Total: 49** (uno por tarea).

| Severidad | Cant. | IDs |
|-----------|------:|-----|
| CRITICAL | 4 | MNT-001, 005, 006, 028 |
| HIGH | 21 | MNT-002, 003, 004, 007, **008b**, 009, 010, 011, 013, 014, 016, 019, 021, 022, 030, 032, 036, 037, 038, 039, 040 |
| MEDIUM | 20 | MNT-008, 012, 015, 017, 018, 020, 023, 024, 027, 029, 031, 033, 034, 035, 041, 042, 043, 045, 046, 048 |
| LOW | 4 | MNT-025, 026, 044, 047 |

> `MNT-008` bajó de CRITICAL a MEDIUM tras la decisión `D-05`: la generación manual es deliberada,
> no un defecto.

| Categoría | Cant. |
|-----------|------:|
| UX | 12 |
| SECURITY | 8 |
| DATA_INTEGRITY | 6 |
| BUSINESS_RULE | 7 |
| VALIDATION | 4 |
| MAINTAINABILITY | 3 |
| CODE_QUALITY | 3 |
| UI | 2 |
| PERFORMANCE | 2 |
| ARCHITECTURE | 1 |
| TESTING | 1 |

### Los 5 problemas más graves (actualizado tras las decisiones)
1. **`MNT-001`** — Ningún POST del módulo exige permiso. La autorización sólo protege las pantallas.
2. **`MNT-028`** — IDOR entre empresas: se puede reiniciar el ciclo de mantenimiento de otra empresa.
3. **`MNT-005`** — Una asignación FLOTANTE bloqueada no se puede desbloquear desde ninguna pantalla:
   el equipo deja de recibir mantenimiento preventivo de forma permanente.
4. **`MNT-006`** — Editar una asignación reinicia silenciosamente el ciclo de mantenimiento.
5. **`MNT-003`** — Dos máquinas de estados divergentes y ninguna aplicada en el servidor. Con `D-02`
   resuelta, el Kanban permite hoy una anulación que el negocio prohíbe explícitamente.

> **`MNT-008` sale de esta lista.** Con `D-05` resuelta, la generación manual es una decisión de
> negocio, no un defecto.

---

## Tareas generadas

49 archivos: `MNT-001` … `MNT-048`, más `MNT-008b` (derivada de la decisión `D-05`).
Todas en `PENDING`.

## Tareas completadas
Ninguna. `/ai/completed` está vacío.

---

## Bloqueadores

| # | Bloqueador | Tareas afectadas |
|---|-----------|------------------|
| B-01 | Sin acceso a datos de producción para los diagnósticos previos | MNT-001, 002, 004, 007, 009, 010, 012, 016, 017, 022, 024, 027, 029, 033, 034, 036 |
| B-02 | Sin proyecto de tests: cualquier cambio es a ciegas | Todas las de refactorización (MNT-013, 025, 029, 031, 046) |
| B-03 | Sin entorno de pruebas conocido para verificar regresiones | Todas |
| B-04 | 13 decisiones de negocio pendientes (+2 sub-preguntas nuevas) | Ver la tabla siguiente |

---

## Decisiones RESUELTAS

Respondidas por el propietario el **2026-08-29**. Son vinculantes: las tareas afectadas ya han sido
actualizadas y **no deben reabrirse** sin una nueva decisión.

### `D-05` — La generación de órdenes NO se automatiza ✅

> *"Es a demanda según lo que el usuario vaya encontrando en las órdenes de trabajo, ya que si
> automatizamos ellos tendrán problemas de planificación a futuro y su backlog será enorme."*

**Consecuencias documentadas:**
- La generación manual (`BR-GE-001`) deja de ser un problema y pasa a ser una **regla de negocio
  deliberada**. Reclasificada en `BUSINESS-RULES.md`.
- `BR-GE-005` (los planes por calendario avanzan **una** posición por ejecución) queda **alineada con
  la decisión**: es precisamente el mecanismo que evita la explosión de backlog. Deja de ser un
  hallazgo y pasa a ser comportamiento correcto.
- `MNT-008` se reescribe por completo: de *"implementar la automatización"* (CRITICAL) a
  *"documentar la decisión y entregar la observabilidad"* (MEDIUM).
- **Sub-pregunta abierta `D-05b`**: `BR-GE-006` — los planes por **contador** sí saltan directamente
  a la posición final y descartan las posiciones intermedias. Eso **contradice** el razonamiento de
  esta decisión: genera menos órdenes de las debidas y pierde mantenimiento en silencio. Ver la
  sección *Decisiones pendientes*.

### `D-02` — No se puede anular una OT con cierre técnico ✅

> *"No debería permitirme anular una orden si esta se encuentra en cierre técnico."*

**Consecuencias documentadas:**
- Se adopta la **Definición A** (`OrdenTrabajo.EstadosHabilitados()`) como única máquina de estados.
- `KanbanMover` es **incorrecto** y debe corregirse: hoy permite `CIERRE_TECNICO → ANULADO`.
- `MNT-003` queda **desbloqueada** y sube en la prioridad de ejecución.
- Máquina de estados oficial:

```
EMITIDO --> CIERRE_TECNICO --> CIERRE_TOTAL
   |
   +------> ANULADO
```

### `D-03` — Los códigos NO son únicos; se advierte al usuario ✅

> *"No deben ser únicos porque a veces se puede duplicar. Lo que sí pondríamos en el UX es una alerta
> de que ya existe un código de hoja de ruta similar. Las secciones dentro de una hoja de ruta pueden
> tener el código duplicado, pero igual deberíamos darle una alerta."*

**Consecuencias documentadas:**
- **No se crean índices únicos** sobre `HojaRuta.Codigo`, `Seccion.Codigo` ni `PlanMantenimiento.Codigo`.
- `BR-UNK-005` deja de ser `UNKNOWN`: pasa a `CONFIRMED` como *"los códigos son deliberadamente no
  únicos"*.
- `MNT-010` reduce su alcance: se eliminan de él los índices únicos de códigos.
- Nueva tarea **`MNT-048`** — alerta no bloqueante de código duplicado en Hoja de Ruta y Sección.
- **Sub-pregunta abierta `D-03b`**: la decisión se refiere a los códigos que **escribe el usuario**.
  `OrdenTrabajo.Codigo` es **generado por el sistema** con `COUNT + 1`, y sus duplicados son
  accidentes de concurrencia, no una duplicación intencional. `MNT-004` se mantiene con el alcance
  reducido a *corregir la generación*, sin índice único. Ver *Decisiones pendientes*.

---

## Decisiones pendientes

Requieren respuesta del propietario del sistema antes de implementar la tarea asociada.

| ID | Pregunta | Tarea | Impacto si se decide mal |
|----|----------|-------|--------------------------|
| `D-01` | ¿Los estados permitidos por rol deben aplicarse, o se retira la funcionalidad? | MNT-002 | Aplicarlos sin auditar los datos bloquearía a usuarios en producción |
| `D-03b` | El código de la OT lo genera el sistema, no el usuario. ¿Se acepta que dos OT de la misma empresa y año compartan código por una condición de carrera, o debe corregirse la generación? | MNT-004 | Dos OT indistinguibles en PDF, Excel y app móvil |
| `D-04` | ¿El desbloqueo por cierre de OT debe ser por orden concreta o por par (plan, objeto técnico)? | MNT-005 | Generación duplicada de órdenes |
| `D-05b` | Los planes por **contador** saltan a la posición final y descartan las intermedias. ¿Es correcto, o deben generarse todas las posiciones pendientes como ocurre por calendario? | MNT-008b (nueva) | Mantenimiento perdido en silencio, o backlog inesperado |
| `D-06` | ¿Se prohíbe asignar ubicaciones a planes por contador, o se implementa el soporte? | MNT-009 | Implementarlo exige un modelo de contadores por ubicación inexistente |
| `D-07` | ¿La UMS de un plan debe ser realmente inmutable tras crearlo? | MNT-015 | Bajo |
| `D-08` | ¿Qué debe ocurrir con las asignaciones activas cuando cambia `CantidadPosiciones`: bloquear el cambio, reiniciar, o remapear? | MNT-016 | Pérdida del avance real de mantenimiento |
| `D-09` | ¿Eliminar una asignación con órdenes abiertas debe bloquearse o sólo advertirse? | MNT-018 | Bloquear podría dejar sin salida al usuario |
| `D-10` | Cuando una OT combina varias secciones, ¿las tareas deben agruparse por sección o mantenerse la mezcla actual por `Orden`? | MNT-024 | Cambia el orden de trabajo del técnico |
| `D-11` | ¿El `Nivel` de una sección debe ser único dentro del plan? ¿Debe correlacionarse con el `Intervalo`? | MNT-027 | Prohibir configuraciones legítimas |
| `D-12` | ¿Normalizar el `PosicionActual` acumulado de las ubicaciones, o sólo aplicar el módulo a los valores nuevos? | MNT-029 | Alterar datos de producción |
| `D-13` | ¿Qué significan las sub-órdenes de trabajo? ¿Puede cerrarse el padre con hijas abiertas? ¿Se acumulan costos? | MNT-033 | Bloquear el cierre podría paralizar la operación |
| `D-14` | ¿Los permisos a nivel de Elemento se implementan o se retiran? | MNT-034 | Medio |
| `D-15` | ¿Qué modelo de permisos debe aplicarse a la API móvil? | MNT-036 | Dejar a los técnicos sin poder registrar su trabajo |
| `D-16` | ¿Qué término usa el negocio para el modo del plan: "Rutina", "Estático/Dinámico", u otro? | MNT-039 | Bajo |

---

## Siguiente acción recomendada

### 1. Revisión de este análisis por el propietario
Antes de escribir una sola línea de código de producción, validar:
- que el modelo de dominio documentado en `DOMAIN-MODEL.md` corresponde a lo esperado,
- que las reglas marcadas `CONFIRMED` reflejan el negocio real,
- las **13 decisiones pendientes**, priorizando `D-05b` (salto de posiciones por contador),
  `D-03b` (código de OT duplicado por concurrencia) y `D-01` (estados por rol).

`D-02`, `D-03` y `D-05` ya están resueltas y aplicadas a la documentación.

### 2. Primer bloque de implementación
En este orden:

| Orden | Tarea | Por qué primero |
|-------|-------|-----------------|
| 1 | `MNT-019` | Crear el proyecto de tests. No toca producción y desbloquea todo lo demás. |
| 2 | `MNT-001` | Mayor superficie de riesgo cerrada con el menor cambio. Requiere el inventario de páginas. |
| 3 | `MNT-028` | IDOR entre empresas. Cambio pequeño, impacto alto. |
| 4 | `MNT-011` | Un carácter (`_.Estado` → `x.Estado`) que elimina una causa de bloqueo permanente. |
| 5 | **`MNT-003`** | **Desbloqueada por `D-02`.** Una sola máquina de estados, aplicada en servidor. Corrige el Kanban, que hoy permite una anulación prohibida. |
| 6 | `MNT-021` | Mismo patrón de defecto que `MNT-028`, en lectura. |

### 3. Segundo bloque (agrupado por archivo, para no tocar dos veces lo mismo)
- **Asignaciones**: `MNT-006` + `MNT-028` + `MNT-041` (mismos controladores y lógicas).
- **Previsualización**: `MNT-030` + `MNT-032` + `MNT-040` (misma vista).
- **Plan de mantenimiento**: `MNT-012` + `MNT-015` + `MNT-027` + `MNT-038` + `MNT-039`.
- **Alertas de código duplicado**: `MNT-048` (desbloqueada por `D-03`), junto a `MNT-037`
  (navegación entre Hoja de Ruta y Sección), que toca las mismas pantallas.

### 4. Diagnósticos a solicitar
Muchas tareas empiezan con un diagnóstico sobre datos reales. Conviene ejecutarlos **todos juntos**
en una sola sesión de consultas y volcar los resultados en `/ai/analysis/`, para no ir pidiendo
accesos de uno en uno. Ver la sección *Análisis pendiente*.

---

## Registro de cambios de este archivo

| Fecha | Cambio |
|-------|--------|
| 2026-08-29 | Creación. Fase ANALYSIS completada; 47 tareas generadas; 16 decisiones pendientes. |
| 2026-08-29 | Decisiones `D-02`, `D-03` y `D-05` resueltas por el propietario. Reescritas `MNT-003`, `MNT-004`, `MNT-008` y `MNT-010`; creada `MNT-048`. Surgen `D-03b` y `D-05b`. Quedan 13 decisiones pendientes. |
