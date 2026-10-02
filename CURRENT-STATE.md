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

## Pendiente inmediato

- [ ] Quitar `--ignore-exit-code 8` de `Amsys.Application.Tests` y `Amsys.Api.IntegrationTests` cuando tengan tests.
- [ ] Revisar carpeta `k8s/` (existe, vacía).
- [ ] Confirmar con el propietario `D-MC-05` (eliminación lógica para todo; ya implementada así).

## Siguiente paso (NP-0, paso 3: autenticación en la API)

1. `Amsys.Api`: implementaciones de `ITenantContext`/`IUsuarioActual` leyendo claims del JWT; `AddInfrastructure`.
2. Hash de contraseñas (`IHasherClave` en Application, implementación con `PasswordHasher<T>` de ASP.NET Core Identity).
3. `POST /api/v1/auth/login` + refresh token (tabla `seguridad.refresh_token`) + `POST /api/v1/auth/refresh`.
4. `MapGroup("/api/v1")` con `RequireAuthorization()` por defecto; ProblemDetails desde `Result`/`Error`.
5. OpenAPI + Scalar en Development.
6. Tests en `Amsys.Api.IntegrationTests` (WebApplicationFactory + Testcontainers): login válido/inválido, usuario inactivo, token de empresa A no accede a datos de B.
7. Semilla de desarrollo (empresa + usuario admin) vía `Amsys.Migrator` o comando aparte.

## Cómo trabajar

- Compilar: `dotnet build Amsys.slnx` (Release = warnings como errores).
- Tests: `dotnet test --solution Amsys.slnx` — **requiere Docker Desktop encendido** para `Amsys.Infrastructure.Tests`.
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
