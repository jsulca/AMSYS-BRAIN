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

## Pendiente inmediato

- [ ] Eliminar código de ejemplo de las plantillas: `Class1.cs` (libs), `UnitTest1.cs` (tests),
      `WeatherForecast` en `Amsys.Api/Program.cs`, `Worker.cs` de ejemplo. Son los que generan los
      3 warnings (CA1852, CA1848, CA1727) que **romperán el build en Release/CI**.
- [ ] `.editorconfig` en la raíz.
- [ ] Primer commit (el repo aún no tiene ninguno).
- [ ] Revisar carpeta `k8s/` (existe, vacía).

## Siguiente paso (NP-0)

1. `Amsys.Domain/Common`: `EntidadBase`, `IEntidadEmpresa` (`EmpresaId`), eliminación lógica, `Result`.
2. `Amsys.Application/Abstractions`: `ITenantContext`, `IUsuarioActual`, `IReloj`.
3. `Amsys.Infrastructure/Persistence`: `AmsysDbContext` con query filters por `EmpresaId` y `Eliminado`,
   Npgsql.
4. `Amsys.Api`: JWT + refresh token, `/api/v1`, OpenAPI + Scalar.
5. Test de integración "un tenant no ve datos de otro" (Testcontainers).
6. CI en GitHub Actions (build + test).

## Bitácora

| Fecha | Avance |
|-------|--------|
| 2026-10-02 | Análisis de ramas por cliente en el legacy → `PLAN-MULTICLIENTE.md` (en el repo legacy) |
| 2026-10-02 | Propuesta de nueva plataforma (inicialmente Blazor WASM, luego cambiado a Server) + API separada → `PLAN-NUEVA-PLATAFORMA.md` (legacy) |
| 2026-10-02 | Creados `global.json`, `Directory.Build.props`, `Directory.Packages.props` |
| 2026-10-02 | Creados los 12 proyectos restantes; Blazor aplanado de `src/Amsys.Web/Amsys.Web*` a `src/`; tests migrados de xunit v2 a xunit.v3; runner MTP activado en `global.json` |
| 2026-10-02 | Creada esta carpeta `ai/` |
| 2026-10-02 | Decisiones D-NP-01 (Blazor **Server**), D-NP-02 (repo `amsys`), D-NP-03 (Minimal APIs), D-NP-04 (nueva app móvil). `Amsys.Web` regenerado como Blazor Server, `Amsys.Web.Client` eliminado, paquetes WebAssembly quitados de CPM. Build OK |
