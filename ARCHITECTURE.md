# Arquitectura

Monolito modular: **una** API como único backend (web + app móvil), front **Blazor Server** que sólo
habla con la API por HTTP, una sola BD por despliegue y una sola cadena de migraciones para todos los clientes.

## Proyectos

| Proyecto | Tipo (SDK) | Rol | Referencia a |
|----------|------------|-----|--------------|
| `src/Amsys.Domain` | classlib | Entidades, enums, reglas puras. Sin EF ni ASP.NET | — |
| `src/Amsys.Application` | classlib | Casos de uso por módulo; interfaces de infraestructura | Domain |
| `src/Amsys.Contracts` | classlib | DTOs Request/Response + validadores FluentValidation (compartido API ↔ Blazor ↔ móvil) | — |
| `src/Amsys.Infrastructure` | classlib | EF Core + Npgsql, migraciones, email, archivos, Excel, PDF | Application |
| `src/Amsys.Api` | `Sdk.Web` | API REST `/api/v1` con **Minimal APIs** (`MapGroup` por módulo), JWT, OpenAPI | Application, Infrastructure, Contracts |
| `src/Amsys.Web` | `Sdk.Web` (Blazor Server, `InteractiveServer`) | Páginas, componentes, cliente HTTP tipado a la API, assets por cliente | Contracts |
| `src/Amsys.Worker` | `Sdk.Worker` | Correos, alertas. **No genera OT** (D-05) | Infrastructure |
| `src/Amsys.Migrator` | console | Aplica migraciones a la BD de un cliente, explícitamente | Infrastructure |
| `tools/Amsys.Importador` | console | Importación Excel / ETL desde BD legacy por cliente | Infrastructure |
| `tests/Amsys.Domain.Tests` | xunit.v3 | Reglas de dominio (cálculo de posiciones, estados) | Domain |
| `tests/Amsys.Application.Tests` | xunit.v3 + NSubstitute | Casos de uso | Application |
| `tests/Amsys.Infrastructure.Tests` | xunit.v3 + Testcontainers | Persistencia contra Postgres real: aislamiento por empresa, auditoría, concurrencia | Infrastructure |
| `tests/Amsys.Api.IntegrationTests` | xunit.v3 + Mvc.Testing + Testcontainers | API contra Postgres real | Api |

```
Web ─────────► Contracts   (HTTP → Api)
Api ─────────► Application, Infrastructure, Contracts
Infrastructure ► Application ► Domain
Worker, Migrator, Importador ► Infrastructure
```

**Regla**: `Web` nunca referencia `Domain`, `Application` ni `Infrastructure` (D-NP-01b).

## Organización interna (por módulo de negocio)

Dentro de Domain / Application / Infrastructure / Api / Web se usan las mismas carpetas:

`Seguridad` · `Configuracion` · `Administracion` · `Activos` (Equipo, Ubicacion, Contador, PuntoMedida) ·
`Planificacion` (Plan, HojaRuta, Seccion, Tarea) · `Mantenimiento` (Aviso, OrdenTrabajo) · `Logistica` · `Reportes`

## Configuración multicliente (núcleo del diseño)

| Mecanismo | Resuelve |
|-----------|----------|
| `EmpresaModulo` (feature flags) | Funcionalidades presentes sólo en algunos clientes |
| `CampoPersonalizado` + columna `datos_adicionales jsonb` en Equipo, Ubicacion, OrdenTrabajo, Aviso | Campos extra por cliente sin migraciones |
| `EtiquetaEstado` | Mismo enum canónico, distinto nombre visible / estados habilitados |
| Branding (`wwwroot/clientes/<codigo>/`) | Logo, cabecera, pie, colores |
| Plantillas de reporte por cliente con fallback | Formatos Excel/PDF distintos |
| Global query filter por `EmpresaId` | Aislamiento de datos entre tenants |

## Stack y convenciones

- .NET 10 · C# latest · `.slnx` · Central Package Management.
- EF Core 10 + Npgsql (PostgreSQL). Sin repositorios genéricos que marquen todo como modificado.
- Sin MediatR ni AutoMapper (licencias comerciales; no hacen falta). Mapeo manual.
- FluentValidation · Result pattern + ProblemDetails.
- Blazor Server (`InteractiveServer`) + MudBlazor. Con varias réplicas: sticky sessions.
- Minimal APIs con `MapGroup` por módulo, versionado `/api/v1`.
- ClosedXML (Excel) · QuestPDF (revisar licencia).
- Tests: xunit.v3 sobre Microsoft.Testing.Platform → `dotnet test --solution Amsys.slnx`.
- Namespaces `Amsys.*` (el legacy usa `AMSYS.*`).

## Persistencia (implementado)

| Convención | Dónde | Detalle |
|------------|-------|---------|
| Base de entidades | `Domain/Common/Entidad.cs` | `Id int`, auditoría (`CreadoEn/Por`, `ModificadoEn/Por`), eliminación lógica (`Eliminado`, `EliminadoEn/Por`), `Version` = columna de sistema `xmin` (concurrencia optimista) |
| Pertenencia a empresa | `IEntidadEmpresa` | Toda entidad operativa la implementa. FK a `seguridad.empresa` e índice por `empresa_id` se crean solos |
| Filtros globales con nombre | `AmsysDbContext` | `FiltrosConsulta.Empresa` (empresa actual; sin empresa → no devuelve nada) y `FiltrosConsulta.Eliminados`. Se desactivan por separado: `.IgnoreQueryFilters([FiltrosConsulta.Eliminados])` |
| Interceptor | `AuditoriaInterceptor` | Asigna `EmpresaId` al insertar si viene en 0; lanza si se escribe sobre otra empresa o se cambia la empresa; completa auditoría; convierte `Remove` en eliminación lógica |
| Nombres | `UseSnakeCaseNamingConvention()` | Tablas y columnas en snake_case, tablas en singular, **un esquema por módulo** (`Persistence/Esquemas.cs`) |
| Historial de migraciones | `public.__ef_migraciones` | |
| Fechas | `DateTime` UTC → `timestamp with time zone` | Reloj inyectado como `TimeProvider` |
| Enums | Guardados como texto | p. ej. `TipoPlan` |
| Errores de negocio | `Result` / `Result<T>` con `Error(Codigo, Mensaje, TipoError)` | Las fábricas de dominio no lanzan excepciones por validación |
| Configuración EF | `Persistence/Configuraciones/<Modulo>/<Entidad>Configuracion.cs` | `IEntityTypeConfiguration<T>`, descubiertas por ensamblado |
