# Plan de mejora – Módulo de Administración

> Documento **ejecutable paso a paso**, con la misma mecánica que `legacy/planes/PLAN-UX-PLANMANTENIMIENTO.md`,
> `legacy/planes/PLAN-UX-HOJARUTA-SECCION.md` y `legacy/planes/PLAN-UX-EQUIPO-UBICACION.md`: cada paso es pequeño, verificable y
> reversible por sí solo. Marca la casilla al terminarlo y anótalo en el *Registro de avance* del final.

- **Alcance**: el área `Areas/Administracion` completa — 25 controladores y sus vistas: 23 catálogos
  simples en modal (`Index` + `_Nuevo` + `_Editar`), **Clase de Equipo** (pantalla completa con tipos,
  modos de falla y datos técnicos), **Empleado**, **Material**, **Sistema / Parte**, **Unidad de
  Medida de Servicio**, **Aspecto** y la **biblioteca de Adjuntos**; más los seis selectores
  compartidos (`_Seleccionar`) que usan Gestión y Logística.
- **Fuera de alcance**: el modelo de datos (salvo las consultas de lectura de AD-10 y AD-17), los
  módulos Gestión, Logística y Seguridad, y el sistema de permisos (ver `DA-04`).
- **Fecha**: 2026-09-19 · **Decisiones `DA-01` … `DA-06` resueltas el 2026-09-19** (sección 7)
- **Relación con AMSYS-BRAIN**: complementa `legacy/analisis/ux.md`, `legacy/analisis/permissions.md` y las tareas
  `MNT-NNN`; cada paso indica su tarea equivalente cuando existe.

---

## 1. Qué es el módulo y qué tiene que transmitir

Administración contiene los **datos maestros** que el resto del sistema consume. Casi nada se usa
aquí: se usa en Gestión (equipos, planes, secciones, avisos, órdenes) y en Logística.

```
Criticidad, Centro de costo ───────────────► Equipo, Ubicación
Clase de equipo ─► Tipos, Datos técnicos, Modos de falla ─► Equipo
Unidad de medida de servicio (Tipo, Calendario) ─► Plan de mantenimiento  (decide cuándo se programa)
Prioridad, Tipo de mantenimiento, Taller ─► Sección del plan ─► Orden de trabajo
Especialidad, Tipo de tarea, Sistema ─► Parte ─► Tarea
Material, Servicio, Socio de negocio ─► Sección, Orden de trabajo, Nota de entrada, Hoja de aceptación
Empleado (Costo por hora, Horario, Usuario) ─► Notificación de la OT  (costo de mano de obra)
Aspecto (Tipo, Opciones) ─► Puntos de medida de equipos y ubicaciones
Adjunto ─► Aviso, Orden de trabajo, Sección, Equipo
```

Por eso la interfaz de un catálogo tiene que responder a dos preguntas que hoy no responde:
**¿dónde se usa este registro?** y **¿qué pasa si lo cambio o lo desactivo?**

Hechos verificados que condicionan el diseño:

| Hecho | Evidencia | Consecuencia |
|-------|-----------|--------------|
| 18 catálogos abren el modal de edición buscando **sólo por `Id`**, sin empresa | `Criticidad.Controller.cs:60` → `CriticidadLogica.BuscarPorIdAsync` (`x.Id == id`); igual en CuentaContable, Especialidad, Impacto, Material, MecanismoFalla, MetodoDeteccion, ModoFalla, Parte, Prioridad, Servicio, Sistema, SocioNegocio, TallerResponsable, TipoMantenimiento, TipoTarea, UnidadMedida, UnidadMedidaServicio | Cualquier usuario autenticado lee registros de otra empresa iterando ids (mismo caso que `MNT-021`) |
| `Parte` se actualiza **sólo por `Id`** y el alta no valida el `SistemaId` | `Parte.Logica.cs:13`, `Parte.Controller.cs` (POST `Nuevo`/`Editar`) | Se puede modificar la parte de otra empresa o colgar una parte de un sistema ajeno |
| Clase de equipo actualiza tipos y datos técnicos con el `Id` que envía el cliente, sin comprobar a qué clase pertenecen | `ClaseEquipo.Logica.cs:24-58` (`Update(item)` + `item.ClaseEquipoId = entidad.Id`) | Un POST manipulado **mueve** un tipo o dato técnico de otra clase (u otra empresa) a la propia |
| El `id` del adjunto temporal se usa como nombre de archivo sin validar | `Adjunto.Controller.cs:43` (`EliminarTemporal`), `AdjuntoLogica.MoverAsync:103` llamado desde 9 puntos de Gestión (`Equipo.Controller.cs:108`, `Seccion.Controller.cs:111`…) | Con `..\` se borra un archivo del servidor, o se **mueve un archivo del servidor a los adjuntos** y luego se descarga |
| `ActualizarAsync` devuelve éxito aunque el registro no exista | `CriticidadLogica.ActualizarAsync` (`else return Task.CompletedTask`) y análogos | El usuario ve «Se guardó el registro» sin que se haya guardado nada |
| Los POST de todos los catálogos no tienen `[FiltroAccion]` | p. ej. `Criticidad.Controller.cs` `[HttpPost] Nuevo/Editar` | Los permisos sólo esconden la pantalla; el guardado lo puede invocar cualquier usuario → `DA-04` |
| Cambiar el `Tipo` o el `TipoCalendario` de una unidad de medida de servicio cambia cómo se programan los planes que la usan | `PlanMantenimiento.Logica.cs:194-206` | Es el campo con más consecuencias del módulo y no lo explica ni lo protege |
| Los modales con **un solo campo de texto** se envían al pulsar Enter como formulario nativo | `<form method="post" asp-action=…>` sin `type="submit"` en Criticidad, Prioridad, TipoTarea y Parte | El navegador abandona la página y muestra `{"id":…}`; el registro se crea igual (verificar en navegador) |

## 2. Pantallas afectadas

| Grupo | Pantallas | Patrón actual |
|-------|-----------|---------------|
| Catálogos simples (23) | Aspecto, Calificación, CausaFalla, CentroCosto, Criticidad, CuentaContable, Empleado, Especialidad, Impacto, Material, MecanismoFalla, MetodoDeteccion, ModoFalla, Parte, Prioridad, Servicio, Sistema, SocioNegocio, TallerResponsable, TipoMantenimiento, TipoTarea, UnidadMedida, UnidadMedidaServicio | `Index` (~158 LOC, copia casi idéntica) + `_Nuevo` / `_Editar` en modal |
| Pantalla maestro-detalle | `ClaseEquipo/{Index, Nuevo, Editar}` | Cabecera + 3 pestañas (Tipos, Modos de falla, Datos técnicos) |
| Biblioteca | `Adjunto/Index` | Lista de sólo lectura con descarga |
| Selectores compartidos (6) | `Empleado`, `Material`, `Servicio`, `SocioNegocio`, `Sistema`, `ModoFalla` → `_Seleccionar` | Modal abierto desde 23 puntos de Gestión y Logística |

## 3. Diagnóstico corto

1. **🔴 Datos de otras empresas.** Lectura sin filtro de empresa en 18 catálogos, escritura sin filtro
   en `Parte`, y reasignación de tipos / datos técnicos en Clase de equipo (sección 1).
2. **🔴 Rutas de archivo sin validar** en los adjuntos temporales: borrar o apropiarse de archivos del
   servidor.
3. **🔴 Guardados que mienten**: éxito aunque no se encuentre el registro; Enter que abandona la página.
4. **Listas en el patrón antiguo** (31 vistas): filtros en el `<thead>` sin etiquetas, `colspan='7'`
   fijo con `</td></td>` (28 vistas), datos sin escapar (ninguna vista usa `helper.html.escape`), sin
   estado de carga ni contador, acciones como iconos sin texto accesible, botón *Nuevo* sólo con `+`.
   Tras guardar, la lista vuelve a la página 1.
5. **Modales sin red de seguridad**: *Cancelar* en rojo (`btn-danger`, 52 vistas), errores en un
   bloque genérico con claves que no son de ningún campo (11 controladores registran `Nombre` para
   el campo *Descripción*), mensaje único «Se guardó el registro», sin foco inicial.
6. **Consecuencias invisibles**: ninguna lista dice si un registro está en uso; desactivar o editar
   un registro usado (unidad de servicio, especialidad, criticidad, dato técnico) no avisa.
7. **Campos sin explicar**: *Tipo / Tipo calendario* de la unidad de servicio, *Opciones* de un
   aspecto (texto con `;`), *Costo por hora* y *Horario* del empleado, *Valor* de la calificación.
8. **Clase de equipo**: confirmación en *Guardar*, *Regresar* ámbar sin aviso de cambios, cabeceras
   `bg-warning`; los tipos existentes muestran un checkbox *activo* sin rótulo y los nuevos una
   papelera (dos columnas distintas en la misma tabla); un dato técnico no se puede quitar y
   renombrarlo cambia el significado del valor guardado en cada equipo, sin avisar.
9. **Sistema y Parte** son dos catálogos separados: para ver las partes de un sistema hay que ir a
   otra lista y filtrar.
10. **Biblioteca de adjuntos**: no dice a qué aviso, orden, sección o equipo pertenece cada archivo;
    los filtros de tamaño y registro son `readonly` (no filtran); la descarga carga el archivo entero
    en memoria (`File.ReadAllBytes`).
11. **Inyección en el `callBack`**: 44 modales escriben el parámetro `callBack` de la URL dentro del
    `<script>` (`@string.Format("{0}(result)", callBack)`). Hoy sólo se abren con valores fijos, pero
    el valor no se valida.
12. **Vocabulario incoherente**: *CODIGO* / *CÓDIGO*, *Descripción* / *Nombre* para el mismo concepto,
    títulos «Lista de X» / «X», «¿Es Personal de Mtto?».

## 4. Principios

- Los de los planes anteriores: `helper.filtros`, `helper.tabla`, `helper.html.escape`,
  `helper.codigoDuplicado`, `.barra-acciones`, respuesta de validación estructurada
  (`ErrorDeValidacion()`), convención de color de `site.css` y `.tabla-apilable`.
- **Primero la base común, después los 23 catálogos**: con 23 copias casi idénticas, cada mejora se
  construye una vez (AD-07) y se aplica por lotes. Nada de corregir el mismo defecto 23 veces a mano.
- **Los selectores son contratos compartidos**: no cambiar parámetros (`callBack`, `filtro.*`) ni la
  forma del objeto devuelto.
- **Inactivo no es borrado**: desactivar oculta el registro en las listas para elegir, pero lo
  conserva donde ya se usa (mismo criterio que EU-02 en Gestión).
- Un paso = un commit. En los pasos por lotes, un commit por lote.

---

## 5. Pasos

### FASE 0 — Seguridad y datos

#### [x] AD-01 · Filtrar por empresa al abrir un registro para editar

- **Hoy**: 18 catálogos abren `_Editar` con `BuscarPorIdAsync(id)` sin empresa.
- **Objetivo**: que ningún usuario pueda leer un registro de otra empresa.
- **Archivos**: los 18 controladores y sus `*.Logica.cs` / `I*.Servicio.cs`.
- **Hacer**:
  - Cambiar la firma a `BuscarPorIdAsync(int id, int empresaId)` (o usar el `BuscarAsync(filtro)`
    que ya tienen Aspecto, Calificación, CausaFalla y CentroCosto) y pasar `usuario.EmpresaId`.
  - Buscar con `grep` todos los usos de cada `BuscarPorIdAsync` fuera de Administración y corregirlos
    en el mismo commit (compila o no compila: el cambio de firma los encuentra todos).
- **Aceptación**:
  - [ ] Abrir `/Administracion/Criticidad/Editar/{id de otra empresa}` devuelve *No se encontró el registro*.
  - [ ] Ninguna llamada a `BuscarPorIdAsync(id)` sin empresa queda en la solución.
- **Esfuerzo** M · **Riesgo** BAJO · **Ref.** `MNT-021` (mismo defecto en Hoja de Ruta)

#### [x] AD-02 · Parte: escribir sólo en la empresa propia

- **Hoy**: `ParteLogica.ActualizarAsync` busca por `Id` sin empresa; el alta acepta cualquier
  `SistemaId`.
- **Archivos**: `Parte.Controller.cs`, `Parte.Logica.cs`.
- **Hacer**: comprobar en `Nuevo` y `Editar` (POST) que el sistema pertenece a la empresa; en
  `ActualizarAsync` filtrar por `x.Sistema.EmpresaId == empresaId`.
- **Aceptación**:
  - [ ] Un POST con una parte o un sistema de otra empresa devuelve error de validación.
- **Esfuerzo** S · **Riesgo** BAJO · **Ref.** `MNT-022`

#### [x] AD-03 · Clase de equipo: no mover tipos ni datos técnicos ajenos

- **Hoy**: `ClaseEquipoLogica.ActualizarAsync` hace `Update(item)` con el `Id` del cliente y le asigna
  la clase actual, sin comprobar que ya fuera suyo.
- **Archivos**: `ClaseEquipo.Logica.cs`, `ClaseEquipo.Controller.cs`.
- **Hacer**:
  - Cargar los tipos y datos técnicos **de la clase** y actualizar sólo los que coincidan por `Id`;
    un `Id` que no pertenezca a la clase es error de validación.
  - Actualizar campo a campo (`Nombre`, `Activo`) en lugar de `Update(item)` de la entidad recibida.
  - Validar que los modos de falla asociados sean de la empresa.
- **Aceptación**:
  - [ ] Un POST con el `Id` de un tipo de otra clase devuelve error y no lo modifica.
- **Esfuerzo** S · **Riesgo** MEDIO (toca el guardado de la clase) · **Ref.** `MNT-022`

#### [x] AD-04 · Adjuntos temporales: identificadores seguros

- **Hoy**: el `id` temporal (`{empresaId}_{guid}`) llega del cliente y se combina con la ruta sin
  validar en `EliminarTemporal` y en `MoverAsync` (9 llamadas desde Gestión).
- **Objetivo**: que el `id` sólo pueda nombrar un archivo temporal de la empresa del usuario.
- **Archivos**: `Adjunto.Controller.cs`, `Adjunto.Logica.cs` (y, sin cambiar su código, los 9 puntos
  de Gestión quedan cubiertos al validar dentro de `MoverAsync`).
- **Hacer**:
  - Validar el `id` con la expresión `^{empresaId}_[0-9a-f-]{36}$` y usar `Path.GetFileName`; si no
    cumple, rechazar.
  - Comprobar que la ruta final está dentro de la carpeta temporal (`Path.GetFullPath` + `StartsWith`).
  - Límite de tamaño (configurable en `AppSettings`) y lista de extensiones permitidas en
    `NuevoTemporal`.
  - Tarea programada o limpieza al arrancar de los temporales con más de 24 h.
- **Aceptación**:
  - [ ] `EliminarTemporal` con `..\` o con el prefijo de otra empresa no borra nada.
  - [ ] Guardar un equipo con un `archivos[0].id` manipulado no crea ningún adjunto.
- **Esfuerzo** S · **Riesgo** BAJO · **Prioridad**: la más alta del plan

#### [x] AD-05 · Guardados que dicen la verdad

- **Hoy**: `ActualizarAsync` termina sin error aunque no encuentre el registro; Enter envía el
  formulario nativo en 4 modales; el `callBack` de la URL se escribe sin validar en 44 modales.
- **Archivos**: `*.Logica.cs` de los catálogos, sus controladores, los `_Nuevo` / `_Editar`.
- **Hacer**:
  - `ActualizarAsync` devuelve `bool` (o lanza) cuando no encuentra el registro; el controlador
    responde *No se encontró el registro*.
  - Enter dentro de un modal = *Guardar* por AJAX (lo resuelve AD-07 para todos).
  - Validar `callBack` en el controlador con `^[A-Za-z_$][\w$]*(\.[A-Za-z_$][\w$]*)*$`; si no
    cumple, usar el valor por defecto.
- **Aceptación**:
  - [ ] Editar un registro borrado entre abrir y guardar muestra un error, no «Se guardó».
  - [ ] Pulsar Enter en *Nueva criticidad* guarda y cierra el modal sin salir de la lista.
- **Esfuerzo** M · **Riesgo** BAJO

---

### FASE 1 — Base común y listas

#### [x] AD-06 · Validación estructurada en todos los catálogos

- **Hoy**: 11 controladores registran la clave `Nombre` para el campo *Descripción*; las respuestas
  de error son HTML (`_Error`), no se puede marcar el campo.
- **Hacer**: `ErrorDeValidacion()` (mismo patrón que Sección, Equipo y Ubicación) en los 25
  controladores, con claves que coinciden con el `id` del control; en Clase de equipo,
  `TiposEquipo[i].Nombre` y `DatosTecnico[i].Nombre` con numeración real.
- **Aceptación**:
  - [ ] Cada error de servidor marca su campo en el modal.
- **Esfuerzo** M · **Riesgo** BAJO · **Ref.** `MNT-043`

#### [x] AD-07 · Componente de catálogo (piloto: Criticidad)

- **Objetivo**: una sola implementación de todo lo que los 23 catálogos repiten.
- **Archivos**: `wwwroot/js/helper.js` (nuevo `helper.catalogo`), `Views/Shared/_PieModalCatalogo.cshtml`
  (nuevo), `Criticidad/{Index,_Nuevo,_Editar}.cshtml`.
- **Hacer**:
  - `helper.catalogo.modal({ form, url, modelo, callBack, validar })`: Enter = guardar, estado
    ocupado, validación en cliente, errores en el campo (AD-06), foco en el primer campo al abrir.
  - Pie de modal común: *Cancelar* `btn-secondary` a la izquierda, *Guardar* `btn-primary`.
  - `helper.catalogo.lista({ tabla, url, columnas, filtros })`: panel de filtros con chips
    (`helper.filtros`), `helper.tabla.cargando` / `vacia`, contador «Mostrando X – Y de N»,
    escapado, acciones `btn btn-light` con `title` y `aria-label`.
  - Tras guardar: mensaje con la operación y el objeto («Se creó la criticidad *Alta*»), la lista
    **se queda en la página y con los filtros** y resalta la fila creada o editada.
  - Aplicarlo a Criticidad y validar el patrón antes de seguir.
- **Aceptación**:
  - [ ] Criticidad sin ningún código propio de lista o modal fuera de la configuración.
  - [ ] Editar un registro de la página 3 vuelve a la página 3 con la fila resaltada.
- **Esfuerzo** M · **Riesgo** BAJO

#### [x] AD-08 · Migrar los catálogos simples al componente (por lotes)

- **Lotes** (un commit cada uno, probar el lote entero antes de seguir):
  1. *Descripción + Activo*: Prioridad, TipoTarea.
  2. *Código + Descripción / Nombre*: CausaFalla, CentroCosto, CuentaContable, Especialidad,
     Impacto, MecanismoFalla, MetodoDeteccion, ModoFalla, TallerResponsable, TipoMantenimiento,
     UnidadMedida.
  3. *Con relación o campos propios*: Calificación, Servicio, SocioNegocio, Sistema, Parte, Material,
     Aspecto, UnidadMedidaServicio, Empleado.
- **Hacer**: lo de AD-07; los campos específicos de cada modal se tratan en la FASE 2.
- **Aceptación**:
  - [ ] Ninguna vista del área contiene `colspan='7'`, `</td></td>` ni `btn-danger" data-bs-dismiss`.
  - [ ] Un nombre con etiquetas HTML se muestra literal en las 23 listas.
- **Esfuerzo** L (repartido en 3 lotes) · **Riesgo** BAJO · **Ref.** `MNT-044`

#### [x] AD-09 · Selectores compartidos al patrón vigente

- **Archivos**: `{Empleado, Material, Servicio, SocioNegocio, Sistema, ModoFalla}/_Seleccionar.cshtml`.
- **Hacer**: estado de carga y vacío, escapado, badge *Inactivo* donde aplique, contador de
  seleccionados en los de selección múltiple, **sin cambiar** parámetros ni objeto devuelto.
- **Aceptación**:
  - [ ] Probado desde Sección, Equipo, Orden de trabajo (Nuevo, Editar, Notificar), Clase de equipo,
    Nota de entrada y Hoja de aceptación: el *callback* recibe el mismo objeto.
- **Esfuerzo** M · **Riesgo** MEDIO (23 puntos de uso) · **Ref.** EU-06

---

### FASE 2 — Consecuencias visibles

#### [x] AD-10 · Columna *En uso* en las listas

- **Hoy**: nada indica si un registro se usa; se desactiva o se edita a ciegas.
- **Hacer**:
  - `ResumirAsync(int[] ids)` por catálogo con **consultas agrupadas por página** (patrón de
    `EquipoRepositorio.ResumirAsync`), empezando por los catálogos con consecuencias:
    Unidad de medida de servicio → planes; Criticidad → equipos y ubicaciones; Especialidad →
    tareas y empleados; Prioridad, Tipo de mantenimiento y Taller → secciones de plan;
    Material / Servicio → secciones y órdenes; Sistema → partes y equipos; Clase de equipo → equipos.
  - Columna *EN USO* con el total y `title` con el desglose; filtro *En uso / Sin uso*.
- **Aceptación**:
  - [ ] Sin consultas por fila (log de EF Core).
- **Esfuerzo** M · **Riesgo** MEDIO (rendimiento) · **Ref.** EU-10, `MNT-047`

#### [x] AD-11 · Avisar al desactivar o cambiar un registro en uso

- **Hacer**: en el modal de edición, al desmarcar *Activo* de un registro en uso, advertencia en
  línea con los números de AD-10: *«Lo usan 12 equipos. Seguirán con este valor, pero no podrá
  elegirse en registros nuevos.»* Sin bloquear. Mismo aviso al cambiar el nombre de un registro en
  uso (el cambio se ve en todos los que lo usan).
- **Aceptación**:
  - [ ] Los números del aviso coinciden con la columna *En uso*.
- **Esfuerzo** S · **Riesgo** BAJO · **Ref.** EU-12

#### [x] AD-12 · Unidad de medida de servicio: el campo que programa los planes

- **Hoy**: *Tipo* y *Tipo calendario* se editan libremente; deciden cómo se calcula la próxima
  fecha de todos los planes que usan la unidad (`PlanMantenimiento.Logica.cs:194-206`).
- **Hacer** (según `DA-02`):
  - Ayuda en el modal: qué significa *Calendario* frente a *Contador*, y qué es *Día / Semana / Mes*,
    con un ejemplo («Intervalo 3 + Mes = cada 3 meses»).
  - Con planes asignados: bloquear *Tipo* y *Tipo calendario* (o avisar, según la decisión) nombrando
    cuántos planes cambian su programación.
- **Aceptación**:
  - [ ] No se puede cambiar la programación de un plan sin saberlo.
- **Esfuerzo** S · **Riesgo** MEDIO

#### [x] AD-13 · Explicar los campos con consecuencias

- **Hacer**:
  - **Empleado**: *Costo por hora* → «se usa para calcular la mano de obra al notificar una OT»
    (ya existe; conservar); *Horario* como grilla de días con total semanal y promedio diario en
    vivo (la misma fórmula que `EmpleadoLogica`, `totalHoras / 7`); *Personal de mantenimiento* con
    texto de dónde aparece; *Usuario asociado* avisa si el usuario ya está vinculado a otro empleado
    (el servidor lo reasigna en silencio: `EmpleadoLogica.AsociarUsuario`).
  - **Aspecto**: *Opciones* como lista de etiquetas (añadir / quitar) en lugar de texto con `;`,
    con vista previa de cómo se verá la medición; al editar un aspecto en uso, avisar que las
    opciones cambian para las mediciones futuras.
  - **Calificación**: qué representa *Valor* y dónde se usa.
  - **Material**: *Unidad de medida* y *Precio* (dónde se toma el precio).
- **Aceptación**:
  - [ ] Cada campo con efecto fuera del catálogo lo explica antes de guardar.
- **Esfuerzo** M · **Riesgo** BAJO

---

### FASE 3 — Pantallas con detalle

#### [x] AD-14 · Clase de equipo: formulario al patrón vigente

- **Archivos**: `ClaseEquipo/{Nuevo, Editar, Index}.cshtml`, `ClaseEquipo.Controller.cs`.
- **Hacer**:
  - Barra `.barra-acciones`, *Guardar* sin confirmación, indicador y aviso de cambios sin guardar,
    *Regresar* `btn-secondary`, errores en campo, fila y pestaña (AD-06).
  - **Tipos**: una sola estructura para filas nuevas y existentes: columna *Activo* rotulada
    (interruptor) y *Quitar* sólo en las filas sin guardar; contador *Tipos (N)*.
  - **Datos técnicos**: contador de equipos que tienen valor en cada uno; al renombrar uno con
    valores, avisar que el nuevo nombre se aplica a los valores ya guardados; quitar un dato técnico
    según `DA-03`.
  - **Modos de falla**: escapado, contador, *Quitar* con `closest('tr')`.
  - Cabeceras en azul (configuración); `Index` con columnas *TIPOS*, *DATOS TÉC.* y *EQUIPOS*.
- **Aceptación**:
  - [ ] Salir con cambios pendientes pide confirmación; guardar es un clic.
  - [ ] Un tipo nuevo se crea activo y se ve igual que los existentes.
- **Esfuerzo** M · **Riesgo** BAJO

#### [x] AD-15 · Sistema y sus partes en un solo lugar

- **Hoy**: las partes de un sistema se gestionan desde otra lista (`Parte/Index`).
- **Hacer**: en la lista de sistemas, columna *PARTES (N)* que despliega las partes del sistema
  (patrón de `HojaRuta/Ver`), con *Nueva parte* que abre el modal de Parte con el sistema ya elegido.
  `Parte/Index` se mantiene, con filtro por sistema desde la URL (`?sistemaId=`).
- **Aceptación**:
  - [ ] Crear una parte de un sistema se hace sin salir de la lista de sistemas.
- **Esfuerzo** M · **Riesgo** BAJO

#### [x] AD-16 · Empleado: ficha útil

- **Hacer**: lista con *Especialidad*, *Personal de mantenimiento*, *Usuario* y *Costo/h*, y filtros
  por esas columnas; modal con la grilla de horario de AD-13.
- **Esfuerzo** S · **Riesgo** BAJO

#### [x] AD-17 · Biblioteca de adjuntos

- **Hacer**:
  - Columna *USADO EN* con enlaces a los avisos, órdenes, secciones y equipos que lo tienen
    (consulta agrupada por página); filtro *Sin uso*.
  - Filtros reales de tamaño y fecha (hoy son `readonly`); tamaño legible (KB / MB).
  - Descarga con `PhysicalFile` en lugar de `File.ReadAllBytes`.
  - Eliminar desde la biblioteca según `DA-06`, con SweetAlert que diga dónde se usa.
- **Aceptación**:
  - [ ] Desde un adjunto se llega en un clic al registro que lo contiene.
- **Esfuerzo** M · **Riesgo** BAJO · **Ref.** `MNT-014`

---

### FASE 4 — Vocabulario, códigos y consistencia visual

#### [x] AD-18 · Alerta de código duplicado

- **Hacer** (según `DA-01`): `BuscarCodigo` con `[FiltroAccion(Accion = "Index")]` y
  `helper.codigoDuplicado` en los catálogos con código: CausaFalla, CentroCosto, CuentaContable,
  Especialidad, Impacto, MecanismoFalla, MetodoDeteccion, ModoFalla, TallerResponsable,
  TipoMantenimiento, Material y Servicio (*Código personalizado*), UnidadMedida (*Abreviatura*),
  Empleado (*Nro. documento*).
- **Esfuerzo** M · **Riesgo** BAJO · **Ref.** `MNT-048`, EU-19

#### [x] AD-19 · Mismos nombres en todo el módulo

- **Hacer**:
  - *CÓDIGO* con tilde en todas las cabeceras; un solo rótulo por concepto (*Descripción* o
    *Nombre*, según lo que el campo contiene en cada catálogo, pero igual en lista y modal).
  - Títulos: página «Criticidades», modal «Nueva criticidad» / «Editar criticidad · Alta».
  - «¿Es Personal de Mtto?» → «Personal de mantenimiento».
- **Aceptación**:
  - [ ] La misma información tiene el mismo nombre en lista, modal y selector.
- **Esfuerzo** S · **Riesgo** BAJO

#### [x] AD-20 · Color semántico y móvil

- **Hacer**:
  - Convención de `site.css`: azul para configuración (tipos, datos técnicos, modos de falla,
    horario), ámbar sólo para advertencias. Hoy Clase de equipo y el horario de Empleado usan
    `bg-warning` en cabeceras.
  - `.tabla-apilable` con `data-label` en las tablas editables de Clase de equipo.
  - Modales `modal-dialog-scrollable` y `modal-fullscreen-sm-down` en los de más de 6 campos
    (Empleado, Material).
- **Aceptación**:
  - [ ] A 400 px se puede crear un empleado y una clase de equipo sin scroll horizontal.
- **Esfuerzo** S · **Riesgo** BAJO

---

## 6. Orden recomendado

| Orden | Paso | Esfuerzo | Riesgo | Por qué en este orden |
|-------|------|----------|--------|-----------------------|
| 1 | **AD-04** Adjuntos temporales | S | BAJO | Permite leer o borrar archivos del servidor |
| 2 | **AD-01** Lectura entre empresas | M | BAJO | 18 pantallas expuestas |
| 3 | **AD-02** Parte | S | BAJO | Escritura entre empresas |
| 4 | **AD-03** Clase de equipo | S | MEDIO | Escritura entre empresas |
| 5 | AD-05 Guardados que dicen la verdad | M | BAJO | Pérdida de datos silenciosa |
| 6 | AD-06 Validación estructurada | M | BAJO | Requisito de AD-07 |
| 7 | **AD-07** Componente de catálogo | M | BAJO | Base de toda la FASE 1 |
| 8 | AD-08 Migrar catálogos (3 lotes) | L | BAJO | Aplica AD-07 |
| 9 | AD-09 Selectores | M | MEDIO | Probar los 23 usos |
| 10 | AD-10 En uso | M | MEDIO | Requisito de AD-11, AD-12 y AD-14 |
| 11 | **AD-12** Unidad de servicio | S | MEDIO | Protege la programación de planes |
| 12 | AD-11 Avisar al desactivar | S | BAJO | Reutiliza AD-10 |
| 13 | AD-14 Clase de equipo | M | BAJO | |
| 14 | AD-13 Campos explicados | M | BAJO | |
| 15 | AD-16 Empleado | S | BAJO | Junto con AD-13 |
| 16 | AD-15 Sistema y partes | M | BAJO | |
| 17 | AD-17 Biblioteca de adjuntos | M | BAJO | |
| 18 | AD-18 Código duplicado | M | BAJO | Tras `DA-01` |
| 19 | AD-19 Vocabulario | S | BAJO | |
| 20 | AD-20 Color y móvil | S | BAJO | |

> [!CAUTION]
> **AD-01 cambia la firma de 18 servicios** y **AD-09 toca selectores usados en 23 lugares**
> (Gestión y Logística). En ambos, compilar la solución completa y recorrer los puntos de uso antes
> de cerrar el paso.

## 7. Decisiones del propietario 🟢 RESUELTAS (2026-09-19)

| Id | Pregunta | Opciones | Decisión | Afecta a |
|----|----------|----------|----------|----------|
| `DA-01` | ¿Los códigos de los catálogos deben ser únicos por empresa? | a) Avisar sin bloquear, como `D-03` en Hoja de Ruta y Sección · b) Bloquear en los catálogos que son claves contables o de integración (Centro de costo, Cuenta contable) y avisar en el resto | **a)** Avisar sin bloquear en todos los catálogos. | AD-18 |
| `DA-02` | Unidad de medida de servicio con planes asignados: ¿se permite cambiar *Tipo* y *Tipo calendario*? | a) Bloquear (recomendado: cambia la programación de todos sus planes) · b) Permitir con advertencia | **a)** Bloquear: con planes asignados no se pueden cambiar *Tipo* ni *Tipo calendario*. | AD-12 |
| `DA-03` | ¿Se puede quitar un dato técnico de una clase? | a) Sólo si ningún equipo tiene valor en él · b) Siempre, borrando los valores de los equipos (con confirmación) · c) No, sólo renombrar | **b)** Se puede quitar siempre, **con confirmación** que indique cuántos equipos pierden su valor. | AD-14 |
| `DA-04` | Los POST de Administración no comprueban permisos (`[FiltroAccion]` sólo está en los GET). ¿Se incluye aquí o en una tarea de permisos aparte? | a) Tarea aparte junto con `legacy/analisis/permissions.md` (recomendado: afecta a todos los módulos) · b) Incluirlo en este plan | **a)** Tarea aparte de permisos; fuera de este plan. | FASE 0 |
| `DA-05` | ¿La base común (AD-07) se implementa sólo en JavaScript (`helper.catalogo`) o también como vistas Razor genéricas por configuración? | a) Sólo JS + parcial de pie de modal (recomendado: menos cambio) · b) Vistas genéricas | **a)** Sólo JS (`helper.catalogo`) + parcial de pie de modal. | AD-07, AD-08 |
| `DA-06` | ¿Se pueden eliminar adjuntos desde la biblioteca? | a) Sólo los que no se usan · b) Cualquiera, desvinculándolo de sus registros · c) No | **a)** Sólo se eliminan adjuntos que no se usan. | AD-17 |

## 8. Hallazgos durante la ejecución

- Cuatro catálogos de confiabilidad (Causa, Impacto, Mecanismo, Método) y Sistemas enviaban un filtro que el servidor
  no tenía: filtrar por código o agrupador no hacía nada. Corregido en AD-08.
- `Adjunto/Listar` devolvía la ruta física de cada archivo en el servidor. Corregido en AD-17.
- `Calificacion` sin valor rompía el guardado (`Valor!.Value` sobre nulo). Corregido en AD-13.
- El contexto de EF usa `NoTracking` por defecto: cualquier entidad cargada y modificada necesita `Update` explícito.
  Tenido en cuenta en AD-03.
- La API móvil (`Api/Controllers/AdjuntoController.Buscar`) sigue cargando el archivo entero en memoria; fuera del área.

## 9. Fuera de alcance, con referencia

- Protección CSRF de los formularios (los modales llevan `asp-antiforgery` pero el AJAX no envía el
  token y no hay validación global): `MNT-035`.
- Permisos de las acciones POST: `DA-04`, `legacy/analisis/permissions.md`.
- Validación de claves foráneas en Gestión (planes, secciones): `MNT-022`.
- Borrado de catálogos: se sigue usando *Activo*; no se añade eliminación física.

## 10. Cómo verificar cada paso

1. `dotnet build AMSYS.sln` sin nuevos avisos.
2. Dos empresas de prueba: repetir con los ids de la otra empresa cada acción de la FASE 0.
3. En cada catálogo: crear, editar, desactivar, filtrar, paginar y volver; un nombre con `<b>`.
4. Recorrer los selectores desde Sección, Equipo, Orden de trabajo (Nuevo, Editar, Notificar),
   Clase de equipo, Nota de entrada y Hoja de aceptación.
5. Consola del navegador sin errores; ancho de 400 px y de 768 px.

## 11. Registro de avance

| Paso | Estado | Fecha | Commit | Notas |
|------|--------|-------|--------|-------|
| AD-01 | APLICADO | 2026-09-19 | | Firma `BuscarPorIdAsync(id, empresaId)` en los 18 servicios; también en las 3 llamadas de `PlanMantenimiento.Controller` (id de la unidad de servicio desde el cliente). Compila toda la solución. Falta probar con dos empresas |
| AD-02 | APLICADO | 2026-09-19 | | `ActualizarAsync(entidad, empresaId)` filtra por `Sistema.EmpresaId`; `ValidarSistemaAsync` en alta y edición. Falta probar con dos empresas |
| AD-03 | APLICADO | 2026-09-19 | | Tipos y datos técnicos se actualizan campo a campo y sólo si son de la clase (con `Update` explícito: el contexto es `NoTracking`); `ValidarDetalleAsync` rechaza ids ajenos y modos de falla de otra empresa; en el alta se ignora cualquier id. Falta probar con dos empresas |
| AD-04 | APLICADO | 2026-09-19 | | `ArchivoTemporal.EsIdValido` (`{empresaId}_{guid}`, sin separadores) en `MoverAsync` (12 llamadas: web y API) y en `EliminarTemporal` (web y API); `MoverAsync` devuelve `bool` y ya no se añade un adjunto con `Id = 0` si el temporal no existe. Límite de 20 MB y extensiones ejecutables bloqueadas. Reactivado `EliminarTemporalesService` (24 h, sólo archivos con formato de temporal). Probado con casos de traversal: 13/13 |
| AD-05 | APLICADO | 2026-09-19 | | `ActualizarAsync` → `Task<bool>` en los 23 catálogos; `RespuestaValidacion.NoEncontrado`. `callBack` validado con `RespuestaValidacion.CallBack` en todos los GET del área (probado con inyecciones). Enter guarda por AJAX (AD-07). Falta verificar en navegador |
| AD-06 | APLICADO | 2026-09-19 | | `RespuestaValidacion.Errores` en los 25 controladores; claves corregidas (`Descripcion`, `Nombre`, `UnidadMedidaId`, `NombreCompleto`, `TiposEquipo[i].Nombre`, `DatosTecnico[i].Nombre`). `helper.error.show` pinta la respuesta JSON como lista |
| AD-07 | APLICADO | 2026-09-19 | | `helper.catalogo.lista` / `modal` / `celdaUso` / `avisoUso` y parcial `Shared/_PieModalCatalogo`. Piloto Criticidad; la fila editada se resalta y la lista se queda en su página (DA-05: sólo JS + parcial) |
| AD-08 | APLICADO | 2026-09-19 | | Los 23 catálogos generados desde una especificación (lotes 1, 2 y 3). Ninguna vista contiene `colspan='7'`, `</td></td>` ni `btn-danger" data-bs-dismiss`; JS de las 79 vistas con script validado con `node --check`. Añadidos filtros que el servidor ignoraba: *Código* en 4 catálogos de confiabilidad y *Agrupador* en Sistema. Falta verificar en navegador |
| AD-09 | APLICADO | 2026-09-19 | | Los 6 selectores con carga/vacío, escapado, datos en `data-*`, selección conservada entre páginas y contador; mismo objeto devuelto. **Falta probar los 23 puntos de uso** |
| AD-10 | APLICADO | 2026-09-19 | | Servicio `IUsoCatalogo` (una consulta por página, navegaciones del modelo) para 22 catálogos; columna *EN USO* con desglose en el `title`. Consultas traducidas a SQL sin error (`ToQueryString`). No se añadió el filtro *En uso / Sin uso* en los catálogos (sí en adjuntos) |
| AD-11 | APLICADO | 2026-09-19 | | Aviso en el modal de edición al desactivar o renombrar un registro en uso, con el desglose real. Falta verificar en navegador |
| AD-12 | APLICADO | 2026-09-19 | | La edición **ya no permitía** cambiar Tipo ni Tipo calendario (el servidor los ignora): DA-02 se cumple. Ahora el modal lo explica, muestra cuántos planes la usan y el alta explica cada tipo y oculta *Calendario* si no aplica |
| AD-13 | APLICADO | 2026-09-19 | | Ayudas en Material (precio), Calificación (valor, antes un valor vacío hacía fallar el guardado), Aspecto (opciones como etiquetas y aviso si está en uso) y Empleado (costo por hora, personal de mantenimiento, horario con total y promedio). Calificación no se usa fuera de Administración: la ayuda no dice más |
| AD-14 | APLICADO | 2026-09-19 | | Barra fija, cambios sin guardar, errores en fila y pestaña, tipos nuevos y guardados con la misma estructura, contadores, cabeceras azules. DA-03: quitar un dato técnico con valores pide confirmación y al guardar borra sus valores en los equipos (`DatosTecnicoEliminados`). Aviso al renombrar un dato con valores. Falta verificar en navegador |
| AD-15 | APLICADO | 2026-09-19 | | Columna *PARTES* en Sistemas enlazada a `Parte/Index?sistemaId=`; acción *Nueva parte* abre el modal con el sistema elegido. Filtro de Partes por sistema |
| AD-16 | APLICADO | 2026-09-19 | | Lista con especialidad, usuario, personal de mantenimiento y costo/h (`conDetalle`, sin cambiar la respuesta del selector). El servidor ya no reasigna un usuario vinculado a otro empleado (`ValidarUsuarioAsync`). Horario como grilla con total y promedio |
| AD-17 | APLICADO | 2026-09-19 | | Columna *USADO EN* enlazada (avisos, OT, secciones, equipos, foto de usuario); filtros reales de registro, tamaño y uso; descarga con `PhysicalFile`; la lista ya no devuelve la ruta física del archivo. DA-06: sólo se eliminan los que no se usan (`soloSinUso`, validado en el servidor) |
| AD-18 | APLICADO | 2026-09-19 | | `BuscarCodigo` en 14 catálogos (código, código personalizado, abreviatura, nro. documento) y aviso no bloqueante en sus modales (DA-01) |
| AD-19 | APLICADO | 2026-09-19 | | Títulos en plural, modales «Nueva …» / «Editar … · nombre», *CÓDIGO* con tilde, «Personal de mantenimiento». Corregido el título del selector de modos de falla («Seleccionar Empleados») |
| AD-20 | APLICADO | 2026-09-19 | | Sin `bg-warning` en cabeceras del área; tablas editables de Clase de equipo con `.tabla-apilable`; modales de Empleado y Material `modal-lg modal-fullscreen-sm-down`. No se usó `modal-dialog-scrollable`: el `<form>` entre `modal-content` y `modal-body` rompe su maquetación. Falta verificar a 400 px |
