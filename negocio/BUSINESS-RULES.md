# Reglas de Negocio – Módulo de Mantenimiento (AMSYS)

> **Sólo reglas identificadas en el código.** No se inventan reglas.
> Cuando una regla no puede determinarse se documenta como `UNKNOWN` con su motivo.

## Niveles de confianza

| Nivel | Significado |
|-------|-------------|
| `CONFIRMED` | Verificada leyendo el código que la implementa. Se cita archivo y línea. |
| `INFERRED` | El código sugiere la regla pero no la impone explícitamente, o hay ambigüedad. |
| `UNKNOWN` | No se pudo determinar. Requiere decisión del propietario (ver `CURRENT-STATE.md`). |

> [!CAUTION]
> Una regla `CONFIRMED` describe **lo que el sistema hace**, no necesariamente lo que *debería*
> hacer. Varias reglas confirmadas son a la vez problemas identificados (columna *Ver*).

> [!NOTE]
> **Decisiones del propietario aplicadas el 2026-08-29** (`D-02`, `D-03`, `D-05`).
> Las reglas afectadas llevan la marca 🟢 **DECIDIDA** e indican qué decisión las respalda.
> Una regla marcada así deja de ser una observación del análisis y pasa a ser **intención de negocio
> declarada**: no debe "corregirse" sin una nueva decisión.

---

## A. Hoja de Ruta

### BR-HR-001 — La Hoja de Ruta es un agrupador simple sin ciclo de vida
- **Entidad**: `HojaRuta`
- **Condición**: siempre
- **Comportamiento**: `HojaRuta` sólo tiene `Codigo`, `Descripcion`, `Activo` y una colección de
  `Secciones`. No tiene estados, ni fechas, ni versiones, ni relación con `PlanMantenimiento`.
- **Evidencia**: `AMSYS.Entidades/Gestion/Genericos/HojaRuta.cs:6-17`
- **Confianza**: `CONFIRMED`

### BR-HR-002 — Una Hoja de Ruta no se puede eliminar; sólo desactivar
- **Entidad**: `HojaRuta`
- **Comportamiento**: `HojaRutaController` expone `Index`, `Nuevo`, `Editar`, `Ver`, `Listar`.
  **No existe acción `Eliminar`** ni método `EliminarAsync` en `HojaRutaLogica`.
- **Evidencia**: `AMSYS.WebAdmin/Areas/Gestion/Controllers/HojaRuta.Controller.cs`,
  `AMSYS.Logicas/Gestion/HojaRuta.Logica.cs`
- **Confianza**: `CONFIRMED`

### BR-HR-003 — Desactivar una Hoja de Ruta oculta sus secciones del buscador
- **Condición**: `SeccionFiltro.HojaRutaActivo == true`
- **Comportamiento**: filtra `!x.HojaRutaId.HasValue || x.HojaRuta!.Activo`. Es decir, las
  secciones sin hoja de ruta **siempre** se muestran; las que tienen hoja de ruta sólo si está activa.
- **Evidencia**: `AMSYS.Repositorios/Gestion/Seccion.Repositorio.cs` (`AgregarFiltros`)
- **Alcance**: sólo se aplica en `SeccionLogica.BuscarAsync` (API móvil). El modal
  `_Seleccionar` del WebAdmin usa `filtro.Activo = true` pero **no** `HojaRutaActivo`, así que ahí
  sí aparecen secciones de hojas de ruta inactivas.
- **Confianza**: `CONFIRMED` — inconsistencia documentada en `analysis/orders.md`

---

## B. Sección

### BR-SE-001 — Una Sección puede existir sin Hoja de Ruta
- **Entidad**: `Seccion`
- **Comportamiento**: `HojaRutaId` es `int?`. La validación que lo exigía está **comentada** en el
  controlador: `//if (!entidad.HojaRutaId.HasValue) ModelState.AddModelError(...)`.
  La vista ofrece explícitamente la opción `NINGUNO`.
- **Evidencia**: `AMSYS.Entidades/Gestion/Genericos/Seccion.cs:9`;
  `AMSYS.WebAdmin/Areas/Gestion/Controllers/Seccion.Controller.cs` (`Validar`, línea comentada);
  `Areas/Gestion/Views/Seccion/Nuevo.cshtml` (`<option value="">NINGUNO</option>`)
- **Confianza**: `CONFIRMED`
- **Nota**: esto **rompe la jerarquía conceptual** Plan → Hoja de Ruta → Sección → Tarea.

### BR-SE-002 — Una Sección pertenece a una sola Hoja de Ruta (0..1)
- **Comportamiento**: relación `HasOne(x => x.HojaRuta).WithMany(x => x.Secciones)` con FK escalar
  única. No hay tabla intermedia.
- **Evidencia**: `AMSYS.Configuraciones/Gestion/Seccion.Config.cs`
- **Confianza**: `CONFIRMED`

### BR-SE-003 — Al actualizar una Sección se borran y recrean TODAS sus tareas, materiales y servicios
- **Condición**: cualquier `POST /Gestion/Seccion/Editar`
- **Comportamiento**: `SeccionLogica.ActualizarAsync` hace `GetAllBy(SeccionId) → Remove(todos)` y
  luego `Save(los del request)` para `Tarea`, `SeccionMaterial` y `SeccionServicio`.
  Consecuencia: **los `Tarea.Id` cambian en cada guardado**.
- **Evidencia**: `AMSYS.Logicas/Gestion/Seccion.Logica.cs:26-72`
- **Confianza**: `CONFIRMED`
- **Ver**: `MNT-014`

### BR-SE-004 — Los adjuntos de una Sección sólo se pueden agregar, nunca quitar
- **Comportamiento**: en `ActualizarAsync`, el bloque de `Adjuntos` sólo hace `Save(...)` de los
  nuevos. No hay `Remove` ni comparación con los existentes.
- **Evidencia**: `AMSYS.Logicas/Gestion/Seccion.Logica.cs:74-79`
- **Confianza**: `CONFIRMED`
- **Ver**: `MNT-014`

### BR-SE-005 — Una Sección no se puede eliminar; sólo desactivar
- **Comportamiento**: no existe acción `Eliminar` en `SeccionController` ni `EliminarAsync` en
  `SeccionLogica`.
- **Confianza**: `CONFIRMED`

### BR-SE-006 — Una Sección se puede duplicar como plantilla
- **Condición**: `GET /Gestion/Seccion/Nuevo?id=N`
- **Comportamiento**: carga la sección `N` con tareas/materiales/servicios/adjuntos y pone
  `_.Id = 0`, produciendo una copia editable. El `Codigo` **no** se modifica → se puede crear un
  duplicado exacto de código.
- **Evidencia**: `AMSYS.WebAdmin/Areas/Gestion/Controllers/Seccion.Controller.cs` (acción `Nuevo`)
- **Confianza**: `CONFIRMED`

---

## C. Tarea

### BR-TA-001 — Una Tarea pertenece obligatoriamente a exactamente una Sección
- **Comportamiento**: `Tarea.SeccionId` es `int` no anulable, FK a `Seccion`.
  No existe forma de crear una tarea fuera de una sección: sólo se persiste desde
  `SeccionLogica.GuardarAsync` / `ActualizarAsync`.
- **Evidencia**: `AMSYS.Entidades/Gestion/Genericos/Tarea.cs:9`;
  `AMSYS.Configuraciones/Gestion/Tarea.Config.cs`
- **Confianza**: `CONFIRMED`
- **Corolario verificado**: *"Una Tarea no puede pertenecer a dos Secciones"* → **CIERTO**.

### BR-TA-002 — La Tarea no tiene estado activo/inactivo
- **Comportamiento**: `Tarea` no tiene propiedad `Activo`. Su único ciclo de vida es existir o ser
  borrada por BR-SE-003.
- **Evidencia**: `AMSYS.Entidades/Gestion/Genericos/Tarea.cs`
- **Confianza**: `CONFIRMED`

### BR-TA-003 — Campos obligatorios de una Tarea
- **Comportamiento** (validado en el controlador, no en BD):
  - `TipoTareaId > 0`
  - `EspecialidadId > 0`
  - `Descripcion` no vacía
  - `Cantidad > 0`
  - `Duracion > 0`
  - `SistemaId`, `ParteId`, `TextoAmpliado` → opcionales
  - `Orden` → **no se valida** (puede ser 0, negativo o duplicado)
- **Evidencia**: `AMSYS.WebAdmin/Areas/Gestion/Controllers/Seccion.Controller.cs`
  (`Validar(SeccionModel.Nuevo)` y `Validar(SeccionModel.Editar)`)
- **Confianza**: `CONFIRMED`

### BR-TA-004 — El orden de ejecución de las tareas se respeta al generar la OT
- **Comportamiento**: al copiar tareas de sección a `OrdenTrabajoTarea` se aplica
  `.OrderBy(x => x.Orden)`.
- **Evidencia**: `AMSYS.Logicas/Gestion/PlanMantenimiento.Logica.cs` (`GenerarOrdenesPorEquipo`
  y `GenerarOrdenesPorUbicacion`)
- **Confianza**: `CONFIRMED`
- **Riesgo**: cuando una posición ejecuta **varias** secciones, las tareas se ordenan sólo por
  `Orden` global, mezclando tareas de distintas secciones. No hay orden entre secciones.

### BR-TA-005 — `Parte` debe pertenecer al `Sistema` de la tarea
- **Confianza**: `UNKNOWN`
- **Motivo**: la UI carga las partes filtradas por `SistemaIds` de las tareas
  (`Seccion.Controller.Editar`), pero **el POST no revalida** que `ParteId` pertenezca a `SistemaId`.
  Se desconoce si la restricción es intencional o un olvido.

---

## D. Plan de Mantenimiento

### BR-PM-001 — El Plan se relaciona con Secciones, NO con Hojas de Ruta
- **Comportamiento**: `PlanMantenimiento` tiene `List<PlanMantenimientoSeccion> Secciones`.
  **No existe ninguna FK ni navegación a `HojaRuta`.**
- **Evidencia**: `AMSYS.Entidades/Gestion/Genericos/PlanMantenimiento.cs`;
  `AMSYS.Entidades/Gestion/Genericos/PlanMantenimientoSeccion.cs`
- **Confianza**: `CONFIRMED`
- **Impacto**: el modelo conceptual `Plan → Hoja de Ruta → Sección → Tarea` **no corresponde a la
  implementación**. Ver `DOMAIN-MODEL.md`.

### BR-PM-002 — Relación Plan ↔ Sección es N:M con metadata propia
- **Comportamiento**: `PlanMantenimientoSeccion` lleva `PrioridadId`, `TipoMantenimientoId`,
  `TallerResponsableId`, `EquipoDetenido`, `Intervalo` y `Nivel`. Es decir, la *misma* sección
  puede participar en varios planes con parámetros distintos.
- **Evidencia**: `AMSYS.Entidades/Gestion/Genericos/PlanMantenimientoSeccion.cs`
- **Confianza**: `CONFIRMED`

### BR-PM-003 — Cálculo de `CantidadPosiciones`
- **Comportamiento**:
  - Si `Rutina == true`  → `CantidadPosiciones = max(Secciones.Intervalo)`
  - Si `Rutina == false` → `CantidadPosiciones = MCM / Intervalo`,
    donde el controlador calcula `MCM = mcm(Secciones.Intervalo) * Intervalo`
- **Evidencia**: `AMSYS.Logicas/Gestion/PlanMantenimiento.Logica.cs:31-34` y `:88-90`;
  `AMSYS.WebAdmin/Areas/Gestion/Controllers/PlanMantenimiento.Controller.cs`
  (`_.MCM = NumeroUtilitario.MCM(...) * _.Intervalo`)
- **Confianza**: `CONFIRMED`
- **Riesgo**: con 0 secciones y `Rutina == false`, `MCM([]) == 0` → `CantidadPosiciones == 0` →
  el plan queda inutilizable (ver `MNT-012`).

### BR-PM-004 — Terminología: `Rutina = true` se muestra como "Estático"
- **Comportamiento**: la grilla muestra `Rutina ? "Estático" : "Dinámico"`; el switch de la vista
  etiqueta *Dinámico* a la izquierda y *Estático* a la derecha del checkbox `Rutina`.
- **Evidencia**: `Areas/Gestion/Controllers/PlanMantenimiento.Controller.cs` (`Listar`);
  `Areas/Gestion/Views/PlanMantenimiento/Nuevo.cshtml`
- **Confianza**: `CONFIRMED`
- **Nota UX**: tres nombres (`Rutina`, `Estático`, `Dinámico`) para un único concepto, sin ayuda
  contextual. Ver `analysis/ux.md`.

### BR-PM-005 — Qué secciones se ejecutan en cada posición
- **Comportamiento**: para la posición `p`:
  1. `frecuencia = (p + 1) * plan.Intervalo`
  2. aplican las secciones donde `frecuencia % (seccion.Intervalo * plan.Intervalo) == 0`
  3. si aplica más de una, **sólo se conservan las de mayor `Nivel`** (absorción)
- **Evidencia**: `AMSYS.Entidades/Gestion/Adicionales/PlanMantenimiento.Adicional.cs:24-77`
- **Confianza**: `CONFIRMED`

### BR-PM-006 — La cabecera de la OT generada toma los datos de la sección de MAYOR intervalo
- **Comportamiento**: `planMantenimientoSeccion = planMantenimientoSecciones.OrderByDescending(x => x.Intervalo).First();`
  De ahí salen `PrioridadId`, `TipoMantenimientoId`, `TallerResponsableId`, `Detenido` y la
  `Descripcion` de la OT (= `Seccion.Nombre`).
- **Evidencia**: `AMSYS.Logicas/Gestion/PlanMantenimiento.Logica.cs` (ambos `GenerarOrdenes…`)
- **Confianza**: `CONFIRMED`
- **Nota**: el criterio de selección en el paso BR-PM-005 es `Nivel`, pero aquí es `Intervalo`.
  Son dos criterios distintos aplicados en cadena.

### BR-PM-007 — Todas las secciones de la posición aportan tareas, materiales y servicios
- **Comportamiento**: aunque la cabecera venga de una sola sección (BR-PM-006), las
  `OrdenTrabajoTarea`, `OrdenTrabajoMaterial` y `ProgramacionServicio` se copian de **todas** las
  secciones de esa posición (`seccionIds.Contains(x.SeccionId)`).
- **Evidencia**: `AMSYS.Logicas/Gestion/PlanMantenimiento.Logica.cs` (ambos `GenerarOrdenes…`)
- **Confianza**: `CONFIRMED`

### BR-PM-008 — La UMS de un Plan es inmutable después de crearlo
- **Comportamiento**: la vista `Editar` renderiza la UMS como `readonly` y
  `PlanMantenimientoModel.Editar.Get()` **no mapea** `UnidadMedidaServicioId`;
  `PlanMantenimientoLogica.ActualizarAsync` tampoco lo asigna.
- **Evidencia**: `Areas/Gestion/Views/PlanMantenimiento/Editar.cshtml`;
  `Areas/Gestion/Models/PlanMantenimiento.Model.cs`;
  `AMSYS.Logicas/Gestion/PlanMantenimiento.Logica.cs:16-53`
- **Confianza**: `CONFIRMED` (comportamiento), `INFERRED` (intencionalidad)
- **Riesgo latente**: el no-mapeo es accidental, no explícito. Ver `MNT-015`.

### BR-PM-009 — Validación del Factor de Planificación
- **Comportamiento**:
  - UMS `CALENDARIO`: `FactorPlanificacion <= intervalo * díasSegúnTipoCalendario`
    (DIA=1, SEMANA=7, MES=30, ANIO=365)
  - UMS `CONTADOR`: `FactorPlanificacion <= Intervalo`
  - Siempre: `FactorPlanificacion >= 0` e `Intervalo > 0`
- **Evidencia**: `Areas/Gestion/Controllers/PlanMantenimiento.Controller.cs`
  (`Validar(decimal, decimal, UnidadMedidaServicio?)`)
- **Confianza**: `CONFIRMED`

### BR-PM-010 — Un Plan no se puede eliminar; sólo desactivar
- **Comportamiento**: no existe acción `Eliminar`. `Activo == false` excluye el plan de
  `ListarParaProgramar` (filtro `Activo = true`).
- **Confianza**: `CONFIRMED`

### BR-PM-011 — Al actualizar un Plan se borran y recrean todas sus `PlanMantenimientoSeccion`
- **Comportamiento**: mismo patrón *delete-all + re-insert* que BR-SE-003.
- **Evidencia**: `AMSYS.Logicas/Gestion/PlanMantenimiento.Logica.cs:36-49`
- **Confianza**: `CONFIRMED`
- **Riesgo**: cambiar `Intervalo` de una sección altera `CantidadPosiciones`, pero
  `PlanMantenimientoEquipo.PosicionActual` **no se recalcula ni se valida** contra el nuevo valor.
  Ver `MNT-016`.

---

## E. Asignación del Plan a objetos técnicos

### BR-AS-001 — Un Plan se asigna a Equipos y/o a Ubicaciones, nunca a Secciones directamente
- **Comportamiento**: `PlanMantenimientoEquipo` y `PlanMantenimientoUbicacion` son las tablas de
  asignación. Cada fila lleva su propio estado de avance (`PosicionActual`, `ContadorActual`,
  `UltimaEjecucion`, `Bloqueado`).
- **Evidencia**: entidades homónimas en `AMSYS.Entidades/Gestion/Genericos/`
- **Confianza**: `CONFIRMED`

### BR-AS-002 — No se puede asignar dos veces el mismo Equipo al mismo Plan
- **Comportamiento**: el controlador cuenta `(PlanMantenimientoId, EquipoId)` y rechaza si existe.
- **Evidencia**: `Areas/Gestion/Controllers/PlanMantenimientoEquipo.Controller.cs` (`Nuevo` POST)
- **Confianza**: `CONFIRMED`
- **Riesgo**: es un *check-then-act* sin índice único → dos peticiones concurrentes crean duplicados.

### BR-AS-003 — La misma validación NO existe para Ubicaciones
- **Comportamiento**: `PlanMantenimientoUbicacionController.Nuevo` no hace el chequeo de duplicado.
- **Evidencia**: `Areas/Gestion/Controllers/PlanMantenimientoUbicacion.Controller.cs`
- **Confianza**: `CONFIRMED`
- **Ver**: `MNT-017`

### BR-AS-004 — Rango válido de `PosicionInicio`
- **Comportamiento**: `0 <= PosicionInicio < PlanMantenimiento.CantidadPosiciones`
- **Evidencia**: `Validar(model, planMantenimiento)` en ambos controladores de asignación
- **Confianza**: `CONFIRMED`

### BR-AS-005 — Rango válido de `ContadorInicio` (planes por CONTADOR)
- **Comportamiento**:
  `Intervalo * PosicionInicio <= ContadorInicio <= Intervalo * PosicionInicio + Intervalo`
  y `ContadorInicio` es obligatorio.
- **Evidencia**: `Areas/Gestion/Controllers/PlanMantenimientoEquipo.Controller.cs`
- **Confianza**: `CONFIRMED`

### BR-AS-006 — `Inicio` debe ser hoy o futuro (planes por CALENDARIO)
- **Comportamiento**: `Inicio >= DateTime.Today`, validado **tanto al crear como al editar**.
- **Evidencia**: `Validar(...)` en `PlanMantenimientoEquipo.Controller.cs`
- **Confianza**: `CONFIRMED`
- **Consecuencia práctica**: editar cualquier otro campo (p.ej. `TipoProgramacion`) de una
  asignación antigua **obliga** a mover la fecha de inicio al futuro. Ver `analysis/ux.md`.

### BR-AS-007 — Editar una asignación REINICIA el ciclo de mantenimiento
- **Comportamiento**: `ActualizarAsync` fija
  `PosicionActual = PosicionInicio`, `ContadorActual = ContadorInicio`, `UltimaEjecucion = null`.
  **No** modifica `Bloqueado`.
- **Evidencia**: `AMSYS.Logicas/Gestion/PlanMantenimientoEquipo.Logica.cs:10-34`;
  `AMSYS.Logicas/Gestion/PlanMantenimientoUbicacion.Logica.cs:10-31`
- **Confianza**: `CONFIRMED`
- **Riesgo**: es destructivo y **no se advierte al usuario**. Ver `MNT-006`.

### BR-AS-008 — Eliminar una asignación no valida órdenes pendientes
- **Comportamiento**: `Eliminar` sólo comprueba que el registro exista. Hay un `TODO` explícito en
  el código: `//TODO: VALIDAR CANTIDAD DE ORDENES DE TRABAJO PENDIENTES`.
- **Evidencia**: `Areas/Gestion/Controllers/PlanMantenimientoEquipo.Controller.cs` (`Eliminar`)
- **Confianza**: `CONFIRMED`
- **Ver**: `MNT-018`

---

## F. Generación de Órdenes de Trabajo

### BR-GE-001 — La generación es 100 % manual, por decisión de negocio 🟢 DECIDIDA (`D-05`)
- **Comportamiento**: no existe job programado. La generación sólo ocurre en
  `POST /Gestion/OrdenTrabajo/Generar` o `POST /Gestion/OrdenTrabajo/Previsualizar`.
- **Evidencia**: `AMSYS.DemonApp/Program.cs` (script de usuarios);
  `AMSYS.WebAdmin/Program.cs:55` (`//services.AddHostedService<EliminarTemporalesService>();`)
- **Confianza**: `CONFIRMED`
- **Decisión del propietario (`D-05`, 2026-08-29)**: *"Es a demanda según lo que el usuario vaya
  encontrando en las órdenes de trabajo, ya que si automatizamos ellos tendrán problemas de
  planificación a futuro y su backlog será enorme."*
- **Estado**: **no es un defecto**. Es un control de flujo deliberado. **No automatizar.**
- **Ver**: `MNT-008` (documentar la decisión y dar observabilidad, sin automatizar)

### BR-GE-002 — Condición de lanzamiento (UMS CALENDARIO)
- **Comportamiento**:
  ```text
  fechaEjecucion   = (UltimaEjecucion ?? Inicio) - FactorPlanificacion dias
  si fechaEjecucion <= hoy:
      fechaLanzamiento = UltimaEjecucion.HasValue
          ? fechaEjecucion + Intervalo (segun TipoCalendario)
          : Inicio - FactorPlanificacion dias
      si fechaLanzamiento <= hoy -> se lanza la posicion actual
  ```
- **Evidencia**: `AMSYS.Logicas/Gestion/PlanMantenimiento.Logica.cs:186-240`
- **Confianza**: `CONFIRMED`

### BR-GE-003 — Condición de lanzamiento (UMS CONTADOR, sólo Equipos)
- **Comportamiento**:
  `posicion = floor((ContadorActual ?? ContadorInicio) / Intervalo)`; se lanza si
  `PosicionActual < posicion`. Si no, se reintenta con
  `floor((ContadorActual + FactorPlanificacion) / Intervalo)`.
- **Evidencia**: `AMSYS.Logicas/Gestion/PlanMantenimiento.Logica.cs:242-262`, `CalcularPosicion`
- **Confianza**: `CONFIRMED`

### BR-GE-004 — Los planes por CONTADOR asignados a Ubicaciones nunca generan órdenes
- **Comportamiento**: `GenerarMantenimientoUbicaciones` sólo tiene rama
  `if (plan.UnidadMedidaServicio!.Tipo == TipoUms.CALENDARIO)`. No hay `else`.
- **Evidencia**: `AMSYS.Logicas/Gestion/PlanMantenimiento.Logica.cs:342`
- **Confianza**: `CONFIRMED` (comportamiento). `UNKNOWN` si es intencional.
- **Ver**: `MNT-009`

### BR-GE-005 — Un plan por CALENDARIO sólo avanza UNA posición por ejecución 🟢 DECIDIDA (`D-05`)
- **Comportamiento**: la lógica es un `if`, no un `while`. Si un plan está atrasado N ciclos, hay
  que pulsar *Generar* N veces.
- **Evidencia**: `AMSYS.Logicas/Gestion/PlanMantenimiento.Logica.cs:186-240` (equipos) y
  `:342-388` (ubicaciones)
- **Confianza**: `CONFIRMED`
- **Estado tras `D-05`**: **comportamiento correcto**. Es precisamente el mecanismo que evita la
  explosión de backlog que el propietario quiere prevenir. **No convertir en bucle.**

### BR-GE-006 — Un plan por CONTADOR SALTA directamente a la posición objetivo ⚠️ EN CONFLICTO
- **Comportamiento**: `ActualizarLanzamiento` fija `PosicionActual = nuevaPosicion` y genera **sólo**
  la orden de la posición final; las posiciones intermedias y sus secciones se pierden.
- **Evidencia**: `AMSYS.Logicas/Gestion/PlanMantenimiento.Logica.cs:270-295`
- **Confianza**: `CONFIRMED` en comportamiento, `UNKNOWN` en intención
- **Conflicto detectado tras `D-05`**: mientras el calendario **conserva** el trabajo pendiente para
  que el planificador lo libere a su ritmo, el contador lo **descarta en silencio**. Los dos tipos de
  plan tratan el atraso de forma opuesta, y sólo uno es coherente con la decisión del propietario.
- **Decisión pendiente**: `D-05b` — ver `CURRENT-STATE.md`
- **Ver**: `MNT-008b`

### BR-GE-007 — Sólo se generan órdenes para equipos "montados"
- **Comportamiento**: el equipo debe estar `Activo` y tener `UbicacionId` o `EquipoPadreId`. Si no
  tiene ubicación propia se busca recursivamente en la cadena de equipos padre. Si no se encuentra
  ninguna ubicación, **la orden no se genera** (`continue` silencioso).
- **Evidencia**: `AMSYS.Logicas/Gestion/PlanMantenimiento.Logica.cs:155` y `:522`
  (`if (planMantenimientoSecciones.Length == 0 || !informaciones.ContainsKey(item.EquipoId)) continue;`)
- **Confianza**: `CONFIRMED`
- **Riesgo**: silencio total. El planificador no sabe que un equipo fue omitido.

### BR-GE-008 — Programación FLOTANTE bloquea la asignación hasta el cierre de la OT
- **Comportamiento**:
  - Al generar: `Bloqueado = (TipoProgramacion == FLOTANTE)`.
  - Las asignaciones con `Bloqueado == true` quedan excluidas de futuras generaciones
    (`GetAllByQueryable(x => !x.Bloqueado && …)`).
  - Se desbloquea cuando una OT del mismo `(PlanMantenimientoId, EquipoId|UbicacionId)` pasa a
    `CIERRE_TECNICO`, `CIERRE_TOTAL` o `ANULADO`, siempre que no existiera ya un cierre previo
    (`existeCierre == false`).
- **Evidencia**: `PlanMantenimiento.Logica.cs:217, 283, 370`;
  `OrdenTrabajo.Logica.cs:420-443` (`ActualizarAsync`), `:684-745` (`NotificarAsync`),
  `:829-875` (`ActualizarEstadoAsync`)
- **Confianza**: `CONFIRMED`
- **Riesgo crítico**: no hay ninguna acción de UI que permita desbloquear manualmente. Una
  asignación bloqueada sin OT cerrable queda **muerta para siempre**. Ver `MNT-005`.

### BR-GE-009 — Programación FIJA no bloquea
- **Comportamiento**: `Bloqueado` queda `false`; el plan sigue avanzando en el calendario aunque
  la OT anterior no se haya cerrado.
- **Confianza**: `CONFIRMED`

### BR-GE-010 — Las lecturas de contador sólo avanzan asignaciones NO bloqueadas
- **Comportamiento**: `ContadorHistorialLogica.GuardarAsync` incrementa `ContadorActual` de las
  `PlanMantenimientoEquipo` con `Bloqueado = false` y misma `UnidadMedidaServicioId`.
  Al cerrar la OT, `ContadorActual` se **recalcula** como `PosicionActual * Intervalo`, ajustado
  por la diferencia entre `ValorEjecucion` y el valor real del contador.
- **Evidencia**: `AMSYS.Logicas/Gestion/ContadorHistorial.Logica.cs:37-66`;
  `AMSYS.Logicas/Gestion/OrdenTrabajo.Logica.cs:693-710`
- **Confianza**: `CONFIRMED`

### BR-GE-011 — Código de la Orden de Trabajo
- **Comportamiento**:
  - Generación automática (por plan): `ordenTrabajoRepositorio.Contar(ref cantidades, año)` y luego
    `OT-{año}-{secuencial:D5}` incrementando en memoria.
  - Creación manual: `COUNT(OT de la empresa en el año) + 1`, formateado igual.
- **Evidencia**: `PlanMantenimiento.Logica.cs` (ambos `GenerarOrdenes…`);
  `OrdenTrabajo.Logica.cs:120-122`
- **Confianza**: `CONFIRMED`
- **Riesgo**: `COUNT + 1` no es una secuencia. Con concurrencia se producen **códigos duplicados**.
- **Matiz tras `D-03`**: el propietario ha declarado que los códigos **escritos por el usuario** no
  necesitan ser únicos. `OrdenTrabajo.Codigo` **no lo escribe el usuario**: lo genera el sistema, y su
  duplicación no es intencional sino una condición de carrera. Pendiente de aclarar en `D-03b`.
- **Ver**: `MNT-004`

### BR-GE-012 — La OT hereda el Centro de Costo y la Organización del objeto técnico
- **Comportamiento**: `CentroCostoId` y `OrganizacionId` se copian del `Equipo` (o de la
  `Ubicacion` cuando la asignación es por ubicación).
- **Evidencia**: `PlanMantenimiento.Logica.cs` (ambos `GenerarOrdenes…`)
- **Confianza**: `CONFIRMED`

### BR-GE-013 — Los códigos mostrados en la previsualización no son los definitivos
- **Comportamiento**: `GenerarOrdenesPorEquipo(crearOrdenes: false)` asigna igualmente
  `item.Codigo`, pero no persiste. Al confirmar se recalculan desde cero.
- **Confianza**: `CONFIRMED`

---

## G. Orden de Trabajo (estados)

### BR-OT-001 — Estados existentes
```text
EMITIDO        = 0
(1 sin usar: PROGRAMADO esta comentado en el enum)
CIERRE_TECNICO = 2
CIERRE_TOTAL   = 3
ANULADO        = 4
```
- **Evidencia**: `AMSYS.Entidades/Constantes/EstadoOrdenTrabajo.cs`
- **Confianza**: `CONFIRMED`

### BR-OT-002 — Transiciones declaradas en el dominio (`EstadosHabilitados`)
| Desde | Hacia permitido |
|-------|-----------------|
| `EMITIDO` | `EMITIDO`, `CIERRE_TECNICO`, `ANULADO` |
| `CIERRE_TECNICO` | `CIERRE_TECNICO`, `CIERRE_TOTAL` |
| `CIERRE_TOTAL` | `CIERRE_TOTAL` |
| `ANULADO` | `ANULADO` |
- **Evidencia**: `AMSYS.Entidades/Gestion/Adicionales/OrdenTrabajo.Adicional.cs:12-23`
- **Confianza**: `CONFIRMED`
- **Alcance real**: se usa **sólo para pintar el `<select>` en las vistas**. No se valida en el POST.
- 🟢 **DECIDIDA (`D-02`)**: ésta es la **única máquina de estados válida** del sistema. Debe pasar a
  aplicarse en el servidor en todas las rutas (`MNT-003`).

### BR-OT-003 — Transiciones del Kanban: INCORRECTAS 🟢 DECIDIDA (`D-02`)
| Desde | Hacia permitido |
|-------|-----------------|
| `EMITIDO` | `CIERRE_TECNICO`, `ANULADO` |
| `CIERRE_TECNICO` | `CIERRE_TOTAL`, **`ANULADO`** ← **prohibido por `D-02`** |
| `CIERRE_TOTAL` | (ninguno) |
| `ANULADO` | (ninguno) |
- **Evidencia**: `Areas/Gestion/Controllers/OrdenTrabajo.Controller.cs` (`KanbanMover`)
- **Confianza**: `CONFIRMED`
- **Decisión del propietario (`D-02`, 2026-08-29)**: *"No debería permitirme anular una orden si esta
  se encuentra en cierre técnico."*
- **Estado**: esta tabla es **incorrecta** y debe eliminarse. La máquina de estados válida es la de
  `BR-OT-002`. Ver `MNT-003`.

### BR-OT-004 — La máquina de estados NO se valida en `Editar` ni `Notificar`
- **Comportamiento**: `POST Editar` y `POST Notificar` asignan `_.Estado = entidad.Estado` sin
  comprobar la transición de origen.
- **Evidencia**: `AMSYS.Logicas/Gestion/OrdenTrabajo.Logica.cs:247` y `:502`
- **Confianza**: `CONFIRMED`
- **Ver**: `MNT-003`

### BR-OT-005 — Los estados permitidos por Rol están definidos pero NO se aplican
- **Comportamiento**: `Rol.EstadosOrdenTrabajo` / `Rol.EstadosAviso` se configuran en Seguridad y se
  cargan a la sesión en `AccountController:82-83`, pero
  `grep usuario.EstadosOrdenTrabajo` **no encuentra ningún consumo** ni en controladores ni en
  vistas del área Gestión.
- **Evidencia**: `AMSYS.WebAdmin/Commons/Session/UserInformation.cs:21-22`;
  `AMSYS.WebAdmin/Controllers/AccountController.cs:82-83`
- **Confianza**: `CONFIRMED`
- **Ver**: `MNT-002`

### BR-OT-006 — Al crear una OT se sintetizan logs de todos los estados anteriores
- **Comportamiento**: `for (int i = 0; i <= (int)entidad.Estado; i++)` crea un `OrdenTrabajoLog`
  por cada valor entero, incluyendo el **1 inexistente**. Crear una OT directamente en
  `ANULADO` (4) inventa un historial completo 0,1,2,3,4.
- **Evidencia**: `AMSYS.Logicas/Gestion/OrdenTrabajo.Logica.cs:136-148`
- **Confianza**: `CONFIRMED`
- **Ver**: `MNT-011`

### BR-OT-007 — Reglas de acción según estado (declaradas en dominio, aplicadas en la vista)
| Propiedad | Condición |
|-----------|-----------|
| `PuedoModificarObjetoTecnico` | `Estado == EMITIDO` |
| `PuedoEditar` | `Estado <= CIERRE_TECNICO` |
| `PuedoNotificar` | `Estado <= CIERRE_TECNICO && PuedeEjecutar` |
| `PuedeNotificarParametro` | `Estado <= CIERRE_TECNICO` |
- **Evidencia**: `AMSYS.Entidades/Gestion/Adicionales/OrdenTrabajo.Adicional.cs:6-10`
- **Confianza**: `CONFIRMED`
- **Alcance real**: sólo condicionan el render. El servidor no las revalida.

---

## H. Integración Aviso ↔ Orden de Trabajo

### BR-AV-001 — Estados del Aviso
`EMITIDO → APROBADO → ATENDIDO → FINALIZADO`, con `RECHAZADO` como salida desde `EMITIDO`.
- **Evidencia**: `AMSYS.Entidades/Gestion/Adicionales/Aviso.Adicional.cs` (`EstadosHabilitados`)
- **Confianza**: `CONFIRMED`

### BR-AV-002 — Sólo un Aviso aprobado (no rechazado, no finalizado) puede escalar a OT
- **Comportamiento**: `PuedoCrearOrdenTrabajo => Estado > EMITIDO && Estado < RECHAZADO`
- **Confianza**: `CONFIRMED`

### BR-AV-003 — Crear la OT desde un Aviso lo pasa a ATENDIDO
- **Comportamiento**: tras `GuardarAsync`, si `AvisoId.HasValue && _avisoServicio.PuedeAtender(...)`
  → `CambiarEstadoAsync(ATENDIDO)`.
- **Evidencia**: `Areas/Gestion/Controllers/OrdenTrabajo.Controller.cs` (`Nuevo` POST)
- **Confianza**: `CONFIRMED`

### BR-AV-004 — Cerrar la OT finaliza el Aviso; anularla lo devuelve a APROBADO
- **Comportamiento**: `CIERRE_TECNICO`/`CIERRE_TOTAL` → `FINALIZADO`; `ANULADO` → `APROBADO`.
- **Evidencia**: `Areas/Gestion/Controllers/OrdenTrabajo.Controller.cs` (`Editar` POST)
- **Confianza**: `CONFIRMED`
- **Nota**: esta sincronización sólo ocurre en `Editar`. Cerrar desde **Kanban** (`KanbanMover`) o
  desde **Notificar** **no** actualiza el Aviso. Ver `MNT-007`.

---

## I. Reglas NO DETERMINADAS

### BR-UNK-001 — Semántica exacta de `Nivel` en `PlanMantenimientoSeccion`
- **Situación**: `Nivel` sólo se usa para absorber secciones que coinciden en una posición
  (se conserva el mayor). No hay validación de rango, ni unicidad, ni documentación.
- **Motivo de `UNKNOWN`**: se desconoce si `Nivel` debe ser único por plan, si debe correlacionarse
  con `Intervalo` (mayor intervalo ⇒ mayor nivel) o si es libre.
- **Impacto**: dos secciones con el mismo `Nivel` en la misma posición generan **ambas** su
  contenido en la OT, lo que puede duplicar tareas.

### BR-UNK-002 — Qué debe ocurrir cuando cambia `CantidadPosiciones` de un plan con asignaciones vivas
- **Situación**: `PosicionActual` de las asignaciones existentes no se recalcula ni se valida.
- **Motivo de `UNKNOWN`**: no hay código que lo trate; podría requerirse reinicio, remapeo
  proporcional o bloqueo del cambio.

### BR-UNK-003 — Comportamiento esperado cuando una posición no tiene secciones
- **Situación**: hoy se avanza la posición y no se genera nada, sin registro ni aviso.
- **Motivo de `UNKNOWN`**: se desconoce si es correcto (posición "de descanso" intencional) o si
  debería avisarse al planificador.

### BR-UNK-004 — Alcance del desbloqueo por cierre de OT
- **Situación**: el desbloqueo busca por `(PlanMantenimientoId, EquipoId)` sin filtrar por la OT
  concreta que causó el bloqueo. Si hay varias OT del mismo plan sobre el mismo equipo, cerrar
  cualquiera desbloquea.
- **Motivo de `UNKNOWN`**: puede ser deliberado (una asignación = un ciclo) o un descuido.

### BR-UNK-005 — Unicidad de códigos → **RESUELTA** 🟢 (`D-03`)
> Esta regla **ya no es `UNKNOWN`**. Se conserva por trazabilidad; su forma definitiva son
> `BR-CO-001` y `BR-CO-002`, en la sección J.

- **Situación original**: no había índice único ni validación de duplicado para `HojaRuta.Codigo`,
  `Seccion.Codigo`, `PlanMantenimiento.Codigo` ni `OrdenTrabajo.Codigo`.
- **Decisión del propietario (`D-03`, 2026-08-29)**: los códigos **no deben ser únicos**; se pide una
  **alerta** al usuario, no un bloqueo.
- **Sub-pregunta abierta `D-03b`**: `OrdenTrabajo.Codigo` lo genera el sistema, no el usuario.

---

## J. Códigos y duplicidad

### BR-CO-001 — Los códigos son deliberadamente NO únicos 🟢 DECIDIDA (`D-03`)
- **Entidades afectadas**: `HojaRuta`, `Seccion`, `PlanMantenimiento`
- **Condición**: siempre
- **Comportamiento esperado**: el sistema **admite** códigos repetidos. No debe existir índice único
  ni validación bloqueante sobre ellos.
- **Evidencia / origen**: decisión del propietario `D-03` (2026-08-29):
  *"No deben ser únicos porque a veces se puede duplicar."*
- **Confianza**: `CONFIRMED` (declaración expresa de negocio)

### BR-CO-002 — Debe advertirse al usuario del código duplicado 🟢 DECIDIDA (`D-03`)
- **Entidades afectadas**: `HojaRuta`, `Seccion`
- **Condición**: al crear o editar, cuando el código introducido ya existe en su ámbito
- **Ámbito de comparación**:
  - `HojaRuta` → dentro de la misma `Empresa`
  - `Seccion` → dentro de la misma `HojaRuta`
- **Comportamiento esperado**: advertencia visual **no bloqueante**, que identifique el registro
  existente. El guardado se permite siempre.
- **Evidencia / origen**: decisión `D-03`:
  *"Lo que sí pondríamos en el UX es una alerta de que ya existe un código de hoja de ruta similar.
  Las secciones dentro de una hoja de ruta pueden tener el código duplicado, pero igual deberíamos
  darle una alerta."*
- **Confianza**: `CONFIRMED`
- **Estado de implementación**: **no implementada**. Ver `MNT-048`.
- **Nota**: *"similar"* se implementa como coincidencia exacta del código. Una comparación difusa
  requeriría una decisión aparte.
