# Plan de mejora de UX – Equipos y Ubicaciones

> Documento **ejecutable paso a paso**, con la misma mecánica que `legacy/planes/PLAN-UX-PLANMANTENIMIENTO.md` y
> `legacy/planes/PLAN-UX-HOJARUTA-SECCION.md`: cada paso es pequeño, verificable y reversible por sí solo. Marca la
> casilla al terminarlo y anótalo en el *Registro de avance* del final.

- **Alcance**: `Equipo/{Index, Nuevo, Editar, Ver, _Seleccionar, _SeleccionarUno}` y
  `Ubicacion/{Index, Nuevo, Editar, Ver, _Seleccionar, _SeleccionarUno}`, más los enlaces desde
  `ArbolJerarquico`.
- **Fuera de alcance**: el algoritmo de programación, los permisos, las pantallas de Contadores,
  Puntos de Medida y Aspectos, y el modelo de datos (salvo las consultas de lectura que piden EU-08,
  EU-09 y EU-10). **Única excepción**: EU-22 cambia el filtro de generación de órdenes de las
  ubicaciones, por decisión del propietario (`DE-04`).
- **Fecha**: 2026-09-17 · **Decisiones `DE-01` … `DE-04` resueltas el 2026-09-17**
- **Relación con AMSYS-BRAIN**: complementa `legacy/analisis/ux.md` y las tareas `MNT-NNN`; cada paso indica su
  tarea equivalente cuando existe.

---

## 1. El concepto que la interfaz tiene que transmitir

**Ubicación** y **Equipo** forman el **árbol de objetos técnicos** sobre el que se mantiene:

```
Ubicación raíz
 └── Ubicación  (Mantenible: puede recibir planes, avisos y órdenes)
      ├── Ubicación …
      └── Equipo  (montado en la ubicación)
           └── Componente  (equipo montado en otro equipo)

Plan de Mantenimiento ──se asigna a──► Equipos y Ubicaciones
```

Hechos verificados que condicionan el diseño:

| Hecho | Evidencia | Consecuencia para la UX |
|-------|-----------|-------------------------|
| Un equipo está «montado» si tiene `UbicacionId` o `EquipoPadreId` | `Equipo.Adicional.cs:23` | El estado de montaje es lo primero que hay que ver de un equipo |
| El montaje sólo se cambia desde el Árbol Jerárquico, y deja historial | `ArbolJerarquicoController`, `EquipoLogica.MontarAsync/DesmontarAsync` | La ficha del equipo debe decir **dónde** está y llevar al árbol, no repetir la operación |
| Sólo genera órdenes un equipo **activo y montado** | `BR-GE-007`, `PlanMantenimiento.Logica.cs:156` | Desactivar o desmontar un equipo con planes **detiene su mantenimiento**: hay que avisarlo |
| Sólo genera órdenes una ubicación **activa** | `PlanMantenimiento.Logica.cs:307` | Lo mismo al desactivar una ubicación |
| `Mantenible` decide si una ubicación puede recibir planes, avisos y órdenes | `PlanMantenimientoUbicacion.Controller.cs:35`, selectores de `Aviso`/`OrdenTrabajo`, `_Generar.cshtml:47` | Es un campo con consecuencias y hoy no tiene ninguna explicación |
| Una ubicación **no mantenible sigue generando órdenes** si tiene planes: la generación sólo filtra `Activo` | `PlanMantenimiento.Logica.cs:307` | Contradice la regla anterior. `DE-04`: debe dejar de generar → EU-22 |
| Cambiar la clase de equipo reemplaza los datos técnicos; guardar borra y recrea todos | `Editar.cshtml:622-644`, `EquipoLogica.ActualizarAsync` (región *Datos Tecnicos*) | Cambiar la clase por error pierde los valores sin aviso |
| El Árbol Jerárquico sólo lista ubicaciones y equipos **activos** | `ArbolJerarquico.Controller.cs:33-34` | Un equipo inactivo montado —y sus componentes— desaparecen del árbol → decisión `DE-02` |

## 2. Pantallas afectadas

| Vista | Archivo | LOC | Rol |
|-------|---------|-----|-----|
| Lista de equipos | `Views/Equipo/Index.cshtml` | 200 | Buscar y abrir |
| Alta / edición de equipo | `Views/Equipo/Nuevo.cshtml`, `Editar.cshtml` | 597 / 663 | Cabecera + 4 pestañas |
| Ficha de equipo | `Views/Equipo/Ver.cshtml` | 591 | Consulta, 6 pestañas |
| Selectores de equipo | `Views/Equipo/_Seleccionar.cshtml`, `_SeleccionarUno.cshtml` | 151 c/u | Modal (Árbol, Aviso, OT, Plan…) |
| Lista de ubicaciones | `Views/Ubicacion/Index.cshtml` | 186 | Buscar y abrir |
| Alta / edición de ubicación | `Views/Ubicacion/Nuevo.cshtml`, `Editar.cshtml` | 154 / 156 | Formulario simple |
| Ficha de ubicación | `Views/Ubicacion/Ver.cshtml` | 57 | Consulta |
| Selectores de ubicación | `Views/Ubicacion/_Seleccionar.cshtml`, `_SeleccionarUno.cshtml` | ~148 c/u | Modal (Aviso, OT, Plan…) |

Los cuatro selectores se abren desde **23 puntos** de la aplicación: cualquier cambio en ellos debe
mantener el nombre de los parámetros (`filtro.*`, `callBack`) y la forma del objeto devuelto.

## 3. Diagnóstico corto

1. **🔴 Editar un equipo borra su Tipo de Equipo.** `Equipo/Editar.cshtml:121` pinta el `<select>` de
   tipo **sin** `asp-items`, aunque el controlador carga `ViewBag.TiposEquipo` y la vista construye
   `optionsTipoEquipoId` (línea 19) que nunca usa. El campo muestra *NINGUNO* y guardar persiste `null`.
2. **🔴 Valores inactivos que se pierden al guardar.** Todos los `<select>` de `Editar` (criticidad,
   centro de costo, organización, clase de equipo, ubicación superior) se llenan sólo con registros
   **activos**. Si el valor guardado está inactivo, el navegador elige otro y guardar lo sobrescribe.
   En ubicaciones es peor: con la ubicación superior inactiva, **guardar la convierte en raíz**.
3. **🔴 Se pueden crear ciclos de ubicaciones.** `Ubicacion.Controller.cs:103` sólo excluye la propia
   ubicación y sus hijos **directos**; un nieto se puede elegir como superior. La rama desaparece del
   árbol y las consultas recursivas (`ListarSubUbicaciones`) no tienen condición de corte.
4. **Pantallas que engañan.** `Ubicacion/Ver.cshtml:21` muestra la **organización** bajo el título
   *Ubicación Superior*. En `Equipo/Index.cshtml:115-116` los filtros de equipo superior leen
   `#FEquipoCodigo` / `#FEquipoNombre`, que no existen (los inputs son `#FEquipoPadreCodigo` /
   `#FEquipoPadreNombre`): **esos dos filtros no filtran**. En `Ubicacion/Index.cshtml:138` *RAIZ*
   depende de `montado`, que las ubicaciones no tienen, así que nunca aparece.
5. **La jerarquía no se ve fuera del árbol.** La ficha del equipo no dice dónde está montado (sólo el
   historial de movimientos, al fondo de una pestaña), sus componentes no enlazan, y no muestra los
   planes, avisos ni órdenes del equipo. La ficha de ubicación son 6 campos, sin *Mantenible*, sin
   *Orden*, sin sub-ubicaciones, sin equipos y sin planes.
6. **Consecuencias invisibles.** Desactivar un equipo o una ubicación con planes asignados detiene sus
   órdenes sin avisar; cambiar la clase de equipo borra los datos técnicos escritos; `Mantenible` y
   `Orden` no se explican.
7. **Datos técnicos invisibles en la ficha.** `Ver` los carga (`conDatosTecnicos: true`) pero no tiene
   pestaña para mostrarlos.
8. **Listas y selectores atrasados respecto al patrón vigente**: filtros en el `<thead>`,
   `colspan='20'` y `colspan='7'` con `</td></td>` (seis vistas), datos sin escapar, sin estado de
   carga. `_Seleccionar.cshtml:1` importa `DocumentFormat.OpenXml.Wordprocessing` sin usarlo.
9. **Formularios sin red de seguridad**: *Guardar* arriba y confirmado, *Regresar* ámbar sin aviso de
   cambios, errores sin campo (`Equipo.Controller.cs:291` y `Ubicacion.Controller.cs:197` usan la clave
   `Descripcion` para el nombre; el mensaje de datos técnicos siempre dice «nro. 1» porque `i` no se
   incrementa, líneas 278 y 310), adjuntos con `confirm()`/`alert()` y borrado inmediato.
10. **Selección silenciosa**: *Organización* es un `select2` sin opción vacía; se guarda la primera
    organización aunque nadie la haya elegido.
11. **Vocabulario incoherente** en `Equipo`: la misma pestaña se llama *Datos Generales* (Nuevo) y
    *Datos Adicionales* (Editar, Ver); la de materiales y sistemas, *Partes o Repuestos* (Nuevo, Ver) y
    *Partes/Sistemas* (Editar). `Editar` arrastra código muerto de `#tblComponentes`.

## 4. Principios

- Los mismos de los planes anteriores: reutilizar `helper.filtros`, `helper.tabla`,
  `helper.html.escape`, `helper.codigoDuplicado`, `.barra-acciones`, la respuesta de validación
  estructurada, la convención de color y `.tabla-apilable`, ya disponibles en `site.css` y `helper.js`.
- **El montaje se hace en el Árbol Jerárquico.** Las fichas lo muestran y enlazan; no duplican la
  operación.
- **Los selectores son contratos compartidos**: no cambiar parámetros ni la forma del objeto devuelto.
- Un paso = un commit.

---

## 5. Pasos

### FASE 0 — Lo que hoy daña datos o engaña

#### [x] EU-01 · Conservar el Tipo de Equipo al editar

- **Hoy**: `Equipo/Editar.cshtml:121` no tiene `asp-items`; cada guardado deja el tipo en `null`.
- **Objetivo**: que abrir y guardar un equipo sin tocar nada no cambie ningún dato.
- **Archivos**: `Views/Equipo/Editar.cshtml`.
- **Hacer**:
  - Añadir `asp-items="optionsTipoEquipoId"` al `<select>` de tipo.
  - **El identificador guardado se mantiene hasta que el usuario lo quite** (`DE-01`): al abrir, el
    tipo guardado queda seleccionado aunque esté inactivo (EU-02) y sólo se envía `null` si el
    usuario elige *NINGUNO* de forma explícita.
  - Al cambiar la clase, mostrar *Cargando…* en el `<select>` de tipo y avisar si falla
    `ClaseEquipo/ListarTipos`. Si el tipo guardado no pertenece a la clase nueva, avisar en línea de
    que se va a limpiar, en lugar de vaciarlo en silencio.
  - Lo mismo para `Nuevo` cuando se vuelve a cargar el formulario tras un error de validación.
- **Aceptación**:
  - [ ] Abrir un equipo con tipo y guardarlo sin cambios conserva el tipo.
  - [ ] El tipo sólo queda vacío cuando el usuario elige *NINGUNO*.
- **Esfuerzo** S · **Riesgo** BAJO
- **Nota** (`DE-01`, resuelta): **no** se repararán los equipos cuyo tipo ya se perdió; quedan en
  `null` y se corrigen a mano cuando alguien edite el equipo.

#### [x] EU-02 · No perder valores inactivos al guardar

- **Hoy**: criticidad, centro de costo, organización, clase de equipo y ubicación superior sólo
  ofrecen registros activos; un valor guardado inactivo se sustituye en silencio (una ubicación con
  superior inactiva pasa a raíz).
- **Objetivo**: el mismo que EU-01, para todos los `<select>` de `Editar`.
- **Archivos**: `Equipo/Editar.cshtml`, `Ubicacion/Editar.cshtml`, `Equipo.Controller.cs`,
  `Ubicacion.Controller.cs`.
- **Hacer**:
  - Si el valor guardado no está en la lista, añadirlo como opción seleccionada con el sufijo
    «(inactivo)», igual que se hizo en `Seccion/_FilaTarea` (HS-01).
  - Mismo tratamiento para el tipo de equipo de EU-01.
- **Aceptación**:
  - [ ] Una ubicación cuya superior está inactiva sigue colgando de ella tras guardar.
  - [ ] Un equipo con criticidad inactiva la conserva tras guardar.
- **Esfuerzo** S · **Riesgo** BAJO

#### [x] EU-03 · Impedir ciclos en la ubicación superior

- **Hoy**: `Ubicacion.Controller.cs:103` excluye sólo la propia ubicación y sus hijos directos; un
  nieto se puede elegir como superior y el servidor no lo valida.
- **Objetivo**: que el árbol de ubicaciones sea siempre un árbol.
- **Archivos**: `Ubicacion.Controller.cs`, `UbicacionLogica`.
- **Hacer**:
  - **Antes de tocar código** (`DE-03`, resuelta: hay que revisarlo): ejecutar en la base de datos una
    consulta que detecte ciclos y guardar el resultado en `legacy/analisis/`. Con un recorrido acotado
    basta, porque una consulta recursiva sobre un ciclo no termina:

    ```sql
    WITH RECURSIVE ruta AS (
        SELECT id, ubicacionpadreid, 1 AS nivel, ARRAY[id] AS camino
        FROM ubicacion
        UNION ALL
        SELECT u.id, u.ubicacionpadreid, r.nivel + 1, r.camino || u.id
        FROM ubicacion u
        JOIN ruta r ON r.ubicacionpadreid = u.id
        WHERE NOT u.id = ANY(r.camino) AND r.nivel < 50
    )
    SELECT * FROM ruta WHERE ubicacionpadreid = ANY(camino);
    ```

    Si aparecen filas, romper cada ciclo (dejar una de las ubicaciones como raíz) **antes** de
    desplegar; el recorrido recursivo de `ListarSubUbicaciones` con un ciclo no tiene corte.
  - Excluir de la lista **todos** los descendientes (`ListarSubUbicaciones` ya los obtiene).
  - Validar en el POST de `Editar` que la superior elegida no sea la propia ubicación ni un
    descendiente, y que pertenezca a la empresa.
- **Aceptación**:
  - [ ] La consulta de ciclos devuelve 0 filas en producción.
  - [ ] Ningún descendiente aparece como opción de ubicación superior.
  - [ ] Un POST manipulado con un descendiente devuelve error de validación.
- **Esfuerzo** S · **Riesgo** BAJO

#### [x] EU-04 · Corregir lo que las pantallas muestran mal

- **Hoy**: `Ubicacion/Ver` rotula la organización como *Ubicación Superior*; dos filtros de
  `Equipo/Index` leen ids inexistentes; *RAIZ* nunca aparece en `Ubicacion/Index`; `Ubicacion/Index`
  envía `FOrganizacionId` y `FMontado`, que no existen en la vista.
- **Archivos**: `Ubicacion/Ver.cshtml`, `Equipo/Index.cshtml`, `Ubicacion/Index.cshtml`.
- **Hacer**:
  - En `Ver`, mostrar `[código] nombre` de `UbicacionPadre` o *RAIZ*.
  - Leer `#FEquipoPadreCodigo` / `#FEquipoPadreNombre` en `Equipo/Index`.
  - Mostrar *RAIZ* cuando `ubicacionPadre` es `null`; quitar los filtros fantasma.
- **Aceptación**:
  - [ ] Filtrar por código de equipo superior reduce la lista.
  - [ ] La ficha de una ubicación raíz dice *RAIZ*.
- **Esfuerzo** S · **Riesgo** BAJO

#### [x] EU-05 · Obligar a elegir organización

- **Hoy**: el `select2` de *Organización* no tiene opción vacía en `Nuevo` de equipo y de ubicación;
  se guarda la primera y la validación `!OrganizacionId.HasValue` nunca salta.
- **Archivos**: `Equipo/Nuevo.cshtml`, `Ubicacion/Nuevo.cshtml`.
- **Hacer**: `<option value="">SELECCIONE</option>` y `placeholder` en `select2`. Si el usuario sólo
  tiene una organización, preseleccionarla (no hay decisión que tomar).
- **Aceptación**:
  - [ ] Con varias organizaciones, crear sin elegir una muestra el error en el campo.
- **Esfuerzo** S · **Riesgo** BAJO

#### [x] EU-06 · Listas y selectores al patrón vigente

- **Hoy**: filtros en el `<thead>` sin etiquetas, `colspan` incorrecto con `</td></td>` en seis
  vistas, datos sin escapar, sin estado de carga ni contador.
- **Archivos**: `Equipo/{Index,_Seleccionar,_SeleccionarUno}.cshtml`,
  `Ubicacion/{Index,_Seleccionar,_SeleccionarUno}.cshtml`.
- **Hacer**:
  - Panel de filtros con chips (`helper.filtros`) en las dos listas, como `PlanMantenimiento/Index`.
    En equipos, *Criticidad*, *Centro de costo* y *Organización* como filtros avanzados.
  - `helper.tabla.cargando` / `vacia`, `helper.html.escape`, contador «Mostrando X – Y de N».
  - Acciones como `btn btn-light` con `title` y `aria-label`, orden *Ver · Editar*; botón *Nuevo* con
    texto.
  - Selectores: estado vacío correcto, escapado y badge *No montado* / *Inactivo* donde aplique, **sin
    cambiar** parámetros ni objeto devuelto. Quitar el `@using DocumentFormat…` sobrante.
- **Aceptación**:
  - [ ] Estado vacío con `colspan` correcto en las seis tablas.
  - [ ] Un nombre con etiquetas HTML se muestra literal.
  - [ ] Montar equipos desde el árbol y elegir equipo en Aviso/OT siguen funcionando.
- **Esfuerzo** M · **Riesgo** BAJO · **Ref.** `MNT-044`

---

### FASE 1 — Hacer visible la jerarquía y el estado

#### [x] EU-07 · Cabecera de estado en la ficha del equipo

- **Hoy**: `Equipo/Ver` repite el formulario en sólo lectura. Para saber dónde está montado hay que
  abrir *Movimientos* y leer la última fila.
- **Objetivo**: responder de un vistazo *qué es, dónde está y si se está manteniendo*.
- **Archivos**: `Equipo/Ver.cshtml`, `Equipo.Controller.cs`; parcial nueva `_EncabezadoEquipo`.
- **Hacer**:
  - Migas de pan con la ruta completa: `Ubicación raíz › … › Ubicación › Equipo padre › Equipo`,
    cada tramo enlazado a su ficha (la cadena ya la recorre `EquipoLogica.BuscarUbicacion`).
  - Badges: *Activo/Inactivo*, *Montado/No montado*, criticidad y, si tiene planes, *Genera
    mantenimiento* o *No genera: inactivo / no montado* (mismo criterio que
    `PlanMantenimientoEquipo.Controller.cs:205-207`).
  - Botones *Editar* y *Ver en el árbol* (abre `ArbolJerarquico` expandido en el equipo).
- **Aceptación**:
  - [ ] Sin cambiar de pestaña se sabe dónde está montado y si genera mantenimiento.
- **Esfuerzo** M · **Riesgo** BAJO · **Ref.** `BR-GE-007`

#### [x] EU-08 · Ficha del equipo completa

- **Hoy**: no hay pestaña de datos técnicos; los componentes no enlazan; no se ven planes, avisos ni
  órdenes del equipo, aunque los filtros por `EquipoId` ya existen.
- **Archivos**: `Equipo/Ver.cshtml`, `Equipo.Controller.cs`.
- **Hacer**:
  - Pestaña *Datos técnicos* (sólo los que tienen valor, con enlace a *Editar* si faltan).
  - *Componentes*: código enlazado, estado activo y nº de sub-componentes.
  - Pestaña *Mantenimiento*: planes asignados (plan, tipo de programación, posición actual, última
    ejecución, *Bloqueado*) enlazados a `PlanMantenimiento/Ver`; últimas órdenes y avisos enlazados.
  - Cargar *Mantenimiento* y *Movimientos* **bajo demanda** al abrir la pestaña (acciones parciales),
    no al abrir la ficha.
  - Contador en cada pestaña: *Componentes (3)*, *Planes (2)*…
- **Aceptación**:
  - [ ] Desde la ficha se llega a un plan, una orden o un componente en un clic.
  - [ ] Abrir la ficha no consulta órdenes ni avisos hasta abrir esa pestaña.
- **Esfuerzo** L · **Riesgo** MEDIO (consultas nuevas) · **Ref.** `MNT-023` (carga del detalle)

#### [x] EU-09 · Ficha de ubicación útil

- **Hoy**: 6 campos en sólo lectura; faltan *Mantenible*, *Orden*, qué contiene y qué planes tiene.
- **Archivos**: `Ubicacion/Ver.cshtml`, `Ubicacion.Controller.cs`.
- **Hacer**:
  - Migas de pan con la ruta de ubicaciones y badges *Activo*, *Mantenible*.
  - Secciones: *Sub-ubicaciones* (directas, enlazadas), *Equipos montados* (directos, enlazados, con
    estado), *Planes asignados* (sólo si es mantenible), últimas órdenes y avisos.
  - Botones *Editar*, *Nueva sub-ubicación* (abre `Nuevo` con la superior preseleccionada) y *Ver en
    el árbol*.
- **Aceptación**:
  - [ ] Una ubicación sin contenido muestra estados vacíos con la acción correspondiente.
  - [ ] *Nueva sub-ubicación* llega a `Nuevo` con la superior ya elegida.
- **Esfuerzo** M · **Riesgo** BAJO

#### [x] EU-10 · Columnas útiles en las listas

- **Hoy**: `Equipo/Index` usa 3 columnas para ubicación y equipo superior, y no dice nada del
  mantenimiento. `Ubicacion/Index` no muestra ni permite filtrar *Mantenible*.
- **Archivos**: ambas `Index`, controladores y repositorios de `Equipo` y `Ubicacion`.
- **Hacer**:
  - Equipos: una columna *MONTADO EN* (`[UB] código` o `[EQ] código`, enlazada, o badge rojo *No
    montado*); columna *PLANES* con nº de asignaciones y bloqueadas en rojo.
  - Ubicaciones: columna y filtro *MANTENIBLE*; columnas *SUB-UB.* y *EQUIPOS* (directos).
  - Conteos con **consultas agrupadas por página**, como `PlanMantenimientoRepositorio.ResumirAsync`.
- **Aceptación**:
  - [ ] Sin consultas por fila (verificar con el log de EF Core).
  - [ ] Un equipo activo no montado con planes se distingue en la lista.
- **Esfuerzo** M · **Riesgo** MEDIO (rendimiento) · **Ref.** `MNT-047` (mismo enfoque)

#### [x] EU-11 · Navegación entre lista, ficha, edición y árbol

- **Hoy**: *Regresar* y el redirect tras guardar siempre van a `Index`; `Nuevo` no lleva a la ficha
  creada; en el árbol el código de una ubicación no enlaza.
- **Archivos**: `Equipo/{Nuevo,Editar,Ver}`, `Ubicacion/{Nuevo,Editar,Ver}`,
  `ArbolJerarquico/_Generar.cshtml`, `ArbolJerarquico/Index.cshtml`.
- **Hacer**:
  - Tras crear o guardar, ir a la **ficha** (el POST ya devuelve el `Id`).
  - Mismo encabezado (EU-07 / EU-09) en `Editar`, con *Ver* como acción.
  - En el árbol, enlazar el código de ubicación a `Ubicacion/Ver`; aceptar `?expandir=u_N|e_N` para
    abrir el árbol en un nodo.
- **Aceptación**:
  - [ ] Desde cualquier pantalla de un equipo se llega a las otras y al árbol en un clic.
- **Esfuerzo** S · **Riesgo** BAJO · **Ref.** `MNT-037`

#### [x] EU-21 · El árbol muestra los inactivos, atenuados y sin acciones

- **Hoy**: `ArbolJerarquico.Controller.cs:33-34` lista sólo ubicaciones y equipos **activos**. Un
  equipo inactivo montado desaparece con todos sus componentes —aunque estén activos—, así que el
  árbol no refleja la planta real.
- **Objetivo** (`DE-02`, resuelta): verlo todo, distinguiendo lo inactivo y **sin poder abrir trabajo
  sobre ello**.
- **Archivos**: `ArbolJerarquico.Controller.cs`, `ArbolJerarquico/_Generar.cshtml`,
  `ArbolJerarquico/Index.cshtml`, `wwwroot/css/site.css`.
- **Hacer**:
  - Listar ubicaciones y equipos sin filtrar `Activo`.
  - Fila inactiva en gris atenuado (clase `.arbol-inactivo`), con badge *INACTIVO* y `title` que lo
    explique. El color es la única diferencia: la fila sigue siendo navegable y desplegable.
  - **Quitar** de esas filas los enlaces *Nueva orden de trabajo* y *Nuevo aviso*; mantener *Ver
    ficha* y el resto de la navegación.
  - En las ubicaciones, mantener además la regla vigente: sin `Mantenible` no hay aviso ni orden
    (`_Generar.cshtml:47`).
  - Interruptor *Mostrar inactivos* en la cabecera del árbol, activado por defecto, que recuerda la
    elección del usuario.
  - Que el buscador del árbol siga encontrando los nodos inactivos.
- **Aceptación**:
  - [ ] Un componente activo bajo un equipo inactivo se ve en el árbol.
  - [ ] Una fila inactiva no ofrece crear aviso ni orden de trabajo, ni por enlace directo.
  - [ ] Montar y desmontar siguen funcionando igual sobre las filas activas.
- **Esfuerzo** M · **Riesgo** BAJO

---

### FASE 2 — Proteger el trabajo y avisar consecuencias

#### [x] EU-12 · Avisar al desactivar

- **Hoy**: desmarcar *Activo* no dice nada. Un equipo inactivo deja de generar órdenes
  (`BR-GE-007`); una ubicación inactiva deja de generar. Tras EU-21 siguen viéndose en el árbol, pero
  ya no admiten avisos ni órdenes.
- **Archivos**: `Equipo/Editar.cshtml`, `Ubicacion/Editar.cshtml`, controladores.
- **Hacer**: al desmarcar *Activo*, advertencia en línea con los números concretos:
  *N planes dejarán de generar órdenes*, *M componentes / equipos montados*, *K sub-ubicaciones
  activas*, y que dejará de aceptar avisos y órdenes nuevas, con enlace a la ficha para revisarlos.
  Sin bloquear. Mismo aviso al desmarcar *Mantenible* en una ubicación con planes (EU-22).
- **Aceptación**:
  - [ ] Los números de la advertencia coinciden con la ficha.
- **Esfuerzo** M · **Riesgo** BAJO

#### [x] EU-22 · Una ubicación no mantenible deja de generar, y el plan dice por qué

- **Hoy** (`DE-04`, resuelta): la generación de ubicaciones sólo filtra `Activo`
  (`PlanMantenimiento.Logica.cs:307`), así que una ubicación **no mantenible** con planes asignados
  sigue generando órdenes, en contra de lo que significa el campo. Y `Asignar` sólo explica el caso
  *Ubicación inactiva* (`PlanMantenimientoUbicacion.Controller.cs:152-153`).
- **Objetivo**: que *Mantenible* signifique lo mismo en todas partes y que el plan diga siempre por
  qué un objeto técnico no va a generar.
- **Archivos**: `AMSYS.Logicas/Gestion/PlanMantenimiento.Logica.cs`,
  `PlanMantenimientoUbicacion.Controller.cs`, `PlanMantenimientoEquipo.Controller.cs`,
  `PlanMantenimiento/{Asignar,Ver}.cshtml`.
- **Hacer**:
  - Añadir `&& x.Mantenible` al filtro de ubicaciones de la generación. Es el **único punto** donde se
    seleccionan ubicaciones para generar, así que la previsualización queda coherente sola.
  - Completar `Habilitado` / `Motivo` de ubicaciones con los motivos: *Ubicación inactiva*,
    *Ubicación no mantenible*, *Asignación bloqueada*, *Plan inactivo*; y añadir a equipos los que
    faltan (*Asignación bloqueada*, *Plan inactivo*) junto a los actuales.
  - Mostrarlos en `Asignar` y en `Ver` con el badge y el `title` que ya usa `Asignar.cshtml:214-216`,
    más un resumen *N no generarán órdenes* sobre la tabla.
- **Aceptación**:
  - [ ] Una ubicación no mantenible con plan no aparece en la previsualización ni genera órdenes.
  - [ ] Cada fila que no vaya a generar dice el motivo, sin abrir otra pantalla.
  - [ ] Ningún cambio en la generación de equipos.
- **Esfuerzo** M · **Riesgo** MEDIO (cambia la generación de órdenes) · **Ref.** `MNT-040`, `BR-GE-004`
- **Nota**: cambio de comportamiento. Antes de desplegar, listar las ubicaciones no mantenibles con
  planes asignados; son las que dejarán de generar.

#### [x] EU-13 · Cambiar la clase de equipo sin perder datos técnicos

- **Hoy**: cambiar la clase reemplaza el bloque de datos técnicos por campos vacíos; al guardar se
  borran los anteriores.
- **Archivos**: `Equipo/Nuevo.cshtml`, `Equipo/Editar.cshtml`.
- **Hacer**:
  - Si algún dato técnico tiene valor, confirmar (SweetAlert) enumerando los que se perderán.
  - Conservar el valor de los datos técnicos que existan en ambas clases (mismo `DatoTecnicoId`).
  - Si se cancela, restaurar la clase anterior.
- **Aceptación**:
  - [ ] Cambiar de clase con datos escritos pide confirmación; sin datos, no molesta.
- **Esfuerzo** S · **Riesgo** BAJO

#### [x] EU-14 · Barra fija, cambios sin guardar y confirmaciones

- **Hacer** (patrón de PM-08, PM-09 y HS-10), en los cuatro formularios:
  - *Guardar* / *Regresar* en `.barra-acciones`; quitar la confirmación de *Guardar*; mensaje de
    éxito que nombre la operación real.
  - Indicador y aviso de cambios sin guardar, incluidos archivos subidos a Dropzone.
  - *Regresar* como `btn-secondary`; `closest('tr')` en lugar de `parents().eq(1)`.
  - Quitar el código muerto de `#tblComponentes` en `Equipo/Editar`.
- **Aceptación**:
  - [ ] Salir con cambios pendientes pide confirmación.
  - [ ] Guardar es un clic.
- **Esfuerzo** M · **Riesgo** BAJO · **Ref.** `MNT-042`, `MNT-045`

#### [x] EU-15 · Errores en el campo, la fila y la pestaña

- **Hoy**: la clave `Descripcion` no corresponde a ningún campo; el mensaje de datos técnicos dice
  siempre «nro. 1»; los errores de materiales no marcan la fila ni la pestaña.
- **Hacer** (patrón de PM-10 y HS-11):
  - Validación en cliente de cabecera y materiales (cantidad > 0).
  - Claves `Nombre`, `Materiales[i].Cantidad`… y respuesta JSON estructurada; corregir el contador `i`.
  - Marcar campo o fila, activar la pestaña del primer error y marcar las demás con punto rojo.
- **Aceptación**:
  - [ ] Un error en *Materiales* se ve aunque el usuario esté en *Datos generales*.
- **Esfuerzo** M · **Riesgo** BAJO · **Ref.** `MNT-043`

#### [x] EU-16 · Explicar los campos con consecuencias

- **Hoy**: *¿Es item mantenible?*, *Orden*, *Horas por día* y los días de la semana no dicen para
  qué sirven. `Nuevo` marca *Ubicación Superior* como obligatoria (`(*)`) pero permite *RAIZ*.
- **Archivos**: `Ubicacion/{Nuevo,Editar}.cshtml`, `Equipo/{Nuevo,Editar}.cshtml`.
- **Hacer**:
  - *Mantenible*: texto de ayuda — *sólo las ubicaciones mantenibles pueden recibir planes, avisos y
    órdenes de trabajo*; tras EU-22, desmarcarlo **detiene la generación** de los planes que ya tenga
    asignados, y así debe decirlo la advertencia.
  - *Orden*: `type="number"`, ayuda *posición entre las ubicaciones del mismo nivel en el árbol*.
  - *Parámetros de operación*: ayuda y resultado calculado en vivo, *≈ X h/día de promedio*
    (misma fórmula que `Equipo.CalcularHorasPorDia`, mostrada sólo como referencia).
  - Quitar el `(*)` de *Ubicación Superior*.
- **Aceptación**:
  - [ ] Cada campo con efecto fuera del formulario lo explica antes de guardar.
- **Esfuerzo** S · **Riesgo** BAJO

#### [x] EU-17 · Adjuntos honestos

- **Hoy**: en `Equipo/Editar` eliminar un adjunto usa `confirm()`/`alert()` y **borra en el servidor
  al instante**, aunque luego no se guarde.
- **Hacer** (patrón de HS-15): SweetAlert que diga que el borrado es inmediato y no se deshace al
  salir sin guardar; contador de adjuntos en la pestaña.
- **Esfuerzo** S · **Riesgo** BAJO · **Ref.** `MNT-014` (diferir el borrado)

---

### FASE 3 — Vocabulario y códigos

#### [x] EU-18 · Mismos nombres en las tres pantallas del equipo

- **Hacer**:
  - Pestañas idénticas en `Nuevo`, `Editar` y `Ver`: *Datos generales* · *Materiales y sistemas* ·
    *Datos técnicos* · *Adjuntos* (+ las de consulta de EU-08 en `Ver`).
  - Contador en cada pestaña de edición: *Materiales y sistemas (5)*, *Datos técnicos (3/8)*
    (con valor / total).
  - Títulos de página con el objeto: *Editar equipo · [CÓDIGO] Nombre*.
- **Aceptación**:
  - [ ] La misma información tiene el mismo nombre en las tres vistas.
- **Esfuerzo** S · **Riesgo** BAJO

#### [x] EU-19 · Alerta de código duplicado (no bloqueante)

- **Requisito del propietario** (`D-03`): el duplicado es válido; se avisa, **nunca** se bloquea.
- **Hacer**: `BuscarCodigo` en `Equipo` y `Ubicacion` (filtrando empresa, `excluirId` al editar) y
  `helper.codigoDuplicado` con enlace a la ficha del registro existente. Ámbito: empresa.
- **Esfuerzo** S · **Riesgo** BAJO · **Ref.** `MNT-048`, HS-16 (reutilizar
  `[FiltroAccion(Accion = "Index")]`)

---

### FASE 4 — Consistencia visual

#### [x] EU-20 · Color semántico y móvil

- **Hoy**: materiales, sistemas, componentes, adjuntos y movimientos usan `bg-warning`; los
  parámetros usan `bg-primary`. Los siete checkboxes de días se aprietan en una fila en móvil; las
  tablas usan `width` en píxeles.
- **Hacer**:
  - Convención de `site.css`: azul para configuración, verde para asignaciones (planes), ámbar sólo
    para advertencias.
  - `.tabla-apilable` con `data-label` en materiales y sistemas.
  - Días de la semana como grupo de botones conmutables que se ajusta a dos filas.
- **Aceptación**:
  - [ ] A 768 px se puede completar un equipo sin scroll horizontal.
- **Esfuerzo** M · **Riesgo** BAJO

---

## 6. Orden recomendado

| Orden | Paso | Esfuerzo | Riesgo | Por qué en este orden |
|-------|------|----------|--------|-----------------------|
| 1 | **EU-01** Tipo de equipo | S | BAJO | Cada guardado borra un dato |
| 2 | **EU-02** Valores inactivos | S | BAJO | Misma familia: pérdida silenciosa |
| 3 | **EU-03** Ciclos de ubicaciones | S | BAJO | Corrompe el árbol |
| 4 | EU-04 Pantallas que engañan | S | BAJO | Arreglos de una línea |
| 5 | EU-05 Organización obligatoria | S | BAJO | Selección silenciosa |
| 6 | EU-06 Listas y selectores | M | BAJO | Base común; probar los 23 usos del selector |
| 7 | EU-07 Cabecera del equipo | M | BAJO | Enseña el concepto «montado» |
| 8 | EU-11 Navegación | S | BAJO | Aprovecha EU-07 |
| 9 | EU-09 Ficha de ubicación | M | BAJO | |
| 10 | **EU-08** Ficha del equipo | L | MEDIO | El cambio de mayor impacto |
| 11 | EU-10 Columnas en listas | M | MEDIO | |
| 12 | EU-21 Árbol con inactivos | M | BAJO | Cierra el hueco que abre EU-12 al desactivar |
| 13 | **EU-22** Mantenible deja de generar | M | MEDIO | Cambia comportamiento: antes de que EU-12 y EU-16 lo expliquen |
| 14 | EU-12 Avisar al desactivar | M | BAJO | Reutiliza los conteos de EU-08/EU-09 |
| 15 | EU-13 Clase y datos técnicos | S | BAJO | |
| 16 | EU-14 Barra y cambios sin guardar | M | BAJO | |
| 17 | EU-15 Errores localizados | M | BAJO | |
| 18 | EU-16 Campos explicados | S | BAJO | El texto de *Mantenible* depende de EU-22 |
| 19 | EU-17 Adjuntos | S | BAJO | |
| 20 | EU-18 Vocabulario | S | BAJO | |
| 21 | EU-19 Código duplicado | S | BAJO | Requisito del propietario |
| 22 | EU-20 Color y móvil | M | BAJO | |

> [!CAUTION]
> **EU-06 toca selectores usados en 23 lugares** (Árbol, Aviso, Orden de Trabajo, Plan, Contador…).
> Antes de cerrarlo, abrir cada selector desde al menos Árbol Jerárquico, Aviso/Nuevo y
> OrdenTrabajo/Nuevo y confirmar que el *callback* recibe el mismo objeto.

## 7. Decisiones del propietario 🟢 RESUELTAS (2026-09-17)

| Id | Pregunta | Decisión | Afecta a |
|----|----------|----------|----------|
| `DE-01` | Por el error de EU-01, los equipos guardados desde `Editar` tienen el **Tipo de Equipo en blanco**. ¿Se revisan? | **No.** Quedan en `null`; se corrigen a mano al editar cada equipo. En el formulario, el identificador guardado **se mantiene hasta que el usuario lo elimine**. | EU-01, EU-02 |
| `DE-02` | El Árbol Jerárquico oculta equipos y ubicaciones **inactivos**, y con ellos todo lo que cuelga debajo. | **Mostrarlos**, con otro color, y **sin** los enlaces de nuevo aviso ni nueva orden de trabajo. | EU-21 (paso nuevo) |
| `DE-03` | Antes de EU-03: ¿existen ya ciclos de ubicaciones en producción? | **Hay que revisarlo**: la consulta de comprobación y el saneamiento forman parte de EU-03. | EU-03 |
| `DE-04` | Una ubicación que deja de ser **Mantenible** con planes asignados hoy **sigue generando** órdenes (`PlanMantenimiento.Logica.cs:307`). ¿Es lo deseado? | **No.** Debe dejar de generar, y el plan debe indicar el **motivo** por el que una ubicación ya no genera órdenes. | EU-22 (paso nuevo), EU-16 |

## 8. Fuera de alcance, con referencia

- `EquipoLogica.MontarAsync` busca los equipos por `Id` **sin filtrar empresa**, y `Desmontar` no la
  valida: equivalente a `MNT-021` para el árbol; abrir tarea de seguridad aparte.
- Montar un equipo ya montado en otro sitio lo mueve sin registrar el desmontaje previo en el
  historial (el selector hoy lo evita con `Montado = false`, pero el servidor no).
- Desbloquear asignaciones desde la ficha del equipo: `MNT-005` (EU-08 sólo lo muestra).
- Borrado diferido de adjuntos: `MNT-014`.

## 9. Cómo verificar cada paso

1. `dotnet build AMSYS.sln` sin nuevos avisos.
2. Probar con: un equipo **montado en ubicación**, un **componente** (montado en otro equipo), un
   equipo **no montado** y uno **inactivo** con componentes activos; una ubicación **raíz**, una de
   tercer nivel, una **inactiva** y una **no mantenible con plan asignado** (EU-21 y EU-22).
3. Abrir y guardar sin cambios, y comparar el registro en base de datos antes y después (EU-01/EU-02).
4. Recorrer los selectores desde Árbol Jerárquico, Aviso y Orden de Trabajo.
5. Consola del navegador sin errores.

## 10. Registro de avance

| Paso | Estado | Fecha | Commit | Notas |
|------|--------|-------|--------|-------|
| EU-01 | APLICADO | 2026-09-17 | | `asp-items` del tipo + el tipo guardado se conserva al cambiar de clase, con aviso; estado *Cargando…* y error en `Nuevo` y `Editar`. Falta verificar en navegador |
| EU-02 | APLICADO | 2026-09-17 | | `ConservarSeleccionAsync` en ambos controladores; marca *(INACTIVO)* o *(SIN ACCESO)*. La superior sólo se recupera si no es descendiente. Falta verificar en navegador |
| EU-03 | APLICADO | 2026-09-17 | | Se excluyen todos los descendientes y se valida en `Editar` y `Nuevo` (POST). **Falta ejecutar la consulta de ciclos en producción** |
| EU-04 | APLICADO | 2026-09-17 | | `Ubicacion/Ver` muestra la superior real o RAIZ; filtros de equipo superior corregidos; RAIZ visible; filtros fantasma quitados. Falta verificar en navegador |
| EU-05 | APLICADO | 2026-09-17 | | Opción SELECCIONE; con una sola organización se preselecciona. Falta verificar en navegador |
| EU-06 | APLICADO | 2026-09-17 | | Dos listas con panel de filtros y *Más filtros*; cuatro selectores con carga/vacío y datos en `data-*`. Quitado el `@@using DocumentFormat…` y el `filtro.Montado: false` fijo de `Equipo/_SeleccionarUno`. **Falta probar los 23 puntos que abren los selectores** |
| EU-07 | APLICADO | 2026-09-17 | | Parcial `_EncabezadoEquipo`: ruta de montaje enlazada, estado y motivo por el que genera o no mantenimiento. Falta verificar en navegador |
| EU-08 | APLICADO | 2026-09-17 | | Pestañas de datos técnicos, mantenimiento y movimientos; componentes enlazados. Mantenimiento y movimientos se cargan al abrir la pestaña (`Equipo/Mantenimiento` y `Equipo/Movimientos`). Falta verificar en navegador |
| EU-09 | APLICADO | 2026-09-17 | | Ficha con ruta, estado, sub-ubicaciones, equipos montados, planes, últimas órdenes y avisos; `Nuevo?ubicacionPadreId=`. Falta verificar en navegador |
| EU-10 | APLICADO | 2026-09-17 | | `ResumirAsync` en Equipo (2 consultas) y Ubicación (3) por página, sólo con `conResumen=true`. Equipos: columna MONTADO EN, COMPON., PLANES y BLOQUEADOS. Ubicaciones: SUB-UB., EQUIPOS, PLANES y MANTENIBLE (con filtro). Falta verificar en navegador |
| EU-11 | APLICADO | 2026-09-17 | | Encabezado también en Editar; tras guardar se va a la ficha; el árbol acepta `?expandir=u_N|e_N` (validado con expresión regular) y el código de ubicación enlaza a su ficha. Falta verificar en navegador |
| EU-12 | APLICADO | 2026-09-17 | | Aviso al desmarcar Activo con los conteos reales, y al desmarcar Mantenible. Falta verificar en navegador |
| EU-13 | APLICADO | 2026-09-19 | | Al cambiar la clase se conservan los datos técnicos comunes (mismo `DatoTecnicoId`); si alguno con valor no existe en la nueva, SweetAlert los enumera y al cancelar vuelve la clase anterior. Nuevo y Editar. Falta verificar en navegador |
| EU-14 | APLICADO | 2026-09-19 | | Barra fija `.barra-acciones` en los cuatro formularios, Guardar sin confirmación, indicador y aviso de cambios sin guardar (incluye Dropzone), Regresar `btn-secondary` (Editar vuelve a la ficha; Nueva sub-ubicación vuelve a la superior), `closest('tr')`, quitado `#tblComponentes`. Falta verificar en navegador |
| EU-15 | APLICADO | 2026-09-19 | | `ErrorDeValidacion()` con respuesta JSON en ambos controladores; claves `Nombre`, `Materiales[i].Cantidad`, `DatosTecnicos[i].DatoTecnicoId` y numeración real (`ValidarDetalle`). Validación en cliente, marca de campo/fila/select2, pestaña del primer error y punto rojo en las demás. Falta verificar en navegador |
| EU-16 | APLICADO | 2026-09-19 | | Ayuda de *Mantenible* (y efecto al desmarcar en Editar), *Orden* `type="number"` con ayuda, *Parámetros de operación* con promedio en vivo; quitado el `(*)` de Ubicación Superior. Falta verificar en navegador |
| EU-17 | APLICADO | 2026-09-19 | | SweetAlert que advierte que el borrado es inmediato; contador de adjuntos en la pestaña (guardados + subidos). Falta verificar en navegador |
| EU-18 | APLICADO | 2026-09-19 | | Pestañas *Datos generales · Materiales y sistemas (N) · Datos técnicos (x/y) · Adjuntos (N)* en Nuevo, Editar y Ver (en Ver, seguidas de las de consulta); títulos *Editar equipo · [CÓDIGO] Nombre*. Falta verificar en navegador |
| EU-19 | APLICADO | 2026-09-19 | | `BuscarPorCodigoAsync` (repositorio, lógica, servicio) y `BuscarCodigo` con `[FiltroAccion(Accion = "Index")]` en Equipo y Ubicación; aviso con enlace a la ficha, ámbito empresa, `excluirId` al editar. Falta verificar en navegador |
| EU-20 | APLICADO | 2026-09-19 | | Cabeceras azules (configuración) en materiales, sistemas y adjuntos; verdes en planes asignados. `.tabla-apilable` con `data-label`, días como botones conmutables (`.dias-semana`, 4 + 3 en móvil), anchos en % en lugar de px. Falta verificar a 768 px |
| EU-21 | APLICADO | 2026-09-17 | | El árbol ya no filtra por activo: filas atenuadas con `.arbol-inactivo`, sin acciones de aviso ni OT, e interruptor *Mostrar inactivos* recordado en el navegador. Falta verificar en navegador |
| EU-22 | APLICADO | 2026-09-17 | | `Mantenible` añadido al filtro de generación (`PlanMantenimiento.Logica.cs`). Motivos completos (inactivo, no mantenible, plan inactivo, bloqueado) en `Asignar` y en `Ver`. **Cambia comportamiento: listar antes las ubicaciones no mantenibles con planes** |
