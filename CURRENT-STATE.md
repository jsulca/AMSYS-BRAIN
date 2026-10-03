# Estado actual

**Etapa**: `NP-2 Activos` — en curso (2.1 organizaciones, ubicaciones y equipos ✅) · NP-0 y NP-1 completas (falta prueba manual en navegador) · NP-0 completa (falta prueba manual en navegador)
**Última actualización**: 2026-10-02

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

- [ ] Prueba manual en navegador (ver *Entorno de desarrollo*). La BD local tiene la configuración `demo`, todas las
      migraciones y `admin` con el rol Administrador (clave temporal `Admin-Dev-2026`, la pedirá cambiar).
- [ ] **Fallo intermitente de los tests de integración** (4 veces hasta 2026-10-03): siempre en la primera ejecución
      tras compilar, decenas de tests fallan a la vez (fixture). Una vez se vio "contenedor exited with code 1". Los
      fixtures reintentan 3 veces e imprimen los logs del contenedor ("PostgreSQL no arrancó"). No se ha podido
      reproducir a voluntad. **Si vuelve a pasar: guardar la salida completa** (`dotnet test --solution Amsys.slnx > tests.log 2>&1`)
      y buscar "no arrancó" / "Exception". Repetir la ejecución pasa siempre.
- [ ] Decidir `D-NP-23` (estados `PROGRAMADO` / tipo `PARADA`) antes de NP-3.
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

### Pendiente de NP-2
- **2.2** Clase de equipo + tipos + datos técnicos por clase (catálogo con campos propios; en el legacy cambiar la
  clase borraba los datos técnicos sin aviso).
- **2.3** Unidad de medida de servicio (tipo, calendario) + contadores e historial + puntos de medida y alertas.
- **Alcance por organización** (`UsuarioOrganizacion` del legacy): qué parte de la planta ve cada usuario. Filtro
  transversal: diseñar como el filtro de empresa (decisión pendiente `D-NP-32`).
- Avisar al desactivar o desmontar un equipo con planes (cuando existan los planes, NP-4).

## Entorno de desarrollo

- PostgreSQL local en Docker (contenedor `amsys-postgres-dev`, volumen `amsys-postgres-dev`, puerto 5432,
  usuario/clave `postgres`/`postgres`, BD `amsys_dev`). Es la cadena de `src/Amsys.Api/appsettings.Development.json`.
  - Crear (si no existe): `docker run -d --name amsys-postgres-dev -e POSTGRES_PASSWORD=postgres -e POSTGRES_DB=amsys_dev -p 5432:5432 -v amsys-postgres-dev:/var/lib/postgresql/data postgres:17-alpine`
  - Iniciar / detener: `docker start amsys-postgres-dev` / `docker stop amsys-postgres-dev`
- Migrar + semilla: `dotnet run --project src/Amsys.Migrator -- --semilla-desarrollo "--ConnectionStrings:Amsys=Host=localhost;Port=5432;Database=amsys_dev;Username=postgres;Password=postgres" "--Semilla:ClaveAdmin=<clave>"`
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
