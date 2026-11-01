# Plan Nueva Plataforma – Amsys (Blazor + API) sucesor de AMSYS legacy

> **Estado**: PROPUESTA · **Fecha**: 2026-10-02
> Complementa `PLAN-MULTICLIENTE.md` (Opción 3). Cambia el **destino** de la migración de clientes:
> en vez de converger las ramas en `main` de este repo, convergen en la **nueva plataforma**.
> Este repo (`AMSYS`) pasa a **legacy**: sólo hotfix hasta que el último cliente migre.

---

## 1. Decisiones técnicas recomendadas

### 1.1 Front: Blazor (no MVC)

| Criterio | MVC + jQuery (hoy) | Blazor |
|----------|--------------------|--------|
| Campos personalizados dinámicos, módulos activables | JS a mano por vista | Un componente `<CamposPersonalizados Entidad="Aviso" />` reutilizado en todo |
| Reutilización | Copiar/pegar vistas (origen de la divergencia por cliente) | Componentes, layouts y temas por cliente |
| Lenguaje | C# + Razor + jQuery inline | C# de punta a punta; **comparte DTOs y validadores con la API** |
| Consumir una API separada | Posible, pero el MVC tiende a ir directo a la BD | Natural: el front sólo habla con la API |
| Curva de aprendizaje | Ninguna | Media (ciclo de vida de componentes, render modes) |

**Recomendación: Blazor Web App con render mode `InteractiveWebAssembly`** y librería de componentes
**MudBlazor** (MIT; grillas, formularios, diálogos, temas).

- **¿Por qué WebAssembly y no Server?** Las plantas industriales suelen tener red inestable. Blazor
  Server mantiene un circuito SignalR por usuario: si la red se corta, la pantalla se congela.
  WASM descarga una vez y luego sólo hace llamadas HTTP a la API. Además obliga a que **toda** la
  lógica viva en la API (la misma que usa la app móvil): no hay forma de "saltarse" la API.
- El costo es la descarga inicial (~2–4 MB, cacheada). Para un sistema interno es aceptable.
- Login y páginas públicas pueden ir en SSR estático (sin interactividad).

**Cuándo NO conviene Blazor**: si se quisiera reutilizar las vistas Razor actuales tal cual. No es el
caso: las vistas son justamente donde está la divergencia por cliente y se reescriben igual.

### 1.2 API separada: sí

`Amsys.Api` es el **único backend**: lo consumen el Web (Blazor) y la app móvil. Hoy la API vive dentro
de `AMSYS.WebAdmin/Api`; es la parte mejor construida del legacy y sirve de punto de partida
(FluentValidation, records `*Response`, tenant desde el claim JWT).

- Versionada: `/api/v1/...` (la app móvil necesita estabilidad).
- Autenticación JWT + refresh token. Claims: `UsuarioId`, `EmpresaId`, `RolId`.
- Autorización **en cada endpoint** (corrige `SEC-01` del legacy: hoy sólo se protegen las pantallas).
- OpenAPI (`Microsoft.AspNetCore.OpenApi`) + Scalar para documentación.
- La app móvil debe migrar a `/api/v1` → planificar endpoints de compatibilidad o una versión nueva de la app (`D-NP-04`).

### 1.3 Stack

| Pieza | Elección | Nota |
|-------|----------|------|
| Runtime | **.NET 10 (LTS)** | `global.json` fijando SDK |
| Solución | `.slnx` + `Directory.Build.props` + **Central Package Management** (`Directory.Packages.props`) | |
| BD | PostgreSQL + EF Core 10 (Npgsql) | `jsonb` para `DatosAdicionales` |
| Multi-tenant | `ITenantContext` + **global query filter por `EmpresaId`** en EF | Imposible olvidar el filtro (falla actual del legacy) |
| Casos de uso | Servicios de aplicación / handlers simples, **sin MediatR** | MediatR y AutoMapper pasaron a licencia comercial; no hacen falta |
| Validación | FluentValidation, validadores en `Contracts` (compartidos API ↔ Blazor) | |
| Errores | Result pattern + `ProblemDetails` | |
| Mapeo | Manual (métodos de extensión) | |
| Excel | ClosedXML (ya se usa) | |
| PDF | QuestPDF | Revisar licencia (Community gratis bajo cierto umbral de ingresos) |
| Logs / trazas | Serilog u OpenTelemetry | El legacy no tiene ningún `ILogger` en la lógica |
| Tests | xUnit + **Testcontainers** (Postgres real) | El legacy no tiene ningún test |
| Local | .NET Aspire AppHost (opcional): levanta Postgres + Api + Web | |
| CI/CD | GitHub Actions: build + test + publicar un artefacto → N despliegues | |

---

## 2. Nombre

**Recomendación**: mantener la marca **AMSYS** (los clientes ya la conocen) y diferenciar el código:

| Elemento | Legacy | Nuevo |
|----------|--------|-------|
| Repositorio GitHub | `jsulca/AMSYS` → renombrar a **`AMSYS-legacy`** | **`amsys`** (o `amsys-platform`) |
| Solución | `AMSYS.sln` | **`Amsys.slnx`** |
| Namespaces | `AMSYS.*` (mayúsculas) | **`Amsys.*`** (PascalCase, convención .NET) |
| Nombre comercial | AMSYS | AMSYS (internamente "AMSYS v4") |

Así ninguna clase, namespace ni paquete colisiona si en algún momento conviven en la misma máquina,
y un `grep` distingue al instante código nuevo de legacy.

---

## 3. Estructura de la solución

Monolito modular: **un** deploy de API, organizado por módulos de negocio dentro de cada capa.

```
amsys/
├── Amsys.slnx
├── global.json
├── Directory.Build.props            ← net10.0, Nullable, ImplicitUsings, TreatWarningsAsErrors
├── Directory.Packages.props         ← versiones centralizadas
├── .editorconfig
├── .github/workflows/ci.yml
├── docs/ai/                         ← la carpeta /ai migra aquí (reglas de negocio, decisiones)
│
├── src/
│   ├── Amsys.Domain/                ← entidades, enums, reglas puras. Sin EF, sin ASP.NET
│   │   ├── Common/                  (EntidadBase, IEntidadEmpresa, EliminacionLogica, Result)
│   │   ├── Seguridad/               (Empresa, Usuario, Rol, Permiso)
│   │   ├── Configuracion/           (EmpresaModulo, CampoPersonalizado, EtiquetaEstado, Branding)
│   │   ├── Administracion/          (catálogos: Prioridad, Especialidad, TipoMantenimiento, ...)
│   │   ├── Activos/                 (Equipo, Ubicacion, Contador, PuntoMedida, DatoTecnico)
│   │   ├── Planificacion/           (PlanMantenimiento, HojaRuta, Seccion, Tarea, cálculo de posiciones)
│   │   ├── Mantenimiento/           (Aviso, OrdenTrabajo + máquinas de estado)
│   │   └── Logistica/               (Almacen, Material, NotaEntrada/Salida, Kardex)
│   │
│   ├── Amsys.Application/           ← casos de uso por módulo; interfaces de infraestructura
│   │   ├── Abstractions/            (ITenantContext, IUsuarioActual, IReloj, IEmailSender, IAlmacenArchivos)
│   │   ├── Mantenimiento/Ordenes/   (CrearOrden, NotificarOrden, CambiarEstado, GenerarDesdePlan, ...)
│   │   ├── Mantenimiento/Avisos/
│   │   ├── Activos/ ...  Planificacion/ ...  Logistica/ ...  Administracion/ ...  Seguridad/ ...
│   │   ├── Configuracion/           (módulos activos, campos personalizados, etiquetas)
│   │   └── Reportes/                (IReporte, MTBF/MTTR/Disponibilidad parametrizados)
│   │
│   ├── Amsys.Contracts/             ← DTOs Request/Response + validadores FluentValidation
│   │                                  Compartido por Api, Web.Client y (si aplica) la app móvil
│   │
│   ├── Amsys.Infrastructure/        ← EF Core, Npgsql, email, archivos, Excel, PDF, WhatsApp
│   │   ├── Persistence/
│   │   │   ├── AmsysDbContext.cs    (query filters por EmpresaId y Eliminado)
│   │   │   ├── Configurations/<Modulo>/
│   │   │   └── Migrations/          ← UNA sola cadena para todos los clientes
│   │   ├── Reportes/  (ClosedXML, QuestPDF, plantillas por cliente)
│   │   └── Integraciones/ (Email, WhatsApp)
│   │
│   ├── Amsys.Api/                   ← ASP.NET Core Minimal APIs (o Controllers) /api/v1
│   │   ├── Endpoints/<Modulo>/
│   │   ├── Auth/  (JWT, refresh, políticas por permiso)
│   │   └── Program.cs
│   │
│   ├── Amsys.Web/                   ← host Blazor Web App (sirve el WASM, login SSR, assets por cliente)
│   │   └── wwwroot/clientes/<codigo>/ (logo, cabecera, pie)
│   ├── Amsys.Web.Client/            ← componentes y páginas InteractiveWebAssembly
│   │   ├── Pages/<Modulo>/
│   │   ├── Components/  (CamposPersonalizados, SelectorEquipo, ArbolJerarquico, EstadoChip, ...)
│   │   └── Services/ApiClient/      (clientes HTTP tipados contra Amsys.Contracts)
│   │
│   ├── Amsys.Worker/                ← tareas en segundo plano: correos, alertas de punto de medida
│   │                                  ⚠️ NO genera OT automáticamente (decisión D-05)
│   └── Amsys.Migrator/              ← consola: aplica migraciones a la BD de UN cliente, explícitamente
│
├── tools/
│   ├── Amsys.Importador/            ← importación Excel genérica (reemplaza DemonApp/AddDataApp)
│   └── clientes/<codigo>/           ← scripts ETL legacy → nueva plataforma, por cliente
│
├── tests/
│   ├── Amsys.Domain.Tests/          ← cálculo de posiciones del plan, máquinas de estado
│   ├── Amsys.Application.Tests/
│   └── Amsys.Api.IntegrationTests/  ← Testcontainers + Postgres; incluye test "tenant A no ve datos de B"
│
└── aspire/ (opcional)
    ├── Amsys.AppHost/
    └── Amsys.ServiceDefaults/
```

**Dependencias** (las flechas sólo apuntan hacia adentro):

```
Web.Client ──► Contracts
Web ─────────► Web.Client
Api ─────────► Application, Infrastructure, Contracts
Infrastructure ► Application ► Domain
Worker, Migrator ► Infrastructure
```

`Web` y `Web.Client` **no referencian** `Infrastructure` ni `Domain`: el front no puede tocar la BD.

### 3.1 Comandos para crearla

```bash
mkdir amsys && cd amsys
dotnet new globaljson --sdk-version 10.0.100 --roll-forward latestFeature
dotnet new sln -n Amsys --format slnx
dotnet new gitignore && dotnet new editorconfig

dotnet new classlib -n Amsys.Domain         -o src/Amsys.Domain
dotnet new classlib -n Amsys.Application    -o src/Amsys.Application
dotnet new classlib -n Amsys.Contracts      -o src/Amsys.Contracts
dotnet new classlib -n Amsys.Infrastructure -o src/Amsys.Infrastructure
dotnet new webapi   -n Amsys.Api            -o src/Amsys.Api
dotnet new blazor   -n Amsys.Web            -o src/Amsys.Web --interactivity WebAssembly --all-interactive --empty
#   ↑ crea también src/Amsys.Web/Amsys.Web.Client; muévelo a src/Amsys.Web.Client si prefieres
dotnet new worker   -n Amsys.Worker         -o src/Amsys.Worker
dotnet new console  -n Amsys.Migrator       -o src/Amsys.Migrator
dotnet new console  -n Amsys.Importador     -o tools/Amsys.Importador
dotnet new xunit    -n Amsys.Domain.Tests          -o tests/Amsys.Domain.Tests
dotnet new xunit    -n Amsys.Application.Tests     -o tests/Amsys.Application.Tests
dotnet new xunit    -n Amsys.Api.IntegrationTests  -o tests/Amsys.Api.IntegrationTests

dotnet sln add (Get-ChildItem -Recurse -Filter *.csproj)   # PowerShell
# bash: dotnet sln add $(find . -name '*.csproj')

dotnet add src/Amsys.Application    reference src/Amsys.Domain
dotnet add src/Amsys.Infrastructure reference src/Amsys.Application
dotnet add src/Amsys.Api            reference src/Amsys.Application src/Amsys.Infrastructure src/Amsys.Contracts
dotnet add src/Amsys.Web.Client     reference src/Amsys.Contracts
dotnet add src/Amsys.Worker         reference src/Amsys.Infrastructure
dotnet add src/Amsys.Migrator       reference src/Amsys.Infrastructure
dotnet add tests/Amsys.Domain.Tests          reference src/Amsys.Domain
dotnet add tests/Amsys.Application.Tests     reference src/Amsys.Application
dotnet add tests/Amsys.Api.IntegrationTests  reference src/Amsys.Api
```

Luego crear `Directory.Build.props` y `Directory.Packages.props` en la raíz.

---

## 4. Estrategia de construcción: no reescribir todo de golpe

El legacy tiene ~860 archivos sólo en WebAdmin. Reescribir todo antes de entregar algo es el riesgo
principal. Se construye **por módulos**, y cada cliente migra cuando la plataforma cubre lo que usa.

| Etapa | Contenido | Hito |
|-------|-----------|------|
| **NP-0 Fundaciones** | Solución, CI, auth JWT, tenant + query filters, `Configuracion` (módulos, campos personalizados, etiquetas, branding), layout Blazor | Login + menú filtrado por permisos y módulos |
| **NP-1 Maestros** | Seguridad (usuarios, roles, permisos), catálogos de Administración | CRUD genérico reutilizable en Blazor |
| **NP-2 Activos** | Equipos, Ubicaciones, árbol jerárquico, contadores, puntos de medida, datos técnicos | Primer uso real de campos personalizados |
| **NP-3 Correctivo** | Avisos → OT, notificación, Kanban, costos | **MVP**: alcanza para migrar `ares`, `energiaycombustion`, `itc` |
| **NP-4 Preventivo** | Hoja de ruta, secciones, planes, previsualización y generación a demanda | Portar `PlanMantenimiento.Adicional.cs` **con tests primero** (núcleo crítico, ver `BUSINESS-RULES.md`) |
| **NP-5 Logística** | Almacenes, notas, kardex, hojas de aceptación | |
| **NP-6 Reportes y módulos** | Indicadores, PDF de OT, exportaciones, módulos `SOLICITUDES`, `CONFORMIDAD_AVISO`, etc. | Migrar `pyme`, `eulen`, `caja_arequipa`, `agchavin`, `rentanor`, `oterra` |

**Migración de cada cliente** = script ETL (`tools/clientes/<x>/`) desde su BD legacy hacia el esquema
nuevo, ensayado sobre copia del backup, conteos y totales cuadrados, aceptación en staging, corte.
El orden de clientes de `PLAN-MULTICLIENTE.md` §5 se mantiene.

**Qué se conserva del legacy**: las reglas de negocio documentadas en `/ai` (y las decisiones
vinculantes `D-02`, `D-03`, `D-05`), el esquema de API de `WebAdmin/Api`, las plantillas Excel.
**Qué no se arrastra**: `NoTracking` global con re-adjunto manual, repositorios instanciados con `new`,
JS inline, enums renombrados por cliente, `if (EmpresaId == X)`.

---

## 5. Decisiones pendientes

| ID | Pregunta | Recomendación |
|----|----------|---------------|
| `D-NP-01` | Blazor WASM vs Server | WASM (red inestable en planta, API como único backend) |
| `D-NP-02` | Nombre del repo nuevo | `amsys`; renombrar el actual a `AMSYS-legacy` |
| `D-NP-03` | Minimal APIs vs Controllers en `Amsys.Api` | Minimal APIs agrupadas por módulo (`MapGroup`) |
| `D-NP-04` | App móvil: ¿endpoints de compatibilidad o nueva versión de la app contra `/api/v1`? | Nueva versión; mantener la API legacy viva hasta el corte de cada cliente |
| `D-NP-05` | ¿Ampliar el legacy mientras tanto? | Sólo hotfix; las tareas `MNT-NNN` de seguridad críticas sí, el resto se rediseña en la nueva plataforma |
