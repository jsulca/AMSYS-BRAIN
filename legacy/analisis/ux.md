# Análisis UX / UI – Módulo de Mantenimiento

> Análisis desde la perspectiva de un **usuario frecuente** (planificador, supervisor, técnico).
> Ninguna mejora ha sido implementada. Cada hallazgo indica pantalla, situación, impacto y propuesta.

---

## 1. Inventario de pantallas

| # | Pantalla | Ruta | LOC | Tipo |
|---|----------|------|-----|------|
| 1 | Lista de Hojas de Ruta | `/Gestion/HojaRuta/Index` | 157 | Grilla + filtros |
| 2 | Nueva/Editar Hoja de Ruta | modal `_Nuevo` / `_Editar` | 79 / 80 | Modal |
| 3 | Ver Hoja de Ruta | `/Gestion/HojaRuta/Ver/{id}` | 164 | Detalle |
| 4 | Lista de Secciones | `/Gestion/Seccion/Index` | 152 | Grilla + filtros |
| 5 | Nueva Sección | `/Gestion/Seccion/Nuevo` | 575 | Formulario + 4 pestañas |
| 6 | Editar Sección | `/Gestion/Seccion/Editar/{id}` | 607 | Formulario + 4 pestañas |
| 7 | Seleccionar Sección | modal `_Seleccionar` | 161 | Modal de búsqueda |
| 8 | Lista de Planes | `/Gestion/PlanMantenimiento/Index` | 174 | Grilla + filtros |
| 9 | Nuevo Plan | `/Gestion/PlanMantenimiento/Nuevo` | 254 | Formulario + tabla |
| 10 | Editar Plan | `/Gestion/PlanMantenimiento/Editar/{id}` | 322 | Formulario + tabla |
| 11 | Asignar objetos al Plan | `/Gestion/PlanMantenimiento/Asignar/{id}` | 342 | 2 tablas + modales |
| 12 | Ver Plan | `/Gestion/PlanMantenimiento/Ver/{id}` | 346 | Detalle + matriz de comportamiento |
| 13 | Asignar Equipo/Ubicación | modales `_Nuevo` / `_Editar` | — | Modal |
| 14 | Previsualizar Órdenes | `/Gestion/OrdenTrabajo/Previsualizar` | 318 | Tarjetas + DataTable |
| 15 | Lista de Órdenes | `/Gestion/OrdenTrabajo/Index` | 266 | Grilla + filtros |
| 16 | Kanban de Órdenes | `/Gestion/OrdenTrabajo/Kanban` | 253 | Columnas drag & drop |
| 17 | Nueva OT | `/Gestion/OrdenTrabajo/Nuevo` | 952 | Formulario grande |
| 18 | Editar OT | `/Gestion/OrdenTrabajo/Editar/{id}` | 1230 | Formulario grande |
| 19 | Notificar OT | `/Gestion/OrdenTrabajo/Notificar/{id}` | 1532 | Formulario muy grande |
| 20 | Ver OT | `/Gestion/OrdenTrabajo/Ver/{id}` | 1307 | Detalle muy grande |

**Observación transversal**: 6 vistas superan las 500 líneas y 4 superan las 950, con JavaScript
inline. Es un factor de riesgo de regresión y una barrera para cualquier rediseño incremental.

---

## 2. Aspectos positivos identificados

Antes de listar problemas, conviene registrar lo que **funciona bien** y debe conservarse:

1. **Matriz de "Comportamiento"** en `PlanMantenimiento/Ver`: tabla que cruza secciones × posiciones
   mostrando en qué posición se ejecuta cada una. Es la mejor pieza de UX del módulo: hace visible
   un concepto abstracto.
2. **Indicadores de estado por color** consistentes: rojo para equipos no montados y para
   asignaciones bloqueadas, verde/rojo para Activo.
3. **Patrón de filtro en la cabecera de tabla** (fila de inputs bajo el `<thead>`) consistente en
   todas las grillas, con búsqueda al pulsar Enter.
4. **Kanban con carga incremental por cursor** (`KanbanColumna` con cursor Base64) — buena decisión
   de rendimiento.
5. **Duplicar sección** (`Seccion/Nuevo?id=N`): acelera mucho la creación de plantillas similares.
6. **Previsualización antes de generar**: el concepto es correcto y valioso.

---

## 3. Hallazgos UX

### UX-01 — CRITICAL — La jerarquía Plan → Hoja de Ruta → Sección → Tarea no se comunica en ningún sitio

- **Pantallas**: todas las del módulo.
- **Situación actual**: el usuario debe descubrir por ensayo y error que:
  - las Secciones se crean en un menú **independiente** del Plan,
  - una Sección puede no tener Hoja de Ruta,
  - el Plan **no** selecciona hojas de ruta, sino secciones sueltas,
  - la Hoja de Ruta es sólo una etiqueta de agrupación para buscar secciones.
  No hay migas de pan, ni diagrama, ni texto de ayuda, ni enlaces cruzados entre las tres pantallas.
- **Impacto**: curva de aprendizaje muy alta; el modelo mental que el usuario construye
  (jerarquía en cascada) **no coincide con el sistema real**, lo que produce planes mal armados.
- **Lo que sí existe**: `HojaRuta/Ver.cshtml:39` enlaza a `Seccion/NuevoPorHR/{id}` ("Nueva Sección"),
  el único puente explícito entre dos entidades del módulo. Es el patrón a replicar.
- **Propuesta**: (a) migas de pan reales en las tres pantallas; (b) desde `Seccion/Ver|Editar`,
  mostrar en qué planes participa esa sección (`Seccion.PlanesMantenimiento` ya existe como
  navegación y no se usa en ninguna vista); (c) panel de ayuda desplegable con el diagrama de
  `DOMAIN-MODEL.md`.
- **Prioridad**: HIGH → tarea `MNT-037`

### UX-02 — HIGH — Al configurar el Plan no se ve el efecto de `Intervalo` y `Nivel`

- **Pantallas**: `PlanMantenimiento/Nuevo`, `PlanMantenimiento/Editar`.
- **Situación actual**: el usuario introduce `Intervalo` y `Nivel` por sección en una tabla, sin
  saber qué ocurrirá. La matriz de comportamiento que lo explica **sólo existe en `Ver`**, es decir
  *después* de guardar. Para ajustar hay que: guardar → ir a Ver → volver a Editar → guardar → …
- **Impacto**: ciclo de retroalimentación roto en la operación conceptualmente más difícil del
  módulo. Fuente principal de planes mal configurados.
- **Propuesta**: mover la matriz de comportamiento a `Nuevo`/`Editar` como vista previa reactiva
  (calculada en cliente, misma fórmula que `PlanMantenimiento.Adicional.cs`), actualizada al
  cambiar `Intervalo`, `Rutina` o cualquier fila.
- **Prioridad**: HIGH → tarea `MNT-038`

### UX-03 — HIGH — Terminología triple e incoherente para el mismo concepto

- **Pantallas**: `PlanMantenimiento/{Index,Nuevo,Editar,Ver}`.
- **Situación actual**:
  - La propiedad se llama `Rutina`.
  - El switch está rotulado *Dinámico* (izquierda) / *Estático* (derecha), sin indicar cuál es el
    valor marcado.
  - La grilla titula la columna **COMPORTAMIENTO** y muestra *Estático* / *Dinámico*.
  - El filtro de la grilla ofrece *ESTÁTICO* / *DINÁMICO*.
  - No hay ninguna explicación de qué cambia (la fórmula de `CantidadPosiciones`).
- **Impacto**: el usuario no puede predecir el efecto de un switch que altera radicalmente el plan.
- **Propuesta**: elegir un único término visible, sustituir el switch por dos *radio buttons* con
  descripción corta bajo cada opción, y un tooltip con la fórmula resultante.
- **Prioridad**: HIGH → tarea `MNT-039`

### UX-04 — CRITICAL — Editar una asignación reinicia el ciclo sin advertencia

- **Pantallas**: `PlanMantenimientoEquipo/_Editar`, `PlanMantenimientoUbicacion/_Editar`.
- **Situación actual**: cambiar cualquier campo (incluso sólo `TipoProgramacion`) pone
  `PosicionActual = PosicionInicio`, `ContadorActual = ContadorInicio` y `UltimaEjecucion = null`
  (`BR-AS-007`). El modal no dice nada.
- **Impacto**: pérdida silenciosa del avance real del mantenimiento de un equipo. Es una acción
  **destructiva disfrazada de edición**.
- **Propuesta**: (a) confirmación explícita que enumere lo que se perderá; (b) separar en dos
  acciones distintas: *Editar datos* (no destructiva) y *Reiniciar ciclo* (destructiva, con
  confirmación).
- **Prioridad**: CRITICAL → tarea `MNT-006`

### UX-05 — HIGH — No hay forma de desbloquear una asignación

- **Pantallas**: `PlanMantenimiento/Ver`, `PlanMantenimiento/Asignar`.
- **Situación actual**: la columna *BLOQUEADO* muestra `SI` en rojo. No hay ninguna acción asociada.
  El usuario ve el problema y no puede resolverlo (ver `MNT-005`).
- **Impacto**: equipos que dejan de generar mantenimiento preventivo indefinidamente, con el
  síntoma visible pero sin remedio disponible.
- **Propuesta**: acción *Desbloquear* con confirmación y registro de auditoría, condicionada a un
  permiso específico; además, mostrar la OT que causó el bloqueo con enlace directo.
- **Prioridad**: CRITICAL → tarea `MNT-005`

### UX-06 — HIGH — La previsualización miente sobre los códigos y no explica las omisiones

- **Pantalla**: `OrdenTrabajo/Previsualizar`.
- **Situación actual**:
  - Se muestran códigos `OT-2026-00123` que **no serán los definitivos** (`BR-GE-013`).
  - Los equipos que no se generan por no estar montados desaparecen sin explicación (`BR-GE-007`).
  - Las posiciones sin secciones no aparecen (`BR-UNK-003`).
  - Los planes bloqueados no se listan ni se mencionan.
- **Impacto**: el planificador no puede confiar en la pantalla ni auditar por qué falta un equipo.
- **Propuesta**: (a) no mostrar código, o rotularlo "código provisional"; (b) sección plegable
  *"No se generará (N)"* con el motivo por elemento: sin ubicación, bloqueado, plan inactivo,
  posición sin secciones.
- **Prioridad**: HIGH → tarea `MNT-040`

### UX-07 — HIGH — Generación selectiva silenciosa y sin manejo de error

- **Pantalla**: `OrdenTrabajo/Previsualizar`.
- **Situación actual**:
  - La selección se lee con `$('input[name="Rutina"]:checked:visible')`. En la pestaña *Tarjetas*
    los checkboxes de la tabla no son visibles → se envía selección vacía y el sistema informa
    *"Se generaron 0 orden(es) de trabajo"*.
  - El `$.post` **no define `error`**: ante un fallo del servidor el botón queda deshabilitado para
    siempre y no aparece ningún mensaje.
  - Usa `confirm()` y `alert()` nativos, rompiendo la consistencia con SweetAlert del resto del módulo.
  - El nombre del control es `Rutina`, sin relación con lo que hace.
- **Impacto**: acción crítica e irreversible (crea órdenes reales) con la peor retroalimentación
  del módulo.
- **Propuesta**: contador de selección visible ("N de M seleccionadas"), botón deshabilitado si N=0,
  `Swal.fire` para confirmar y para el resultado, manejador `error` obligatorio, y renombrar el input.
- **Prioridad**: HIGH → tarea `MNT-032`

### UX-08 — MEDIUM — Diferencia irreconciliable entre lo que muestra el `<select>` de estado y lo que acepta el servidor

- **Pantallas**: `OrdenTrabajo/Editar`, `OrdenTrabajo/Notificar`, `OrdenTrabajo/Kanban`.
- **Situación actual**: el Kanban permite `CIERRE_TECNICO → ANULADO`; el formulario no lo ofrece.
  Y el formulario, a la inversa, acepta cualquier estado si se manipula el POST.
- **Impacto**: dos caminos para la misma operación con reglas distintas; el usuario aprende que
  "por Kanban sí se puede y por el formulario no", sin motivo aparente.
- **Prioridad**: HIGH → tarea `MNT-003`

### UX-09 — MEDIUM — `Inicio >= hoy` bloquea la edición de asignaciones antiguas

- **Pantalla**: `PlanMantenimientoEquipo/_Editar`.
- **Situación actual**: `BR-AS-006` valida `Inicio >= DateTime.Today` **también al editar**. Para
  cambiar el `TipoProgramacion` de una asignación creada hace un año hay que mover la fecha de
  inicio al futuro, con el efecto colateral de UX-04.
- **Impacto**: el usuario no puede corregir datos sin alterar la programación.
- **Propuesta**: aplicar la validación sólo a la creación, o sólo si `Inicio` realmente cambió.
- **Prioridad**: MEDIUM → tarea `MNT-041`

### UX-10 — MEDIUM — Botón *Guardar* separado de la mitad del formulario

- **Pantallas**: `PlanMantenimiento/{Nuevo,Editar}`, `Seccion/{Nuevo,Editar}`.
- **Situación actual**: el botón *Guardar* está en el pie de la tarjeta *Datos de Cabecera*, y
  debajo hay una segunda (o quinta) tarjeta con Secciones / Tareas / Materiales / Servicios /
  Adjuntos. Tras añadir 20 tareas hay que subir a buscar el botón.
- **Impacto**: fricción constante; sensación de que el botón guarda "sólo la cabecera".
- **Propuesta**: barra de acciones fija (`position: sticky`) al pie de la ventana con
  *Guardar* / *Cancelar*, e indicador de cambios sin guardar.
- **Prioridad**: MEDIUM → tarea `MNT-042`

### UX-11 — MEDIUM — Sin aviso de cambios sin guardar

- **Pantallas**: todos los formularios grandes.
- **Situación actual**: el enlace *Regresar* es un `<a href>` normal. Pulsarlo tras 15 minutos de
  captura descarta todo sin preguntar. Igual ocurre al cerrar los modales con `data-bs-dismiss`.
- **Impacto**: pérdida de trabajo. Alta probabilidad en `Seccion/Nuevo` y `OrdenTrabajo/Notificar`.
- **Propuesta**: `beforeunload` + interceptar *Regresar* cuando el formulario esté sucio.
- **Prioridad**: MEDIUM → tarea `MNT-042`

### UX-12 — MEDIUM — Mensajes de validación agrupados y despegados del campo

- **Pantallas**: todas.
- **Situación actual**: el servidor devuelve un `PartialView("_Error")` con la lista de errores,
  que el JS inyecta en un `<div id="mensajes">`. Los mensajes son del estilo
  *"La tarea nro. 7, es necesario que la duración sea mayor a cero."* Nada marca la fila 7 ni
  desplaza la vista hasta ella.
- **Impacto**: en una sección con 30 tareas, localizar el error es manual.
- **Propuesta**: devolver errores estructurados (campo → mensaje), resaltar la fila/celda, hacer
  scroll al primer error y validar en cliente antes de enviar.
- **Prioridad**: MEDIUM → tarea `MNT-043`

### UX-13 — MEDIUM — Estados vacíos y de carga pobres

- **Situación actual**:
  - Estado vacío: `"No existen registros"` en una celda con `colspan` **incorrecto** (`colspan='7'`
    en `Seccion/_Seleccionar` que tiene 5 columnas; `colspan='10'` en `PlanMantenimiento/Index` que
    tiene 8) y con HTML mal cerrado (`</td></td>`).
  - Estado de carga: sólo `helper.wait` genérico. En `Previsualizar`, que puede tardar segundos,
    no hay ningún indicador durante el GET.
  - El estado vacío no ofrece la acción siguiente ("Crear el primer plan").
- **Prioridad**: LOW → tarea `MNT-044`

### UX-14 — MEDIUM — Acciones destructivas sin confirmación uniforme

- **Situación actual**:
  - Quitar una fila de sección/tarea de la tabla: `$(this).parents().eq(1).remove()` — **sin
    confirmación**, y sin deshacer.
  - Eliminar una asignación de equipo: sí confirma.
  - Generar órdenes: confirma con `confirm()` nativo.
  - Guardar: confirma con `Swal.fire` (confirmar para guardar es innecesario y entrena al usuario a
    aceptar sin leer, lo que degrada las confirmaciones que sí importan).
- **Propuesta**: quitar la confirmación de *Guardar*, añadirla a las eliminaciones de filas
  (o mejor, permitir deshacer), y unificar en SweetAlert.
- **Prioridad**: MEDIUM → tarea `MNT-045`

### UX-15 — MEDIUM — Densidad de información en Notificar / Ver OT

- **Pantallas**: `OrdenTrabajo/Notificar` (1532 líneas), `OrdenTrabajo/Ver` (1307).
- **Situación actual**: la pantalla de Notificar carga simultáneamente tareas, materiales,
  materiales externos, empleados, socios de negocio, socios externos, contadores, puntos de medida,
  aspectos de equipo, aspectos de ubicación, adjuntos y comentarios. `Ver` carga 17 colecciones en
  una sola petición (`BuscarAsync` con 17 flags en `true`).
- **Impacto**: carga cognitiva altísima para el técnico, que en el 90 % de los casos sólo marca
  tareas ejecutadas y horas. Además el tiempo de carga crece con cada colección.
- **Propuesta**: pestañas con carga diferida (lazy) por pestaña; en móvil, un flujo simplificado
  centrado en "marcar tareas" (la API móvil ya existe: `Api/Controllers/NotificacionTareaController`).
- **Prioridad**: MEDIUM → tarea `MNT-046`

### UX-18 — MEDIUM — No se avisa de un código duplicado 🟢 REQUISITO DEL PROPIETARIO (`D-03`)

- **Pantallas**: `HojaRuta/_Nuevo`, `HojaRuta/_Editar`, `Seccion/Nuevo`, `Seccion/Editar`.
- **Situación actual**: nada indica que el código introducido ya existe. El usuario lo descubre
  después, al buscar y encontrar dos registros con el mismo código. La función *"duplicar sección"*
  (`Seccion/Nuevo?id=N`) agrava el caso: clona el registro **conservando el código**, de modo que el
  duplicado se produce sin que el usuario escriba nada.
- **Impacto**: confusión al seleccionar secciones en un plan, donde el modal muestra código y nombre
  y dos filas pueden resultar indistinguibles.
- **Decisión del propietario (`D-03`, 2026-08-29)**:
  > *"No deben ser únicos porque a veces se puede duplicar. Lo que sí pondríamos en el UX es una
  > alerta de que ya existe un código de hoja de ruta similar. Las secciones dentro de una hoja de
  > ruta pueden tener el código duplicado, pero igual deberíamos darle una alerta."*
- **Propuesta**: advertencia **no bloqueante** (ámbar) junto al campo *Código*, al salir de él, que
  identifique el registro existente por su nombre. Ámbito: la empresa para Hoja de Ruta, la Hoja de
  Ruta para Sección. El guardado se permite siempre.
- **Prioridad**: MEDIUM → tarea `MNT-048`

> [!CAUTION]
> Este hallazgo **no pide una validación**. Convertirlo en un bloqueo contradice `D-03` y rompería
> flujos de trabajo que hoy son legítimos.

### UX-16 — LOW — La lista de Planes no muestra el dato más útil

- **Pantalla**: `PlanMantenimiento/Index`.
- **Situación actual**: las columnas son Código, Descripción, UMS+Intervalo, Factor Plan.,
  Comportamiento, Activo. **No muestra** cuántos equipos/ubicaciones tiene asignados, cuántas
  secciones, cuántas OT abiertas ni cuántas asignaciones bloqueadas.
- **Impacto**: para saber si un plan "está vivo" hay que entrar a Ver, uno por uno.
- **Propuesta**: columnas de conteo (secciones, objetos asignados, bloqueados) con badge de alerta.
- **Prioridad**: LOW → tarea `MNT-047`

### UX-17 — LOW — Sin ordenamiento por columna en las grillas propias

- **Situación actual**: `helper.pagination` no soporta ordenar; el orden es fijo
  (`OrderByDescending(x => x.Id)`). Sólo `Previsualizar` usa DataTables.
- **Prioridad**: LOW

---

## 4. Hallazgos UI

### UI-01 — MEDIUM — Responsive incompleto en las tablas editables
- Las tablas de secciones/tareas usan `table-responsive` (scroll horizontal) con 9 columnas que
  contienen `<select>` y `<input>`. En móvil son inutilizables: hay que hacer scroll horizontal
  mientras se escribe.
- Las cabeceras usan `width="150"` en píxeles fijos, que no se adaptan.
- **Propuesta**: en breakpoints pequeños, colapsar cada fila a una tarjeta con etiquetas.

### UI-02 — MEDIUM — Colores de cabecera de tabla sin significado consistente
- `bg-primary` (secciones), `bg-warning` (tareas y comportamiento), `bg-success` (equipos y
  ubicaciones asignados). El mismo `bg-warning` se usa para "tareas" y para "matriz de
  comportamiento", que no tienen relación.
- **Propuesta**: reservar el color para el significado (azul = configuración, verde = asignación,
  ámbar = advertencia) y documentarlo.

### UI-03 — LOW — El botón "Regresar" usa `btn-warning`
- Ámbar comunica advertencia. Una navegación de retorno debería ser `btn-secondary` o un enlace.
- Aparece así en todas las pantallas del módulo.

### UI-04 — LOW — Iconografía ambigua en la grilla de Planes
- `fa-pencil-alt` (Editar), `fa-project-diagram` (Asignar), `fa-eye` (Ver). *Asignar* es la acción
  más importante del flujo y su icono no lo sugiere; sólo se distingue por el `title`.

### UI-05 — LOW — Campos numéricos sin unidad visible
- `Intervalo` en el Plan no muestra la unidad (la UMS está en otro campo). En la tabla de secciones,
  la columna `INTERVALO` es un multiplicador relativo, no una unidad de tiempo, y nada lo indica.
- **Propuesta**: `input-group` con la unidad como sufijo, y renombrar la columna a
  *"Cada N ciclos"* o similar.

### UI-06 — LOW — Etiquetas de switch sin estado activo
- El switch `Rutina` tiene dos etiquetas a los lados sin resaltar cuál está seleccionada.

### UI-07 — LOW — Tipografía y espaciado
- Uso mixto de `g-1` y `g-2` para el mismo tipo de rejilla entre `Nuevo` y `Ver`; `font-size-18`
  como clase de utilidad ad-hoc sólo en los títulos de página.

---

## 5. Evaluación desde el uso frecuente

| Pregunta | Respuesta | Evidencia |
|----------|-----------|-----------|
| ¿Puede encontrar rápido lo que necesita? | Parcialmente. Los filtros por columna son buenos, pero no hay búsqueda global ni accesos recientes. | UX-16 |
| ¿Las acciones importantes están claras? | No. *Asignar* y *Generar* — las dos acciones que realmente producen mantenimiento — están escondidas tras un icono y tras dos niveles de navegación. | UX-01, UI-04 |
| ¿Hay demasiada información simultánea? | Sí, gravemente, en `Notificar` y `Ver` de la OT. | UX-15 |
| ¿Existen pasos innecesarios? | Sí: confirmar cada *Guardar*; y el ciclo guardar→Ver→Editar para ajustar un plan. | UX-02, UX-14 |
| ¿El sistema comunica lo que ocurre? | No en los caminos críticos: generación selectiva vacía, equipos omitidos, asignaciones bloqueadas. | UX-05, UX-06, UX-07 |
| ¿Los errores son comprensibles? | Parcialmente. El texto es claro, pero no se localiza el campo. | UX-12 |
| ¿Es fácil corregir un error? | No en el Plan: hay que reeditar y volver a comprobar en otra pantalla. | UX-02 |
| ¿Las relaciones Plan → HR → Sección → Tarea son claras? | **No.** Y además la relación real no es la que el usuario supone. | UX-01 |

---

## 6. Resumen priorizado

| Prioridad | Hallazgos | Tareas |
|-----------|-----------|--------|
| CRITICAL | UX-04, UX-05 | `MNT-005`, `MNT-006` |
| HIGH | UX-01, UX-02, UX-03, UX-06, UX-07, UX-08 | `MNT-003`, `MNT-032`, `MNT-037`, `MNT-038`, `MNT-039`, `MNT-040` |
| MEDIUM | UX-09…UX-15, **UX-18**, UI-01, UI-02 | `MNT-041`, `MNT-042`, `MNT-043`, `MNT-045`, `MNT-046`, **`MNT-048`** |
| LOW | UX-16, UX-17, UI-03…UI-07 | `MNT-044`, `MNT-047` |

### Nota sobre las decisiones del propietario (2026-08-29)

| Decisión | Efecto en este análisis |
|----------|-------------------------|
| `D-03` | **UX-18 pasa de observación a requisito explícito.** El propietario pidió la alerta de código duplicado; es la única mejora de UX de este documento solicitada directamente por él. |
| `D-02` | UX-08 (divergencia entre el `<select>` y el Kanban) queda resuelta en su parte de diseño: el Kanban es el que está mal. Sólo falta implementarlo (`MNT-003`). |
| `D-05` | No afecta a ningún hallazgo de UX, pero **refuerza UX-06 y UX-07**: si la generación depende por completo de una persona pulsando un botón, la pantalla de previsualización tiene que comunicar impecablemente qué va a generar y qué no. |
