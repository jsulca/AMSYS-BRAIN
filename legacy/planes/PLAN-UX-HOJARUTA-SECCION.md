# Plan de mejora de UX – Hojas de Ruta y Secciones

> Documento **ejecutable paso a paso**, con la misma mecánica que `PLAN-UX-PLANMANTENIMIENTO.md`:
> cada paso es pequeño, verificable y reversible por sí solo. Marca la casilla al terminarlo y anótalo
> en el *Registro de avance* del final.

- **Alcance**: `HojaRuta/{Index, Ver, _Nuevo, _Editar}` y `Seccion/{Index, Nuevo, Editar, _Seleccionar}`.
- **Fuera de alcance**: el algoritmo de programación, la generación de órdenes, los permisos y el
  modelo de datos (salvo el endpoint mínimo que pide HS-09).
- **Fecha**: 2026-09-16
- **Relación con `/ai`**: complementa `analysis/ux.md` y las tareas `MNT-NNN`; cada paso indica su
  tarea equivalente cuando existe.

---

## 1. El concepto que la interfaz tiene que transmitir

**Hoja de Ruta** y **Sección** existen para **agrupar tareas**:

```
Hoja de Ruta  (agrupador opcional de secciones)
 └── Sección  (paquete reutilizable: tareas + materiales + servicios + adjuntos)
      └── Tarea  (qué se hace, quién, cuánto tiempo)

Plan de Mantenimiento ──usa──► Secciones sueltas (no hojas de ruta)
```

Hechos verificados que condicionan el diseño:

| Hecho | Evidencia | Consecuencia para la UX |
|-------|-----------|-------------------------|
| Una sección puede no tener hoja de ruta | `BR-SE-001` (validación comentada, opción `NINGUNO`) | Las secciones «sueltas» deben verse como grupo propio, no desaparecer |
| El plan elige **secciones**, no hojas de ruta | `DOMAIN-MODEL.md` | La hoja de ruta sólo sirve para encontrar y ordenar secciones |
| Guardar una sección borra y recrea sus tareas | `BR-SE-003` | Nunca usar el guardado completo para cambios pequeños (p. ej. mover de hoja de ruta) |
| Una sección se reutiliza en varios planes | `PlanMantenimientoSeccion` (N:M) | Editarla afecta a todos esos planes: hay que decirlo |
| Las órdenes ya emitidas guardan una copia de las tareas | `MNT-014` | Editar una sección **no** altera órdenes pasadas, sólo futuras |
| No se encontró ninguna comprobación de `Seccion.Activo` en `AMSYS.Logicas` ni `AMSYS.Repositorios` | búsqueda en el código | Desactivar una sección **no parece** quitarla de los planes → ver decisión `DS-01` |

## 2. Pantallas afectadas

| Vista | Archivo | LOC | Rol |
|-------|---------|-----|-----|
| Lista de hojas de ruta | `Views/HojaRuta/Index.cshtml` | 157 | Buscar y abrir |
| Alta / edición | `Views/HojaRuta/_Nuevo.cshtml`, `_Editar.cshtml` | 79 / 80 | Modal |
| Detalle | `Views/HojaRuta/Ver.cshtml` | 164 | Secciones de la hoja con todas sus tareas |
| Lista de secciones | `Views/Seccion/Index.cshtml` | 152 | Buscar, editar, duplicar |
| Alta / duplicado | `Views/Seccion/Nuevo.cshtml` | 575 | Formulario + 4 pestañas |
| Edición | `Views/Seccion/Editar.cshtml` | 607 | Formulario + 4 pestañas |
| Selector | `Views/Seccion/_Seleccionar.cshtml` | 161 | Modal usado por el Plan |

## 3. Diagnóstico corto

1. **🔴 Editar o duplicar una sección cambia la especialidad de sus tareas sin avisar.**
   `Seccion/Editar.cshtml:145` y `Seccion/Nuevo.cshtml:147` preseleccionan la especialidad comparando
   `item.TipoTareaId == tipo.Id` en lugar de `item.EspecialidadId`. El `<select>` muestra una
   especialidad que no es la guardada y, al pulsar *Guardar*, **esa** es la que se persiste para
   todas las tareas. Cada guardado corrompe datos.
2. **La agrupación no se ve.** `HojaRuta/Ver` vuelca todas las secciones expandidas, con todas sus
   tareas, materiales y servicios, sin totales, sin acciones por sección (ni editar ni duplicar) y sin
   estado vacío. `Seccion/Index` es una lista plana sin tareas, horas ni planes.
3. **No se sabe qué rompe una edición.** Nada indica en cuántos planes se usa una sección antes de
   modificarla o desactivarla.
4. **Organizar es rígido.** Desde una hoja de ruta sólo se pueden crear secciones nuevas: no se puede
   traer una sección suelta existente, ni sacarla. Hay que abrir la sección y guardarla entera
   (recreando sus tareas) para cambiarle la hoja.
5. **Selección silenciosa.** Los `<select>` de tipo de tarea y especialidad de las filas nuevas no
   tienen opción vacía: se guarda la primera opción aunque el usuario no la haya elegido, y la
   validación del servidor (`TipoTareaId <= 0`) nunca salta.
6. **Listas atrasadas respecto al patrón vigente**: filtros en el `<thead>`, `colspan='7'` sobre 5 y 6
   columnas (`HojaRuta/Index.cshtml:84`, `Seccion/Index.cshtml:87`, `Seccion/_Seleccionar.cshtml:80`),
   `</td></td>` mal cerrado, datos sin escapar.
7. **Formularios largos sin red de seguridad**: *Guardar* arriba y confirmado, sin aviso de cambios
   sin guardar, errores «La tarea nro. 7…» sin marcar la fila ni la pestaña.
8. **Incoherencias menores verificadas**: el botón de nueva tarea tiene `title="Nuevo Tipo de Equipo"`
   (`Nuevo.cshtml:99`, `Editar.cshtml:97`); el agrupador del sistema se muestra en `Nuevo`
   (`Nuevo.cshtml:18`) pero no en `Editar`; `Editar` siempre vuelve a `Seccion/Index` aunque se haya
   llegado desde una hoja de ruta (`Editar.cshtml:594`), mientras `Nuevo` sí vuelve
   (`Nuevo.cshtml:558`); eliminar un adjunto usa `confirm()`/`alert()` nativos y **se aplica al
   instante en el servidor** (`Editar.cshtml:482-485`), a diferencia del resto del formulario.
9. **Duplicar pierde adjuntos en silencio**: `Nuevo?id=N` carga los adjuntos de la original, pero la
   vista no los muestra y el POST sólo guarda los subidos de nuevo.

## 4. Principios

- Los mismos que en el plan anterior: reutilizar `helper.filtros`, `helper.tabla`,
  `helper.html.escape`, la barra fija (`.barra-acciones`), la respuesta de validación estructurada, la
  convención de color y `.tabla-apilable`, ya disponibles en `site.css` y `helper.js`.
- **Nunca usar el guardado completo de una sección para un cambio parcial** (`BR-SE-003`).
- Un paso = un commit.

---

## 5. Pasos

### FASE 0 — Lo que hoy daña datos o engaña

#### [x] HS-01 · Preseleccionar la especialidad correcta de cada tarea

- **Hoy**: `Editar.cshtml:145` y `Nuevo.cshtml:147` comparan `item.TipoTareaId == tipo.Id`. Al abrir
  una sección, cada tarea muestra una especialidad ajena (la que casualmente tenga el mismo `Id` que
  el tipo de tarea, o la primera de la lista) y guardar la sobrescribe.
- **Objetivo**: que abrir y guardar sin tocar nada no cambie ningún dato.
- **Archivos**: `Views/Seccion/Editar.cshtml`, `Views/Seccion/Nuevo.cshtml`.
- **Hacer**:
  - Comparar `item.EspecialidadId == tipo.Id` en ambas vistas.
  - Si la especialidad guardada está inactiva (no viene en la lista), añadirla como opción marcada
    «(inactiva)» para no perderla al guardar.
- **Aceptación**:
  - [ ] Abrir una sección y guardarla sin cambios deja idénticas las especialidades de todas sus tareas.
  - [ ] Duplicar conserva la especialidad de cada tarea.
- **Esfuerzo** S · **Riesgo** BAJO
- **Nota**: los datos ya guardados pueden estar alterados. Ver decisión `DS-03`.

#### [x] HS-02 · Obligar a elegir tipo de tarea y especialidad

- **Hoy**: las filas nuevas copian `<select>` sin opción vacía; se guarda la primera opción aunque
  nadie la haya elegido, y `TipoTareaId <= 0` nunca se cumple.
- **Objetivo**: que el valor guardado sea siempre una decisión del usuario.
- **Archivos**: `Nuevo.cshtml`, `Editar.cshtml` (bloque `<template>`).
- **Hacer**: añadir `<option value="">SELECCIONE</option>` a los `<select>` de tipo de tarea y
  especialidad de la plantilla de filas nuevas; las filas existentes no cambian.
- **Aceptación**:
  - [ ] Una tarea nueva sin tipo o sin especialidad no se puede guardar y el error señala la fila.
- **Esfuerzo** S · **Riesgo** BAJO

#### [x] HS-03 · Listas y selector al patrón vigente

- **Hoy**: filtros en el `<thead>` sin etiquetas, `colspan` incorrecto con `</td></td>`, datos sin
  escapar, sin estado de carga, en las tres listas.
- **Archivos**: `HojaRuta/Index.cshtml`, `Seccion/Index.cshtml`, `Seccion/_Seleccionar.cshtml`.
- **Hacer**:
  - Panel de filtros con chips (`helper.filtros`) en las dos listas, como `PlanMantenimiento/Index`.
  - `helper.tabla.cargando` / `vacia`, `helper.html.escape`, contador «Mostrando X – Y de N».
  - Acciones como `btn btn-light` con `aria-label`; botón *Nuevo* con texto.
  - En `Seccion/Index`, el código de la hoja de ruta enlaza a `HojaRuta/Ver`.
  - En el selector, mostrar con badge las secciones cuya hoja de ruta está inactiva (ver `DS-02`).
- **Aceptación**:
  - [ ] Estado vacío con `colspan` correcto en las tres tablas.
  - [ ] Un nombre con etiquetas HTML se muestra literal.
- **Esfuerzo** M · **Riesgo** BAJO · **Ref.** `MNT-044`

---

### FASE 1 — Hacer visible la agrupación

#### [x] HS-04 · Hoja de Ruta como árbol plegable

- **Hoy**: `HojaRuta/Ver` pinta cada sección expandida con todas sus tareas, materiales y servicios;
  con 15 secciones la página es inmanejable y no hay acciones por sección.
- **Objetivo**: ver la hoja de ruta de un vistazo y bajar al detalle sólo donde interesa.
- **Archivos**: `HojaRuta/Ver.cshtml`, `HojaRuta.Controller.cs`, `Seccion.Controller.cs`.
- **Hacer**:
  - Cabecera con totales de la hoja: secciones (activas / total), tareas, horas-hombre.
  - Una fila por sección, **plegada**: código, nombre, estado, nº de tareas, HH, nº de materiales y
    servicios, y acciones *Editar* y *Duplicar*.
  - Al desplegar, cargar las tareas de esa sección bajo demanda (acción parcial), no todas al abrir.
  - Estado vacío con *Crear la primera sección* y *Agregar secciones existentes* (HS-09).
  - Botón *Editar hoja de ruta* (hoy sólo accesible desde la lista).
  - Reutilizar el estilo `.tabla-arbol` que ya usa `ArbolJerarquico/_Generar.cshtml`.
- **Aceptación**:
  - [ ] Una hoja de 15 secciones cabe en una pantalla plegada.
  - [ ] Abrir la hoja no carga tareas, materiales ni servicios hasta desplegar.
- **Esfuerzo** L · **Riesgo** MEDIO · **Ref.** `MNT-023` (carga del detalle)

#### [x] HS-05 · Contadores en las listas

- **Objetivo**: detectar desde la lista hojas vacías y secciones sin tareas o sin uso.
- **Archivos**: ambas `Index`, controladores y repositorios de `HojaRuta` y `Seccion`.
- **Hacer**:
  - `HojaRuta/Index`: columna *SECCIONES* (activas / total).
  - `Seccion/Index`: columnas *TAREAS*, *HH* y *PLANES* (planes que la usan, enlazable).
  - Conteos con **consultas agrupadas por página**, como `PlanMantenimientoRepositorio.ResumirAsync`.
- **Aceptación**:
  - [ ] Sin consultas por fila (verificar con el log de EF Core).
  - [ ] Una sección con 0 tareas y una hoja con 0 secciones se ven resaltadas.
- **Esfuerzo** M · **Riesgo** MEDIO (rendimiento)

#### [x] HS-06 · Resumen vivo de la sección mientras se edita

- **Hoy**: no hay totales; las pestañas no dicen cuántos elementos tienen, así que un material o un
  adjunto sólo se descubre entrando a la pestaña.
- **Archivos**: `Seccion/Nuevo.cshtml`, `Seccion/Editar.cshtml`.
- **Hacer**:
  - Contador en cada pestaña: *Tareas (12)*, *Materiales (3)*, *Servicios (0)*, *Adjuntos (2)*.
  - En la cabecera: horas-hombre totales (Σ cantidad × duración), recalculadas al editar.
- **Aceptación**:
  - [ ] Añadir o quitar una fila actualiza el contador de su pestaña y el total de HH.
- **Esfuerzo** S · **Riesgo** BAJO

#### [x] HS-07 · «Usada en N planes» antes de editar o desactivar

- **Hoy**: nada indica que una sección se reutiliza. Quien la edita no sabe que cambia las órdenes
  futuras de todos esos planes, y quien la desactiva no sabe que —según lo verificado— sigue en ellos.
- **Objetivo**: decidir con la información completa.
- **Archivos**: `Seccion/Editar.cshtml`, `Seccion.Controller.cs`.
- **Hacer**:
  - Aviso en la cabecera: *Esta sección se usa en N planes* con la lista enlazada a `PlanMantenimiento/Ver`.
  - Texto: los cambios afectan a las **órdenes que se generen a partir de ahora**; las ya emitidas no cambian.
  - Al desmarcar *Activo* con N > 0, advertencia en línea con el comportamiento que se confirme en `DS-01`.
- **Aceptación**:
  - [ ] Una sección usada en planes lo muestra antes de guardar.
  - [ ] El texto de la advertencia de desactivación coincide con lo decidido en `DS-01`.
- **Esfuerzo** M · **Riesgo** BAJO · **Ref.** `MNT-037` (b)

#### [x] HS-08 · Navegación entre hoja de ruta y sección

- **Hoy**: `Seccion/Editar` siempre vuelve a la lista de secciones; no hay migas de pan; la hoja de
  ruta de una sección no es un enlace.
- **Archivos**: `Seccion/{Nuevo,Editar}.cshtml`, `HojaRuta/Ver.cshtml`.
- **Hacer**:
  - Migas de pan: `Hojas de Ruta / [HR] Descripción / [SEC] Nombre` (o `Secciones / Sin hoja de ruta / …`).
  - *Regresar* y el redirect tras guardar vuelven a la hoja de ruta de la sección cuando la tiene.
  - Mismo encabezado reutilizable que `_EncabezadoPlan`.
- **Aceptación**:
  - [ ] Editar una sección abierta desde una hoja de ruta devuelve a esa hoja de ruta.
- **Esfuerzo** S · **Riesgo** BAJO

#### [x] HS-09 · Agregar y quitar secciones de una hoja de ruta

- **Hoy**: desde una hoja sólo se crean secciones nuevas. Para mover una existente hay que abrirla y
  guardarla completa, lo que **recrea todas sus tareas** (`BR-SE-003`).
- **Objetivo**: organizar sin tocar el contenido de las secciones.
- **Archivos**: `HojaRuta/Ver.cshtml`, `HojaRuta.Controller.cs`, lógica y repositorio de `Seccion`.
- **Hacer**:
  - *Agregar secciones existentes*: selector múltiple de secciones sin hoja de ruta (o de otra hoja,
    con aviso de que se moverán).
  - *Quitar de la hoja de ruta* por sección (queda suelta, no se desactiva ni se borra).
  - Endpoint que **sólo** actualiza `Seccion.HojaRutaId` (p. ej. `ExecuteUpdate`), validando empresa.
- **Aceptación**:
  - [ ] Mover una sección no cambia los `Id` de sus tareas.
  - [ ] No se puede mover una sección de otra empresa.
- **Esfuerzo** M · **Riesgo** MEDIO (escritura nueva)

---

### FASE 2 — Editar tareas con menos fricción

#### [x] HS-10 · Barra fija, cambios sin guardar y confirmaciones

- **Hacer** (patrón de PM-08 y PM-09):
  - *Guardar* / *Regresar* en `.barra-acciones`; quitar la confirmación de *Guardar*.
  - Indicador y aviso de cambios sin guardar, incluidos archivos subidos a Dropzone y aún no guardados.
  - Confirmar al quitar una tarea que tenga descripción o texto ampliado.
  - *Regresar* como `btn-secondary`; `title` correcto del botón de nueva tarea.
- **Aceptación**:
  - [ ] Salir con cambios pendientes pide confirmación.
- **Esfuerzo** M · **Riesgo** BAJO · **Ref.** `MNT-042`, `MNT-045`

#### [x] HS-11 · Errores en la fila y en la pestaña

- **Hacer** (patrón de PM-10):
  - Validación en cliente de tareas, materiales y servicios.
  - Claves `Tareas[i].Campo`, `Materiales[i].Cantidad`… y respuesta JSON estructurada.
  - Marcar la fila, **activar la pestaña del primer error** y marcar con un punto rojo las demás
    pestañas con errores.
- **Aceptación**:
  - [ ] Un error en la pestaña *Materiales* se ve aunque el usuario esté en *Tareas*.
- **Esfuerzo** M · **Riesgo** BAJO · **Ref.** `MNT-043`

#### [x] HS-12 · Ordenar tareas sin teclear números

- **Hoy**: `Orden` es un número editable libre; admite repetidos y huecos, y quitar una tarea no
  renumera.
- **Hacer**: botones *subir* / *bajar* por tarea que mueven la fila (con su texto ampliado) y
  renumeran; renumerar también al añadir o quitar. El campo pasa a sólo lectura.
- **Aceptación**:
  - [ ] Tras cualquier operación, los órdenes son 1..N sin huecos ni repetidos.
- **Esfuerzo** M · **Riesgo** BAJO · **Ref.** `MNT-024` (la validación en servidor sigue siendo suya)

#### [x] HS-13 · Texto ampliado visible

- **Hoy**: el texto ampliado se abre con un icono de comentarios que no indica si hay contenido.
- **Hacer**: icono relleno o badge cuando hay texto; botón *Mostrar todos / Ocultar todos*;
  `aria-expanded` en el botón.
- **Esfuerzo** S · **Riesgo** BAJO

#### [x] HS-14 · Sistema y parte coherentes

- **Hoy**: `Nuevo` muestra `[Agrupador] Sistema` y `Editar` no; la carga de partes no maneja error ni
  indica que está cargando.
- **Hacer**: mismo formato en ambas vistas; estado *Cargando…* y mensaje si falla
  `Parte/BuscarPorSistema`.
- **Esfuerzo** S · **Riesgo** BAJO

#### [x] HS-15 · Adjuntos honestos

- **Hoy**: eliminar un adjunto existente pide `confirm()`, muestra `alert()` y **borra en el servidor
  al instante**, aunque luego el usuario no guarde. Duplicar una sección no copia sus adjuntos y no lo
  dice.
- **Hacer**:
  - SweetAlert que diga explícitamente que el borrado es inmediato y no se deshace al salir sin guardar.
  - Al duplicar, aviso: *Los adjuntos de la sección original no se copian*.
- **Esfuerzo** S · **Riesgo** BAJO · **Ref.** `MNT-014` (diferir el borrado al guardado es parte de esa tarea)

---

### FASE 3 — Códigos y duplicación

#### [x] HS-16 · Alerta de código duplicado (no bloqueante)

- **Requisito del propietario** (`D-03`): el duplicado es válido; se avisa, **nunca** se bloquea.
- **Hacer**: al salir del campo *Código*, aviso ámbar con el registro existente. Ámbito: empresa para
  hoja de ruta; hoja de ruta para sección.
- **Esfuerzo** M · **Riesgo** BAJO · **Ref.** `MNT-048` — **leerla completa antes de empezar**

#### [x] HS-17 · Duplicar sección de forma explícita

- **Hoy**: `Nuevo?id=N` abre un formulario idéntico al de alta, sin indicar que es una copia ni de qué.
- **Hacer**: título *Duplicar sección*, banner *Copia de [código] nombre* con enlace a la original,
  foco en el campo *Código* (dispara HS-16), y el aviso de adjuntos de HS-15.
- **Esfuerzo** S · **Riesgo** BAJO · **Ref.** `BR-SE-006`

---

### FASE 4 — Consistencia visual

#### [x] HS-18 · Color semántico y móvil

- **Hoy**: las pestañas de la sección usan `bg-warning` para tareas, materiales, servicios y adjuntos;
  `HojaRuta/Ver` mezcla `bg-primary`, `bg-success` y `bg-info`. La tabla de tareas tiene 9 columnas
  editables.
- **Hacer**:
  - Azul para todas las tablas de configuración (convención ya documentada en `site.css`).
  - `.tabla-apilable` con `data-label` en la tabla de tareas (y su fila de texto ampliado),
    materiales y servicios.
- **Aceptación**:
  - [ ] A 768 px se puede añadir y completar una tarea sin scroll horizontal.
- **Esfuerzo** M · **Riesgo** BAJO

---

## 6. Orden recomendado

| Orden | Paso | Esfuerzo | Riesgo | Por qué en este orden |
|-------|------|----------|--------|-----------------------|
| 1 | **HS-01** Especialidad correcta | S | BAJO | Cada día sin corregir corrompe más datos |
| 2 | HS-02 Elegir tipo y especialidad | S | BAJO | Misma familia de error silencioso |
| 3 | HS-03 Listas y selector | M | BAJO | Base común; rápido y visible |
| 4 | HS-06 Resumen vivo | S | BAJO | Enseña el concepto «la sección agrupa» con poco código |
| 5 | HS-08 Navegación | S | BAJO | Prepara HS-04 |
| 6 | **HS-04** Árbol de la hoja de ruta | L | MEDIO | El cambio de mayor impacto conceptual |
| 7 | HS-05 Contadores | M | MEDIO | |
| 8 | HS-07 Usada en N planes | M | BAJO | Requiere `DS-01` para el texto de desactivación |
| 9 | HS-09 Agregar / quitar secciones | M | MEDIO | Escritura nueva: después de validar HS-04 |
| 10 | HS-10 Barra y cambios sin guardar | M | BAJO | |
| 11 | HS-11 Errores en fila y pestaña | M | BAJO | Aprovecha HS-02 |
| 12 | HS-12 Ordenar tareas | M | BAJO | |
| 13 | HS-13 Texto ampliado | S | BAJO | |
| 14 | HS-14 Sistema y parte | S | BAJO | |
| 15 | HS-15 Adjuntos | S | BAJO | |
| 16 | HS-16 Código duplicado | M | BAJO | Requisito del propietario |
| 17 | HS-17 Duplicar explícito | S | BAJO | Aprovecha HS-15 y HS-16 |
| 18 | HS-18 Color y móvil | M | BAJO | |

## 7. Decisiones pendientes del propietario

| Id | Pregunta | Afecta a |
|----|----------|----------|
| `DS-01` | Una sección **desactivada** que ya está en planes, ¿debe dejar de generar órdenes? Verificado: `PlanMantenimientoRepositorio.ListarParaProgramar` incluye las secciones del plan sin filtrar `Seccion.Activo` y no hay filtros globales, así que hoy **sí** siguen generando órdenes. | HS-07 (texto) y, si se decide que sí, una tarea de lógica aparte |
| `DS-02` | Las secciones de una hoja de ruta **inactiva**, ¿deben poder elegirse en un plan? Hoy sí en la web y no en la app móvil (`BR-HR-003`). | HS-03 |
| `DS-03` | Por el error de HS-01, las especialidades de tareas guardadas desde `Editar` o duplicadas pueden estar mal. ¿Se revisan? Los valores originales no se conservan; las órdenes ya emitidas guardan copia de sus tareas y podrían servir de referencia. | Tarea de datos aparte |
| `DS-04` | ¿Una sección debe pertenecer **siempre** a una hoja de ruta? Hoy es opcional (`BR-SE-001`). Si pasa a obligatoria, HS-04 y HS-09 se simplifican. | HS-04, HS-09 |

## 8. Fuera de alcance, con referencia

- IDOR de lectura en `HojaRuta/Editar` (`HojaRuta.Controller.cs:60` busca por `id` sin empresa): `MNT-021`.
- Identidad de tareas y borrado diferido de adjuntos (`BR-SE-003`, `BR-SE-004`): `MNT-014`.
- Validación de `Orden` en servidor: `MNT-024`.

## 9. Registro de avance

| Paso | Estado | Fecha | Commit | Notas |
|------|--------|-------|--------|-------|
| HS-01 | APLICADO | 2026-09-16 | | Parcial `_FilaTarea`; también conserva tipo/especialidad/sistema/parte inactivos; corrige error 500 y nombres de sistema duplicados al duplicar. Falta verificar en navegador |
| HS-02 | APLICADO | 2026-09-16 | | Opción SELECCIONE + marca de fila antes de guardar. Falta verificar en navegador |
| HS-03 | APLICADO | 2026-09-16 | | Listas con panel de filtros; selector con badge de hoja inactiva y datos en data-* (misma forma de objeto para Plan y OT). Falta verificar en navegador |
| HS-04 | APLICADO | 2026-09-16 | | Árbol con detalle bajo demanda (`Seccion/Detalle`); botón Editar hoja de ruta. *Agregar secciones existentes* queda para HS-09. Falta verificar en navegador |
| HS-05 | APLICADO | 2026-09-16 | | `ResumirAsync` en HojaRuta (2 consultas) y Seccion (4 consultas) por página. La columna PLANES no enlaza: no existe una pantalla de planes filtrada por sección. Falta verificar en navegador |
| HS-06 | APLICADO | 2026-09-16 | | Contadores en pestañas + resumen (tareas, HH, materiales, servicios, adjuntos) recalculado con MutationObserver. Falta verificar en navegador |
| HS-07 | APLICADO | 2026-09-16 | | Lista de planes enlazada + aviso al desmarcar Activo. Texto basado en el código actual (`ListarParaProgramar` no filtra `Seccion.Activo`); revisar si `DS-01` cambia el comportamiento. Falta verificar en navegador |
| HS-08 | APLICADO | 2026-09-16 | | Parcial `_EncabezadoSeccion`; Regresar y redirect a la hoja elegida. Corrige además que una hoja inactiva se perdía al guardar (select sin la opción). Falta verificar en navegador |
| HS-09 | APLICADO | 2026-09-16 | | `HojaRuta/AgregarSecciones` y `QuitarSeccion` con `ExecuteUpdateAsync` sobre `HojaRutaId` (filtra empresa). El selector sólo ofrece secciones activas. Falta verificar en navegador |
| HS-10 | APLICADO | 2026-09-16 | | Barra fija, cambios sin guardar (incluye archivos subidos), sin confirmación de Guardar, confirmación al quitar tareas con contenido. Falta verificar en navegador |
| HS-11 | APLICADO | 2026-09-16 | | Claves `Tareas[i].Campo` / `Materiales[i].Cantidad` y respuesta JSON; activa la pestaña del primer error y marca con punto rojo las demás. Falta verificar en navegador |
| HS-12 | APLICADO | 2026-09-16 | | Subir/bajar con la fila de texto ampliado; orden de sólo lectura renumerado 1..N. Al abrir, si había huecos o repetidos se renumera, se avisa y queda como cambio pendiente. Falta verificar en navegador |
| HS-13 | APLICADO | 2026-09-16 | | Punto azul si hay texto; botón Mostrar/Ocultar todos; `aria-expanded`. Falta verificar en navegador |
| HS-14 | APLICADO | 2026-09-16 | | Agrupador igual en Nuevo y Editar (HS-01); carga de partes con estado «Cargando…», aviso si falla y nombres escapados. Falta verificar en navegador |
| HS-15 | APLICADO | 2026-09-16 | | SweetAlert que dice que el borrado es inmediato y no se deshace; aviso de adjuntos no copiados al duplicar. Diferir el borrado sigue en MNT-014. Falta verificar en navegador |
| HS-16 | APLICADO | 2026-09-16 | | `BuscarCodigo` en HojaRuta y Seccion con `[FiltroAccion(Accion = "Index")]` (una acción nueva no tiene página registrada), filtra empresa, coincidencia exacta; `helper.codigoDuplicado` reutilizable. Nunca bloquea. Falta verificar en navegador |
| HS-17 | APLICADO | 2026-09-16 | | Título «Duplicar sección», banner con enlace a la original y nº de adjuntos no copiados, foco en Código y aviso de duplicado inmediato. Falta verificar en navegador |
| HS-18 | APLICADO | 2026-09-16 | | Cabeceras azules; tareas, materiales y servicios apilables < 992 px (fila de texto ampliado incluida); datos de materiales/servicios escapados. Falta verificar en navegador |
