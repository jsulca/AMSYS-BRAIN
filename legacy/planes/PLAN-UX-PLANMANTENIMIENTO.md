# Plan de mejora de UX – Módulo Plan de Mantenimiento

> Documento **ejecutable paso a paso**. Cada paso es independiente, pequeño y verificable.
> Marca la casilla de cada paso al terminarlo y anótalo en el *Registro de avance* del final.

- **Alcance**: las 6 vistas de `PlanMantenimiento` y los 4 modales de asignación.
- **Fuera de alcance**: cambiar el algoritmo de programación, el modelo de datos, los permisos y
  cualquier pantalla de `OrdenTrabajo`, `Seccion` o `HojaRuta` (salvo enlaces de navegación).
- **Fecha**: 2026-09-16
- **Relación con `/ai`**: este documento **no reemplaza** `analysis/ux.md` ni `/tasks`. Es la
  secuencia concreta para la parte de PlanMantenimiento; cada paso indica a qué tarea `MNT-NNN`
  corresponde cuando ya existe.

---

## 1. Pantallas afectadas

| Vista | Archivo | LOC | Rol |
|-------|---------|-----|-----|
| Lista | `Views/PlanMantenimiento/Index.cshtml` | 174 | Buscar y entrar al plan |
| Nuevo | `Views/PlanMantenimiento/Nuevo.cshtml` | 254 | Crear el plan y elegir secciones |
| Editar | `Views/PlanMantenimiento/Editar.cshtml` | 322 | Ajustar cabecera y secciones |
| Asignar | `Views/PlanMantenimiento/Asignar.cshtml` | 342 | Enganchar equipos/ubicaciones |
| Ver | `Views/PlanMantenimiento/Ver.cshtml` | 346 | Consulta + matriz de comportamiento |
| Seleccionar | `Views/PlanMantenimiento/_Seleccionar.cshtml` | 143 | Modal de selección de planes |
| Modales | `Views/PlanMantenimientoEquipo/_{Nuevo,Editar}.cshtml`, `Views/PlanMantenimientoUbicacion/_{Nuevo,Editar}.cshtml` | ~120 c/u | Alta/edición de asignación |

## 2. Diagnóstico corto

1. **La lista se quedó atrás.** El commit `722013a` introdujo un patrón nuevo de listados
   (`helper.filtros`, `helper.tabla`, `helper.html.escape`, panel de filtros con *chips*) que hoy
   usan `Aviso/Index`, `Aviso/MisAvisos` y `OrdenTrabajo/Index`. `PlanMantenimiento/Index` sigue
   con el patrón viejo: fila de inputs dentro del `<thead>`, sin estado de carga, sin escapado.
2. **El concepto central del plan es invisible mientras se configura.** La matriz de
   *Comportamiento* —lo mejor de la interfaz— sólo existe en `Ver` y `Asignar`, es decir *después*
   de guardar. En `Nuevo`/`Editar` el usuario escribe `Intervalo` y `Nivel` a ciegas.
3. **Vocabulario inconsistente**: la misma propiedad se llama `Rutina` en el código,
   *Dinámico/Estático* en el switch y *COMPORTAMIENTO* en la grilla.
4. **La columna `INTERVALO` de secciones significa dos cosas distintas** según la pantalla: en
   `Nuevo`/`Editar` es el multiplicador crudo; en `Ver` se muestra ya multiplicado por el intervalo
   del plan (`Ver.cshtml:118`). Mismo título, distinto número.
5. **Acciones destructivas mal calibradas**: se confirma *Guardar* (que no destruye nada) y no se
   confirma quitar una sección (`Nuevo.cshtml:212`, `Editar.cshtml:280`), pese a que al guardar se
   borran y recrean todas las filas de `PlanMantenimientoSeccion`.
6. **`Asignar` no muestra el estado que importa**: no hay `BLOQUEADO`, ni `ÚLTIMA EJECUCIÓN`, ni
   `POSICIÓN ACTUAL`; esas columnas sólo están en `Ver`. Además usa `confirm()` nativo mientras el
   resto del módulo usa SweetAlert.
7. **Defectos de marcado verificados**: `colspan='10'` sobre una tabla de 8 columnas y `</td></td>`
   mal cerrado (`Index.cshtml:106`); atributo con comilla doble `class="text-center""`
   (`Index.cshtml:128`).

## 3. Principios a respetar

- **Reutilizar antes que inventar**: `helper.filtros`, `helper.tabla`, `helper.pagination`,
  `helper.html.escape`, `helper.fecha`, `Swal`. El patrón de referencia es
  `Areas/Gestion/Views/Aviso/Index.cshtml`.
- **Un solo algoritmo**: el cálculo del comportamiento vive en C#
  (`PlanMantenimiento.Adicional.cs`). No se reimplementa en JavaScript.
- **Cada paso compila, se prueba solo y se puede revertir solo.** Un paso = un commit.
- **Nada de cambios de esquema ni de lógica de negocio** en este plan.

---

## 4. Pasos

### FASE 0 — Higiene y alineación al patrón vigente

#### [x] PM-01 · Corregir los defectos de marcado y escapar el HTML de la lista

- **Hoy**: `Index.cshtml:106` pinta el estado vacío con `colspan='10'` (la tabla tiene 8 columnas) y
  cierra `</td></td>`; `Index.cshtml:128` tiene `class="text-center""`. La descripción se inyecta
  sin escapar, así que un plan con `<` o `&` rompe la fila.
- **Objetivo**: que la tabla sea válida y no dependa de que los datos no tengan caracteres HTML.
- **Archivos**: `Views/PlanMantenimiento/Index.cshtml`, `Views/PlanMantenimiento/_Seleccionar.cshtml`.
- **Hacer**:
  - Sustituir el estado vacío por `helper.tabla.vacia(table)` y añadir `helper.tabla.cargando(table)`
    en `beforeSend` (ambos calculan solos el `colspan`).
  - Corregir la comilla sobrante del `<td>` de intervalo.
  - Envolver `codigo`, `descripcion` y `unidadMedidaServicio.abreviatura` con `helper.html.escape`.
  - Repetir lo mismo en `_Seleccionar.cshtml`, que usa `colspan='7'` sobre 4 columnas.
- **Aceptación**:
  - [ ] Sin filas, aparece el mensaje con icono y el `colspan` correcto.
  - [ ] Durante la carga se ve el indicador «Cargando…».
  - [ ] Un plan cuya descripción contenga etiquetas HTML se muestra literal, sin romper la tabla.
- **Esfuerzo** S · **Riesgo** BAJO · **Ref.** UX-13 / `MNT-044`

#### [x] PM-02 · Panel de filtros estándar en la lista

- **Hoy**: los filtros son inputs sueltos dentro del `<thead>`, sin etiquetas ni placeholders, sólo
  se disparan con Enter, no hay botón *Buscar* ni *Limpiar*, y no se ve qué filtros están activos.
- **Objetivo**: la misma experiencia de búsqueda que ya tienen Avisos y Órdenes de Trabajo.
- **Archivos**: `Views/PlanMantenimiento/Index.cshtml`.
- **Hacer**:
  - Copiar la estructura de `Aviso/Index.cshtml`: un `<form id="frmFiltros">` dentro de un
    `card-body filtros-panel`, con `label` y `placeholder` por campo y los botones
    *Limpiar* / *Buscar*.
  - Declarar `const FILTROS = { form, chips, campos: [...] }` con Código, Descripción, UMS,
    Comportamiento y Activo; llamar a `helper.filtros.inicializar(FILTROS, () => index.Listar(1))`
    y a `helper.filtros.chips(FILTROS)` dentro de `Listar`.
  - Añadir el contenedor `#chipsFiltros` sobre la tabla.
  - Extraer los filtros a `index.ObtenerFiltros()`, como en la vista de referencia, para poder
    reutilizarlos luego en los contadores (PM-17) o en una exportación.
- **Aceptación**:
  - [ ] Los filtros activos se muestran como *chips* y cada uno se puede quitar individualmente.
  - [ ] *Limpiar* deja la lista sin filtros y recarga.
  - [ ] Enter dentro del formulario busca y no recarga la página.
- **Esfuerzo** M · **Riesgo** BAJO

#### [x] PM-03 · Columnas y acciones legibles en la lista

- **Hoy**: la columna titulada `UMS` muestra en realidad `intervalo + abreviatura`; `FACTOR PLAN.`
  llega ya formateada desde el servidor; `COMPORTAMIENTO` muestra texto plano; las tres acciones son
  iconos sin texto ni `aria-label`; el botón *Nuevo* es sólo un `+`.
- **Objetivo**: que se entienda cada columna sin abrir el plan.
- **Archivos**: `Views/PlanMantenimiento/Index.cshtml`,
  `Areas/Gestion/Controllers/PlanMantenimiento.Controller.cs` (acción `Listar`).
- **Hacer**:
  - Separar en dos columnas: `CICLO` (`intervalo` + abreviatura, p. ej. «3 MES») y `FACTOR PLAN.`.
  - Mostrar `COMPORTAMIENTO` con `helper.html.badgeEstado`, un color por Estático/Dinámico.
  - Acciones como `btn btn-light` con `title` **y** `aria-label`, igual que en `Aviso/Index`, y con
    el mismo orden en todas las pantallas: Ver · Editar · Asignar.
  - Botón *Nuevo* con texto visible en pantallas medianas (`<span class="d-none d-md-inline">`).
  - Activar el contador «mostrando X–Y de N», que `helper.pagination` ya soporta vía
    `data-totaltext`.
- **Aceptación**:
  - [ ] Ninguna columna mezcla dos datos distintos.
  - [ ] Las acciones son alcanzables con teclado y anunciables por lector de pantalla.
  - [ ] Se ve el total de registros sin contar filas.
- **Esfuerzo** M · **Riesgo** BAJO · **Ref.** UI-04

---

### FASE 1 — Hacer entendible el plan (núcleo del problema)

#### [x] PM-04 · Un solo término para `Rutina`

- **Hoy**: `Rutina` en el modelo, switch *Dinámico | Estático* sin indicar cuál está activo, columna
  *COMPORTAMIENTO* en la grilla y filtro *ESTÁTICO/DINÁMICO*. Nada explica que el valor cambia la
  fórmula de `CantidadPosiciones`.
- **Objetivo**: que el usuario pueda predecir el efecto antes de tocarlo.
- **Archivos**: `Nuevo.cshtml`, `Editar.cshtml`, `Ver.cshtml`, `Asignar.cshtml`, `Index.cshtml`.
- **Hacer**:
  - Elegir **un** término visible (propuesta: *Tipo de ciclo*, con valores *Estático* y *Dinámico*)
    y usarlo idéntico en las cinco pantallas.
  - Sustituir el switch por dos *radio buttons* con una línea de descripción bajo cada uno:
    - *Dinámico*: el ciclo abarca `MCM(intervalos de las secciones) ÷ intervalo` posiciones.
    - *Estático*: el ciclo abarca tantas posiciones como el mayor intervalo de sección.
  - Mostrar el número de posiciones resultante junto a la opción seleccionada.
- **Aceptación**:
  - [ ] El mismo término aparece en lista, alta, edición, asignación y consulta.
  - [ ] Se ve siempre cuál de las dos opciones está activa.
  - [ ] Al cambiar de opción, el número de posiciones mostrado cambia.
- **Esfuerzo** M · **Riesgo** BAJO · **Ref.** UX-03 / `MNT-039`

#### [x] PM-05 · Vista previa del comportamiento mientras se configura

- **Hoy**: la matriz secciones × posiciones sólo existe en `Ver` y `Asignar`. El ciclo real de
  trabajo es editar → guardar → ir a *Ver* → volver a *Editar*.
- **Objetivo**: cerrar el bucle de retroalimentación en la operación más difícil del módulo.
- **Archivos**: nueva parcial `Views/PlanMantenimiento/_Comportamiento.cshtml`; `Ver.cshtml`,
  `Asignar.cshtml`, `Nuevo.cshtml`, `Editar.cshtml`; `PlanMantenimiento.Controller.cs`.
- **Hacer**:
  1. Extraer la tabla de comportamiento —hoy duplicada literalmente en `Ver.cshtml` y
     `Asignar.cshtml`— a una parcial reutilizable.
  2. Añadir una acción `POST PlanMantenimiento/Comportamiento` que reciba la configuración en curso,
     **sin persistir nada**, construya un `PlanMantenimiento` en memoria, invoque
     `ComportamientoConPlanMantenimientoSeccion()` y devuelva la parcial renderizada.
  3. En `Nuevo`/`Editar`, invocarla con *debounce* (~400 ms) al cambiar el intervalo del plan, el
     tipo de ciclo, o el intervalo/nivel de cualquier fila.
  4. Mostrar junto a la matriz el `CantidadPosiciones` y el `MCM` calculados.
- **Aceptación**:
  - [ ] La matriz previa coincide exactamente con la de `Ver` después de guardar.
  - [ ] Existe **una sola** implementación del algoritmo: no hay copia en JavaScript.
  - [ ] Ninguna ruta de la acción nueva llega a `SaveChangesAsync`.
- **Esfuerzo** L · **Riesgo** MEDIO
- **Ref.** UX-02 / `MNT-038` — leer esa tarea completa antes de empezar.

#### [x] PM-06 · Unificar el significado de `INTERVALO` por sección

- **Hoy**: en `Nuevo`/`Editar` la columna `INTERVALO` es el multiplicador crudo; en `Ver` la misma
  columna muestra `item.Intervalo * Model.Intervalo`. Quien compare las dos pantallas ve números
  distintos bajo el mismo título. Además el campo llega vacío al añadir una sección, lo que produce
  el error de servidor «el intervalo debe ser mayor a cero».
- **Objetivo**: que el número signifique siempre lo mismo y no haya que adivinar la unidad.
- **Archivos**: `Nuevo.cshtml`, `Editar.cshtml`, `Ver.cshtml`.
- **Hacer**:
  - Renombrar la columna editable a **`CADA N CICLOS`** y añadir a su derecha una columna calculada
    de solo lectura **`EQUIVALE A`** (`n × intervalo` + abreviatura de la UMS).
  - Valor por defecto `1` al añadir una sección, igual que ya ocurre con `Nivel`.
  - En `Ver`, usar los mismos dos títulos para las mismas dos cifras.
- **Aceptación**:
  - [ ] El mismo plan muestra los mismos números en `Editar` y en `Ver`.
  - [ ] Añadir una sección y guardar sin tocar nada ya no produce error de validación.
- **Esfuerzo** M · **Riesgo** BAJO · **Ref.** UI-05

#### [x] PM-07 · Explicar la UMS y por qué se bloquea

- **Hoy**: en `Nuevo` la UMS es un `<select>` libre; en `Editar` aparece como campo de solo lectura
  sin explicación. El usuario no sabe, al crear, que esa decisión es definitiva; ni entiende, al
  editar, por qué no puede cambiarla.
- **Objetivo**: informar de una decisión irreversible **antes** de tomarla.
- **Archivos**: `Nuevo.cshtml`, `Editar.cshtml`.
- **Hacer**:
  - En `Nuevo`, texto de ayuda bajo el campo: la UMS determina si el plan se programa por calendario
    o por contador y **no podrá cambiarse después**.
  - En `Editar`, icono de información junto al campo bloqueado, explicando el motivo y la
    alternativa (crear un plan nuevo).
  - Mostrar el tipo (CALENDARIO / CONTADOR) junto a la abreviatura, no sólo el nombre.
- **Aceptación**:
  - [ ] El aviso es visible antes del primer guardado, no después.
  - [ ] En `Editar` se explica el bloqueo sin necesidad de preguntar a soporte.
- **Esfuerzo** S · **Riesgo** BAJO

---

### FASE 2 — Proteger el trabajo del usuario

#### [x] PM-08 · Poner las confirmaciones donde importan

- **Hoy**: *Guardar* pide confirmación aunque no destruye nada; quitar una sección no pide nada
  (`Nuevo.cshtml:212`, `Editar.cshtml:280`) aunque al guardar se borran y recrean todas las filas de
  `PlanMantenimientoSeccion`. Además `Nuevo` informa «Se actualizó el registro» al **crear**
  (`Nuevo.cshtml:240`).
- **Objetivo**: que una confirmación signifique algo, para que el usuario la lea.
- **Archivos**: `Nuevo.cshtml`, `Editar.cshtml`.
- **Hacer**:
  - Quitar el `Swal` de confirmación de *Guardar*; mantener el de resultado con el texto correcto
    («Se creó el plan» / «Se actualizó el plan»).
  - Confirmar al quitar una sección **sólo en `Editar`** (en `Nuevo` nada está persistido todavía);
    si resulta molesto, sustituir la pregunta por un *Deshacer* temporal.
  - Reemplazar `$(this).parents().eq(1).remove()` por `$(this).closest('tr').remove()`, que no
    depende de la profundidad del marcado.
- **Aceptación**:
  - [ ] Guardar es un clic.
  - [ ] Quitar una sección ya guardada avisa antes.
  - [ ] El mensaje de éxito nombra la operación real.
- **Esfuerzo** S · **Riesgo** BAJO · **Ref.** UX-14 / `MNT-045`

#### [x] PM-09 · Barra de acciones fija y aviso de cambios sin guardar

- **Hoy**: *Guardar* vive al pie de la tarjeta *Datos de Cabecera*, con la tabla de secciones debajo:
  tras añadir 20 secciones hay que subir a buscarlo. *Regresar* es un `<a href>` que descarta todo
  sin preguntar.
- **Objetivo**: que guardar esté siempre a mano y que no se pierda trabajo.
- **Archivos**: `Nuevo.cshtml`, `Editar.cshtml`, `wwwroot/css/site.css`.
- **Hacer**:
  - Barra `position: sticky; bottom: 0` con *Guardar* / *Regresar*, fuera de la tarjeta de cabecera.
  - Marcar el formulario como «sucio» ante cualquier `change` en la cabecera o en la tabla, con un
    indicador discreto («Cambios sin guardar»).
  - Interceptar *Regresar* y `beforeunload` cuando esté sucio.
  - Cambiar *Regresar* de `btn-warning` a `btn-secondary`: el ámbar comunica advertencia.
- **Aceptación**:
  - [ ] *Guardar* es visible con la página desplazada al final.
  - [ ] Salir con cambios pendientes pide confirmación; sin cambios, no molesta.
- **Esfuerzo** M · **Riesgo** BAJO · **Ref.** UX-10, UX-11, UI-03 / `MNT-042`

#### [x] PM-10 · Errores localizados en la fila que los causa

- **Hoy**: el servidor devuelve la parcial `_Error` con textos como «La sección nro. 7, es necesario
  seleccionar una prioridad» y el JS los vuelca en `#mensajes`. Nada marca la fila 7 ni desplaza la
  vista hasta ella.
- **Objetivo**: que corregir un error sea inmediato.
- **Archivos**: `Nuevo.cshtml`, `Editar.cshtml`, `PlanMantenimiento.Controller.cs`.
- **Hacer**:
  - Validar en cliente, antes de enviar, lo que ya valida el servidor: prioridad, tipo de
    mantenimiento, taller, intervalo > 0, código y descripción no vacíos.
  - Resaltar la fila y la celda en conflicto con `is-invalid` y hacer scroll al primer error.
  - Cambiar la clave del error del servidor para que identifique la fila (por ejemplo
    `Secciones[6].PrioridadId` en vez de `Secciones_SeccionId` para todos los casos), de modo que el
    cliente pueda mapear mensaje → fila.
- **Aceptación**:
  - [ ] Con una sección incompleta, la fila queda marcada y visible sin buscarla.
  - [ ] Los errores del servidor siguen mostrándose aunque el cliente no los haya previsto.
- **Esfuerzo** M · **Riesgo** BAJO · **Ref.** UX-12 / `MNT-043`

---

### FASE 3 — Asignación de equipos y ubicaciones

#### [x] PM-11 · Consistencia y robustez de `Asignar`

- **Hoy**: `confirm()` nativo para eliminar (`Asignar.cshtml:302` y `:311`); los `$.post` de
  `ListarEquipo`/`ListarUbicacion` no tienen manejador de error; las tablas no tienen estado vacío
  ni de carga; `ListarUbicacion()` se ejecuta siempre (`:329`) aunque la pestaña *Ubicaciones* sólo
  exista cuando la UMS es CALENDARIO.
- **Objetivo**: que la pantalla se comporte como el resto del módulo y no falle en silencio.
- **Archivos**: `Asignar.cshtml`.
- **Hacer**:
  - Sustituir `confirm()` por `Swal.fire`, con el mismo texto que las demás pantallas.
  - Añadir `.fail()` a ambos listados, mostrando el error en `#mensajes`.
  - Usar `helper.tabla.cargando` / `helper.tabla.vacia`, con una llamada a la acción en el estado
    vacío («Asignar el primer equipo»).
  - Llamar a `ListarUbicacion()` sólo si la pestaña existe.
  - Escapar `equipo.nombre` / `ubicacion.nombre` con `helper.html.escape`.
- **Aceptación**:
  - [ ] Ningún `confirm()` ni `alert()` nativo en la vista.
  - [ ] Un fallo del servidor al listar muestra un mensaje.
  - [ ] Un plan por contador no dispara la petición de ubicaciones.
- **Esfuerzo** S · **Riesgo** BAJO

#### [x] PM-12 · Mostrar en `Asignar` el estado real de cada asignación

- **Hoy**: las tablas de `Asignar` muestran Código, Nombre, Pos. Inicio, Fecha/Contador Inicio y
  Tipo Prog. No muestran `BLOQUEADO`, `POSICIÓN ACTUAL` ni `ÚLTIMA EJECUCIÓN`, que sí están en
  `Ver`. Se asigna sin ver si el equipo está generando mantenimiento o no.
- **Objetivo**: decidir sobre la asignación en la pantalla donde se asigna.
- **Archivos**: `Asignar.cshtml`, `PlanMantenimientoEquipo.Controller.cs`,
  `PlanMantenimientoUbicacion.Controller.cs` (campos devueltos por `Listar`).
- **Hacer**:
  - Añadir las columnas `POS. ACTUAL`, `ÚLT. EJECUCIÓN` y `BLOQUEADO` (badge rojo).
  - Marcar en rojo el equipo no montado o inactivo, con el mismo criterio que `Ver.cshtml`
    (`Activo && (UbicacionId || EquipoPadreId)`), y explicar el porqué en el `title`.
  - Resumen sobre la tabla: «N asignados · M bloqueados · K sin ubicación».
- **Aceptación**:
  - [ ] Las mismas columnas significan lo mismo en `Asignar` y en `Ver`.
  - [ ] Un equipo bloqueado se distingue de un vistazo.
- **Esfuerzo** M · **Riesgo** BAJO · **Ref.** UX-05 (la acción *Desbloquear* es `MNT-005`, aparte)

#### [x] PM-13 · Asignación masiva de equipos

- **Hoy**: el modal `_Nuevo` tiene un `select2` de selección **única**. Asignar 40 equipos a un plan
  son 40 aperturas de modal, repitiendo a mano los mismos valores cada vez.
- **Objetivo**: reducir la operación más repetitiva del módulo a un solo paso.
- **Archivos**: `Views/PlanMantenimientoEquipo/_Nuevo.cshtml`,
  `PlanMantenimientoEquipo.Controller.cs`.
- **Hacer**:
  - Modal de selección múltiple con filtros (código, nombre, ubicación) y casillas, siguiendo el
    patrón de `Seccion/_Seleccionar`.
  - Un único bloque de valores comunes (tipo de programación, posición inicio, fecha/contador) que
    se aplica a toda la selección, ajustable después fila a fila desde la tabla.
  - Acción de servidor que reciba la lista y devuelva cuántas se crearon y cuántas se omitieron por
    estar ya asignadas, con el detalle.
- **Aceptación**:
  - [ ] Se pueden asignar N equipos en una sola operación.
  - [ ] Los equipos ya asignados al plan no se duplican y se informa de la omisión.
  - [ ] Un fallo parcial no deja asignaciones a medias sin avisar.
- **Esfuerzo** L · **Riesgo** MEDIO (toca una acción que escribe en base de datos)

#### [x] PM-14 · Modal de asignación: ayuda de posición y advertencia de reinicio

- **Hoy**: `PosicionInicio` es un número sin rango ni explicación. Y editar cualquier campo de una
  asignación reinicia el ciclo (`PosicionActual = PosicionInicio`, `ContadorActual = ContadorInicio`,
  `UltimaEjecucion = null`, regla `BR-AS-007`) **sin decirlo**: es una acción destructiva disfrazada
  de edición.
- **Objetivo**: que nadie pierda el avance real del mantenimiento de un equipo por editar un campo.
- **Archivos**: `Views/PlanMantenimientoEquipo/_{Nuevo,Editar}.cshtml`,
  `Views/PlanMantenimientoUbicacion/_{Nuevo,Editar}.cshtml`.
- **Hacer**:
  - Indicar el rango válido de `PosicionInicio` (`0 … CantidadPosiciones-1`), aplicarlo con
    `min`/`max`, y mostrar qué secciones toca esa posición según la matriz.
  - En `_Editar`, destacar lo que se perderá (posición actual, contador actual, última ejecución) y
    pedir confirmación explícita.
  - Separar visualmente *Editar datos* (no destructivo) de *Reiniciar ciclo* (destructivo).
  - Corregir el `asp-action="Nuevo"` copiado por error en los formularios `_Editar`.
- **Aceptación**:
  - [ ] La advertencia enumera los valores concretos que se van a perder.
  - [ ] `PosicionInicio` fuera de rango no se puede enviar.
- **Esfuerzo** M · **Riesgo** MEDIO · **Ref.** UX-04 / `MNT-006` — separar las dos acciones depende
  de esa tarea; aquí se cubre al menos la advertencia.

---

### FASE 4 — Consulta y navegación

#### [x] PM-15 · Acciones en `Ver` y migas de pan en todas las pantallas

- **Hoy**: `Ver` sólo ofrece *Regresar*: para editar hay que volver a la lista y buscar el plan otra
  vez. Y ninguna pantalla indica dónde está el usuario dentro de Plan → Sección → Tarea.
- **Objetivo**: moverse entre las pantallas del plan sin volver a la lista.
- **Archivos**: las cinco vistas de `PlanMantenimiento`.
- **Hacer**:
  - En `Ver`: botones *Editar* y *Asignar*; en `Asignar`: *Ver* y *Editar*; en `Editar`: *Ver* y
    *Asignar*. Mismo orden y mismos iconos que en la lista (PM-03).
  - Migas de pan en el `page-title-box`: `Planes de Mantenimiento / [CÓDIGO] Descripción / Asignar`.
  - Enlazar cada sección de la tabla a su ficha (`/Gestion/Seccion/Ver/{id}`).
- **Aceptación**:
  - [ ] Desde cualquier pantalla del plan se llega a las otras dos en un clic.
  - [ ] El título identifica el plan concreto, no sólo la operación.
- **Esfuerzo** M · **Riesgo** BAJO · **Ref.** UX-01 / `MNT-037`

#### [x] PM-16 · Matriz de comportamiento legible

- **Hoy**: la matriz puede tener decenas de columnas (una por posición) sin cabecera fija; las celdas
  del cuerpo son `<th>` en lugar de `<td>`; una posición vacía no se distingue de una ocupada más
  que por la ausencia de la `X`; no hay leyenda.
- **Objetivo**: que la mejor pieza de la interfaz siga siendo legible con 30 posiciones.
- **Archivos**: la parcial `_Comportamiento.cshtml` creada en PM-05.
- **Hacer**:
  - Cabecera de fila y de columna fijas al hacer scroll horizontal.
  - Resaltar las **posiciones sin ninguna sección** (no se generará nada) y los **empates de nivel**
    (dos secciones del mismo nivel en la misma posición).
  - Leyenda corta debajo explicando la `X`, la posición vacía y el empate.
  - Usar `<td>` en el cuerpo y `scope` en las cabeceras.
- **Aceptación**:
  - [ ] Con 30 posiciones se sigue sabiendo a qué sección pertenece cada celda.
  - [ ] Una posición vacía se ve sin contar columnas.
- **Esfuerzo** M · **Riesgo** BAJO · **Ref.** se apoya en `MNT-027` (empates) sin resolverlo

#### [x] PM-17 · Contadores en la lista de planes

- **Hoy**: para saber si un plan «está vivo» hay que entrar a `Ver`, uno por uno.
- **Objetivo**: detectar desde la lista los planes con problemas.
- **Archivos**: `Index.cshtml`, `PlanMantenimiento.Controller.cs`,
  `PlanMantenimiento.Repositorio.cs`.
- **Hacer**:
  - Añadir a la proyección de `Listar` los conteos de secciones, objetos asignados y asignaciones
    bloqueadas, **con una sola consulta agregada**, no una por fila.
  - Mostrarlos como columnas con badge; el de bloqueados en rojo cuando sea mayor que cero.
  - Enlazar el badge de bloqueados a la pantalla `Asignar` del plan.
- **Aceptación**:
  - [ ] La lista no ejecuta consultas adicionales por fila (verificar con el log de EF Core).
  - [ ] Un plan sin secciones se distingue de uno configurado.
- **Esfuerzo** M · **Riesgo** MEDIO (rendimiento) · **Ref.** UX-16 / `MNT-047`

#### [x] PM-18 · Color semántico y comportamiento en móvil

- **Hoy**: las cabeceras usan `bg-primary` para secciones en `Nuevo`/`Editar`, `bg-success` para
  equipos en `Ver` pero `bg-primary` para esos mismos equipos en `Asignar`, y `bg-warning` tanto
  para tareas como para la matriz. Las tablas editables tienen 9 columnas con `select`/`input`
  dentro de un `table-responsive`: en móvil hay que hacer scroll horizontal mientras se escribe, y
  los `width="150"` en píxeles no se adaptan.
- **Objetivo**: que el color signifique algo y que la pantalla sea usable en tablet.
- **Archivos**: las cinco vistas y `wwwroot/css/site.css`.
- **Hacer**:
  - Fijar y documentar la convención: azul = configuración, verde = asignación, ámbar = advertencia.
    Aplicarla en las cinco vistas, empezando por igualar `Asignar` con `Ver`.
  - Sustituir los `width` en píxeles por clases de utilidad.
  - En breakpoints pequeños, colapsar cada fila editable a una tarjeta con etiquetas.
- **Aceptación**:
  - [ ] Dos tablas con el mismo contenido tienen el mismo color en todas las pantallas.
  - [ ] A 768 px se puede completar una sección sin scroll horizontal.
- **Esfuerzo** L · **Riesgo** BAJO · **Ref.** UI-01, UI-02, UI-07

---

## 5. Orden recomendado y resumen

| Orden | Paso | Fase | Esfuerzo | Riesgo | Impacto |
|-------|------|------|----------|--------|---------|
| 1 | PM-01 Marcado y escapado | 0 | S | BAJO | Medio |
| 2 | PM-02 Panel de filtros | 0 | M | BAJO | Alto |
| 3 | PM-03 Columnas y acciones | 0 | M | BAJO | Medio |
| 4 | PM-04 Término único de ciclo | 1 | M | BAJO | Alto |
| 5 | PM-06 Significado de intervalo | 1 | M | BAJO | Alto |
| 6 | **PM-05 Vista previa del comportamiento** | 1 | L | MEDIO | **Máximo** |
| 7 | PM-07 UMS y su bloqueo | 1 | S | BAJO | Medio |
| 8 | PM-08 Confirmaciones | 2 | S | BAJO | Medio |
| 9 | PM-09 Barra fija y cambios sin guardar | 2 | M | BAJO | Alto |
| 10 | PM-10 Errores en la fila | 2 | M | BAJO | Medio |
| 11 | PM-11 Robustez de Asignar | 3 | S | BAJO | Medio |
| 12 | PM-12 Estado real en Asignar | 3 | M | BAJO | Alto |
| 13 | PM-14 Ayuda y advertencia del modal | 3 | M | MEDIO | Alto |
| 14 | PM-13 Asignación masiva | 3 | L | MEDIO | Alto |
| 15 | PM-15 Acciones y migas de pan | 4 | M | BAJO | Medio |
| 16 | PM-16 Matriz legible | 4 | M | BAJO | Medio |
| 17 | PM-17 Contadores en la lista | 4 | M | MEDIO | Medio |
| 18 | PM-18 Color y móvil | 4 | L | BAJO | Medio |

> [!NOTE]
> **PM-04 y PM-06 van antes que PM-05 a propósito.** La vista previa muestra términos y números; si
> los términos siguen siendo ambiguos, la vista previa hereda la ambigüedad.

> [!CAUTION]
> **PM-05 es el paso que más cambia la experiencia y el único con riesgo de diseño real.** Lee
> `ai/tasks/MNT-038.md` completo antes de empezarlo: calcular en el servidor, y no en JavaScript, no
> es negociable — el operador módulo con decimales no da el mismo resultado en C# y en JavaScript.

## 6. Qué **no** hace este plan

- No cambia el algoritmo de programación ni la fórmula de `CantidadPosiciones`.
- No resuelve el bloqueo de asignaciones (`MNT-005`) ni separa *editar* de *reiniciar ciclo*
  (`MNT-006`): PM-12 y PM-14 sólo hacen visible el problema.
- No valida los empates de nivel (`MNT-027`): PM-16 sólo los muestra.
- No toca permisos, ni la generación de órdenes, ni la previsualización.
- No extrae el JavaScript inline a archivos propios de forma sistemática; hacerlo en bloque sería un
  cambio grande de un solo golpe. Cada paso puede mover a `wwwroot/js/` lo que le corresponda.

## 7. Cómo verificar cada paso

1. `dotnet build AMSYS.sln` sin nuevos avisos.
2. Recorrer el flujo completo con un plan de UMS **CALENDARIO** y otro de UMS **CONTADOR**: las
   pantallas se comportan distinto según el tipo (pestaña *Ubicaciones*, campos de contador).
3. Probar con un plan **sin secciones** y con uno de **más de 20 posiciones**.
4. Comprobar que no hay errores en la consola del navegador: varias vistas llaman a `select2` sobre
   elementos que no existen (`.select2` en `Nuevo`, `#EmpleadoId` en los modales); conviene limpiarlo
   al pasar por cada vista.

## 8. Registro de avance

| Paso | Estado | Fecha | Commit | Notas |
|------|--------|-------|--------|-------|
| PM-01 | APLICADO | 2026-09-16 | | Falta verificar en navegador |
| PM-02 | APLICADO | 2026-09-16 | | Falta verificar en navegador |
| PM-03 | APLICADO | 2026-09-16 | | Falta verificar en navegador |
| PM-04 | APLICADO | 2026-09-16 | | Falta verificar en navegador |
| PM-05 | APLICADO | 2026-09-16 | | Falta verificar en navegador |
| PM-06 | APLICADO | 2026-09-16 | | Falta verificar en navegador |
| PM-07 | APLICADO | 2026-09-16 | | Falta verificar en navegador |
| PM-08 | APLICADO | 2026-09-16 | | Falta verificar en navegador |
| PM-09 | APLICADO | 2026-09-16 | | Falta verificar en navegador |
| PM-10 | APLICADO | 2026-09-16 | | Falta verificar en navegador |
| PM-11 | APLICADO | 2026-09-16 | | Falta verificar en navegador |
| PM-12 | APLICADO | 2026-09-16 | | Falta verificar en navegador |
| PM-13 | APLICADO | 2026-09-16 | | Falta verificar en navegador |
| PM-14 | APLICADO | 2026-09-16 | | Advertencia + confirmación explícita; separar editar/reiniciar en el servidor sigue dependiendo de MNT-006 |
| PM-15 | APLICADO | 2026-09-16 | | No existe `Seccion/Ver`: las secciones enlazan a `Seccion/Editar` en pestaña nueva |
| PM-16 | APLICADO | 2026-09-16 | | Falta verificar en navegador |
| PM-17 | APLICADO | 2026-09-16 | | 3 consultas agrupadas por página (`ResumirAsync`), sólo con `conResumen=true` |
| PM-18 | APLICADO | 2026-09-16 | | Convención documentada en `site.css`; tabla de secciones apilable < 992 px. Los `width` en px de las tablas de sólo lectura se mantienen |


## 9. Mejoras adicionales (fuera de los 18 pasos)

| Id | Descripción | Estado | Fecha | Notas |
|----|-------------|--------|-------|-------|
| PM-X1 | Explicación informativa de programación **FIJA** y **FLOTANTE** al asignar u editar un equipo o una ubicación (`Areas/Gestion/Views/Shared/_AyudaTipoProgramacion.cshtml`), con la opción elegida resaltada. Sólo informa; no cambia validaciones ni comportamiento. | APLICADO | 2026-09-16 | Texto basado en `BR-GE-008`/`BR-GE-009` y en `OrdenTrabajoLogica` (desbloqueo al cerrar o anular). Falta verificar en navegador |
