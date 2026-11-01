# Porte de la UI de `main` a la rama `agchavin`

Estado al 2026-10-30.

- **Commit:** hecho el 2026-10-26 en `0945b8d` (feat: mejorar UI) y `be90f45` (feat: mejoras UI). No quedó
  código del porte fuera del commit (solo están sin versionar `.idea/`, `ai/` y `script.sql`).
- **Compilación:** 0 errores, 0 advertencias. EF sin cambios de modelo pendientes.
- **Migración:** `20261020022722_VistaLista_Crear_Almacen_AgregarActivo` aplicada el 2026-10-30 en
  **localhost** (`amsys_v3_agchavin`). **Falta** aplicarla en el servidor `10.2.1.2` / producción.
- **`main` revisada de nuevo el 2026-10-30:** sin commits nuevos (local y `origin/main` en `be8869b`, 2026-10-16).
  El porte ya cubre `be8869b` salvo lo indicado en "No portado".
- **No se ha probado en el navegador.**

## Siguientes pasos (en orden)

1. ~~Aplicar la migración en desarrollo~~ (hecho en localhost). Para el servidor/producción, generar el script
   solo de esta migración (el `script.sql` del árbol crea la base completa y **no** la incluye):
   ```
   dotnet ef migrations script 20250831143101_Actualizar_OrdenTrabajo_PMS -p AMSYS.Contextos -s AMSYS.WebAdmin -o migracion.sql
   ```

2. **Probar en el navegador** (ver checklist abajo). Prioridad: Material, Parte, Sistema
   (mezclan cambios de las dos ramas), Avisos/Órdenes (columnas configurables) y Logística (cambia comportamiento).

3. ~~Revisar el diff y hacer commit~~ (hecho). No commitear `appsettings.Development.json`: el cambio local solo
   apunta la conexión a localhost. Ese archivo tiene en el historial la clave del servidor `10.2.1.2`:
   conviene moverla a user-secrets y rotarla.

4. **Decidir si se sigue con lo pendiente** (ver sección "No portado").

## Checklist de pruebas

- [ ] Catálogos de Administración: alta, edición, filtros/chips, error de validación marcando el campo.
- [ ] Aviso de código repetido (`BuscarCodigo`) en Centro de costo, Empleado, Material, etc.
- [ ] Unidad de medida de servicio: editar sin cambiar el tipo (se reenvía el actual).
- [ ] Parte: filtro por sistema y "nueva parte" con el sistema preseleccionado; Sistema: filtro por agrupador.
- [ ] Listas de Equipos/Ubicaciones/Planes/Hojas de ruta/Secciones: columnas de conteos (resumen).
- [ ] Exportar Excel en Equipos y Ubicaciones.
- [ ] Ficha de Equipo → pestaña "Órdenes y Avisos": carga una sola vez, enlaces a OT/aviso, mensaje si no hay registros.
- [ ] Árbol jerárquico: equipos ordenados por `Orden`, inactivos atenuados, parámetro `?expandir=e_5`.
- [ ] Avisos / Mis avisos / Órdenes: panel "Columnas", guardar vista, compartirla, tamaño de página.
- [ ] Excel de Avisos/Órdenes: con vista predeterminada = formato de siempre; con vista propia = sus columnas
      (Órdenes conserva la hoja 2 de notificaciones).
- [ ] Órdenes: descarga masiva de PDF (casillas).
- [ ] Órdenes Nuevo/Editar: tareas (con y sin sección), materiales, servicios, empleados/socios con horas,
      inicio/fin programado, "Puede ejecutar"; no se puede borrar una tarea con notificaciones de tiempo.
- [ ] Notificar solo aparece con "Puede ejecutar"; editar una OT con avance no reinicia las tareas ejecutadas.
- [ ] Reporte Preventivo y Excel de planificación con OTs EMITIDO + Puede ejecutar.
- [ ] Filtros de prioridad y usuario en Avisos (antes se ignoraban).
- [ ] Logística: anular nota de entrada/salida y hoja de aceptación, traslado entre almacenes,
      stock insuficiente rechazado, exportaciones.
- [ ] Almacén: desactivar con stock debe rechazarse; notas solo ofrecen almacenes activos.
- [ ] Monitoreo (`NotificacionTarea/Index`) y Reporte de actividades: resumen, detalle, costo.
- [ ] Mis órdenes (`ProgramacionEmpleado`): iniciar/detener tiempo, una sola tarea abierta, OT no asignada rechazada.
- [ ] Mensajes de error y paginador ("Mostrando x - y de n") en pantallas no tocadas (vienen del nuevo helper.js).

## Qué se hizo

### Base visual (afecta a toda la app)
- `wwwroot/css/site.css`, `wwwroot/js/helper.js`, `wwwroot/js/constantes.js` copiados de main (superconjunto de agchavin).
- Nuevos: `Views/Shared/_PieModalCatalogo.cshtml`, `Commons/RespuestaValidacion.cs`,
  `wwwroot/js/columnas.js`, `wwwroot/libs/sortablejs/Sortable.min.js` (añadidos al `_Layout`).

### Catálogos de Administración (23)
- Vistas Index/_Nuevo/_Editar de main, sin "EN USO"/avisos de uso (backend inexistente).
- Sin campo `Codigo` en CausaFalla, Impacto, MecanismoFalla, MetodoDeteccion (requiere migración en main).
- Empleado sin vínculo a usuario. Material conserva precio; Sistema/Parte conservan agrupador.
- Controladores: `RespuestaValidacion.Errores/CallBack`, acción `BuscarCodigo` (solo lectura).
- `SistemaFiltro.Agrupador` + filtro en repositorio; `ServicioFiltro.Ids`; `ISocioNegocioServicio.BuscarPorIdAsync(id, empresaId)`.

### Gestión
- Listas con diseño de main: ArbolJerarquico, Aviso Index/MisAvisos, Equipo, HojaRuta, OrdenTrabajo,
  PlanMantenimiento, Seccion, Ubicacion.
- `ResumirAsync` (DTO + repositorio + lógica + servicio) para Equipo, Ubicacion, PlanMantenimiento, HojaRuta,
  Seccion; `Listar` acepta `conResumen` (sin él la respuesta es la de antes).
- Árbol: controlador con `expandir` e `inactivos`; `_Generar` de main con `OrderBy(x => x.Orden)` restaurado.
- Avisos: `AvisoFiltro.PrioridadId` y `UsuarioNombre` + repositorio.
- Selectores `Equipo/_Seleccionar`, `Seccion/_Seleccionar`, `PlanMantenimiento/_Seleccionar` (carga/escape),
  `ContadorHistorial/_Ver` (gráfico), `Aviso/Gestionar` (select2), `Aviso/Ver` (fecha de registro).

### Columnas configurables (Avisos, Mis avisos, Órdenes)
- Backend de main: `ListaConfigurable`, `CatalogoColumnas`, `ConfiguracionLista`, `VistaLista`, `UsuarioLista`,
  configs, repositorios, `VistaListaLogica`, `ExcelColumnas`, `VistaListaController` (acceso con la regla de
  `FiltroAccion`, sin `SinAutorizacion`), `_ConfigurarColumnas`.
- Catálogo de Órdenes adaptado: predeterminada = columnas de agchavin; sin codigoExterno/finProgramado/liberado.
- `OrdenTrabajoModel.Listar` ampliado con prioridad, centro de costo, cuenta contable, OT padre, valores del plan,
  valor de ejecución, fecha de lanzamiento, detenido y tareas (para el avance).

### Logística (completa desde main)
- Backend y vistas de main (anulación, traslados, bloqueo transaccional de inventario, exportaciones).
- Sin `[ExigeElemento]` ni `Html.Elemento(...)`: Anular lo ve quien tiene acceso a la pantalla.
- `Almacen.Activo` incluido (migración) y regla "no desactivar con stock".

### Ficha de Equipo: pestaña "Órdenes y Avisos" (2026-10-30, sin commit)
- De `be8869b` de main: acción `EquipoController.OrdenesAvisos` (10 últimas OT y 10 últimos avisos, vía
  `ListarPorPaginaAsync` con `EquipoId`) y `Equipo/_OrdenesAvisos.cshtml` copiado tal cual.
- `Equipo/Ver` de agchavin: nueva pestaña `#tab-9` que se carga al abrirla (`data-cargar`/`data-destino`,
  script en `@section Scripts` igual al de main). El resto de la ficha de agchavin no cambia.

### Órdenes de trabajo: sin estado PROGRAMADO, con `PuedeEjecutar` (2026-10-30, sin commit)
Igual que main: la planificación se hace en Nuevo/Editar y la vista/acción **Programar se eliminó**.
- `EstadoOrdenTrabajo`: `PROGRAMADO = 1` comentado; valores explícitos (EMITIDO 0, CIERRE_TECNICO 2, CIERRE_TOTAL 3, ANULADO 4).
- `OrdenTrabajo`: `FinProgramado` y `PuedeEjecutar`. `PuedoNotificar = Estado <= CIERRE_TECNICO && PuedeEjecutar`;
  `EstadosHabilitados`: EMITIDO → CIERRE_TECNICO / ANULADO. Sin `PuedoProgramar`.
- `OrdenTrabajoLogica`: `GuardarAsync(entidad, usuarioId)` guarda tareas/materiales/servicios/empleados/socios;
  `ActualizarAsync` absorbe lo que hacía `ProgramarAsync` (eliminado). Se conservan las horas normal/extra de
  empleados y socios (main las quitó). El avance de las tareas (`Ejecutado`) ya no se pisa al editar.
  Corregido `existeCierre` (comparaba `_.Estado` en vez del estado del log).
- Controlador: `Validar` exige inicio programado (salvo ANULADO), valida fin ≥ inicio y horas ≥ 0;
  no deja borrar tareas con notificaciones de tiempo (`ContarNotificacionesPorTareaAsync`).
- Vistas Nuevo/Editar de main, sin Código Externo y con columnas NORMAL/EXTRA. Lista: sin botón Programar,
  ícono "En ejecución" = EMITIDO + PuedeEjecutar; columnas opcionales "Fin prog." y "Puede ejecutar".
- Equivalencia aplicada en el resto (antes PROGRAMADO ⇒ ahora EMITIDO + PuedeEjecutar):
  API móvil `Guardar` (EMITIDO + PuedeEjecutar), WebAPI notificación de materiales/socios (`PuedoNotificar`),
  filtro `PuedeInspeccionar`, "en ejecución" del dashboard, Excel de planificación (amarillo),
  reporte Preventivo (`ExcluirEmitidasSinEjecutar`), listas de estados en Avisos/Planes/Reportes,
  checkbox PROGRAMADO quitado de los reportes Costo y Tarea, color del dashboard.
- Migración `20261030152417_OrdenTrabajo_AgregarProgramacion` (columnas `finprogramado`, `puedeejecutar`,
  sin conversión de datos), **aplicada en localhost**.

**Datos (los hace el usuario):** las órdenes en estado 1 deben pasar a `estado = 0, puedeejecutar = true`.
Ojo: también las que están en CIERRE TÉCNICO quedan con `puedeejecutar = false` tras la migración y **no se
podrán notificar** hasta marcarlas (`PuedoNotificar` lo exige). Los logs con estado 1 se muestran como "1"
en vistas Razor (en JS siguen como PROGRAMADO por `constantes.js`).

### Monitoreo de actividad y Programación de empleados (2026-10-30, sin commit)
Traído de main (commits `4d5f274`, `f88c868`, `722013a`). **No requiere migración**: la tabla
`notificaciontarea`, `usuario.empleadoid` y `empleado.costoporhora` ya existían.
- Pantallas:
  - `/Gestion/NotificacionTarea/Index`: monitoreo; cada empleado activo con su tarea en curso o la última.
  - `/Gestion/NotificacionTarea/Reporte` (+ `_Reporte`): rango de fechas y empleado opcional; resumen por
    empleado y detalle empleado × OT (actividades, horas de tareas, horas notificadas, costo = horas × costo/hora).
  - `/Gestion/ProgramacionEmpleado/Index`: "Mis órdenes de trabajo" del empleado vinculado al usuario
    (EMITIDO + Puede ejecutar, de sus organizaciones) y la tarea que tiene en ejecución.
  - `/Gestion/ProgramacionEmpleado/Editar/{id}`: cronómetro por tarea (`IniciarTarea` / `DetenerTarea`, POST sin
    `FiltroAccion`); solo si la OT está asignada al empleado; muestra solo sus propios tiempos. Una sola tarea
    abierta por empleado.
- Backend:
  - Filtros: `NotificacionTareaFiltro` (EmpleadoId, OrdenTrabajoTareaId, Desde, Hasta),
    `ProgramacionEmpleadoFiltro` (EmpleadoId, OrganizacionIds, Estado, PuedeEjecutar),
    `NotificacionEmpleadoFiltro` (Desde, Hasta).
  - Repositorios: `NotificacionTareaRepositorio` (tarea abierta, en ejecución, monitoreo, reporte; se mantiene el
    nombre de archivo `NotificacionTarea.Repositorio.cs`), `ProgramacionEmpleadoRepositorio` (`ListarOrdenesAsync`,
    `ExisteAsignacionAsync`), `NotificacionEmpleadoRepositorio` (rango de fechas), `OrdenTrabajoTareaRepositorio`
    (`ListarSinOrdenAsync`, include de Sección), todos iguales a main.
  - Nuevos `INotificacionTareaServicio`/`NotificacionTareaLogica` y `IProgramacionEmpleadoServicio`/
    `ProgramacionEmpleadoLogica`, registrados en `Program.cs`. `INotificacionEmpleadoServicio.EliminarAsync` agregado.
  - `NotificacionTareaController.cs` de agchavin (solo `Calcular`) reemplazado por `NotificacionTarea.Controller.cs`
    de main (incluye `Calcular`). Nuevo `ProgramacionEmpleado.Controller.cs`, modelos y 5 vistas de main
    (las vistas llevan `@using AMSYS.WebAdmin.Areas.Gestion.Models` porque el `_ViewImports` de agchavin no lo tiene).
- Duplicado conocido: `IOrdenTrabajoServicio.ContarNotificacionesPorTareaAsync` (agchavin) y
  `INotificacionTareaServicio.ContarPorTareaAsync` (main) hacen lo mismo; se dejaron los dos.

**Pendiente para usarlas:**
1. **Permisos:** dar de alta en Seguridad → Página las 4 páginas (Área `Gestion`; `NotificacionTarea`/`Index`,
   `NotificacionTarea`/`Reporte`, `ProgramacionEmpleado`/`Index`, `ProgramacionEmpleado`/`Editar`), los menús
   (`/Gestion/NotificacionTarea/Index`, `/Gestion/NotificacionTarea/Reporte`, `/Gestion/ProgramacionEmpleado/Index`)
   y asignarlos a los roles. Sin eso `FiltroAccion` responde 401. Volver a iniciar sesión para recargar permisos.
2. **Vínculo usuario ↔ empleado:** en agchavin no hay pantalla para llenar `usuario.empleadoid` (en main se elige
   el usuario desde la ficha del Empleado). Mientras no se porte, llenarlo por SQL; sin vínculo, "Mis órdenes"
   sale vacío y Editar responde "No tienes asignada esta orden de trabajo".
3. La OT debe tener al empleado en la pestaña Empleados (programación) y estar EMITIDO + Puede ejecutar.
4. Igual que en main: guardar Notificar de la OT reemplaza la lista de tiempos con lo que envía el formulario; un
   cronómetro iniciado mientras alguien tiene abierto Notificar se borraría al guardar.
5. No portado: API móvil de main (`Api/Controllers/NotificacionTareaController`, `NotificacionEmpleadoController`
   con sus requests/validators).

### Ficha de OT (`OrdenTrabajo/Ver`) (2026-10-31, sin commit)
- Restaurado el script de main que muestra/oculta las notificaciones de cada tarea (`a.colapsar`); los enlaces ya
  estaban pero no hacían nada. Quitado un `console.log(id)` suelto.

### Migración
- `AMSYS.Contextos/Migrations/20261020022722_VistaLista_Crear_Almacen_AgregarActivo`:
  tablas `vistalista`, `usuariolista` y columna `almacen.activo` (default `true`).

## No portado (y por qué)

| Qué | Motivo |
|---|---|
| Formularios/fichas de Equipo, Ubicación, Plan, Sección, Hoja de ruta, Órdenes (Nuevo/Editar/Ver) | Contratos de backend distintos y lógica de negocio (posiciones del ciclo, asignación en bloque, adjuntos temporales). Riesgo sobre la lógica propia de agchavin (posición absoluta en contadores). |
| Seguridad (Empresa, Rol, Usuario, Menú, Organización, Página) | ~~Depende de licencias, perfiles, claves temporales, catálogo de elementos (migraciones de main).~~ **Portada el 2026-10-31** en `PORTE-SEGURIDAD-MAIN-AGCHAVIN.md`. |
| Reportes | Sin mejora visual; agchavin tiene más funciones (indicadores globales, Preventivo, PorEstado). |
| Kanban, Paradas, "Generar órdenes", API móvil de NotificacionTarea/NotificacionEmpleado | Son funciones nuevas, no UI. |
| Vínculo usuario ↔ empleado en la ficha de Empleado | Necesario para Programación de empleados; pendiente. |
| Columna "EN USO" de catálogos y avisos de uso | Requiere `IUsoCatalogoServicio` de main. |
| `Ubicacion/_Seleccionar`, `Equipo/_SeleccionarUno` de main | Cambian la forma de los datos devueltos / el filtro de montados: rompen a sus llamadores. |
| Permisos de Rol (`a02662f`, `Rol/_Permisos.cshtml`) | ~~Parte de Seguridad (no portada).~~ Portado el 2026-10-31 con Seguridad. |

Si se retoma alguno, hacerlo módulo por módulo, comparando el controlador y el modelo de main contra los de
agchavin antes de traer la vista.

## Herramientas usadas

Scripts auxiliares (en el scratchpad de la sesión, no en el repo): verificación de vistas portadas
(endpoints, ViewBag, parciales, propiedades de filtros), conversión de listas, inserción de `ResumirAsync`.
Comandos útiles para revisar:

```
git diff --stat                      # alcance de los cambios
git diff agchavin main -- <ruta>     # comparar una vista/controlador entre ramas
dotnet build AMSYS.sln
dotnet ef migrations has-pending-model-changes -p AMSYS.Contextos -s AMSYS.WebAdmin
```
