# Estado actual

**Etapa**: NP-0 a NP-6 completas · 2026-10-03/04: interfaz (UI-01/02, es-PE), **NT-01 completa** (técnico, parámetros,
comentarios, cierre del plan, monitoreo), aspectos, Mis avisos, base compartida y portal de la plataforma (D-MC-01,
D-PL-01) · **retomar por "Siguientes pasos"**
**Última actualización**: 2026-10-04

## Siguientes pasos (para retomar)

En orden. Lo hecho está en la *Bitácora*; las decisiones en `ai/DECISIONS.md` (D-UI-01…04, D-NT-01…10, D-OT-01,
D-MC-01, D-PL-01, D-AR-01, D-UI-05).

1. ~~Poner al día `amsys_dev`~~ ✅ 2026-10-04 (todas las migraciones, cliente `amsys` con PLATAFORMA y usuario
   `plataforma`). Falta en la web: rol "Técnico" (órdenes ver + ejecutar + **lecturas registrar**), vincular usuarios a
   empleados (Administración → Empleados) y asignar técnicos en la ficha de la OT.
2. **Prueba manual en navegador** de lo nuevo con `amsys_dev`: portal (crear cliente, módulos, administrador, suspender),
   técnico en el celular (Mis órdenes → play/pausa → materiales → **parámetros** → ejecución → **comentarios** → cierre
   técnico), Mis avisos, fechas. Las pantallas de NT-01b/c/d ya se revisaron con Playwright en `amsys_ui` (ficha OT-2026-00003 y -00004, técnico `lquispe` en móvil, Técnicos); falta repetirlo en `amsys_dev`.
3. ~~NT-01b~~ ✅ 2026-10-04 (D-NT-08): lecturas y mediciones vinculadas a la OT, comentarios de la OT.
4. ~~NT-01c~~ ✅ 2026-10-04 (D-NT-09): valor de ejecución / fecha de cierre del plan al cierre técnico (BR-GE-010).
   Los aspectos del legacy (`Aspecto`, `EquipoAspecto*`, `UbicacionAspecto*`) pasan al importador de la ola 1 (paso 8;
   hoy `tools/Amsys.Importador` es sólo la plantilla).
5. ~~NT-01d~~ ✅ 2026-10-04 (D-NT-10): Mantenimiento → Técnicos (monitoreo, cierre de tramos olvidados, horas por
   empleado con Excel).
6. **Portal (D-PL-01), mejoras**: ~~subida de logo~~ ✅ 2026-10-04 (D-AR-01, disco local). Faltan: campos
   personalizados y etiquetas desde el portal (hoy por archivo), decidir si la empresa de la plataforma ve sólo el menú
   "Plataforma", historial de cambios del cliente. Al desplegar: montar un volumen persistente en `Archivos:Ruta`.
7. **Revisión visual pendiente** con el tema nuevo: tablero Kanban, ficha del plan (matriz), resto de listas. Las tablas
   ya tienen cabecera con color primario y acciones a la izquierda (D-UI-05); revisar las que no se capturaron
   (logística, planificación, portal).
8. Después, el plan general: **importador de la ola 1** (`ai/PENDIENTES-MIGRACION.md`).

## Hecho

- [x] Solución `Amsys.slnx` con carpetas `src/`, `tools/`, `tests/`, `Solution Items`.
- [x] `global.json`: SDK 10.0.100 (`rollForward: latestFeature`, hoy resuelve 10.0.103) y
      `test.runner = Microsoft.Testing.Platform` (necesario para xunit.v3 en .NET 10).
- [x] `Directory.Build.props`: `net10.0`, `Nullable`, `ImplicitUsings`, `AnalysisLevel latest-recommended`,
      `EnforceCodeStyleInBuild`, nullable = error; `TreatWarningsAsErrors` en Release o con `CI=true`.
- [x] `Directory.Packages.props`: Central Package Management con versiones verificadas en NuGet el 2026-10-02.
- [x] Proyectos creados y referenciados (ver `ARCHITECTURE.md`). Los `.csproj` no repiten
      propiedades comunes ni declaran versiones.
- [x] `dotnet build Amsys.slnx` → 0 errores, 3 warnings (código de ejemplo de plantillas).
- [x] `dotnet test --solution Amsys.slnx` → 3/3 correctos (tests de ejemplo).

- [x] Limpieza de plantillas, `.editorconfig`, commit inicial.
- [x] **Dominio base** (`Amsys.Domain/Common`): `Entidad` (Id, auditoría, eliminación lógica, `Version`→`xmin`),
      `IAuditable`, `IEliminable`, `IEntidadEmpresa`, `Result`/`Result<T>`, `Error`/`TipoError`.
- [x] **Seguridad** (`Amsys.Domain/Seguridad`): `Empresa` (tenant, `Codigo` único para branding) y `Usuario`
      (pertenece a empresa, `NombreUsuario` único global). Fábricas `Crear(...)` que devuelven `Result`.
- [x] `Amsys.Application/Abstractions`: `ITenantContext`, `IUsuarioActual` (el reloj es `TimeProvider`).
- [x] **Persistencia** (`Amsys.Infrastructure`): `AmsysDbContext` con filtros globales con nombre
      (`FiltrosConsulta.Empresa`, `FiltrosConsulta.Eliminados`) aplicados por convención; `AuditoriaInterceptor`
      (asigna empresa, bloquea escrituras cruzadas, auditoría, eliminación lógica); snake_case; un esquema
      PostgreSQL por módulo; `AddInfrastructure(cadena)`; fábrica de diseño para `dotnet ef`.
- [x] Migración `Inicial` generada (esquema `seguridad`: `empresa`, `usuario`). **No aplicada a ninguna BD.**
- [x] `dotnet-ef` 10.0.12 como herramienta local (`dotnet-tools.json`).
- [x] Tests: 16 de dominio + 11 de integración (`Amsys.Infrastructure.Tests`, Postgres real con Testcontainers).
      Verificado que los tests de aislamiento **fallan** si se quita el filtro por empresa.
- [x] Build Release 0 warnings · `dotnet test --solution Amsys.slnx` 27/27.

- [x] **Autenticación (paso 3)**:
      - Domain: `TokenRefresco` (sólo se guarda el hash SHA-256, rotación, revocación).
      - Application: `IAmsysDbContext`, `IHasherClave`, `IGeneradorToken`, `ClaimsAmsys`, `ServicioAutenticacion`
        (login, refresco con rotación y **detección de reuso** → revoca todas las sesiones, cierre de sesión),
        `ServicioUsuarios`. `FiltrosConsulta` se movió a `Application/Abstractions`.
      - Infrastructure: `HasherClave` (PBKDF2 de ASP.NET Core Identity), `GeneradorTokenJwt` (HS256),
        `JwtOpciones` validadas al arrancar, `ContextoSistema`, `AddInfrastructure(IConfiguration)` / `AddPersistencia`.
        La cadena de conexión se lee al crear el contexto (la configuración del host siempre gana).
      - Api: Minimal APIs en `/api/v1` con `RequireAuthorization()` por defecto; `ContextoUsuarioHttp` (empresa y
        usuario desde el JWT); `Error` → ProblemDetails con `codigo`; filtro de validación FluentValidation;
        límite de 10 intentos/min por IP en login y refresco; OpenAPI con esquema Bearer + Scalar en Development.
      - Endpoints: `POST auth/login`, `POST auth/refrescar`, `POST auth/cerrar-sesion`, `GET auth/yo`,
        `GET seguridad/usuarios`, `GET seguridad/usuarios/{id}`.
      - Migración `TokenRefresco` (tabla `seguridad.token_refresco`).
      - `Amsys.Migrator`: aplica migraciones; `--semilla-desarrollo` crea empresa `demo` + usuario `admin`.
- [x] Tests: 41/41 (13 nuevos de API con WebApplicationFactory + Postgres). Verificado que el test de aislamiento
      de la API falla si un servicio se salta el filtro de empresa.
- [x] Prueba manual de punta a punta: Migrator + API en Development + login/yo/Scalar OK. En Production sin
      `Jwt:Clave` la API no arranca (validación de opciones).

- [x] **API: cambio de contraseña** (`POST auth/cambiar-clave`): verifica la actual, valida la nueva con
      `CambiarClaveRequestValidator` (mín. 8, letras y números, distinta), revoca todas las sesiones y devuelve
      una nueva. Claim `debe_cambiar_clave` en el JWT. Política por defecto de la API: token válido **y** sin
      cambio pendiente; `auth/yo` y `auth/cambiar-clave` usan la política `sesion-iniciada`. `/auth` quedó
      fuera del grupo protegido por defecto; los módulos van en `v1.MapGroup("").RequireAuthorization()`.
- [x] **Web Blazor Server (paso 4)**:
      - MudBlazor 9; `InteractiveServer` **sin prerender** (global, en `App.razor`); tema `TemaAmsys`.
      - Sesión: cookie `amsys.sesion` (HttpOnly) con claims básicos + id de sesión; **los tokens de la API
        viven en el servidor** (`AlmacenSesiones` sobre `IDistributedCache`, hoy en memoria).
      - Login interactivo → código de un solo uso (60 s) → `GET /cuenta/completar-ingreso` emite la cookie
        (un circuito no puede escribir cookies). `POST /cuenta/salir` (antiforgery) revoca en la API.
        `GET /cuenta/sesion-expirada` limpia la cookie.
      - Renovación del token de acceso 1 min antes de vencer, **una sola a la vez por sesión** (candado):
        dos refrescos simultáneos serían "reuso" para la API y cerrarían la sesión.
      - `ProveedorEstadoAutenticacion` revalida la sesión cada minuto; la cookie se rechaza si la sesión ya no
        existe. Si la API devuelve 401, `ClienteApi` lleva a `sesion-expirada`.
      - Autorización: `Pages/_Imports.razor` pone `[Authorize]` a todas las páginas (política por defecto =
        sesión y sin cambio de clave pendiente). Las páginas de cuenta están en `Components/Cuenta/` para
        **no** heredarlo (si no, `cambiar-clave` se redirigía a sí misma en bucle — lo detectó un test).
      - `ClienteApi` tipado (`Contracts`) → `ResultadoApi<T>` / `ErrorApi` (lee ProblemDetails: título,
        `codigo`, errores por campo; mensajes genéricos por estado: 401, 403, 404, 429, 5xx).
      - Formularios validan con los **mismos validadores de `Contracts`** que la API (`ValidacionFormulario`).
      - Páginas: Login, Cambiar contraseña (obligatoria si `DebeCambiarClave`), Inicio, Seguridad/Usuarios
        (MudDataGrid con búsqueda), No encontrado, Acceso denegado. Layout con menú lateral y menú de usuario.
      - Menú: `Navegacion/MenuAmsys.cs` con `Modulo`/`Permiso` por opción; `Visibles()` es el punto de
        extensión para filtrar por módulos (paso 5) y permisos (NP-1).
- [x] Tests: **65/65**. Nuevo `tests/Amsys.Web.Tests` (WebApplicationFactory de la web con API simulada):
      redirecciones, código de un solo uso, cambio de clave obligatorio, open redirect, cookie sin sesión,
      renovación de token (10 llamadas simultáneas → 1 refresco), refresco rechazado.
- [ ] **Sin probar en navegador**: la parte visual (MudBlazor, menú, formularios) no se verificó con un
      navegador en esta sesión. Prueba manual pendiente del propietario.

- [x] **Configuración multicliente (paso 5)**:
      - Domain/Configuracion: catálogo de módulos en código (`Modulos`, 11 activables; el núcleo no se
        desactiva) + `EmpresaModulo`; `CampoPersonalizado` (Equipo, Ubicacion, OrdenTrabajo, Aviso; tipos Texto,
        TextoLargo, Numero, Fecha, SiNo, Lista; clave y tipo inmutables) + `ValidadorCamposPersonalizados`
        (valida y normaliza el JSON que llegará a `datos_adicionales`); `EtiquetaEstado` + `CatalogosEstado`
        (nombres por defecto en el dominio). Marca en `Empresa` (nombre comercial, colores).
      - Domain/Mantenimiento: enums canónicos `EstadoAviso`, `EstadoOrdenTrabajo`, `TipoAviso` (del legacy main).
      - Application: `ServicioConfiguracion` (configuración de la empresa actual: catálogo completo de módulos
        con activo/inactivo, todas las etiquetas resueltas, campos activos) y `ServicioConfiguracionEmpresa`
        (aplica un archivo de cliente; idempotente; **todo o nada** con transacción).
      - Migración `ConfiguracionMulticliente` (esquema `configuracion`). `GET /api/v1/configuracion`.
      - `Migrator --configurar <archivo>`; `tools/clientes/{README.md, _plantilla, demo}`.
      - Web: `ConfiguracionCliente` (una carga por circuito, en cascada desde `MainLayout`), tema y logo por
        cliente (`TemaAmsys.Crear`, `RecursosMarca` con respaldo), menú filtrado por módulo, `EstadoChip`,
        editor `CamposPersonalizados`, página Administración → Configuración (con vista previa de campos).
- [x] Tests: **100/100**. Un solo contenedor de PostgreSQL por proyecto de tests (`AssemblyFixture`):
      evita fallos intermitentes de Docker y baja el tiempo de ~30 s a ~12 s.
- [x] Probado contra la BD local: `--configurar` de demo (2ª vez "sin cambios"), archivo inválido rechazado
      sin cambios, `GET /configuracion` con la API real.
- [ ] **Sin probar en navegador**: pasos 4 y 5 (login, cambio de clave, menú, tema/logo, página de configuración).

## Pendiente inmediato

> Inventario completo de lo que falta migrar del legacy, con las rutas de ambos proyectos: `ai/PENDIENTES-MIGRACION.md`.
> Tareas listas para ejecutar: `ai/tareas/` (p. ej. `UI-01-tema-base-y-revision-visual.md`).

- [x] **UI-01** Tema base (D-UI-01) y revisión de Inicio y Ficha de OT — hecha, ver la tarea y sus capturas.
- [x] Cultura única en la web: es-PE (D-UI-03).
- [x] **NT-01a** Notificación del técnico: "Mis órdenes", play/pausa por tarea, materiales/servicios, ejecución y cierre
      técnico (D-NT-01…05). Ver `ai/tareas/NT-01-notificacion-tecnico.md`.
- [x] Mis avisos (D-NT-06) y pestañas con fondo blanco.
- [x] Campos fecha-hora: corregido "Not a valid date time" (`ConvertidorFechaHoraLocal`).
- [x] **Base compartida (D-MC-01) y portal de la plataforma (D-PL-01)**: Plataforma → Clientes. Falta en `amsys_dev`:
      `--configurar tools/clientes/amsys/configuracion.json` y `--crear-admin amsys` (ver `tools/clientes/README.md`).
- [x] **Tareas de la OT por sección (D-OT-01)**: referencia a sección/hoja de ruta, "Desde sección" en la ficha y grupos
      en la ficha y en la vista del técnico. Migración `TareaOrdenSeccion` (aplicada sólo en `amsys_ui`).
- [x] **Aspectos (D-NT-07)**: catálogo, aspectos de equipos y ubicaciones con historial, inspección desde la OT y el
      paso "Parámetros" del técnico. Migración `Aspectos` (aplicada sólo en `amsys_ui`).
- [ ] Aplicar en `amsys_dev` las migraciones `NotificacionTecnico`, `TareaOrdenSeccion` y `Aspectos` y la puesta en marcha de la plataforma (ver *Siguientes pasos* 1).
- [ ] NT-01b/c/d y revisión visual pendiente (ver *Siguientes pasos* 3–7).
- [x] UI-02 interfaz minimalista (D-UI-02): controles, barra superior y menú — capturas en `ai/tareas/capturas/UI-02/`.
- [ ] Logos de cliente: deben verse sobre la barra pizarra (logos claros o a color; uno oscuro no se leería).

- [ ] Prueba manual en navegador (ver *Entorno de desarrollo*). La BD local tiene la configuración `demo`, todas las
      migraciones y `admin` con el rol Administrador (clave temporal `Admin-Dev-2026`, la pedirá cambiar).
- [ ] **Fallo intermitente de los tests de integración** (4 veces hasta 2026-10-03): siempre en la primera ejecución
      tras compilar, decenas de tests fallan a la vez (fixture). Una vez se vio "contenedor exited with code 1". Los
      fixtures reintentan 3 veces e imprimen los logs del contenedor ("PostgreSQL no arrancó"). No se ha podido
      reproducir a voluntad. **Si vuelve a pasar: guardar la salida completa** (`dotnet test --solution Amsys.slnx > tests.log 2>&1`)
      y buscar "no arrancó" / "Exception". Repetir la ejecución pasa siempre.
- [ ] Confirmar la licencia de QuestPDF (D-NP-76) y revisar las fórmulas de indicadores con oterra (D-MC-06/D-NP-74).
- [ ] Probar en navegador inicio (tablero), Excel de las listas, PDF de una OT e indicadores.
- [ ] Probar en navegador logística: compra → existencias → salida a una OT (ver el costo en la OT) → traslado → anular.
- [ ] Probar en navegador el preventivo: sección → plan (matriz) → asignar equipos → Generar órdenes → cerrar la OT
      flotante y ver que se libera.
- [ ] Probar en navegador avisos y órdenes (aviso → aprobar → generar OT → tareas → ejecución → cierre técnico).
- [ ] El importador del legacy deberá traer empleados, socios de negocio y materiales, y convertir las 7 tablas de
      notificación a las 3 nuevas (D-NP-50), fijando el costo/hora con el actual del empleado.
- [ ] Probar en navegador el alcance por organización (asignar organizaciones a un usuario no administrador).
- [ ] Migración de usuarios del legacy: las claves son HMAC-SHA256 con clave fija en el código y sin sal
      (`CriptografiaUtilitario.ToSHA526`). En el ETL: verificar con ese algoritmo en el primer ingreso y re-hashear
      con PBKDF2, o forzar restablecimiento.
- [ ] Producción con varias réplicas de la web: Redis para `AlmacenSesiones`, claves de Data Protection
      compartidas, afinidad de sesión (Blazor Server).
- [ ] Zona horaria por empresa (hoy se usa la del servidor).
- [ ] Confirmar `D-MC-02` (JSONB para campos personalizados; validador ya implementado) y `D-MC-05`.
- [ ] Revisar carpeta `k8s/` (existe, vacía).

## NP-1 Maestros (completa)

- [x] **Roles y permisos**: catálogo de permisos en código (`Domain/Seguridad/Permisos.cs`), `Rol` por empresa,
      Administrador automático, permisos efectivos por petición (rol ∩ módulos activos, caché 1 min), sin escalada,
      `RequierePermiso` en la API, `GET /auth/permisos`, CRUD de roles; web: menú por permiso, `ConPermiso`,
      pantalla de roles.
- [x] **Usuarios**: alta con contraseña temporal, edición, activar/desactivar, restablecer clave, desbloquear;
      bloqueo tras 5 intentos fallidos (15 min).
- [x] **Catálogos simples** (14): patrón `ElementoCatalogo` + una clase por catálogo + registro `CatalogosSimples`;
      una tabla por catálogo (TPC, secuencia compartida `administracion.elemento_catalogo_id_seq`); servicio y
      endpoints genéricos `/administracion/catalogos/{clave}`; código repetido = advertencia (D-03); web genérica
      (índice por grupos + página por catálogo + diálogo).
- [x] Tests: **144/144**.

**Pendiente de NP-1 (no bloquea NP-2):**
- Catálogos con campos propios: `Calificacion` (valor), `Aspecto` (tipo + opciones), `ClaseEquipo` (tipos, datos
  técnicos, modos de falla), `UnidadMedidaServicio` (decide la programación de planes), `Sistema`/`Parte`,
  `Empleado` (costo por hora), `Material`, `Servicio`, `SocioNegocio`. Se harán cuando los necesite su etapa.
- Columna "En uso" y aviso al desactivar un elemento usado (cuando existan las entidades que los referencian).
- Límites de usuarios por perfil (`Limitacion` del legacy).

## NP-2 Activos

### 2.1 Organizaciones, ubicaciones y equipos ✅
- Domain: `Organizacion` (árbol, Seguridad), `Ubicacion` (árbol, mantenible, orden), `Equipo` (datos generales,
  horario de operación con `DiasSemana`, montaje exclusivo en ubicación **o** equipo padre), `MovimientoEquipo`
  (historial; quién = `CreadoPor`), `Jerarquia.CreaCiclo` (también corta datos ya corruptos), `IConDatosAdicionales`
  (campos personalizados en jsonb; los valores de campos desactivados se conservan al editar).
- Application: `ConsultasTexto.Buscar` (búsqueda sin mayúsculas reutilizable → `lower() LIKE`) y `Paginar`;
  `ValidacionActivos` (referencias activas salvo que no cambien, campos personalizados, aviso de código repetido);
  servicios de organizaciones, ubicaciones y equipos (montar/desmontar/movimientos/árbol). Crear un equipo ya
  montado es transaccional.
- API: `/organizaciones`, `/activos/ubicaciones`, `/activos/equipos` (paginados, filtros), `/montar`, `/desmontar`,
  `/movimientos`, `/activos/arbol`. Permisos nuevos: `activos.ver`, `activos.editar`, `seguridad.organizaciones.editar`;
  `RequiereAlgunPermiso`.
- Web: selectores reutilizables (`SelectorOrganizacion`, `SelectorCatalogo`, `BuscadorActivo`), `ValoresCampos`
  (JSON ↔ editor), páginas Organizaciones, Ubicaciones (diálogo), Equipos (lista paginada en servidor con columnas de
  campos personalizados) y ficha de equipo (pestañas, montaje, historial), Árbol de activos (inactivos atenuados).
- Migración `ActivosUbicacionesEquipos`. Tests: **167/167**.

### 2.2 Clases de equipo ✅
- `ClaseEquipo` (agregado) con `TipoEquipo`, `DatoTecnico` (definiciones) y modos de falla (owned, FK al catálogo).
  Sincronización por lista: con `Id` actualiza (debe ser de la clase: corrige AD-03 del legacy), sin `Id` crea, lo que
  falta se quita salvo tipos usados por equipos (desactivar) o datos técnicos con valores (bloqueado).
- `Equipo.Clasificar(clase, tipo, valores)`: tipo de la clase, valores sólo de datos de la clase; al cambiar de clase
  quita los que no aplican y la API **avisa** cuántos (el legacy los borraba sin aviso). Valores en
  `activos.equipo_dato_tecnico` (owned).
- API `/activos/clases` (lectura con `catalogos.ver` o `activos.ver`, edición con `catalogos.editar`).
- Web: Administración → Clases de equipo (tabla editable de tipos y datos técnicos con contadores de uso, modos de
  falla), ficha de equipo con clase, tipo y pestaña de datos técnicos (confirma antes de cambiar de clase).
- `Result<T>.Entonces(...)`. Migración `ClasesEquipo`. Tests: **179/179**.

### 2.3 Contadores y puntos de medida ✅
- `UnidadMedidaServicio` (Calendario con periodo / Contador / PuntoMedida): en uso no cambia de tipo ni periodo (AD-12).
- `Contador` por equipo (uno activo por equipo y unidad, índice único parcial): alimentación acumulada (no baja) o
  parcial (suma); lecturas no futuras ni anteriores a la última; promedio diario manual o calculado. `LecturaContador`
  (historial con diferencia y origen).
- `PuntoMedida` con límites de control (advertencia) y alarma (orden validado); `MedicionPuntoMedida` clasificada
  Normal/Advertencia/Alarma; una medición atrasada queda en el historial sin cambiar el valor actual.
- Concurrencia: dos lecturas simultáneas → `Medicion.Simultanea` (409) gracias al `xmin` del contador/punto.
- Permiso nuevo `activos.lecturas.registrar` (técnicos registran sin editar el equipo).
- API `/administracion/unidades-servicio`, `/activos/equipos/{id}/contadores|puntos-medida`, `/activos/contadores/{id}/lecturas`,
  `/activos/puntos-medida/{id}/mediciones`. Web: Administración → Unidades de servicio; pestañas Contadores y Puntos
  de medida en la ficha del equipo (registro, historial, nivel con color). Migración `ContadoresPuntosMedida`.
- Tests: **198/198**.
- **Pendiente para NP-3**: crear un aviso automático al medir en alarma (`Configuracion.CrearAvisoPorPuntoMedida`).
  **Pendiente para NP-4**: la UMS también "en uso" por planes; proyección de contadores con el horario de operación.

### 2.4 Alcance por organización (D-NP-32) ✅
- `Usuario.Organizaciones` (tabla `seguridad.usuario_organizacion`). Alcance = asignadas + descendientes
  (`Jerarquia.ConDescendientes`); `null` (sin restricción) si no tiene asignadas o su rol es administrador.
- `ServicioAlcance` lo calcula por petición (caché 1 min, clave con `VersionPermisos`; se invalida al editar usuarios u
  organizaciones). Middleware `UseAlcanceOrganizacion()` en la API, tras `UseAuthorization()`.
- Entidades con `IEntidadOrganizacion` (hoy `Ubicacion`, `Equipo`; en NP-3 `Aviso` y `OrdenTrabajo`): filtro global
  `FiltrosConsulta.Organizacion` + el interceptor lanza si se guarda fuera del alcance (respaldo).
- `ValidacionActivos.OrganizacionAsync` → `Activos.OrganizacionFueraDeAlcance` (403). `OrganizacionResponse.EnAlcance`;
  el `SelectorOrganizacion` sólo ofrece las del alcance.
- Usuarios: `OrganizacionIds` en alta/edición (`null` = sin cambio, vacío = todas). Un usuario restringido sólo asigna
  organizaciones de su alcance y no puede dejar a otro sin restricción. Web: selector múltiple en el diálogo de usuario.
- Migración `AlcanceOrganizacion` (aplicada en la BD de desarrollo). Tests: **206/206**.
- Entidades hijas de un equipo (contadores, puntos de medida, movimientos) no llevan el filtro propio: los servicios
  las buscan a través del equipo visible (`ContadoresVisibles`/`PuntosVisibles` en `ServicioMediciones`). Cubierto por
  test (lectura en un contador de otra organización → 404). **Regla para NP-3**: toda entidad hija que se consulte por
  su propio id debe pasar por su padre visible o implementar `IEntidadOrganizacion`.

### Pendiente de NP-2
- Avisar al desactivar o desmontar un equipo con planes (cuando existan los planes, NP-4).

## NP-3 Correctivo

Plan: **3.1 Avisos** ✅ · 3.2 OT desde aviso (tareas, estados, el aviso pasa a Atendido/Finalizado/Aprobado según la
OT, en la misma transacción) · 3.3 Notificación (horas de personal, materiales, lecturas al cerrar) · 3.4 Kanban de
OT · 3.5 Costos de OT.

### 3.1 Avisos ✅
- Dominio `Mantenimiento/Aviso` (D-NP-43/45): tipo fijo, estados con historial (`aviso_historial`, owned), datos de
  falla (método de detección, parada con inicio/fin y horas), análisis de falla (modo, causa, mecanismo, impacto) sólo
  en fallas aprobadas/atendidas, campos personalizados (`datos_adicionales`), `IEntidadOrganizacion` (alcance D-NP-32),
  `PuntoMedidaId` de origen.
- Código correlativo `AV-AAAA-NNNNN` sin carreras (D-NP-42): `ICorrelativos` + `mantenimiento.correlativo`; test con 10
  altas simultáneas.
- Permisos `mantenimiento.avisos.ver|crear|gestionar` (D-NP-44); estados/tipos deshabilitados por la empresa no se asignan.
- API `/mantenimiento/avisos` (lista paginada con filtros por estado, tipo, organización, equipo, ubicación y fechas;
  ficha; alta; edición; `POST /{id}/estado`). La respuesta trae `EstadosSiguientes` y `PuedeEditar…` según permisos.
- Web: Mantenimiento → Avisos (lista con filtros y columnas personalizadas), ficha con acciones de estado (diálogo con
  motivo), historial; "Crear aviso" desde la ficha del equipo y desde un punto de medida en alarma (prellenado).
- `GET /administracion/catalogos/{clave}` sólo pide sesión (D-NP-41).
- Fechas: se editan en hora local y se guardan en UTC (zona por empresa sigue pendiente).
- Migración `Avisos` (aplicada en la BD de desarrollo). Tests: **226/226**.
- **Pendiente de avisos**: adjuntos (falta almacenamiento de archivos), foto de contadores/puntos al reportar una falla
  (`AvisoContador`/`AvisoPuntoMedida`, para indicadores, NP-6), aviso automático al medir en alarma
  (`Configuracion.CrearAvisoPorPuntoMedida` del legacy; hoy se ofrece crearlo con un clic), exportar a Excel,
  conformidad del solicitante (módulo `CONFORMIDAD_AVISO`), campos de Solicitudes (módulo `SOLICITUDES`).

### 3.2 Órdenes de trabajo ✅
- Dominio `Mantenimiento/OrdenTrabajo` (D-NP-46): código `OT-AAAA-NNNNN` (mismo correlativo), objeto técnico y
  organización (alcance), aviso de origen, tipo de mantenimiento, taller, prioridad, centro de costo, cuenta contable,
  programación e inicio/fin de ejecución, equipo detenido, comentario, observación, motivo de anulación, campos
  personalizados, tareas (owned `orden_trabajo_tarea`: descripción, tipo, especialidad, personas, horas, hecha;
  reemplazo por Id) e historial (`orden_trabajo_historial`).
- Aviso ↔ OT en la misma transacción (D-NP-47): `Aviso.AtenderPorOrden`, `FinalizarPorOrden`, `ReabrirPorAnulacion`;
  el aviso muestra sus órdenes y si se puede generar una.
- `ObjetosTecnicos` (Application/Mantenimiento): resolución equipo/ubicación → organización, nombres, estados
  deshabilitados y utilidades, compartidos por avisos y órdenes.
- Permisos `mantenimiento.ordenes.ver|editar|cerrar` (D-NP-48). API `/mantenimiento/ordenes` (lista con filtros por
  estado, abiertas, organización, equipo y aviso; ficha; alta; edición; `POST /{id}/estado` → `Guardado` con advertencias).
- Web: Mantenimiento → Órdenes de trabajo (lista con avance de tareas), ficha con tareas editables, programación y
  ejecución, acciones de estado (diálogo genérico `CambiarEstadoDialogo`), historial; "Generar orden" desde el aviso.
- Migración `OrdenesTrabajo` (aplicada en la BD de desarrollo). Tests: **240/240**.
- **Pendiente de OT**: materiales (necesita el maestro de materiales, NP-5), personal y proveedores programados
  (necesita maestros de empleados y socios de negocio → 3.3), adjuntos y comentarios, PDF (módulo `REPORTE_PDF_OT`),
  OT padre/hija, exportar a Excel.

### 3.3 Notificación y costos ✅
- Maestros (D-NP-53): `Empleado` (documento único, especialidad, costo/hora, horas/día, ingreso/cese, personal de
  mantenimiento), `SocioNegocio` (RUC, nombre, correo, teléfono), `Material` (código único, descripción, unidad,
  tipo, precio de referencia). API `/administracion/empleados|socios-negocio|materiales`; páginas en Administración.
- OT: líneas owned `orden_trabajo_mano_obra|material|servicio` (D-NP-50) con reemplazo por Id; costo/hora congelado
  al registrar (D-NP-51); costos por tipo y total en la respuesta y en la lista de órdenes.
- `PUT /mantenimiento/ordenes/{id}/notificacion` (cada lista `null` = no cambia), permiso `ordenes.notificar`;
  emitida o en cierre técnico, no tras el cierre total (D-NP-52).
- Web: sección "Notificación" en la ficha de la OT (tres tablas editables, totales en vivo) y panel con los contadores
  y puntos de medida del equipo para registrar lecturas.
- Migración `NotificacionOrdenes` (aplicada en desarrollo). Tests: **248/248**.
- Con esto **3.5 Costos queda cubierto en lo básico** (costo por OT). Lo que resta (consolidado por equipo, centro de
  costo y periodo; módulo `COSTOS_OT_AVANZADO`) va con los reportes (NP-6).
- **Pendiente**: lecturas vinculadas a la OT (hoy se registran con origen Manual), programación de personal
  (`ProgramacionEmpleado`), turnos, comentarios y adjuntos de OT, selector de materiales con búsqueda en servidor
  (hoy carga hasta 500).

### 3.4 Tablero de órdenes ✅
- `ServicioTableroOrdenes`: `GET /mantenimiento/ordenes/tablero` (4 columnas con total, primera página, cursor y
  destinos permitidos para el usuario) y `GET .../tablero/columna?estado&cursor` ("ver más"). Filtros: búsqueda,
  organización, tipo de mantenimiento, prioridad. Tarjeta: código, descripción, objeto técnico, aviso, prioridad,
  tipo, programación, avance de tareas, en ejecución, atrasada (D-NP-54).
- Web: Mantenimiento → Tablero de órdenes (`MudDropContainer`): arrastrar entre columnas, sólo hacia destinos válidos,
  con el diálogo de confirmación/motivo y las advertencias del cambio de estado.
- Sin migración. Tests: **251/251**.

**NP-3 completa.** Pendientes acumulados de NP-3 (ver cada sección): adjuntos y comentarios, PDF de OT, exportar a
Excel, aviso automático por alarma, lecturas vinculadas a la OT, programación de personal.

## NP-4 Preventivo

Fuente: `ai/BUSINESS-RULES.md` del legacy (reglas BR-HR/SE/TA/PM/AS/GE con nivel de confianza y decisiones del
propietario D-02/D-03/D-05). Plan: **4.1** hojas de ruta y secciones ✅ · **4.2** planes y cálculo de posiciones ✅ ·
**4.3** asignaciones a equipos/ubicaciones · **4.4** previsualización y generación a demanda (sin automatizar, D-05).

### 4.1 Hojas de ruta y secciones ✅
- Dominio `Planificacion/HojaRuta`, `Seccion` (hoja opcional; tareas owned `seccion_tarea` con orden, tipo,
  especialidad, personas, horas y texto ampliado; materiales owned `seccion_material`), duplicar (BR-SE-006).
  Esquema `planificacion`.
- API `/planificacion/hojas-ruta`, `/planificacion/secciones` (`paraElegir`: activas de hojas activas o sin hoja,
  BR-HR-003). Advertencias de código repetido (hoja: empresa; sección: misma hoja) y de sección usada por planes.
- Web: Planificación → Hojas de ruta (hojas a la izquierda, secciones a la derecha), ficha de sección con tareas
  ordenables y materiales.

### 4.2 Planes y cálculo de posiciones ✅
- Dominio `Planificacion/PlanMantenimiento` (D-NP-55): UMS calendario o contador, intervalo, factor de planificación
  validado (BR-PM-009), tipo de ciclo, secciones del plan (`plan_seccion`: cada N ciclos, nivel, prioridad, tipo de
  mantenimiento, taller, equipo detenido), `CantidadPosiciones`, `Mcm`, `Comportamiento()`, `SeccionesEn(posición
  absoluta)`, `Advertencias()` (empates de nivel, posiciones vacías — D-NP-57).
- Tests de dominio: casos documentados del legacy + **equivalencia con el algoritmo legacy en 500 casos aleatorios**.
- API `/planificacion/planes` + `POST /vista-previa` (D-NP-58). Web: lista y ficha con matriz secciones × posiciones
  que se recalcula en el servidor mientras se edita (debounce 400 ms).
- Permisos `planificacion.ver|editar|generar`, sólo con el módulo `PLANIFICACION` (D-NP-59). Migración
  `Planificacion` (aplicada en desarrollo). Tests: **271/271**.
- Pendiente de 4.1/4.2: servicios de terceros en la sección (`SeccionServicio` del legacy; requiere un maestro de
  servicios), adjuntos de sección, `Sistema`/`Parte` de las tareas (catálogos no migrados aún).

### 4.3 Asignaciones ✅ y 4.4 Generación a demanda ✅ (decisiones D-NP-60…67 aceptadas)
- Dominio `Planificacion/PlanAsignacion` (`plan_asignacion`, alcance por organización): equipo o ubicación (índices
  únicos por plan, también para ubicaciones), fija/flotante, posición inicial y **posición absoluta** que se lee
  dentro del ciclo (D-NP-64). Calendario: próxima fecha (inicio hoy o futuro, BR-AS-006). Contador (sólo equipos,
  D-NP-62): contador del equipo + lectura base; contador del plan = inicio + (lectura − base), rango BR-AS-005.
  `Evaluar` (vence, posición, atrasadas), `Avanzar` (una posición, D-NP-60), `CambiarProgramacion` (no reinicia),
  `ReiniciarCiclo` (explícito, D-NP-67), `Desbloquear(motivo)` y `LiberarPorOrden` (sólo la OT que bloqueó, D-NP-61).
- `OrdenTrabajo.PlanId/PlanAsignacionId/PosicionPlan` (`VincularPlan`); al cierre técnico/total o anulación de esa OT
  se libera la asignación flotante.
- Plan con asignaciones: no cambia de unidad (D-NP-63); si cambia el número de posiciones, advertencia (D-NP-64).
- API: `GET|POST /planificacion/planes/{id}/asignaciones` (asignación masiva de equipos), `PUT
  /planificacion/asignaciones/{id}/programacion`, `POST …/reiniciar`, `POST …/desbloquear`, `DELETE` (bloqueado con OT
  emitidas, D-NP-65); `GET /planificacion/generacion` (previsualización con motivo de lo no generable: bloqueada,
  equipo inactivo o sin montar, contador cambiado…) y `POST /planificacion/generacion` (permiso `generar`).
- Generación (BR-PM-006/007, BR-GE-012, D-NP-66): cabecera de la sección de mayor ciclo, descripción "plan · secciones",
  tareas de todas las secciones agrupadas por sección y en su orden, centro de costo y organización del objeto
  técnico, inicio programado = fecha de la posición; transacción única con correlativo; concurrencia por `xmin`.
- Web: asignaciones en la ficha del plan (asignar varios equipos, cambiar programación, reiniciar con confirmación,
  desbloquear con motivo, quitar), Planificación → Generar órdenes (selección, resultado con enlaces y omitidas), y la
  ficha de la OT indica el plan y la posición de origen.
- Migración `AsignacionesPlanes` (aplicada en desarrollo). Tests: **284/284**.
- **Pendiente de NP-4**: materiales previstos de la sección → materiales planificados en la OT (necesita reservas de
  logística, NP-5), servicios de sección, excel de previsualización/planificación anual (NP-6), ajuste del contador
  del plan con el valor real al cerrar la OT (BR-GE-010 del legacy), aviso cuando un equipo con planes se desmonta.

## NP-5 Logística ✅

Fuente: entidades y lógicas `AMSYS.Logicas/Logistica` del legacy y su `ai/PLAN-UX-LOGISTICA.md` (LG-01…17, decisiones
DL-01…05 del propietario).
- Dominio `Logistica/`: `Almacen` (no se desactiva con existencias), `Existencia` (cantidad, valor, costo promedio,
  punto de reposición), `Movimiento` (kardex: inicial, entrada, salida, final en cantidad y valor), `NotaEntrada`
  (Compra/Ajuste del usuario; Traslado/AnulacionSalida del sistema; líneas = lotes con disponible y valor disponible),
  `NotaSalida` (SalidaAlmacen con OT opcional, Ajuste, Traslado con destino; AnulacionEntrada del sistema; costo FIFO
  por línea), `OperacionesInventario` (anular entrada/salida, entrada de traslado, anular traslado). D-NP-68…72.
- Tests de dominio: FIFO, conservación exacta del valor al consumir por partes, kardex, tipos elegibles, anulaciones,
  traslados.
- Aplicación: `ServicioAlmacenes`, `ServicioExistencias`, `ServicioNotasInventario` (transacción + bloqueo + correlativo;
  re-validación de existencias con el bloqueo y mensaje con material y almacén, LG-05), `ServicioKardex`.
- OT: el costo total suma las salidas de almacén no anuladas (DL-01); la notificación muestra la lista y ofrece
  "Salida de almacén para esta orden"; sólo contra OT emitidas o en cierre técnico (DL-05).
- API `/logistica/almacenes|existencias|notas-entrada|notas-salida|kardex`. Web: Logística → Existencias (filtros,
  punto de reposición editable, valor total), Notas de entrada/salida (lista y ficha con alta, relacionadas y anular con
  explicación), Kardex (por almacén y material), Almacenes.
- Migración `Logistica` (aplicada en desarrollo). Tests: **301/301** (incluye 4 salidas simultáneas sobre stock 10: sólo
  pasan 2).
- **Pendiente**: hoja de aceptación de servicios (requiere maestro de servicios), reservas de materiales previstos por
  los planes, exportación del kardex a Excel (NP-6), filtros por fecha en la web, importación de stock inicial del legacy
  (convertir `NotaEntradaMaterial.Disponible` a lotes con valor disponible).

## NP-6 Reportes y módulos

Plan: **6.1** tablero de inicio ✅ · **6.2** Excel ✅ · **6.3** PDF de OT ✅ · **6.4** indicadores de confiabilidad ✅ ·
**6.5** módulos exclusivos de oterra (`AREAS_IMPACTO`, `CONFORMIDAD_AVISO`, `TURNOS_PROGRAMACION`) — **D-MC-04 decidida:
exclusivos de oterra**, se construyen en la ola 4 con su migración. Otros módulos de cliente (`SOLICITUDES` de
eulen/caja_arequipa, `FERIADOS` y calificación de OT de caja_arequipa) se hacen con la ola de su cliente.

- **Tablero de inicio** (`GET /reportes/tablero`): avisos abiertos y por mes (fallas/solicitudes), fallas del mes,
  órdenes abiertas/atrasadas/cerradas en el mes y por tipo de mantenimiento, preventivo por generar, materiales por
  reponer y valor del inventario. Cada bloque según permiso (y módulo). Web: tarjetas, gráficos y accesos.
- **Excel** (`IExportadorExcel`, ClosedXML): avisos, órdenes, equipos, existencias y kardex con los mismos filtros de la
  lista y una columna por campo personalizado. Web: botón "Excel" en cada lista (`BotonDescarga` + `wwwroot/js/descargas.js`;
  la web descarga de la API y entrega el archivo al navegador sin exponer tokens).
- **PDF de la orden** (`IGeneradorPdfOrden`, QuestPDF; módulo REPORTE_PDF_OT, permiso `ordenes.imprimir`): marca de
  la empresa, datos, campos personalizados, tareas con casillas, ejecución y costos, observaciones, firmas. Plantilla por
  cliente con la general por defecto. (Glifo ☑ no disponible en las fuentes: la casilla se dibuja.)
- **Indicadores** (`Confiabilidad` en el dominio + `ServicioIndicadores`; módulo INDICADORES_CONFIABILIDAD): MTBF, MTTR,
  disponibilidad por equipo, total y por mes, filtrable por equipos u organización. D-NP-73/74. Web: Reportes →
  Indicadores de confiabilidad.
- Sin migración. `demo` con REPORTE_PDF_OT activado. Tests: **309/309**.
- **Pendiente**: confirmar licencia de QuestPDF (D-NP-76); revisar las fórmulas con cada cliente (D-MC-06); fuentes en el
  servidor de producción (Linux/Docker) para QuestPDF; reportes del legacy no portados aún: proyección de
  mantenimiento (Excel de planificación anual), reporte de notificación de tareas, Excel de previsualización del plan.

## Entorno de desarrollo

- PostgreSQL de desarrollo: **servidor del usuario** en Docker (contenedor `bdpostgresql`, imagen `jsulca/postgresql:v1`,
  PostgreSQL 14.1, puerto 5432, usuario/clave `postgres`/`123`, BD `amsys_dev`). Es la cadena de
  `src/Amsys.Api/appsettings.Development.json` (desde 2026-10-03). Ese servidor también tiene las bases del legacy
  (`amsys`, `amsys_v3_<cliente>`): fuente para el importador.
  - El contenedor anterior `amsys-postgres-dev` (postgres:17, clave `postgres`) quedó detenido; ocupan el mismo puerto,
    no deben correr a la vez. Los tests usan su propio Postgres 17 con Testcontainers.
- Migrar + semilla: `dotnet run --project src/Amsys.Migrator -- --semilla-desarrollo "--ConnectionStrings:Amsys=Host=localhost;Port=5432;Database=amsys_dev;Username=postgres;Password=123" "--Semilla:ClaveAdmin=<clave>"`
- API: `dotnet run --project src/Amsys.Api --launch-profile http` → Scalar en `http://localhost:5276/scalar/v1`
- Web: `dotnet run --project src/Amsys.Web --launch-profile http` → `http://localhost:5296` (necesita la API corriendo;
  `Api:UrlBase` en `src/Amsys.Web/appsettings.Development.json`)
- Usuario de desarrollo: `admin` (empresa `demo`); la clave es la pasada en `Semilla:ClaveAdmin`.
- Configuración de desarrollo: `dotnet run --project src/Amsys.Migrator -- --configurar tools/clientes/demo/configuracion.json "--ConnectionStrings:Amsys=..."`
- En otros entornos `Jwt:Clave` y la cadena van por variables de entorno (`Jwt__Clave`, `ConnectionStrings__Amsys`).

## Cómo trabajar

- Compilar: `dotnet build Amsys.slnx` (Release = warnings como errores).
- Tests: `dotnet test --solution Amsys.slnx` — **requiere Docker Desktop encendido** (Infrastructure y Api tests).
  Detén la API/Web si están corriendo: bloquean los .exe y la compilación falla (MSB3027).
- Nueva migración: `dotnet ef migrations add <Nombre> -p src/Amsys.Infrastructure -s src/Amsys.Infrastructure -o Persistence/Migrations`
- Ver SQL: `dotnet ef migrations script -p src/Amsys.Infrastructure -s src/Amsys.Infrastructure`

## Bitácora

| Fecha | Avance |
|-------|--------|
| 2026-10-02 | Análisis de ramas por cliente en el legacy → `PLAN-MULTICLIENTE.md` (en el repo legacy) |
| 2026-10-02 | Propuesta de nueva plataforma (inicialmente Blazor WASM, luego cambiado a Server) + API separada → `PLAN-NUEVA-PLATAFORMA.md` (legacy) |
| 2026-10-02 | Creados `global.json`, `Directory.Build.props`, `Directory.Packages.props` |
| 2026-10-02 | Creados los 12 proyectos restantes; Blazor aplanado de `src/Amsys.Web/Amsys.Web*` a `src/`; tests migrados de xunit v2 a xunit.v3; runner MTP activado en `global.json` |
| 2026-10-02 | Creada esta carpeta `ai/` |
| 2026-10-02 | Decisiones D-NP-01 (Blazor **Server**), D-NP-02 (repo `amsys`), D-NP-03 (Minimal APIs), D-NP-04 (nueva app móvil). `Amsys.Web` regenerado como Blazor Server, `Amsys.Web.Client` eliminado, paquetes WebAssembly quitados de CPM. Build OK |
| 2026-10-02 | Paso 1: limpieza de plantillas, `.editorconfig`, commit inicial |
| 2026-10-02 | Paso 2: dominio base (Entidad, Result, Empresa, Usuario), `AmsysDbContext` con filtros por empresa y eliminados, `AuditoriaInterceptor`, migración `Inicial`, 27 tests verdes (incluye aislamiento entre empresas con Postgres real) |
| 2026-10-02 | Paso 3: autenticación JWT + refresh token rotado con detección de reuso, Minimal APIs `/api/v1`, ProblemDetails, validación, límite de intentos, OpenAPI/Scalar, Migrator con semilla, 41 tests verdes, prueba manual de punta a punta con Postgres local en Docker |
| 2026-10-02 | Paso 4: `auth/cambiar-clave` + política "sin cambio de clave pendiente" en API y web; web Blazor Server con MudBlazor, sesión con tokens en servidor, renovación con candado por sesión, login, cambio de clave, inicio, usuarios; nuevo `Amsys.Web.Tests`; 65 tests verdes. Bug de bucle de redirección en `cambiar-clave` detectado por test y corregido. Falta prueba manual en navegador |
| 2026-10-03 | Paso 5: configuración multicliente (módulos, campos personalizados con validador, etiquetas de estado, marca), archivo por cliente aplicado con el Migrator (idempotente, transaccional), `GET /configuracion`, web con tema/logo/menú por cliente y página de configuración; un contenedor Postgres por proyecto de tests; 100 tests verdes. **NP-0 completa** salvo prueba manual en navegador |
| 2026-10-03 | NP-1.1 roles y permisos: catálogo de permisos en código (por módulo), `Rol` por empresa (Administrador automático), permisos evaluados en cada petición con caché de 1 min e invalidación al editar roles, sin escalada de privilegios, `RequierePermiso` en la API, `GET /auth/permisos`, CRUD de roles, web con menú por permiso, `ConPermiso` y pantalla de roles. **Hueco detectado por test y corregido**: una política propia en un endpoint anulaba la política por defecto (usuario con clave pendiente accedía). 115 tests verdes |
| 2026-10-03 | NP-1.2 gestión de usuarios: alta con contraseña temporal generada (se muestra una vez), edición, activar/desactivar (cierra sesiones), restablecer clave, desbloquear, roles asignables sin escalada, nadie se desactiva ni se cambia el rol a sí mismo; bloqueo tras 5 intentos fallidos durante 15 min; web con acciones por usuario. Fixtures de Postgres con reintento y logs (fallo intermitente de arranque tras compilar). `Amsys.Application.Tests` ya tiene tests. 127 tests verdes |
| 2026-10-03 | NP-1.3 catálogos simples: 14 catálogos con un solo patrón (TPC, registro, servicio/endpoints/página genéricos), advertencia por código repetido (D-03). **NP-1 completa**. 144 tests verdes |
| 2026-10-03 | NP-2.1 organizaciones, ubicaciones y equipos: árboles sin ciclos, montaje con historial, campos personalizados en jsonb (se conservan los de campos desactivados), listas paginadas con búsqueda, árbol de activos, permisos de activos. 167 tests verdes |
| 2026-10-03 | NP-2.2 clases de equipo: agregado con tipos, datos técnicos y modos de falla; equipo clasificado con valores técnicos; corrige AD-03 (mover hijos ajenos) y el borrado silencioso al cambiar de clase. 179 tests verdes |
| 2026-10-03 | NP-2.3 unidades de servicio, contadores (lecturas acumuladas/parciales, promedio diario) y puntos de medida (niveles de alarma), permiso para registrar lecturas, control de concurrencia. 198 tests verdes. NP-2 completa salvo el alcance por organización (D-NP-32) |
| 2026-10-03 | D-NP-32 alcance por organización: usuarios con organizaciones asignadas ven esas y sus descendientes (filtro global + respaldo en el interceptor), validación al crear/editar activos y usuarios, `EnAlcance` en organizaciones, selector múltiple en usuarios. Migración `AlcanceOrganizacion`. 206 tests verdes. **NP-2 completa** |
| 2026-10-03 | NP-3.1 avisos: dominio con máquina de estados e historial, correlativo sin carreras, falla/parada/análisis, campos personalizados, alcance por organización, permisos ver/crear/gestionar, API y web (lista, ficha, cambio de estado, crear desde equipo o punto en alarma). Lectura de catálogos con sólo sesión (D-NP-41). Fixture de Postgres: el reintento ya no se rompe si el contenedor no llegó a crearse. 226 tests verdes |
| 2026-10-03 | D-NP-23 decidido (sin PROGRAMADO ni PARADA). NP-3.2 órdenes de trabajo: dominio con tareas e historial, estados con permisos ver/editar/cerrar, aviso atendido/finalizado/reabierto en la misma transacción (varias OT por aviso), API y web (lista, ficha con tareas, generar desde aviso). 240 tests verdes |
| 2026-10-03 | NP-3.3 notificación: maestros de empleados, socios de negocio y materiales; mano de obra (costo/hora congelado), materiales y servicios (del maestro o externos) con costos por OT; cierre total congela. Web: páginas de maestros y notificación en la ficha de la OT. 248 tests verdes |
| 2026-10-03 | NP-3.4 tablero Kanban de OT (columnas por estado, cursor, destinos por permisos, arrastrar para cambiar de estado). **NP-3 completa**. 251 tests verdes |
| 2026-10-03 | NP-4.1 hojas de ruta y secciones; NP-4.2 planes con cálculo de posiciones portado con tests primero (equivalencia con el legacy en 500 casos aleatorios), vista previa de la matriz en el servidor, módulo PLANIFICACION. Decisiones D-NP-55…59 tomadas y D-NP-60…67 propuestas para 4.3/4.4. 271 tests verdes |
| 2026-10-03 | D-NP-60…67 aceptadas. NP-4.3 asignaciones (calendario/contador, fija/flotante, reinicio explícito, desbloqueo manual) y NP-4.4 generación a demanda (previsualización con motivos, una posición por vez, OT con tareas agrupadas, liberación por la OT concreta). **NP-4 completa**. 284 tests verdes |
| 2026-10-03 | NP-5 Logística: almacenes, existencias con reposición, notas de entrada (lotes) y salida (FIFO con valor exacto), traslado como documento único, anulaciones coherentes, kardex, bloqueo de inventario por empresa, costo de almacén en la OT (DL-01/02/04/05). **NP-5 completa**. 301 tests verdes |
| 2026-10-03 | NP-6.1–6.4: tablero de inicio, exportación a Excel con campos personalizados, PDF de OT con plantilla por cliente, indicadores de confiabilidad (fórmulas de oterra corregidas, tiempo de operación por horario del equipo). ClosedXML y QuestPDF. 309 tests verdes |
| 2026-10-03 | D-MC-04 decidida: los módulos de oterra son exclusivos de oterra; se construyen en la ola 4. NP-6 cerrada para el producto |
| 2026-10-03 | Base de desarrollo movida al servidor Docker del usuario (`bdpostgresql`, PG 14.1, clave `123`): 16 migraciones aplicadas, semilla (`demo` + `admin`, clave temporal `Admin-Dev-2026`) y configuración `demo`; `appsettings.Development.json` de la API actualizado |
| 2026-10-03 | Inventario de pendientes de migración en `ai/PENDIENTES-MIGRACION.md` (funcionalidades del legacy faltantes, partes incompletas, módulos de clientes, salida a producción, orden recomendado, skills para la UI) |
| 2026-10-03 | Tarea UI-01 (tema base de MudBlazor + revisión de Inicio y Ficha de OT con `frontend-design`) creada en `ai/tareas/` |
| 2026-10-03 | UI-01: tema base (D-UI-01: neutros fríos, semánticos AA, Archivo, paneles con borde; primario del cliente oscurecido automáticamente hasta 4.5:1, barra con su color y texto por contraste). Inicio con franja de indicadores y accesos agrupados; ficha de OT con encabezado "placa", campos densos, cifras a la derecha y resumen de costos. Capturas antes/después y con 3 colores en `ai/tareas/capturas/UI-01/` (BD aparte `amsys_ui`). 322 tests verdes, Release sin advertencias |
| 2026-10-03 | UI-02 (pedido del usuario): interfaz minimalista. Campos con etiqueta fija encima, borde de 1px y foco con anillo suave (CSS global, todas las páginas); tablas planas; barra superior pizarra con línea de marca, botón "Nuevo" (altas por permiso) y menú de usuario con iniciales; menú lateral compacto; MudBlazor en español (`LocalizadorMud`: paginadores, filtros). Corregido en el camino: menú de usuario con `ActivatorContent` debe llamar a `context.ToggleAsync` (MudBlazor 9). 328 tests verdes, Release sin advertencias |
| 2026-10-03 | D-UI-03: formato de Perú en toda la web (cultura es-PE fija, importes `3,850.00`, campos numéricos `0.00##`, fechas `dd/MM/yyyy`) y tipografía Poppins con tamaños menores (menú más discreto). 331 tests verdes, Release sin advertencias |
| 2026-10-03 | Análisis de la notificación del técnico del legacy (play/pause `NotificacionTarea`, parámetros, valor de ejecución) frente a la plataforma nueva; propuesta por fases en `ai/tareas/NT-01-notificacion-tecnico.md` con 6 decisiones pendientes |
| 2026-10-03 | NT-01a: notificación del técnico. Empleado↔usuario, técnicos asignados a la OT, tramos de tiempo play/pausa (un tramo abierto por empleado con índice único parcial, motivo de pausa), consumos y ejecución por el técnico, cierre técnico de sus órdenes; permiso `ordenes.ejecutar`; API `/mantenimiento/ejecucion`; web "Mis órdenes" para celular con barra de pasos y cronómetro. Migración `NotificacionTecnico`. 349 tests verdes, Release sin advertencias |
| 2026-10-03 | Mis avisos (D-NT-06): `GET /mantenimiento/avisos/mios` (propios, pendientes/todos), ficha de aviso accesible al autor con sólo `avisos.crear`, página en tarjetas y opción de menú. Pestañas (`MudTabs`) como panel blanco con borde en todas las vistas. 350 tests verdes, Release sin advertencias |
| 2026-10-03 | Corregido "Not a valid date time" en todos los campos fecha-hora: Blazor entrega el valor del `datetime-local` con segundos (`2026-10-03T08:30:00`) y el `Format="yyyy-MM-ddTHH:mm"` de MudBlazor lo rechazaba (no era por la cultura es-PE: fallaba también sin ella). Nuevo `ConvertidorFechaHoraLocal` (acepta con y sin segundos) en las 10 fichas/campos; mensajes de conversión de MudBlazor en español. Probado guardando y recargando en el navegador. Tests web 73/73 |
| 2026-10-03 | D-MC-01 decidida: base compartida. D-PL-01 portal de la plataforma: módulo interno `PLATAFORMA` y permiso `plataforma.clientes.gestionar`, `IOperacionSobreEmpresa` para operar sobre la empresa elegida sin romper el aislamiento, API `/plataforma/clientes` (listar, ver, crear, editar, módulos, suspender/reactivar, administradores), web Plataforma → Clientes con resumen de vigencia, ficha con marca y módulos, `Migrator --crear-admin`, empresa `tools/clientes/amsys`. 359 tests verdes, Release sin advertencias |
| 2026-10-04 | **Tareas de la OT por sección (D-OT-01)**: `TareaOrden.SeccionId` (FK a `planificacion.seccion`, migración `TareaOrdenSeccion`), llenado al generar desde planes; `TareaOrdenRequest/Response` con `SeccionId` y `Seccion`/`HojaRuta` resueltos al leer; validación de sección activa al agregarla. Web: botón "Desde sección" en la ficha de la OT (copia las tareas de la sección, editables) y encabezados por sección en la ficha y en "Mis órdenes" del técnico. Test de integración nuevo; 360/360. Probado con Playwright en `amsys_ui` (OT-2026-00003: se le agregó la sección 1000 y el técnico `lquispe`) |
| 2026-10-04 | Seleccionables con "SELECCIONE" (obligatorio) / "NINGUNO" (opcional) en lugar de "0" (D-UI-04): componente `OpcionVacia` en 28 seleccionables de formularios, `SelectorCatalogo`, `SelectorOrganizacion` (`TextoVacio`) y campos personalizados tipo lista. 360/360; probado con Playwright (OT, sección, nuevo usuario). La API de desarrollo apunta a `amsys_ui` (cambio local, no commitear) |
| 2026-10-04 | `amsys_dev` puesta al día: migraciones `NotificacionTecnico`, `TareaOrdenSeccion`, `Aspectos` y `ParametrosYComentariosOrden`; cliente `amsys` configurado (módulo PLATAFORMA) y administrador `plataforma` creado (clave temporal mostrada en consola, se cambia al ingresar). Docker Desktop y el contenedor `bdpostgresql` estaban apagados: se inician con `docker start bdpostgresql` |
| 2026-10-04 | **NT-01b (D-NT-08)**: `LecturaContador` y `MedicionPuntoMedida` con `OrdenTrabajoId` (origen `OrdenTrabajo`); `RegistrarLecturaRequest.OrdenTrabajoId` valida orden emitida/en cierre técnico y que el equipo sea el de la orden o uno montado (lógica común en `ObjetosTecnicos.ObjetosDeOrdenAsync`/`OrdenParaParametrosAsync`, también usada por aspectos). Endpoints `GET /mantenimiento/ordenes/{id}/contadores` y `/puntos-medida` (permiso de órdenes, con `ValorEnOrden`/`NivelEnOrden`); historial con código de OT. **Comentarios** `ComentarioOrden` (`mantenimiento.orden_trabajo_comentario`): `GET/POST/DELETE /mantenimiento/ordenes/{id}/comentarios`. Migración `ParametrosYComentariosOrden` (aplicada en `amsys_dev` y `amsys_ui`). Web: `LecturasOrden` (paso "Parámetros" del técnico, ahora visible sin `activos.ver`, y panel de la ficha de la OT), `ComentariosOrden` (ficha de la OT y paso "Ejecución"). 374/374, Release sin advertencias |
| 2026-10-04 | **Tablas (D-UI-05)**: cabecera con el color primario del cliente (CSS global, más específico que el de MudBlazor) y columna "Acciones" al inicio con `AccionFila`/`AccionesFila`/`TipoAccion` en ~45 tablas de 38 pantallas (`MudTable`, `MudDataGrid`, `MudSimpleTable`); los menús de tres puntos (Usuarios) pasan a íconos; las filas con navegación tienen el ojo "Ver". Tablas sin acciones (Indicadores, Kardex, historial) sólo cambian de cabecera. Web 73/73, build sin advertencias; revisado con Playwright en `amsys_ui` (usuarios, órdenes, ficha OT, roles, organizaciones) |
| 2026-10-04 | **Archivos (D-AR-01, disco local)**: `IAlmacenArchivos` + `AlmacenArchivosLocal` (`Archivos:Ruta`, carpeta ignorada en git), `TiposArchivo` (tipo por contenido). **Logo** del cliente: `POST/DELETE /plataforma/clientes/{id}/logo`, público `GET /marca/{codigo}/logo`; web `/marca/{codigo}/logo?v=` y botones "Subir/Cambiar/Quitar logo" en la ficha del cliente del portal. **Adjuntos de la OT** (`mantenimiento.orden_trabajo_adjunto`): `GET/POST /mantenimiento/ordenes/{id}/adjuntos`, `GET/DELETE …/adjuntos/{adjuntoId}`; componente `AdjuntosOrden` en la ficha de la OT y en el paso "Ejecución" del técnico ("Fotos y archivos", cámara en el celular). Regla común `ServicioOrdenes.PuedeParticiparAsync` (comentarios y adjuntos). Migración `Archivos` (aplicada en `amsys_dev` y `amsys_ui`). 381 tests de API/dominio + 19 de infraestructura, Release sin advertencias; probado con Playwright en `amsys_ui` (logo de prueba quitado; queda `foto-prueba.png` en OT-2026-00003) |
| 2026-10-04 | **NT-01d (D-NT-10)**: `ServicioTecnicos` y endpoints `/mantenimiento/tecnicos/monitoreo`, `/{empleadoId}/cerrar-tramo`, `/horas` y `/horas/excel`; `OrdenTrabajo.PausarTramo` acepta la hora de fin (entre el inicio y ahora). Web: Mantenimiento → **Técnicos** (pestaña "Ahora" con cronómetro y tramos de otro día resaltados, diálogo "Cerrar tramo" con hora propuesta; pestaña "Horas por empleado" con detalle por orden, total y Excel). Sin migración. 379 tests, Release sin advertencias |
| 2026-10-04 | **NT-01c (D-NT-09)**: al cierre técnico de una OT de plan, `CambiarEstadoOrdenRequest` acepta `ValorEjecucion` (plan por contador) o `FechaCierrePlan` (calendario); se guardan en la OT (migración `CierrePlanOrden`, aplicada en `amsys_dev` y `amsys_ui`) y `PlanAsignacion.ReprogramarDesdeEjecucion` reprograma si es la última OT de la asignación (si no, advertencia). `OrdenTrabajoResponse` con `TipoPlan`, `LecturaPlan`, `ValorEjecucion`, `FechaCierrePlan`. Web: `CambiarEstadoDialogo` devuelve `CambioEstado` y pide el dato con valor propuesto (lectura actual / fin de la ejecución) en la ficha de la OT y en "Enviar a cierre técnico" del técnico. 377 tests, Release sin advertencias |
| 2026-10-04 | **Aspectos (D-NT-07)**: dominio `Aspecto`/`AspectoObjeto`/`InspeccionAspecto` (migración `Aspectos`), `ServicioAspectos` y endpoints (`/administracion/aspectos`, `/activos/{equipos|ubicaciones}/{id}/aspectos`, `/activos/aspectos/{id}[/inspecciones]`, `/mantenimiento/ordenes/{id}/aspectos`). Web: Administración → Aspectos, pestaña en la ficha de equipo, botón en Ubicaciones, panel "Inspección de aspectos" en la ficha de la OT y paso "Parámetros" del técnico (los cerrados se responden con un toque). Corregido además el XML-doc de `TareaOrdenRequest/Response` que rompía el build Release. 368/368, Release sin advertencias; probado con Playwright en `amsys_ui` (BB-12: "Estado de la faja" y "Observaciones") |
