# Arquitectura

Monolito modular: **una** API como único backend (web + app móvil), front **Blazor Server** que sólo
habla con la API por HTTP, una sola BD por despliegue y una sola cadena de migraciones para todos los clientes.

## Proyectos

| Proyecto | Tipo (SDK) | Rol | Referencia a |
|----------|------------|-----|--------------|
| `src/Amsys.Domain` | classlib | Entidades, enums, reglas puras. Sin EF ni ASP.NET | — |
| `src/Amsys.Application` | classlib | Casos de uso por módulo (`Servicio<Algo>`); interfaces de infraestructura; acceso a datos vía `IAmsysDbContext` (EF Core) | Domain, Contracts |
| `src/Amsys.Contracts` | classlib | DTOs Request/Response + validadores FluentValidation (compartido API ↔ Blazor ↔ móvil) | — |
| `src/Amsys.Infrastructure` | classlib | EF Core + Npgsql, migraciones, email, archivos, Excel, PDF | Application |
| `src/Amsys.Api` | `Sdk.Web` | API REST `/api/v1` con **Minimal APIs** (`MapGroup` por módulo), JWT, OpenAPI | Application, Infrastructure, Contracts |
| `src/Amsys.Web` | `Sdk.Web` (Blazor Server, `InteractiveServer` sin prerender) + MudBlazor | Páginas, componentes, cliente HTTP tipado a la API, sesión (cookie + tokens en servidor), assets por cliente | Contracts |
| `src/Amsys.Worker` | `Sdk.Worker` | Correos, alertas. **No genera OT** (D-05) | Infrastructure |
| `src/Amsys.Migrator` | console | Aplica migraciones a la BD de un cliente, explícitamente | Infrastructure |
| `tools/Amsys.Importador` | console | Importación Excel / ETL desde BD legacy por cliente | Infrastructure |
| `tests/Amsys.Domain.Tests` | xunit.v3 | Reglas de dominio (cálculo de posiciones, estados) | Domain |
| `tests/Amsys.Application.Tests` | xunit.v3 + NSubstitute | Casos de uso | Application |
| `tests/Amsys.Infrastructure.Tests` | xunit.v3 + Testcontainers | Persistencia contra Postgres real: aislamiento por empresa, auditoría, concurrencia | Infrastructure |
| `tests/Amsys.Web.Tests` | xunit.v3 + Mvc.Testing | Web en memoria con API simulada: cookie, redirecciones, renovación de tokens | Web |
| `tests/Amsys.Api.IntegrationTests` | xunit.v3 + Mvc.Testing + Testcontainers | API contra Postgres real | Api |

```
Web ─────────► Contracts   (HTTP → Api)
Api ─────────► Application, Infrastructure, Contracts
Infrastructure ► Application ► Domain, Contracts
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

## Autenticación y API (implementado)

| Pieza | Detalle |
|-------|---------|
| Token de acceso | JWT HS256, 15 min (`Jwt:MinutosTokenAcceso`). Claims: `sub` (usuario), `empresa_id`, `unique_name`, `name`, `jti` (`ClaimsAmsys`) |
| Token de refresco | Aleatorio de 64 bytes, 7 días (`Jwt:DiasTokenRefresco`). En BD sólo su SHA-256 (`seguridad.token_refresco`). Se rota en cada uso; reutilizar uno rotado revoca todas las sesiones del usuario |
| Contraseñas | PBKDF2 vía `PasswordHasher` de ASP.NET Core Identity (`HasherClave`) |
| Empresa actual | `ContextoUsuarioHttp` lee `empresa_id`/`sub` del JWT → `ITenantContext`/`IUsuarioActual`. Procesos sin usuario: `ContextoSistema` |
| Login / refresco | Corren sin empresa: desactivan sólo `FiltrosConsulta.Empresa` y escriben con `EmpresaId` explícito |
| Endpoints | `app.MapGroup("/api/v1").RequireAuthorization()`; cada módulo expone `Map<Modulo>(this RouteGroupBuilder)` en `Api/<Modulo>/Endpoints<Algo>.cs`; anónimos con `.AllowAnonymous()` |
| Errores | `Result`/`Error` → `ProblemDetails` con extensión `codigo` (`Api/Comun/ResultadosHttp.cs`): Validacion 400, NoAutorizado 401, Prohibido 403, NoEncontrado 404, Conflicto 409 |
| Validación | `.Validar<TRequest>()` ejecuta el validador FluentValidation de `Contracts` → 400 ValidationProblem |
| Límite de intentos | Política `login`: `Seguridad:IntentosLoginPorMinuto` (10) por IP en login y refresco → 429 |
| Configuración | `ConnectionStrings:Amsys`, `Jwt:{Emisor,Audiencia,Clave,...}`. `JwtOpciones` se valida al arrancar: sin clave la API no inicia |
| Documentación | OpenAPI (`/openapi/v1.json`) con esquema Bearer + Scalar (`/scalar/v1`) sólo en Development |

## Web (implementado)

| Pieza | Dónde | Detalle |
|-------|-------|---------|
| Modo de render | `Components/App.razor` | `InteractiveServerRenderMode(prerender: false)` global |
| Sesión | `Sesion/AlmacenSesiones.cs` | Tokens de la API en `IDistributedCache` por id de sesión; renovación 1 min antes de vencer con candado por sesión |
| Cookie | `Program.cs` | `amsys.sesion`, HttpOnly, expira con el token de refresco; `OnValidatePrincipal` exige que la sesión exista |
| Endpoints HTTP de cuenta | `Sesion/EndpointsCuenta.cs` | `completar-ingreso` (canjea código → cookie), `salir` (POST + antiforgery), `sesion-expirada`. `UrlLocal` evita open redirect |
| Estado de autenticación | `Sesion/ProveedorEstadoAutenticacion.cs` | Revalida cada minuto |
| Autorización | `Program.cs` + `Components/Pages/_Imports.razor` | Política por defecto = sesión y sin cambio de clave pendiente; `PoliticasWeb.SesionIniciada` para cuenta. **Páginas en `Components/Pages/` exigen la política por defecto; las de `Components/Cuenta/` declaran la suya** |
| Cliente de la API | `Api/ClienteApi.cs` | Un método por endpoint; devuelve `ResultadoApi<T>`; 401 → `sesion-expirada` |
| Validación de formularios | `Api/ValidacionFormulario.cs` | Validadores de `Contracts` campo a campo (MudTextField `Validation`) |
| Menú | `Navegacion/MenuAmsys.cs` | Opciones con `Grupo`, `Modulo`, `Permiso`; `Visibles()` = punto de extensión |
| Nueva página | `Components/Pages/<Modulo>/<Pagina>.razor` | Agregar la opción a `MenuAmsys.Opciones` y el método a `ClienteApi` |

## Configuración multicliente (implementado)

| Pieza | Dónde | Detalle |
|-------|-------|---------|
| Catálogo de módulos | `Domain/Configuracion/Modulos.cs` | En código (cada módulo es funcionalidad programada). Activación por empresa: `configuracion.empresa_modulo` |
| Campos personalizados | `Domain/Configuracion/CampoPersonalizado.cs` | Definición por empresa y entidad. Clave y tipo inmutables; retirar = desactivar (los datos quedan) |
| Valores de campos | `ValidadorCamposPersonalizados` | Recibe `Dictionary<string, JsonElement>`, valida contra los campos activos y normaliza (string, decimal, bool, fecha `yyyy-MM-dd`). Se guardarán en `datos_adicionales jsonb` de cada entidad (NP-2/NP-3) |
| Estados canónicos | `Domain/Mantenimiento/Estados.cs` | Un único enum por catálogo para todos los clientes |
| Etiquetas | `EtiquetaEstado` + `CatalogosEstado.EtiquetasPorDefecto` | Nombre, color y habilitado por empresa; sin etiqueta → nombre por defecto |
| Marca | `Empresa.NombreComercial/ColorPrimario/ColorSecundario` + `wwwroot/clientes/<codigo>/logo.(svg\|png)` | Respaldo: tema y logo de AMSYS |
| Fuente de verdad | `tools/clientes/<codigo>/configuracion.json` | Aplicada con `Migrator --configurar`; idempotente y transaccional. Ver `tools/clientes/README.md` |
| Lectura | `GET /api/v1/configuracion` (política `sesion-iniciada`) | Catálogo de módulos con `activo`, todas las etiquetas resueltas, campos activos, marca |
| Web | `Configuracion/ConfiguracionCliente.cs` | Una carga por circuito; `MainLayout` la pasa en cascada (`[CascadingParameter] ConfiguracionResponse?`) |
| Componentes | `Components/Shared/EstadoChip.razor`, `CamposPersonalizados.razor` | Usar en todas las pantallas de Aviso/OT/Equipo/Ubicación |
| Tests | `AssemblyFixture` | Un contenedor Postgres por proyecto de tests; los tests usan códigos únicos |

## Seguridad: permisos (implementado)

| Pieza | Dónde | Detalle |
|-------|-------|---------|
| Catálogo de permisos | `Domain/Seguridad/Permisos.cs` | `modulo.recurso.accion`; cada permiso puede depender de un módulo activable |
| Rol | `Domain/Seguridad/Rol.cs` | Por empresa, permisos en `text[]`, perfil de licencia; `EsAdministrador` = todos los disponibles |
| Permisos efectivos | `Application/Seguridad/ServicioPermisos.cs` | Rol ∩ módulos activos; usuario inactivo o sin rol = ninguno; caché 1 min invalidada con `VersionPermisos` |
| API | `Api/Seguridad/AutorizacionPermisos.cs` | `.RequierePermiso(Permisos.X)` incluye la política base (`ExigirSesionConClaveVigente`) |
| Web | `PermisosWeb` (copia verificada por test), `ConPermiso`, `OpcionMenu.Permiso` | Sólo oculta: la API es la que exige |
| Nueva funcionalidad protegida | — | 1) permiso en `Permisos.Todos` (+ `PermisosWeb`), 2) `.RequierePermiso` en el endpoint, 3) `Permiso` en `MenuAmsys`, 4) `ConPermiso` en la página |

## Catálogos simples (implementado)

| Pieza | Dónde |
|-------|-------|
| Base y clases | `Domain/Administracion/ElementoCatalogo.cs`, `CatalogosSimples.cs` (clases + registro) |
| Persistencia | `Infrastructure/Persistence/Configuraciones/Administracion/CatalogosConfiguracion.cs`: TPC, una tabla por catálogo en `administracion`, secuencia compartida para los ids |
| Servicio | `Application/Administracion/ServicioCatalogos.cs`: genérico por clave (`AccesoCatalogoTipado<T>`) |
| API | `GET/POST /api/v1/administracion/catalogos/{clave}`, `PUT /{clave}/{id}`, `POST /{clave}/{id}/activar|desactivar` |
| Web | `Pages/Administracion/Catalogos.razor` (índice), `Catalogo.razor` (genérica), `ElementoCatalogoDialogo.razor` |
| **Agregar un catálogo simple** | Una clase `sealed class X : ElementoCatalogo;` + una línea en `CatalogosSimples.Todos` + `dotnet ef migrations add` |

## Activos (implementado en NP-2.1)

| Pieza | Detalle |
|-------|---------|
| Árboles | `Organizacion.PadreId`, `Ubicacion.UbicacionPadreId`, `Equipo.EquipoPadreId`. Ciclos: `Jerarquia.CreaCiclo` con el mapa `id → padre` de la empresa (cargado en memoria) |
| Montaje | `Equipo.Montar/Desmontar` → `MovimientoEquipo`. Ubicación **o** equipo padre, nunca ambos. El montaje no se edita con el resto de datos |
| Campos personalizados | `IConDatosAdicionales` + `ConversionDatosAdicionales.Configurar` (campo privado `_datosAdicionales` → `datos_adicionales jsonb`). Validar con `ValidacionActivos.DatosAdicionalesAsync` y asignar con `AsignarDatosAdicionales(validados, clavesActivas)` |
| Listas grandes | `Pagina<T>` (`Contracts/Comun`), `ConsultasTexto.Buscar(...)` + `Paginar(...)`; en la web `MudDataGrid ServerData` |
| Guardar con avisos | `Guardado<T>(Elemento, Advertencias)`: código repetido (D-03) y consecuencias (p. ej. desactivar una ubicación con equipos montados) |
| Referencias | Se exige que existan en la empresa y estén activas, **salvo que no cambien** (editar un registro cuya criticidad se desactivó no obliga a cambiarla) |
| Selectores web | `SelectorOrganizacion` (jerárquico), `SelectorCatalogo` (por clave), `BuscadorActivo` (autocompletado de ubicación/equipo) |
