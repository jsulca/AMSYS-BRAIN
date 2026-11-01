# Plan de mejora – Módulo de Logística

> Documento **ejecutable paso a paso**, con la misma mecánica que `legacy/planes/PLAN-UX-PLANMANTENIMIENTO.md`,
> `legacy/planes/PLAN-UX-HOJARUTA-SECCION.md`, `legacy/planes/PLAN-UX-EQUIPO-UBICACION.md` y `legacy/planes/PLAN-UX-ADMINISTRACION.md`: cada paso
> es pequeño, verificable y reversible por sí solo. Marca la casilla al terminarlo y anótalo en el
> *Registro de avance* del final.

- **Alcance**: el área `Areas/Logistica` completa — 6 controladores: **Almacén** (catálogo en modal),
  **Stock** (`AlmacenMaterial`: existencias, punto de reposición y selector), **Nota de entrada**,
  **Nota de salida**, **Hoja de aceptación** y **Kardex** (`Movimiento`); más sus lógicas y
  repositorios, y el cálculo de costo de la orden de trabajo en lo que depende de Logística.
- **Fuera de alcance**: el resto de Gestión (salvo el costo de la OT, LG-01), los permisos de los POST
  (misma decisión que `DA-04`), CSRF (`MNT-035`) y las plantillas Excel de exportación.
- **Fecha**: 2026-09-19 · **Decisiones `DL-01` … `DL-05` resueltas el 2026-09-19** (sección 7)
- **Relación con AMSYS-BRAIN**: reutiliza lo construido en `legacy/planes/PLAN-UX-ADMINISTRACION.md` (`helper.catalogo`,
  `RespuestaValidacion`, `IUsoCatalogo`) y referencia las tareas `MNT-NNN` cuando existen.

---

## 1. Qué es el módulo y qué tiene que transmitir

Logística lleva el **inventario valorizado** de materiales por almacén y el costo de materiales y
servicios de las órdenes de trabajo:

```
Nota de entrada (compra, ajuste, traslado) ──► +stock del almacén, lote con precio unitario
Nota de salida  (salida, ajuste, traslado)  ──► −stock, consume lotes por antigüedad (FIFO) ──► costo de la OT
Hoja de aceptación (servicios de un socio)  ──────────────────────────────────────────────► costo de la OT
Anular una nota ──► genera la nota contraria (NS de anulación / NE de anulación) y recalcula la OT
Cada movimiento ──► Kardex: inicial · entrada · salida · final, en cantidad y valor
```

La interfaz tiene que dejar claro, en cada documento: **qué stock mueve, a qué costo, contra qué OT, y
qué pasa si se anula**.

Hechos verificados que condicionan el diseño:

| Hecho | Evidencia | Consecuencia |
|-------|-----------|--------------|
| El costo de materiales de la OT multiplica **dos veces** por la cantidad: en la nota de salida `Precio` ya es el **total** de la línea, pero el costo suma `Cantidad * Precio` | `NotaSalida.Logica.cs:163` (`item.Precio = precioTotal`), `NotaSalidaMaterial.Adicional.cs` (`PrecioUnitario = Precio / Cantidad`), `NotaSalidaMaterial.Repositorio.cs:12` (`Sum(x => x.Cantidad * x.Precio)`) | 5 unidades a 10 cuestan 250 en la OT en lugar de 50. La ficha de la OT suma bien (`OrdenTrabajo/Ver.cshtml:1098`), así que **el detalle y el total de la OT no cuadran** |
| Almacén, material, OT, socio de negocio, servicio y nota de salida llegan del cliente y **no se comprueba que sean de la empresa** | `NotaEntrada/NotaSalida/HojaAceptacion.Controller.cs` (`Validar` sólo mira `> 0`) | Se puede dejar stock en un almacén ajeno o **recalcular y cargar costos a la OT de otra empresa** (`CalcularAsync(ordenTrabajoId)`) — mismo caso que `MNT-022` |
| El tipo de nota lo elige el usuario entre **todos** los valores, incluidos *Anulación de NE / NS* | `Nuevo.cshtml` (`GetEnumSelectList`), `Controller.Validar` (`Tipo < 0`) | Se pueden crear a mano notas «de anulación» que no anulan nada |
| Se ofrece **Anular** en cualquier nota no anulada, también en las generadas por una anulación y en la salida de un traslado cuya entrada ya se registró | `NotaEntrada/NotaSalida/Index.cshtml` (`!anulado`), `NotaSalida.Logica.AnularAsync` | Anular una anulación vuelve a mover el stock; anular la salida de un traslado **duplica** el material (vuelve al origen y sigue en el destino) |
| Una nota de salida de un material **sin fila de stock** hace fallar el servidor | `NotaSalida.Controller.cs:179` (`item.Material!` es nulo: el POST sólo trae ids) | Error 500 en lugar del mensaje «no tiene cantidades disponibles» |
| La existencia se valida en el controlador y se descuenta en la lógica, **sin transacción ni bloqueo**; el correlativo es `CountBy(...) + 1` | `NotaSalida.Controller.Nuevo`, `NotaSalida.Logica.cs:70`, `NotaEntrada.Logica.cs:57`, `HojaAceptacion.Logica.cs:68` | Dos salidas simultáneas pueden dejar **stock negativo**; dos documentos del mismo mes pueden recibir **el mismo código** |
| La entrada de **traslado** exige `NotaSalidaId`, pero el formulario no tiene ese campo | `NotaEntrada/Nuevo.cshtml:126` (`$('#NotaSalidaId')` no existe) | Un traslado entre almacenes **no se puede completar** desde la aplicación → `DL-02` |
| Filtros de las listas que el servidor no tiene | Vistas `Index` vs `*Filtro.cs`: *Comprobante*, *NS/NE origen*, *Usuario*, *OT* | Filtrar por ellos no hace nada |
| El botón *Reposición* de la lista de stock lleva a una acción que **no existe** | `AlmacenMaterial/Index.cshtml:16` → `/Logistica/AlmacenMaterial/Reposicion` | 404 |
| El kardex sólo filtra por almacén | `Movimiento/Index.cshtml:87`, `MovimientoFiltro` | No se puede ver el kardex de **un material** ni de un periodo |

## 2. Pantallas afectadas

| Pantalla | Archivos | Patrón actual |
|----------|----------|---------------|
| Almacenes | `Almacen/{Index,_Nuevo,_Editar}` | Catálogo en modal, patrón antiguo |
| Stock | `AlmacenMaterial/{Index,_Editar,_Seleccionar}` | Lista con punto de reposición; selector usado por la nota de salida |
| Notas de entrada | `NotaEntrada/{Index,Nuevo,Ver}` | Lista con *Anular*, formulario con materiales por almacén |
| Notas de salida | `NotaSalida/{Index,Nuevo,Ver}` | Ídem, con OT opcional |
| Hojas de aceptación | `HojaAceptacion/{Index,Nuevo,Ver}` | Servicios de un socio de negocio, con OT opcional |
| Kardex | `Movimiento/Index` | Lista y exportación a Excel |

## 3. Diagnóstico corto

1. **🔴 Costos de OT inflados** por la doble multiplicación de las notas de salida (sección 1).
2. **🔴 Datos de otras empresas**: claves foráneas sin validar; costos cargados a OT ajenas.
3. **🔴 Inventario que se descuadra**: anulaciones que no deberían permitirse, tipos de anulación
   creados a mano, stock negativo por concurrencia, códigos repetidos.
4. **🔴 Error 500** al retirar un material sin fila de stock.
5. **Flujos imposibles o rotos**: traslado sin forma de indicar la salida de origen; botón
   *Reposición* a una página inexistente; filtros que no filtran; kardex sin filtro por material.
6. **Formularios sin red de seguridad**: `confirm()` / `alert()` en 6 vistas, *Regresar* ámbar sin
   aviso de cambios, errores en un bloque con claves `Materiales_Cantidad` que no marcan la fila, sin
   totales en vivo, tras guardar vuelve a la lista en lugar de a la ficha.
7. **Consecuencias invisibles**: anular no explica que genera una nota contraria, que devuelve o retira
   stock ni que recalcula la OT; la salida no muestra el costo que va a cargar.
8. **Vocabulario del precio incoherente**: en la entrada `Precio` es unitario, en la salida es total;
   las pantallas lo rotulan distinto (*PRECIO*, *PRECIO UNIT.*, *PRECIO TOT.*).
9. **Listas en el patrón antiguo** (filtros en el `<thead>`, sin escapado, sin estado de carga, sin
   badge de tipo ni de estado) y cabeceras `bg-warning` en 5 vistas.

## 4. Principios

- Los de los planes anteriores y **lo ya construido en Administración**: `helper.catalogo.lista` /
  `modal`, `RespuestaValidacion` (errores con clave de campo, `callBack` validado), `helper.filtros`,
  `.barra-acciones`, `.tabla-apilable`, convención de color.
- **El stock sólo se mueve con documentos**: no se edita la cantidad a mano; cualquier corrección es una
  nota de ajuste o una anulación, y queda en el kardex.
- **Toda operación de stock es atómica**: validar y descontar dentro de la misma transacción.
- **Los selectores son contratos compartidos** (`AlmacenMaterial/_Seleccionar`, `OrdenTrabajo/SeleccionarUno`).
- Un paso = un commit.

---

## 5. Pasos

### FASE 0 — Datos que hoy se corrompen

#### [x] LG-01 · Costo de la nota de salida en la OT

- **Hoy**: `NotaSalidaMaterialRepositorio.CostoPorOrdenTrabajo` suma `Cantidad * Precio`, pero `Precio`
  ya es el total de la línea.
- **Archivos**: `NotaSalidaMaterial.Repositorio.cs`; script de recálculo según `DL-03`.
- **Hacer**:
  - Sumar `Precio` (total de la línea), igual que la ficha de la OT.
  - Recalcular `OrdenTrabajoCosto` de las OT con notas de salida (según `DL-03`), con una consulta
    previa que liste las OT afectadas y la diferencia antes / después.
- **Aceptación**:
  - [ ] Una salida de 5 unidades a 10 carga 50 a la OT.
  - [ ] El total de materiales de la OT coincide con la suma de su pestaña de notas de salida.
- **Esfuerzo** S · **Riesgo** MEDIO (cambia costos ya reportados) · **Prioridad**: la más alta del plan

#### [x] LG-02 · Claves foráneas de la empresa

- **Hoy**: almacén, material, OT, socio, servicio y nota de salida de origen sólo se validan `> 0`.
- **Archivos**: `NotaEntrada`, `NotaSalida`, `HojaAceptacion` (controladores).
- **Hacer**:
  - Un método de validación por documento que cargue los ids recibidos filtrando por empresa y marque
    `Materiales[i].AlmacenId`, `Materiales[i].MaterialId`, `OrdenTrabajoId`, `SocioNegocioId`,
    `Servicios[i].ServicioId`, `NotaSalidaId` si alguno no existe.
  - `CalcularAsync` sólo después de validar la OT.
  - Las búsquedas de `Anular` (`BuscarPorIdAsync(new() { Id })`) también con empresa.
- **Aceptación**:
  - [ ] Un POST con el almacén o la OT de otra empresa devuelve error de validación y no mueve stock
    ni recalcula nada.
- **Esfuerzo** M · **Riesgo** BAJO · **Ref.** `MNT-022`, AD-02

#### [x] LG-03 · Tipos que el usuario puede elegir

- **Hoy**: el formulario ofrece *Anulación de NE / NS*; el servidor acepta cualquier entero.
- **Hacer**:
  - Ofrecer sólo los tipos manuales: entrada *Compra*, *Ajuste de inventario* (y *Traslado* según
    `DL-02`); salida *Salida de almacén*, *Ajuste de inventario* (y *Traslado*).
  - Servidor: `Enum.IsDefined` y rechazo explícito de los tipos de anulación.
  - Ayuda por tipo: qué stock mueve y qué exige (comprobante en compra, OT opcional en salida).
- **Aceptación**:
  - [ ] Un POST con tipo *Anulación* o fuera de rango devuelve error.
- **Esfuerzo** S · **Riesgo** BAJO

#### [x] LG-04 · Anulaciones coherentes

- **Hacer**:
  - No permitir anular notas de tipo *Anulación* (ni ofrecer el botón).
  - No permitir anular la salida de un traslado si ya tiene entrada registrada (anular primero la
    entrada), y viceversa.
  - La nota contraria generada guarda el `UsuarioId` de quien anula y enlaza con la original.
  - Mensaje de error en lugar de `throw new Exception` (entrada con materiales ya consumidos) y
    respuesta estructurada.
- **Aceptación**:
  - [ ] Ninguna combinación de anulaciones deja el stock distinto al que habría sin los documentos.
- **Esfuerzo** M · **Riesgo** MEDIO

#### [x] LG-05 · Salida de un material sin stock

- **Hoy**: `NotaSalida.Controller.cs:179` usa `item.Material!` (nulo) → error 500; el mensaje tiene un
  `$` de más.
- **Hacer**: cargar código de material y almacén por id para los mensajes; sumar las líneas repetidas
  del mismo almacén y material antes de comparar con la existencia; claves `Materiales[i].Cantidad`.
- **Aceptación**:
  - [ ] Retirar un material sin stock en ese almacén muestra el mensaje en su fila.
- **Esfuerzo** S · **Riesgo** BAJO

#### [x] LG-06 · Stock y correlativos atómicos

- **Hoy**: la validación de existencias y el descuento ocurren en pasos separados, sin transacción;
  el código es `CountBy + 1`.
- **Archivos**: `NotaEntrada/NotaSalida/HojaAceptacion.Logica.cs`, repositorio de `AlmacenMaterial`.
- **Hacer**:
  - Guardar y anular dentro de una transacción; bloquear las filas de `AlmacenMaterial` afectadas
    (`SELECT … FOR UPDATE`) y **volver a validar la existencia dentro de la transacción**.
  - Correlativo con índice único `(EmpresaId, Codigo)` y reintento, o tabla de secuencias por
    empresa / año / mes.
- **Aceptación**:
  - [ ] Dos salidas simultáneas del último stock: una se guarda y la otra recibe el mensaje de
    existencias.
  - [ ] No hay dos documentos con el mismo código.
- **Esfuerzo** M · **Riesgo** ALTO (toca el guardado de todos los documentos; probar con carga)

#### [x] LG-07 · Validación estructurada y `callBack`

- **Hacer**: `RespuestaValidacion.Errores` / `NoEncontrado` en los 6 controladores, claves por fila
  (`Materiales[i].Cantidad`, `Servicios[i].Precio`) y numeración real; `RespuestaValidacion.CallBack`
  en `Almacen`, `AlmacenMaterial` y el selector; `Almacen.ActualizarAsync` → `Task<bool>`.
- **Esfuerzo** S · **Riesgo** BAJO · **Ref.** AD-05, AD-06

---

### FASE 1 — Flujos que no se pueden completar

#### [x] LG-08 · Traslado entre almacenes

- **Hoy**: la salida de traslado se puede registrar, pero la entrada de traslado exige una nota de
  salida que el formulario no permite indicar.
- **Hacer** (según `DL-02`):
  - *Opción recomendada*: documento único **Traslado** (almacén origen → destino) que en una misma
    transacción genera la salida y la entrada enlazadas, trasladando el costo FIFO de la salida como
    precio unitario de la entrada.
  - *Alternativa*: en la entrada de traslado, selector de «salidas de traslado pendientes» que precarga
    materiales, cantidades y costo, y valida que coincidan.
- **Aceptación**:
  - [ ] Un traslado deja el mismo valor total de inventario antes y después.
- **Esfuerzo** L · **Riesgo** MEDIO

#### [x] LG-09 · Punto de reposición

- **Hoy**: el botón *Reposición* lleva a una página que no existe.
- **Hacer**: filtro *Bajo reposición* en la lista de stock (en lugar de una página aparte), badge en la
  fila y contador en el encabezado; exportación con el mismo filtro. Ayuda en el modal: «cantidad
  mínima; por debajo, el material aparece como pendiente de reponer».
- **Esfuerzo** S · **Riesgo** BAJO

#### [x] LG-10 · Filtros que no filtran y kardex por material

- **Hacer**:
  - Añadir al servidor los filtros que las listas ya envían (comprobante, NE / NS de origen, usuario,
    código de OT) o quitarlos de la vista.
  - Kardex: filtros por material, fechas y tipo de documento; orden cronológico por material;
    exportación con los mismos filtros.
- **Esfuerzo** M · **Riesgo** BAJO · **Ref.** AD-08 (mismos filtros fantasma en Administración)

---

### FASE 2 — Listas, formularios y fichas al patrón vigente

#### [x] LG-11 · Listas de documentos

- **Archivos**: `NotaEntrada`, `NotaSalida`, `HojaAceptacion` → `Index`.
- **Hacer**: `helper.catalogo.lista` con panel de filtros y chips; badge de tipo y de estado
  (*Anulada*); columnas *OT* y *documento de origen* enlazadas; total valorizado; acciones *Ver* y
  *Anular* (sólo cuando LG-04 lo permite). *Anular* con SweetAlert que explique la consecuencia:
  «Se generará la NS de anulación, se retirarán N materiales del almacén y se recalculará el costo de
  la OT OT-…».
- **Esfuerzo** M · **Riesgo** BAJO

#### [x] LG-12 · Formularios de nota de entrada, salida y hoja de aceptación

- **Hacer** (patrón de EU-14 / EU-15):
  - Barra fija, sin `confirm()` / `alert()`, indicador y aviso de cambios sin guardar, errores en fila.
  - Totales en vivo: cantidad × precio unitario por línea y total del documento.
  - Salida: existencia disponible y **costo estimado** (FIFO) por línea; cantidad mayor a la existencia
    marcada antes de enviar.
  - Entrada: almacén por línea con opción «aplicar a todas»; precio unitario obligatorio en compra.
  - OT: selector limitado a los estados que permita `DL-05`, con su código y descripción visibles.
  - Tras guardar, ir a la **ficha** del documento.
- **Esfuerzo** L · **Riesgo** BAJO

#### [x] LG-13 · Fichas de documento

- **Hacer**: encabezado con tipo, estado, usuario y fecha; enlaces a la OT, al documento de origen y al
  de anulación; totales; *Anular* desde la ficha con la misma explicación de LG-11.
- **Esfuerzo** S · **Riesgo** BAJO

#### [x] LG-14 · Almacenes y stock

- **Hacer**:
  - Almacenes con `helper.catalogo` (lista y modal), columna *En uso* (materiales con stock,
    movimientos) y desactivación según `DL-04`.
  - Stock: valor total por almacén y de la página, precio unitario promedio, enlace al kardex del
    material, filtro *Con stock*.
- **Esfuerzo** M · **Riesgo** BAJO · **Ref.** AD-07, AD-10

#### [x] LG-15 · Selector de stock

- **Archivos**: `AlmacenMaterial/_Seleccionar.cshtml` (usado por la nota de salida).
- **Hacer**: patrón de AD-09 (carga y vacío, escapado, datos en `data-*`, selección entre páginas),
  sólo filas con existencia, existencia y costo unitario visibles; **sin cambiar** el objeto devuelto.
- **Esfuerzo** S · **Riesgo** MEDIO (contrato compartido)

---

### FASE 3 — Vocabulario y consistencia visual

#### [x] LG-16 · El mismo nombre para el mismo precio

- **Hacer**: rotular siempre *Precio unitario* y *Importe* (cantidad × precio) en entrada, salida,
  stock, kardex, hoja de aceptación y ficha de OT; formato numérico único (2 decimales, separador de
  miles `es-PE`). Documentar en el código que en `NotaSalidaMaterial` y `AlmacenMaterial` `Precio` es
  el importe total.
- **Esfuerzo** S · **Riesgo** BAJO

#### [x] LG-17 · Color y móvil

- **Hacer**: sin `bg-warning` en cabeceras (5 vistas); `.tabla-apilable` con `data-label` en las
  tablas de líneas; totales visibles sin scroll horizontal a 400 px.
- **Esfuerzo** S · **Riesgo** BAJO

---

## 6. Orden recomendado

| Orden | Paso | Esfuerzo | Riesgo | Por qué en este orden |
|-------|------|----------|--------|-----------------------|
| 1 | **LG-01** Costo de la salida en la OT | S | MEDIO | Costos de OT inflados hoy |
| 2 | **LG-02** Claves de la empresa | M | BAJO | Escritura entre empresas |
| 3 | LG-05 Salida sin stock | S | BAJO | Error 500 |
| 4 | LG-03 Tipos elegibles | S | BAJO | Evita documentos falsos |
| 5 | **LG-04** Anulaciones coherentes | M | MEDIO | Descuadres de inventario |
| 6 | **LG-06** Stock y correlativos atómicos | M | ALTO | Stock negativo, códigos repetidos |
| 7 | LG-07 Validación estructurada | S | BAJO | Base de los formularios |
| 8 | LG-08 Traslados | L | MEDIO | Tras `DL-02` |
| 9 | LG-10 Filtros y kardex | M | BAJO | |
| 10 | LG-09 Reposición | S | BAJO | |
| 11 | LG-12 Formularios | L | BAJO | |
| 12 | LG-11 Listas | M | BAJO | |
| 13 | LG-13 Fichas | S | BAJO | |
| 14 | LG-15 Selector de stock | S | MEDIO | Contrato compartido |
| 15 | LG-14 Almacenes y stock | M | BAJO | Tras `DL-04` |
| 16 | LG-16 Vocabulario del precio | S | BAJO | |
| 17 | LG-17 Color y móvil | S | BAJO | |

> [!CAUTION]
> **LG-01 y LG-06 cambian datos de negocio.** Antes de LG-01, obtener la lista de OT afectadas con el
> costo actual y el corregido; antes de desplegar LG-06, probar dos salidas simultáneas sobre el mismo
> stock en un entorno de pruebas.

## 7. Decisiones del propietario 🟢 RESUELTAS (2026-09-19)

| Id | Pregunta | Opciones | Decisión | Afecta a |
|----|----------|----------|----------|----------|
| `DL-01` | El costo de materiales de la OT suma **notas de salida** (almacén, costo FIFO) **y** materiales **notificados** en la OT (precio del catálogo). Si un mismo material se notifica y además sale del almacén, cuenta dos veces. ¿Cuál es la fuente? | a) Sólo notas de salida para materiales de almacén; la notificación queda para materiales sin stock (externos) · b) Notificar un material genera la nota de salida · c) Mantener ambos (hoy) | **c)** Se mantienen ambas fuentes: notas de salida y materiales notificados. | LG-01, LG-12 y Gestión |
| `DL-02` | ¿Cómo se registra un traslado entre almacenes? | a) Documento único *Traslado* que genera salida y entrada juntas (recomendado) · b) Salida de traslado + entrada que la referencia | **a)** Documento único *Traslado* que genera la salida y la entrada juntas. | LG-03, LG-08 |
| `DL-03` | Tras corregir LG-01, ¿se recalculan los costos de las OT ya registradas? | a) Sí, todas, con informe previo de diferencias (recomendado) · b) Sólo las OT abiertas · c) No, sólo desde el despliegue | **a)** Recalcular todas, con informe previo de diferencias. | LG-01 |
| `DL-04` | Los almacenes no se pueden desactivar (no tienen *Activo*). ¿Se añade? | a) Sí, sólo si el almacén no tiene stock (requiere migración) · b) No | **a)** Sí, sólo si el almacén no tiene stock. **La migración se entrega escrita; la aplica el propietario.** | LG-14 |
| `DL-05` | ¿Contra qué OT se pueden registrar notas de salida y hojas de aceptación? | a) Sólo OT no cerradas ni anuladas · b) Cualquier OT (hoy) | **a)** Sólo OT no cerradas ni anuladas. | LG-02, LG-12 |

## 8. Hallazgos durante la ejecución

- La nota de salida no guardaba el `NroComprobante` que el modelo recibía: el campo nunca llegó a la entidad. Ahora el
  formulario no lo ofrece (la salida no tiene comprobante).
- `Movimiento` se ordena por identificador descendente: el kardex se lee de lo más reciente a lo más antiguo, también
  al filtrar por material.
- El bloqueo de inventario usa `pg_advisory_xact_lock`, propio de PostgreSQL; con otro proveedor la operación sigue
  funcionando sin bloqueo (queda documentado en `BloqueoLogistica`).

## 9. Fuera de alcance, con referencia

- Permisos de los POST (`[FiltroAccion]` sólo en los GET): misma decisión que `DA-04`.
- Protección CSRF: `MNT-035`.
- Plantillas Excel de exportación (`wwwroot/reportes`): sólo se ajustan los filtros que reciben.
- Notificación de materiales en la OT (Gestión): depende de `DL-01`.

## 10. Cómo verificar cada paso

1. `dotnet build AMSYS.sln` sin nuevos avisos.
2. Conciliar después de cada paso de la FASE 0: para cada almacén y material, `AlmacenMaterial.Cantidad`
   = suma de entradas − suma de salidas del kardex, y `Precio` = suma de `Disponible × Precio` de sus
   lotes de entrada.
3. Casos: compra, salida con OT, salida sin OT, ajuste, anulación de entrada sin consumo, anulación de
   entrada ya consumida (debe negarse), anulación de salida con OT, traslado, dos empresas.
4. Recorrer el selector de stock desde la nota de salida y el de OT desde salida y hoja de aceptación.
5. Consola del navegador sin errores; ancho de 400 px.

## 11. Registro de avance

| Paso | Estado | Fecha | Commit | Notas |
|------|--------|-------|--------|-------|
| LG-01 | APLICADO | 2026-09-19 | | El costo suma el importe de la línea (`Sum(x => x.Precio)`), como la ficha de la OT. Informe y script de recálculo en `legacy/analisis/lg-01-costo-ot.sql` (DL-03: recalcular todas). **Falta ejecutar el informe y la corrección en la base** |
| LG-02 | APLICADO | 2026-09-19 | | Almacén, material, socio, servicio y OT se validan contra la empresa en las tres altas; `Anular` busca con empresa. DL-05: sólo se admiten OT **emitidas o en cierre técnico** (`ValidacionLogistica`). Falta probar con dos empresas |
| LG-03 | APLICADO | 2026-09-19 | | Los formularios sólo ofrecen los tipos manuales y el servidor rechaza los de anulación y los valores fuera de rango (`Enum.IsDefined`); cada tipo explica qué hace |
| LG-04 | APLICADO | 2026-09-19 | | No se anulan las notas generadas por una anulación; la entrada de un traslado se anula desde su salida; el motivo del rechazo llega como error de validación (`ResultadoOperacionDTO`) en lugar de una excepción; la nota contraria guarda el usuario que anuló |
| LG-05 | APLICADO | 2026-09-19 | | Los mensajes de existencias usan los datos del inventario (el POST sólo trae ids: antes reventaba el servidor) y se suman las líneas repetidas del mismo material y almacén; errores por fila |
| LG-06 | APLICADO | 2026-09-19 | | Guardar y anular ocurren en una transacción con un bloqueo por empresa (`pg_advisory_xact_lock`); la existencia se vuelve a comprobar dentro de la transacción y el correlativo ya no se puede repetir. **Falta probar dos salidas simultáneas** |
| LG-07 | APLICADO | 2026-09-19 | | `RespuestaValidacion` en los 6 controladores (errores con clave de campo y `callBack` validado); `Almacen.ActualizarAsync` devuelve resultado |
| LG-08 | APLICADO | 2026-09-19 | | DL-02: el traslado es un solo documento — la nota de salida de tipo *Traslado* pide almacén destino y el servidor crea la nota de entrada con el mismo costo, en la misma transacción. Anular la salida anula las dos notas |
| LG-09 | APLICADO | 2026-09-19 | | Filtro *Pendientes de reponer* y badge en la lista de stock, con ayuda en el modal; el botón que llevaba a una página inexistente ya no está |
| LG-10 | APLICADO | 2026-09-19 | | Añadidos al servidor los filtros que las listas enviaban (comprobante, documento de origen, OT, socio, usuario) y el kardex filtra por material, fechas, tipo de movimiento y documento; la exportación usa los mismos filtros |
| LG-11 | APLICADO | 2026-09-19 | | Las tres listas con panel de filtros, chips, badge de tipo y estado, enlaces a OT y documento, y *Anular* que explica lo que va a pasar antes de hacerlo |
| LG-12 | APLICADO | 2026-09-19 | | Formularios con barra fija, sin `confirm()`/`alert()`, aviso de cambios sin guardar, errores por fila, totales en vivo, existencias y costo estimado en la salida, almacén para todas las líneas en la entrada, y al guardar se va a la ficha |
| LG-13 | APLICADO | 2026-09-19 | | Fichas con estado, usuario, totales y enlaces al documento de origen, al de anulación y a la OT; *Anular* desde la ficha |
| LG-14 | APLICADO | 2026-09-19 | | Almacenes con el componente de catálogo y columna *En uso* (materiales con stock y movimientos). DL-04: campo *Activo* con la regla de no desactivar con existencias; **migración `Almacen_AgregarActivo` creada, la aplica el propietario**. Stock con valor, precio unitario y enlace al kardex |
| LG-15 | APLICADO | 2026-09-19 | | Selector de stock al patrón vigente (carga, vacío, escapado, selección entre páginas); el objeto devuelto mantiene su forma y sólo añade el costo unitario |
| LG-16 | APLICADO | 2026-09-19 | | Se distingue *precio unitario* de *importe* en entrada, salida, stock, kardex y fichas, con formato `es-PE` de dos decimales; documentado en el código que en `NotaSalidaMaterial` y `AlmacenMaterial` `Precio` es el importe |
| LG-17 | APLICADO | 2026-09-19 | | Sin `bg-warning` en el área; tablas de líneas con `.tabla-apilable`. Falta verificar a 400 px |
