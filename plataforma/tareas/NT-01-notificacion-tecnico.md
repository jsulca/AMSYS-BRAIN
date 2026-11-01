# NT-01 · Notificación del técnico (play/pause, materiales, servicios, parámetros, ejecución)

- **Estado**: ✅ **completa** — NT-01a (2026-10-03) · NT-01b, NT-01c y NT-01d (2026-10-04, D-NT-07…10)
- **Creada**: 2026-10-03
- **Legacy**: `D:\Documentos\Alphamanufacturas\AMSYS\AMSYS` (rama `main`)

## 1. Qué hace el legacy

### Pantalla `Gestion/OrdenTrabajo/Notificar` (web, 1532 líneas) y API móvil

Pestañas: **General** · **Planificado y programado** (tareas, sólo lectura) · **Notificar** · **Parámetros** ·
**Ejecución** · **Adjuntos**. Un solo botón guarda todo (`POST Notificar` → `OrdenTrabajoLogica.NotificarAsync` y
luego `OrdenTrabajoCostoServicio.CalcularAsync`).

| Paso | Legacy | Fuente |
|------|--------|--------|
| **Tareas con tiempo (play/pause)** | `NotificacionTarea` (OT, tarea, empleado, `Inicio`, `Fin?`, `Duracion` en horas). **Iniciar** crea un tramo abierto; **Detener** pone `Fin = ahora` y calcula la duración (4 decimales). Volver a iniciar crea **otro tramo** (así funciona la "pausa"). **Un solo tramo abierto por empleado** en toda la empresa ("Ya tienes una tarea en ejecución. Detén tu tiempo antes de iniciar otra"); iniciar la misma tarea abierta devuelve el tramo existente. Sólo si la OT está **asignada al empleado** (`ProgramacionEmpleado`). El usuario se vincula al empleado con `Usuario.EmpleadoId`. En la web el supervisor también puede agregar/editar tramos a mano (inicio, fin, duración con botón "calcular"), duplicar y eliminar; tareas agrupadas por sección | `NotificacionTarea.Logica.cs:55-127`, `Api/Controllers/NotificacionTareaController.cs:95-177` |
| Horas de empleados (sin tarea) | `NotificacionEmpleado` (empleado, fecha, duración) | `Notificar.cshtml:402` |
| Tareas hechas | Casilla "Ejecutado" por tarea → `TotalTareas`, `TotalTareasEjecutadas`, `EnEjecucion` | `OrdenTrabajo.Logica.cs:512-535` |
| **Materiales** | `NotificacionMaterial` (material del maestro, cantidad, precio, comprobante, fecha) y `NotificacionMaterialExterno` | `Notificar.cshtml:591` |
| **Servicios** | `NotificacionSocioNegocio` (proveedor, precio, fecha) y `…Externo` | `Notificar.cshtml:637` |
| **Parámetros** | Modales que registran: `NotificacionContador` (contador, muestra, valor), `NotificacionPuntoMedida`, `NotificacionEquipoAspecto` y `NotificacionUbicacionAspecto` (valor texto). Quedan **vinculados a la OT** y actualizan el valor actual del contador/punto/aspecto. Visible si `Estado <= CIERRE_TECNICO` | `Notificar.cshtml:679-790`, `Notificacion*.Logica.cs` |
| **Ejecución** | Inicio y fin de ejecución, **duración de todo el mantenimiento**, equipo detenido, estado. Si la OT viene de un plan: por **contador** → *Valor de ejecución* (reajusta `ContadorActual` del plan con la diferencia frente al contador real, BR-GE-010); por **calendario** → *Fecha de cierre del plan* (mueve `UltimaEjecucion` si es la última OT del plan). Ambos se bloquean una vez puestos / tras el cierre | `Notificar.cshtml:833-900`, `OrdenTrabajo.Logica.cs:682-740` |
| **Comentario y adjuntos** | Comentario (`OrdenTrabajoComentario` con usuario) y archivos (dropzone) | `OrdenTrabajo.Controller.cs:386-420` |
| Monitoreo | `NotificacionTarea/Index`: qué está haciendo cada empleado ahora; `Reporte`: horas por empleado y rango | `NotificacionTarea.Controller.cs` |
| Carga masiva | Excel de parámetros (contadores, puntos, aspectos) "por oportunidad" | `Notificacion.Logica.cs` |

Problemas del legacy a **no** copiar: el estado se cambia desde Notificar sin validar la máquina de estados
(BR-OT-004/MNT-003) y cerrar desde aquí no finaliza el aviso (MNT-007); 10 tablas de notificación distintas.

## 2. Qué tiene hoy la plataforma nueva

| Pieza | Estado |
|-------|--------|
| Mano de obra (empleado, tarea opcional, fecha, horas, costo/hora congelado) | ✅ `OrdenTrabajo` líneas `orden_trabajo_mano_obra` (D-NP-50/51). Se edita en la ficha de la OT (`NotificacionOrden.razor`), pensada para supervisor |
| Materiales y servicios (maestro o externo) | ✅ mismas pantallas |
| Salidas de almacén contra la OT | ✅ (logística) |
| Tareas hechas | ✅ casilla en la ficha |
| Contadores y puntos de medida | ✅ 2026-10-04: vinculados a la OT (D-NT-08) |
| Inicio/fin de ejecución, equipo detenido, observación | ✅ en la ficha (cabecera) |
| **Play/pause por tarea** | ✅ NT-01a |
| **Usuario ↔ empleado** | ✅ NT-01a (`Empleado.UsuarioId`) |
| **Asignación de técnicos a la OT** (`ProgramacionEmpleado`) | ✅ NT-01a |
| **Aspectos** (catálogo, aspectos por equipo/ubicación, historial) | ✅ 2026-10-04 (D-NT-07) |
| Valor de ejecución / fecha de cierre del plan (BR-GE-010) | ✅ 2026-10-04 al cierre técnico (D-NT-09) |
| Comentarios y adjuntos de OT | ✅ comentarios (D-NT-08) · ✅ adjuntos (D-AR-01, disco local) |
| Pantalla del técnico ("mis órdenes", móvil) | ✅ NT-01a |
| Monitoreo / reporte de horas | ✅ 2026-10-04 Mantenimiento → Técnicos (D-NT-10) |

**Al crear la tarea (2026-10-03) no existía el formulario del técnico**, sólo la notificación de escritorio (supervisor); hoy NT-01 está completa.

## 3. Propuesta

### Modelo (sin crear las 10 tablas del legacy)

- **Tramos de tiempo = líneas de mano de obra**: `ManoObra` gana `Inicio` y `Fin?` (hoy tiene `Fecha` y `Horas`).
  *Iniciar* crea una línea con `Fin = null` ("en curso"); *pausar/detener* la cierra y calcula `Horas` y el costo con el
  costo/hora del empleado en ese momento. Un tramo abierto por empleado en la empresa (índice único parcial
  `WHERE fin IS NULL`), igual que el legacy. Las líneas manuales del supervisor siguen funcionando igual.
- **Usuario ↔ empleado**: `Usuario.EmpleadoId` (opcional, único por empresa), editable en Usuarios.
- **Técnicos asignados a la OT**: lista de empleados en la OT (`orden_trabajo_tecnico`), editable por quien edita la OT.
  Sólo un técnico asignado puede usar play/pause en esa OT (regla del legacy).
- **Parámetros vinculados**: `LecturaContador` y `MedicionPuntoMedida` ganan `OrdenTrabajoId?` y el origen
  `OrdenTrabajo`; la OT lista "lecturas de esta orden".
- **Aspectos** (fase 2): catálogo `Aspecto` (abierto/cerrado con opciones), `AspectoEquipo`/`AspectoUbicacion` con
  valor actual e historial (con `OrdenTrabajoId?`).
- **Ejecución**: `ValorEjecucion` (plan por contador) y `FechaCierrePlan` (plan por calendario) con el efecto de
  BR-GE-010 al pasar a cierre técnico, en la misma transacción que libera la asignación.
- **Comentarios** de OT (texto + usuario + fecha). Adjuntos quedan para cuando exista almacenamiento de archivos.

### Pantalla del técnico (móvil primero) — `Mantenimiento → Mis órdenes`

Lista de OT asignadas al técnico (emitidas o en cierre técnico) con la tarea en curso arriba (cronómetro). Al abrir una
OT, un asistente en el orden del trabajo real:

1. **Tareas** — cada tarea con ▶ / ⏸, tiempo acumulado del técnico y del equipo de trabajo, casilla "hecha".
   Un aviso si ya tiene otra tarea en curso (con enlace para pausarla).
2. **Materiales y servicios** — agregar del maestro o externos (y ver salidas de almacén de la OT).
3. **Parámetros** — contadores, puntos de medida (con nivel de alarma) y aspectos del objeto técnico.
4. **Ejecución** — inicio/fin de ejecución (propuestos desde el primer y último tramo), valor de ejecución o fecha de
   cierre del plan si aplica, comentario, y **"Enviar a cierre técnico"** (con la máquina de estados del dominio y los
   permisos; no se cambia el estado "a mano" como en el legacy).

Permiso nuevo `mantenimiento.ordenes.ejecutar` (técnico) separado de `notificar` (supervisor), para que el técnico vea
sólo sus órdenes asignadas.

### Fases sugeridas

1. **NT-01a**: usuario↔empleado, técnicos asignados, tramos play/pause (dominio + API + tests de concurrencia: dos
   "iniciar" a la vez → un solo tramo), pantalla "Mis órdenes" con pasos 1, 2 y 4 (sin plan).
2. **NT-01b**: parámetros vinculados a la OT (contadores y puntos) en el paso 3; comentarios.
3. **NT-01c**: aspectos (catálogo + por equipo/ubicación) y valor de ejecución / fecha de cierre del plan (BR-GE-010).
4. **NT-01d**: monitoreo de técnicos en tiempo real y reporte de horas por empleado.

## 4. Decisiones (2026-10-03)

Respondidas por el propietario: 1 → **tramos con motivo opcional al pausar**; 2 → **sólo técnicos asignados**;
5 → **el técnico envía a cierre técnico si tiene el permiso**; 6 → **hay conexión en planta** (web Blazor Server).
Adoptadas por defecto (recomendación, se pueden cambiar): 3 → sólo el supervisor corrige tramos; 4 → sin cierre
automático de tramos abiertos.

### Preguntas originales

1. ¿La "pausa" basta con **cerrar el tramo y abrir otro** (como el legacy) o se quiere un estado *pausado* con motivo
   (almuerzo, espera de repuesto…)? Recomendación: tramos, y motivo opcional al pausar.
2. ¿Un técnico **sólo** puede notificar OT a las que está asignado (legacy) o cualquiera con el permiso?
   Recomendación: sólo asignadas.
3. ¿El técnico puede **corregir** a mano sus tramos (inicio/fin) o sólo el supervisor? Recomendación: sólo el supervisor.
4. ¿Qué pasa con un tramo que queda abierto al final del día? Recomendación: el supervisor lo ve en el monitoreo y lo
   cierra; sin cierre automático.
5. ¿El técnico puede **enviar a cierre técnico** o sólo dejar la OT "lista para cierre" y lo cierra el supervisor?
6. ¿Se necesita uso **sin conexión** en planta (la web es Blazor Server: necesita conexión permanente)? Si sí, eso es la
   app móvil (D-NP-04), no esta pantalla.

## Criterios de aceptación (NT-01a)

- [ ] Un técnico (usuario con empleado) ve sólo sus OT asignadas y puede iniciar/pausar tareas; un solo tramo abierto.
- [ ] Al pausar se crea la línea de mano de obra con horas y costo; los costos de la OT se actualizan.
- [ ] Registra materiales y servicios y los datos de ejecución; envía a cierre técnico respetando estados y permisos.
- [ ] Tests de dominio, de API (aislamiento por empresa/alcance, permisos, concurrencia) y build Release sin advertencias.

## Resultado NT-01a (2026-10-03)

- **Dominio**: `Empleado.UsuarioId` (único); `OrdenTrabajo.Tecnicos` (`orden_trabajo_tecnico`), `AsignarTecnicos`,
  `IniciarTramo`/`PausarTramo` (líneas de mano de obra con `Fin`, `EnCurso`, `MotivoPausa`), `RegistrarEjecucion`.
  Reglas: un tramo abierto por empleado (índice único parcial `en_curso` + verificación en la aplicación), tramo < 1 min
  se descarta, sin cierre técnico ni anulación con tiempos corriendo, no se quita a un técnico trabajando, la notificación
  del supervisor no toca los tramos en curso y sólo valida (≤ 24 h) líneas nuevas o cambiadas.
- **Permiso** `mantenimiento.ordenes.ejecutar` (D-NT-05). **API** `/mantenimiento/ejecucion` (mis órdenes, ver,
  iniciar, pausar, consumos, ejecución) y `PUT /mantenimiento/ordenes/{id}/tecnicos`; el cambio de estado acepta el
  cierre técnico del técnico asignado.
- **Migración** `NotificacionTecnico` (aplicada sólo en la BD de prueba `amsys_ui`; **no** en `amsys_dev`).
- **Web**: Mantenimiento → Mis órdenes (tarjetas, tiempo en curso con cronómetro), pantalla de la orden con barra de
  pasos (Tareas ▶/⏸ con diálogo de pausa · Materiales y servicios · Parámetros · Ejecución → Enviar a cierre técnico),
  técnicos asignados en la ficha de la OT, usuario del sistema en Empleados, tramos "En curso" en la notificación.
- Tests: 14 de dominio + 5 de API (incluye dos "play" simultáneos en órdenes distintas). Capturas en
  `plataforma/tareas/capturas/NT-01/`.

## Resultado NT-01b (2026-10-04, D-NT-08)

- **Dominio**: `LecturaContador.OrdenTrabajoId` y `MedicionPuntoMedida.OrdenTrabajoId` (origen `OrdenTrabajo`);
  `ComentarioOrden` (tabla `mantenimiento.orden_trabajo_comentario`). Migración `ParametrosYComentariosOrden`.
- **Aplicación**: `ObjetosTecnicos.ObjetosDeOrdenAsync` (equipo + montados, o ubicación) y `OrdenParaParametrosAsync`
  (orden emitida o en cierre técnico), compartidos por mediciones y aspectos; `ServicioMediciones.ContadoresDeOrdenAsync` /
  `PuntosDeOrdenAsync`; `ServicioComentariosOrden`.
- **API**: `RegistrarLecturaRequest.OrdenTrabajoId` en `POST /activos/contadores/{id}/lecturas` y
  `/activos/puntos-medida/{id}/mediciones`; `GET /mantenimiento/ordenes/{id}/contadores|puntos-medida` (permiso de
  órdenes); `GET|POST /mantenimiento/ordenes/{id}/comentarios`, `DELETE …/comentarios/{comentarioId}`.
- **Web**: `LecturasOrden.razor` (filas táctiles con "En esta orden", aviso si la medición sale de rango) en el paso
  "Parámetros" del técnico y en la ficha de la OT; `ComentariosOrden.razor` en la ficha (sección "Comentarios") y en el
  paso "Ejecución" del técnico.
- Tests: 3 de dominio + 2 de API (vinculación, equipo fuera de la orden, orden anulada, técnico sin `activos.ver`,
  comentarios por permiso/asignación, sólo el autor elimina, aislamiento por empresa).

## Resultado NT-01c (2026-10-04, D-NT-07 y D-NT-09)

- **Aspectos**: ver D-NT-07 (catálogo, por equipo/ubicación, inspección desde la OT). Su importación desde el legacy va
  con el importador de la ola 1.
- **Cierre del plan**: `OrdenTrabajo.ValorEjecucion` / `FechaCierrePlan` (migración `CierrePlanOrden`) fijados con
  `RegistrarCierrePlan` en el cambio a cierre técnico; `PlanAsignacion.ValidarDatosCierre` y
  `ReprogramarDesdeEjecucion`; `ServicioOrdenes.ReprogramarPlanAsync` (sólo la última OT de la asignación).
- **Web**: `CambiarEstadoDialogo` (devuelve `CambioEstado`) pide el dato del plan con valor propuesto en la ficha de la OT
  y en el paso "Ejecución" del técnico; la ficha muestra lo fijado junto al plan de origen.
- Tests: 1 de dominio y 2 de API (contador: valor mayor a la lectura, dato de otro tipo, reprogramación efectiva;
  calendario: fecha futura, orden no última con advertencia, reprogramación y bloqueo tras el cierre).

## Resultado NT-01d (2026-10-04, D-NT-10)

- **Dominio**: `OrdenTrabajo.PausarTramo(..., finUtc)` para que el supervisor cierre con la hora real.
- **Aplicación/API**: `ServicioTecnicos` → `GET /mantenimiento/tecnicos/monitoreo`, `POST /mantenimiento/tecnicos/{empleadoId}/cerrar-tramo`,
  `GET /mantenimiento/tecnicos/horas?desde&hasta[&empleadoId]` y `/horas/excel`.
- **Web**: Mantenimiento → Técnicos (`Tecnicos.razor`, `CerrarTramoDialogo.razor`).
- Tests: 1 de dominio y 1 de API (monitoreo, tramo de otro día, hora de fin inválida, horas y costo, Excel, rango
  inválido, aislamiento por empresa y permiso).
