# Pendientes de migración del legacy a la nueva plataforma

> Inventario al **2026-10-03**, tras completar NP-0 … NP-6. Sirve para retomar el trabajo: qué falta migrar, en qué
> orden y dónde está cada cosa. Mantenerlo al día junto con `CURRENT-STATE.md`.

## Rutas

| Proyecto | Ruta | Notas |
|----------|------|-------|
| **AMSYS legacy** (ASP.NET MVC, una rama por cliente) | `D:\Documentos\Alphamanufacturas\AMSYS\AMSYS` | Rama `main` = producto base; ramas `agchavin`, `ares`, `caja_arequipa`, `energiaycombustion`, `eulen`, `itc`, `oterra`, `pyme`, `rentanor`. Análisis del legacy en su carpeta `ai/` (sobre todo `ai/BUSINESS-RULES.md`, `ai/PLAN-MULTICLIENTE.md`, `ai/PLAN-NUEVA-PLATAFORMA.md`, `ai/PLAN-UX-*.md`) |
| **AMSYS nuevo** (.NET 10, Minimal API + Blazor Server + MudBlazor, repo `amsys`) | `D:\Documentos\Amsys` | Contexto en `ai/` (`README.md`, `CURRENT-STATE.md`, `DECISIONS.md`, `ARCHITECTURE.md`, `ROADMAP.md`) y `CLAUDE.md` |
| Base de desarrollo del nuevo | `Host=localhost;Port=5432;Database=amsys_dev;Username=postgres;Password=123` | Contenedor Docker `bdpostgresql` (PostgreSQL 14.1). Usuario `admin`, empresa `demo` |
| Bases del legacy (fuente del importador) | Mismo servidor: `amsys`, `amsys_v3_rentanor`, `amsys_v3_agchavin`, `amsys_v3_itc`, `amsys_v3_caja_arequipa`, `amsys_v3_demo`, `amsys_v3_eulen`, `amsys_v3_oterra` | Revisar si faltan ares, energiaycombustion y pyme |

**Ejecutar el nuevo** (desde `D:\Documentos\Amsys`): `dotnet run --project src/Amsys.Api --launch-profile http` y
`dotnet run --project src/Amsys.Web --launch-profile http` → http://localhost:5296. Tests: `dotnet test --solution Amsys.slnx`
(necesita Docker; detener API/Web antes de compilar).

## Lo que ya está migrado (resumen)

Seguridad (usuarios, roles, permisos, alcance por organización), configuración multicliente (módulos, campos
personalizados, etiquetas de estado, marca), catálogos, maestros (empleados, socios de negocio, materiales), activos
(organizaciones, ubicaciones, equipos, clases, contadores, puntos de medida, árbol), correctivo (avisos, órdenes de
trabajo, notificación y costos, Kanban), preventivo (hojas de ruta, secciones, planes con cálculo de posiciones,
asignaciones, generación a demanda), logística (almacenes, existencias, notas FIFO, traslados, anulaciones, kardex) y
reportes (tablero de inicio, Excel, PDF de OT, indicadores MTBF/MTTR/disponibilidad). Detalle en `CURRENT-STATE.md`.

## 1. Funcionalidades del legacy (`main`) que no existen todavía

| Funcionalidad del legacy | Qué es | Impacto | Dónde está en el legacy |
|---|---|---|---|
| **API móvil** (17 controladores: avisos, OT, notificaciones, Kanban, adjuntos…) | App de técnicos en campo. Decidido: nueva versión de la app contra `/api/v1` (D-NP-04) | **Alto** | `AMSYS.WebAdmin/Api/Controllers` |
| **Adjuntos** | Fotos y documentos en avisos, OT y secciones | **Alto** (falta definir almacenamiento de archivos) | `Areas/Administracion/Controllers/Adjunto`, `Api/Controllers/*Adjunto*` |
| **Paradas** | Paradas de planta planificadas por ubicación (alimentan indicadores) | Medio (hoy: OT con equipo detenido, D-NP-74) | `Areas/Gestion/Controllers/Parada` |
| **Aspectos** | Variables cualitativas a inspeccionar en equipos/ubicaciones, con historial y notificación | Medio | `Aspecto`, `EquipoAspecto*`, `UbicacionAspecto*`, `NotificacionEquipoAspecto`, `NotificacionUbicacionAspecto` |
| **Inspección** | Vista de OT para registrar inspecciones | Medio (va con aspectos) | `Areas/Gestion/Controllers/Inspeccion` |
| **Sistemas y partes** | Desglose del equipo usado en tareas y avisos (`SistemaId`/`ParteId`) | Medio | `Sistema`, `Parte`, `EquipoSistema` |
| **Programación de personal** | Asignar empleados a OT antes de ejecutar | Medio | `ProgramacionEmpleado` |
| **Alertas de punto de medida** | Bandeja de mediciones fuera de rango para crear avisos | Bajo (hoy: "Crear aviso" desde el punto en alarma) | `AlertaPuntoMedida` |
| **Hoja de aceptación** + maestro **Servicio** | Aceptación formal de servicios de terceros contra OT | Bajo/medio (los servicios ya se notifican en la OT) | `Areas/Logistica/Controllers/HojaAceptacion`, `Servicio` |
| **Proyección** (calendario/contador) y **planificación anual** en Excel | Proyección del preventivo a futuro | Medio | `Areas/Reporte/Controllers/Proyeccion`, `Plan` |
| Excel de previsualización del plan, reporte de notificación de tareas | Exportaciones puntuales | Bajo | `PlanMantenimiento.Logica.GenerarExcel*`, `NotificacionTarea/Reporte` |
| **Grupos de indicadores** | Conjuntos de equipos guardados por usuario | Bajo | `IndicadorGrupo` |
| **Seguridad avanzada** | Bitácora de accesos, menú configurable, alta de empresas y renovación de licencias (superadministrador) | Medio (hoy las empresas se crean con el Migrator) | `SeguridadLog`, `Menu`, `Pagina`, `Empresa`, `Renovacion` |

## 2. Partes incompletas de lo ya migrado

- **Avisos**: foto de contadores y puntos de medida al reportar una falla (`AvisoContador`/`AvisoPuntoMedida`); aviso
  automático por medición en alarma (`Configuracion.CrearAvisoPorPuntoMedida`).
- **OT**: OT padre/hija; comentarios; ajuste del contador del plan con el valor real al cerrar (BR-GE-010); lecturas
  tomadas desde la OT quedan con origen "manual".
- **Preventivo**: materiales previstos de la sección → reservas en logística; aviso al desmontar un equipo con planes.
- **Logística**: filtros por fecha en la web; selector de materiales con búsqueda en servidor (hoy carga hasta 500).
- **Seguridad**: migración de usuarios del legacy (claves HMAC-SHA256 sin sal → re-hashear en el primer ingreso o
  forzar restablecimiento).
- **Zona horaria por empresa** (hoy, la del servidor).
- **Reportes**: fuentes del servidor de producción para QuestPDF.

## 3. Módulos de clientes (fuera de `main`; se hacen con la ola de cada cliente)

| Cliente | Funcionalidad propia | Estado |
|---|---|---|
| **oterra** (ola 4) | Áreas e impacto en el proceso (avisos padre/hijos), conformidad del aviso, turnos de programación | **Exclusivos de oterra** (D-MC-04) |
| **eulen, caja_arequipa** | Solicitudes: clientes, categorías y tipos de solicitud, avisos notificados por correo | Módulo `SOLICITUDES` |
| **caja_arequipa** | Feriados, calificación de OT, estados renombrados | D-MC-03 por confirmar |
| **agchavin** | Indicador mundial | — |
| Todos | Formatos y reportes propios | Plantillas por cliente (el PDF de OT ya lo soporta) |

## 4. Para salir a producción

1. **Importador de datos** desde las bases `amsys_v3_<cliente>` (permite migrar a cada cliente).
2. **Prueba en navegador** de todo lo construido (pendiente desde NP-0).
3. **Despliegue**: servidor, fuentes para PDF, Redis si la web corre en varias instancias, variables de entorno
   (`Jwt__Clave`, `ConnectionStrings__Amsys`).
4. **Decisiones abiertas**: licencia de QuestPDF (D-NP-76), revisión de indicadores con oterra (D-MC-06/D-NP-74),
   confirmar D-MC-02, D-MC-03 y D-MC-05.

## Orden recomendado

Olas de clientes: **1** ares, energiaycombustion, itc, pyme · **2/3** según `ROADMAP.md` · **4** oterra.

Para la **ola 1** sólo hace falta lo de valor alto:
1. **Contar qué usan de verdad** los clientes de la ola 1 en sus bases `amsys_v3_*` (aspectos, paradas, adjuntos,
   sistemas/partes, hojas de aceptación…). Lo que no usan, espera.
2. **Importador** (maestros, activos, avisos, OT con notificación 7→3 tablas, planes con su avance, stock como lotes,
   correlativos ajustados, usuarios).
3. **Adjuntos**.
4. **API para la app móvil**.
5. **Sistemas y partes**, si los usan.

## Mejora de la UI (para cuando se retome)

- Skill **`frontend-design`** (plugin oficial `frontend-design@claude-plugins-official`, **instalado** el 2026-10-03, alcance usuario):
  dirección visual, tipografía, paleta y composición. Instalar con `/plugin` y pedirle una revisión de pantallas
  concretas (inicio, ficha de OT, tablero Kanban, ficha del plan). Disponible en sesiones nuevas de Claude Code.
- Skill **`playwright-blazor`** (plugin `dotnet-skills`, **ya instalado**): pruebas de UI de Blazor Server con
  Playwright; sirve para la "prueba en navegador" automatizada y para capturar pantallas antes/después.
- Sin skill: la paleta y la marca por cliente ya salen de la configuración (`ColorPrimario`, `ColorSecundario`,
  logo); conviene definir un tema base de MudBlazor coherente antes de rediseñar pantallas.
