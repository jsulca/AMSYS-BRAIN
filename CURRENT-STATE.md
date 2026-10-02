# Estado actual

**Etapa**: `NP-0 Fundaciones` — en curso
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

## Pendiente inmediato

- [ ] Prueba manual en navegador del flujo completo (ver *Entorno de desarrollo*).
- [ ] Quitar `--ignore-exit-code 8` de `Amsys.Application.Tests` cuando tenga tests.
- [ ] **Permisos por rol** en `seguridad/usuarios`: hoy basta con estar autenticado (temporal, ver `D-NP-16`).
- [ ] Bloqueo de usuario tras N intentos fallidos (el legacy tiene `ControlIntentos`); hoy sólo hay límite por IP.
- [ ] Migración de usuarios del legacy: revisar cómo guarda claves `AMSYS.Utilitarios/Criptografia`.
- [ ] Producción con varias réplicas de la web: caché distribuido (Redis) para `AlmacenSesiones`, claves de
      Data Protection persistidas y compartidas, afinidad de sesión (Blazor Server).
- [ ] Zona horaria: las fechas se muestran con la hora del servidor (`ToLocalTime`); definir zona por empresa.
- [ ] `Amsys.Migrator` imprime todo el SQL de EF: bajar el log de EF a Warning.
- [ ] Confirmar `D-MC-05` (eliminación lógica para todo; ya implementada así).
- [ ] Revisar carpeta `k8s/` (existe, vacía).

## Siguiente paso (NP-0, paso 5: configuración multicliente)

1. Domain/Configuracion: `EmpresaModulo` (módulos activables), `CampoPersonalizado` + `datos_adicionales jsonb`
   (Equipo, Ubicacion, OrdenTrabajo, Aviso — se crean en sus etapas; aquí la infraestructura),
   `EtiquetaEstado`, branding (`Codigo` ya existe; color primario, nombre comercial, logo).
2. API: `GET /api/v1/configuracion` (módulos activos, etiquetas, branding de la empresa actual).
3. Web: cargar la configuración al iniciar el circuito; `MenuAmsys.Visibles()` filtra por módulo;
   tema y logo por cliente (`wwwroot/clientes/<codigo>/` con fallback).
4. Administración básica de módulos por empresa (superadministrador).

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
