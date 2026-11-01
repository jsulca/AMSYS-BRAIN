# Documentación de Análisis – Módulo de Mantenimiento (AMSYS)

## Propósito

Este documento (antes `ai/README.md` del repo legacy; desde el 2026-10-31 en AMSYS-BRAIN) describe la **fuente de conocimiento del módulo de Mantenimiento** de AMSYS. Su objetivo
es que cualquier agente de IA (incluido Claude Code) o cualquier persona nueva pueda comprender cómo
funciona realmente el módulo y ejecutar mejoras de forma segura y progresiva.

## Objetivo del análisis

Documentar **cómo funciona el módulo hoy** —no cómo debería funcionar— y, a partir de esa base,
generar tareas de mejora concretas, pequeñas e independientes.

## Alcance

### Entidades principales analizadas

| Entidad | Descripción |
|---------|-------------|
| **PlanMantenimiento** | Define la programación cíclica del mantenimiento preventivo |
| **HojaRuta** | Agrupador opcional de secciones. Catálogo simple, sin ciclo de vida |
| **Seccion** | Agrupación de tareas, materiales, servicios y adjuntos |
| **Tarea** | Actividad individual dentro de una sección |
| **PlanMantenimientoSeccion** | Tabla intermedia Plan ↔ Sección, con prioridad, taller, intervalo y nivel |
| **PlanMantenimientoEquipo** | Asignación Plan → Equipo, con el estado de avance del ciclo |
| **PlanMantenimientoUbicacion** | Asignación Plan → Ubicación, con el estado de avance del ciclo |
| **OrdenTrabajo** | Instancia ejecutable de mantenimiento (preventiva, correctiva o manual) |
| **Aviso** | Notificación de falla o solicitud de trabajo que puede escalar a OT |

### Entidades relacionadas cubiertas
`Equipo`, `Ubicacion`, `Contador`, `ContadorHistorial`, `PuntoMedida`, `TipoMantenimiento`,
`TallerResponsable`, `Prioridad`, `Especialidad`, `TipoTarea`, `UnidadMedidaServicio`,
`Sistema`, `Parte`, `Material`, `Servicio`, `OrdenTrabajoTarea`, `OrdenTrabajoMaterial`,
`OrdenTrabajoCosto`, `OrdenTrabajoLog`, `Notificacion*`, `Programacion*`,
`Empresa`, `Organizacion`, `Usuario`, `Rol`, `Pagina`, `Elemento`.

### Fuera de alcance
El módulo `Dashboard` y el proyecto `BackupPG`. El análisis original se limitaba a Mantenimiento;
`Administracion`, `Logistica` y `Seguridad` tienen desde entonces su propio plan de mejora
(`legacy/planes/PLAN-UX-*.md`), construido sobre el mismo material.

## Estructura de la documentación

```
AMSYS-BRAIN (lo que vino de ai/ del legacy)
├── legacy/README.md                    ← Este archivo
├── negocio/SYSTEM-CONTEXT.md            ← Qué hace el sistema y el módulo
├── negocio/DOMAIN-MODEL.md              ← Entidades, relaciones y cardinalidades verificadas
├── negocio/BUSINESS-RULES.md            ← 56 reglas con nivel de confianza
├── legacy/ARCHITECTURE.md              ← Arquitectura actual y deuda técnica
├── legacy/CURRENT-STATE.md             ← Estado del proceso, bloqueadores y decisiones pendientes
├── legacy/planes/PLAN-UX-PLANMANTENIMIENTO.md ← Ruta paso a paso (PM-01…PM-18) para mejorar la UX del Plan
├── legacy/planes/PLAN-UX-HOJARUTA-SECCION.md  ← Ruta paso a paso (HS-01…HS-18) para Hojas de Ruta y Secciones
├── legacy/planes/PLAN-UX-EQUIPO-UBICACION.md  ← Ruta paso a paso (EU-NN) para Equipos y Ubicaciones
├── legacy/planes/PLAN-UX-ADMINISTRACION.md    ← Ruta paso a paso (AD-01…AD-18) para los catálogos maestros
├── legacy/planes/PLAN-UX-LOGISTICA.md         ← Ruta paso a paso (LG-01…LG-17) para almacén, notas y kardex
├── legacy/planes/PLAN-UX-SEGURIDAD.md         ← Ruta paso a paso (SG-01…SG-25) para usuarios, roles y permisos
├── legacy/planes/PLAN-MULTICLIENTE.md         ← Unificar las ramas por cliente en un producto configurable (MC-NN)
├── migracion/PLAN-NUEVA-PLATAFORMA.md     ← Sucesor: Amsys (Blazor WASM + API, .NET 10); este repo pasa a legacy
├── negocio/flujos/orders.md       ← Análisis por entidad y proceso operativo
├── negocio/flujos/workflow.md     ← Flujo real, estados y transiciones
├── legacy/analisis/permissions.md ← Permisos, seguridad y vulnerabilidades
├── legacy/analisis/ux.md          ← Análisis UX/UI de todas las pantallas
├── legacy/tareas/                 ← MNT-001 … MNT-048 + MNT-008b (PENDING)
└── legacy/tareas/completadas/     ← Tareas finalizadas (vacío)
```

## Cómo utilizar esta documentación

### Para comprender el módulo (lectura en este orden)
1. `negocio/SYSTEM-CONTEXT.md` — contexto funcional.
2. `negocio/DOMAIN-MODEL.md` — **empieza aquí si vas a tocar código**: la estructura real no es la que sugieren
   los nombres de las entidades.
3. `negocio/flujos/workflow.md` — el flujo real y sus estados.
4. `negocio/BUSINESS-RULES.md` — las reglas, con su nivel de confianza.
5. `legacy/ARCHITECTURE.md` — cómo está construido.

### Para implementar una mejora (Claude Code)
1. Leer `legacy/CURRENT-STATE.md`: fase, bloqueadores y decisiones pendientes.
2. Elegir la tarea siguiendo el orden recomendado al final de ese archivo.
3. Leer la tarea completa en `legacy/tareas/MNT-NNN.md`, **incluidas las secciones "Riesgos", "Fuera de
   alcance" y "Notas para Claude Code"**.
4. Verificar en `negocio/BUSINESS-RULES.md` las reglas implicadas y su nivel de confianza.
5. Si la tarea depende de una decisión `D-NN` no resuelta, **detenerse y preguntar**.
6. Si la tarea empieza con un diagnóstico sobre datos, ejecutarlo y entregarlo **antes** de cambiar código.
7. Al terminar: actualizar `legacy/CURRENT-STATE.md` y mover la tarea a `/completed`.

## Reglas fundamentales para futuros agentes

> [!CAUTION]
> **NO REGRESIÓN.** El módulo **no tiene ningún test**. Toda modificación debe preservar las
> funcionalidades existentes. El inventario de flujos críticos y casos borde está en
> `negocio/flujos/orders.md` §9: verifícalos manualmente antes de dar por buena cualquier entrega.

> [!IMPORTANT]
> **EVIDENCIA ANTES QUE OPINIÓN.** Antes de modificar una regla de negocio, comprueba que esté
> documentada como `CONFIRMED`. Las reglas `INFERRED` o `UNKNOWN` requieren confirmación del
> propietario.

> [!WARNING]
> **DECISIONES PENDIENTES.** Quedan 13 decisiones de negocio abiertas en `legacy/CURRENT-STATE.md`, más
> `D-03b` y `D-05b`. Varias tareas están bloqueadas por ellas. Implementar una opción sin la
> decisión puede causar un incidente operativo — está señalado en cada tarea.

> [!CAUTION]
> **DECISIONES YA TOMADAS: no reabrir.** `D-02`, `D-03` y `D-05` están resueltas por el propietario y
> son vinculantes. En particular:
> - **No automatizar la generación de órdenes** (`D-05`).
> - **No permitir anular una OT en `CIERRE_TECNICO`** (`D-02`).
> - **No crear índices únicos sobre campos `Codigo`** (`D-03`).
>
> Si el código actual parece contradecir una de estas decisiones, **el código es lo que está mal**.

> [!CAUTION]
> **NO EJECUTES MIGRACIONES.** Varias tareas generan migraciones de EF Core. Genera el archivo y
> detente: aplicarla en producción es decisión del propietario, y varias fallarían con los datos
> actuales.

### Principios de trabajo
1. **Una tarea = un cambio atómico.** No mezclar mejoras de tareas distintas en el mismo commit.
2. **Diagnóstico antes que cambio.** Cuando la tarea lo indique, entrega primero el informe de datos.
3. **Preservar el comportamiento** salvo que la tarea diga explícitamente lo contrario.
4. **Agrupar por archivo, no por tema.** Varias tareas tocan los mismos archivos; `legacy/CURRENT-STATE.md`
   propone los bloques.
5. **Actualizar la documentación** cuando el análisis resulte incorrecto: `/ai` es la fuente de
   verdad y debe mantenerse.
6. **Mover las tareas completadas** de `/tasks` a `/completed`, con una nota de qué se implementó.

## Hallazgos que conviene conocer antes de tocar nada

Cinco hechos verificados que contradicen lo que sugiere el código a primera vista:

1. **`PlanMantenimiento` no tiene ninguna relación con `HojaRuta`.** El plan referencia `Seccion`
   directamente, en una relación N:M. La jerarquía en cascada no existe (`BR-PM-001`).
2. **Una `Seccion` puede no tener `HojaRuta`**: `HojaRutaId` es anulable y la validación que lo
   exigía está comentada (`BR-SE-001`).
3. **No existe generación automática de órdenes, y es intencional.** `AMSYS.DemonApp` no es un
   demonio; es un script de importación de usuarios. La decisión `D-05` confirma que la generación
   debe seguir siendo **a demanda** para controlar el backlog (`BR-GE-001`). **No automatizar.**
4. **La autorización sólo protege las pantallas, no las escrituras.** Ningún POST del módulo lleva
   `[FiltroAccion]` (`legacy/analisis/permissions.md` SEC-01).
5. **El contexto EF es `NoTracking` globalmente.** Todo el código re-adjunta entidades a mano, y la
   previsualización de órdenes es segura **gracias a eso**. No cambies esa configuración.

## Estado actual del análisis

**Fase**: `ANALYSIS` — completada
**Última actualización**: 2026-08-29
**Tareas**: 49 creadas, 0 completadas
**Decisiones**: 3 resueltas (`D-02`, `D-03`, `D-05`) · 13 pendientes + 2 sub-preguntas nuevas

### Decisiones ya tomadas por el propietario — vinculantes
| ID | Decisión | Efecto |
|----|----------|--------|
| `D-05` | La generación de órdenes **no se automatiza**: es a demanda, para controlar el backlog | `MNT-008` reescrita; `BR-GE-001` y `BR-GE-005` pasan a ser reglas deliberadas |
| `D-02` | **No** se puede anular una OT en `CIERRE_TECNICO` | `MNT-003` desbloqueada; la tabla del Kanban es incorrecta y debe eliminarse |
| `D-03` | Los códigos **no** son únicos; se pide una **alerta**, no un bloqueo | `MNT-010` reduce alcance; nace `MNT-048` |

Detalle y justificación en `legacy/CURRENT-STATE.md` → *Decisiones RESUELTAS*.

Ver `legacy/CURRENT-STATE.md` para el detalle y la siguiente acción recomendada.

---

## Recomendación de nomenclatura

La estructura acordada conserva los nombres `negocio/flujos/orders.md` y el prefijo `MNT-` para las tareas.

- **Tareas**: el prefijo `MNT-` ya es correcto y descriptivo. No requiere cambio.
- **`negocio/flujos/orders.md`**: el nombre es engañoso — el archivo cubre todas las entidades operativas
  del módulo, no sólo las órdenes de trabajo. Se recomienda renombrarlo a `analysis/maintenance.md`
  y, si el módulo crece, dividirlo en `analysis/planning.md` (plan, hoja de ruta, sección, tarea) y
  `analysis/work-orders.md` (orden de trabajo, aviso).
- **`negocio/flujos/workflow.md`**: nombre adecuado; podría precisarse como
  `analysis/maintenance-workflow.md` si se analizan otros módulos en el futuro.

**No se ha aplicado ningún renombrado.** Requiere autorización del propietario.
