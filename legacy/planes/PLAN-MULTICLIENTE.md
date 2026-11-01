# Plan Multicliente – De "una rama por cliente" a "un producto configurable"

> **Estado**: PROPUESTA — requiere decisiones del propietario (`D-MC-NN`, §7) antes de ejecutar.
> **Fecha del análisis**: 2026-10-02
> **Prefijo de tareas**: `MC-NN`
>
> **Actualización**: el destino de la unificación es la nueva plataforma descrita en
> `PLAN-NUEVA-PLATAFORMA.md`, no `main` de este repo. Los conceptos (módulos, campos personalizados,
> etiquetas de estado, branding) se mantienen; las fases 1–3 se construyen allí y la Fase 4 pasa a ser
> un ETL de la BD legacy de cada cliente hacia el esquema nuevo.

---

## 1. Diagnóstico: cómo se gestiona hoy cada cliente

**HECHO**: cada cliente es una **rama git de larga vida** que se bifurcó de `main` en algún momento y
evolucionó por su cuenta. Cada una tiene su propia base de datos, sus propias migraciones EF y su
propio `appsettings.json`.

| Rama | Bifurcada de `main` | Último commit | Commits propios | Commits de `main` que le faltan | Migraciones propias | Divergencia |
|------|---------------------|---------------|-----------------|---------------------------------|---------------------|-------------|
| `ares` | 2025-10-03 | 2025-12-12 | 5 | 16 | 0 | 🟢 Baja (logo + lógica OT) |
| `energiaycombustion` | 2024-11-28 | 2024-12-01 | 2 | 29 | 0 | 🟢 Baja (dashboard Home) |
| `pyme` (PanaService) | 2025-03-02 | 2025-05-12 | 7 | 19 | 0 | 🟢 Baja (costos OT, reporte costo, plantillas Excel) |
| `itc` | 2024-03-15 | 2024-06-06 | 3 | 70 | 1 | 🟢 Baja (datos técnicos — **ya está en `main`**) |
| `eulen` | 2025-02-01 | 2026-07-20 | 58 | 20 | 12 | 🟠 Alta |
| `caja_arequipa` | 2025-02-01 | 2026-05-20 | 43 | 20 | 15 | 🟠 Alta |
| `agchavin` | 2024-02-13 | 2026-05-25 | 77 | 80 | 10 | 🔴 Muy alta |
| `rentanor` | 2024-01-13 | 2025-08-03 | 75 | 96 | 16 | 🔴 Muy alta |
| `oterra` | **2023-10-18** | 2026-09-13 | 30 | **120** | 20 | 🔴 Máxima (597 archivos) |

Medido con `git merge-base main origin/<rama>` y `git diff --stat` excluyendo migraciones y librerías.

### 1.1 Qué cambia realmente entre clientes

Analizando los diffs, **las diferencias caen en 6 categorías**. Casi ninguna justifica un fork:

| # | Categoría | Ejemplos reales | Solución propuesta |
|---|-----------|-----------------|--------------------|
| **A** | **Ya está en `main`** (la rama simplemente está atrasada) | `Sistema/Parte` en Aviso, `EquipoDatoTecnico`, `EquipoSistema`, `NotificacionTarea`, `OrdenTrabajo.ValorEjecucion/FechaLanzamiento` (agchavin, rentanor, itc) | Nada que diseñar: se resuelve al migrar el cliente a `main` |
| **B** | **Funcionalidad compartida por ≥2 clientes**, copiada a mano | `Cliente` + `CategoriaAviso` + `TipoSolicitudAviso` + `NotificacionAviso` + `EmailService` + `BaseEntity` (soft delete): **idénticos** en `eulen` y `caja_arequipa`. `HomeController` **idéntico** en `agchavin` y `rentanor`. Indicadores MTBF/MTTR/Disponibilidad y `ReportePDF` de OT en `oterra`, `rentanor`, `agchavin` (**3 versiones distintas del mismo reporte**) | **Módulo del core** activable por cliente (feature flag) |
| **C** | **Campos extra simples** en Equipo / Ubicación / OT / Aviso | `Aviso.CorreoA, CopiaA, Solicitante, CodigoExterno, FechaPeticion` (eulen); `OT.CodigoEJB, HorasServicio, Kilometros, Liberado` (rentanor); `OT.FinProgramado` (caja); `Equipo.Orden` (agchavin) | **Campos personalizados** configurables (JSONB), sin migración por cliente |
| **D** | **Vocabulario / estados** | `EstadoAviso`: `EMITIDO/APROBADO/ATENDIDO/FINALIZADO/RECHAZADO` vs `ABIERTO/APROBADO/ATENDIDO/CERRADO/CANCELADO` (caja). `CIERRE_TECNICO` → `CIERRE_PARCIAL`, `ANULADO` → `CANCELADO` (caja). `PROGRAMADO` comentado (oterra). `TipoAviso.FALLA`/`PARADA` comentados | Enum canónico único + **etiquetas y estados habilitados por cliente** |
| **E** | **Branding y plantillas** | `logo_ares.png`, `logoPanaService.jpg`, `ImagenCabecera/ImagenPie` (rentanor), `formatoAvisoExportar.xlsx`, `formatoOrdenTrabajoExportar.xlsx`, `formatoEquipoExportar.xlsx` modificados por cliente | **Assets por cliente** con fallback al default |
| **F** | **Lógica realmente propia** | `oterra`: `Area`, `ImpactoProceso`, `Conformidad`, `Turno`, `AvisoPadre`, `AvisoContador/PuntoMedida`. `caja_arequipa`: `Feriado`, `OrdenTrabajoCalificacion`. Scripts de importación (`DemonApp/Program.cs` 270–1460 líneas distintas por cliente) | Módulo opcional del core **si** tiene sentido de producto; si no, extensión aislada (§3.4). Scripts → `tools/clientes/<x>/` |

> **Conclusión**: estimamos que **≥80 % de la divergencia es A + B + C + D + E**, es decir, cosas que un
> producto configurable resuelve sin código por cliente. Sólo la categoría F necesita decisión caso
> por caso.

### 1.2 Costo del modelo actual

- **Cada corrección se hace N veces.** Las mejoras de `/ai/tasks` (seguridad SEC-01, permisos,
  UX…) sólo llegan a `main`; ningún cliente las recibe. `oterra` lleva 120 commits atrasado.
- **El mismo reporte existe en 3–4 versiones** (`_Disponibilidad.cshtml` tiene 4 hashes distintos).
- **Las migraciones EF son incompatibles entre ramas**: 45 en `main` + 74 propias repartidas en 6
  ramas. No se puede hacer `merge` de una rama de cliente sin romper el `ModelSnapshot`.
- **Secretos versionados.** `eulen/AMSYS.WebAdmin/appsettings.json` contiene un token de SendGrid y
  la contraseña SMTP en texto plano (revisar también el resto de ramas). → `MC-00`.
- **Sin CI** (`.github/workflows` vacío): no hay forma de saber si un cambio en `main` rompe a un cliente.

---

## 2. Opciones evaluadas

### Opción 1 — Mantener ramas por cliente, pero sincronizarlas (rebase/merge periódico)
- ✅ Cero cambio de arquitectura.
- ❌ Los conflictos de migraciones y vistas crecen con cada cliente. Es lo que ya no escala.
- **Descartada** salvo como paliativo temporal.

### Opción 2 — Un front (y backend) separado por cliente sobre un "core" compartido (NuGet/submódulo)
- ✅ Libertad total por cliente.
- ❌ Las vistas Razor son justamente donde está la mayor parte de la divergencia: un front por
  cliente **multiplica** el problema en lugar de resolverlo. 9 fronts que mantener.
- ❌ El dominio (Aviso, OT) está acoplado a las vistas por los modelos `XxxModel.Get()`.
- **No recomendada.** Un front por cliente sólo tiene sentido si los clientes tuvieran UX
  radicalmente distinta, y no es el caso: cambian campos, etiquetas y reportes.

### Opción 3 — ⭐ Un solo producto, una sola rama, configurable por cliente (RECOMENDADA)
- Un único código (`main`), un único front, un único esquema de BD.
- Lo que cambia entre clientes se expresa como **configuración** (datos), no como código:
  1. **Módulos activables** (feature flags por `Empresa`).
  2. **Campos personalizados** por entidad.
  3. **Etiquetas de estados** y estados habilitados.
  4. **Branding y plantillas** de reportes.
  5. **Extensiones** aisladas sólo para la lógica F que no encaje.
- Despliegue: **el mismo artefacto** se publica por cliente (ver D-MC-01).
- ✅ Una corrección llega a todos. ✅ Un reporte, parametrizado. ✅ Una cadena de migraciones.
- ❌ Requiere una fase de convergencia de BD por cliente (la parte más delicada, §5).

### Opción 4 — SaaS multi-tenant real (una instancia + una BD para todos)
- AMSYS **ya tiene la base**: `Empresa`, `Limitacion`, `TipoPlan`, `Configuracion`, y la API filtra
  por el claim `EmpresaId`.
- ❌ Hoy cada cliente tiene su BD y sus datos; consolidar implica migrar datos y garantizar que
  *todas* las consultas filtren por `EmpresaId` (`analysis/permissions.md` muestra que no es así en
  todas partes).
- **Es el destino natural de la Opción 3**, no un paso separado: si se construye la Opción 3 con
  la configuración colgando de `Empresa`, pasar a una sola instancia es después sólo un tema de despliegue.

---

## 3. Arquitectura objetivo (Opción 3)

```
main (único)
├── AMSYS.Entidades / Configuraciones / Contextos / Repositorios / Logicas   ← core
├── AMSYS.Modulos.*            ← (opcional) módulos de la categoría B/F, activables
├── AMSYS.WebAdmin             ← un solo front
│   └── wwwroot/clientes/<codigo>/  logo, cabecera, pie, plantillas .xlsx
└── tools/clientes/<codigo>/   ← scripts de importación (ex DemonApp/AddDataApp por rama)
```

### 3.1 Configuración por cliente (colgada de `Empresa`)

Extender la entidad existente `Configuracion` (hoy sólo tiene `CrearAvisoPorPuntoMedida`) o crear
`EmpresaModulo`:

```csharp
public class EmpresaModulo            // feature flags
{
    public int EmpresaId { get; set; }
    public string Modulo { get; set; }   // "SOLICITUDES", "INDICADORES_CONFIABILIDAD", "CALIFICACION_OT", ...
    public bool Activo { get; set; }
}
```

- Servicio `IConfiguracionCliente` (scoped, cacheado) que la UI y la lógica consultan:
  `if (config.ModuloActivo(Modulos.Solicitudes)) …`.
- En Razor: un tag helper `<modulo nombre="SOLICITUDES">…</modulo>` y filtro de menú
  (el menú ya se construye desde `Pagina`/`Rol`; basta con ocultar páginas de módulos inactivos).

### 3.2 Campos personalizados (categoría C)

```csharp
public class CampoPersonalizado
{
    public int Id { get; set; }
    public int EmpresaId { get; set; }
    public string Entidad { get; set; }     // "Equipo" | "Ubicacion" | "OrdenTrabajo" | "Aviso"
    public string Clave { get; set; }       // "codigoEJB"
    public string Etiqueta { get; set; }    // "Código EJB"
    public TipoCampo Tipo { get; set; }     // Texto, Numero, Fecha, Booleano, Lista, Correo
    public string? Opciones { get; set; }   // JSON para listas
    public bool Requerido { get; set; }
    public int Orden { get; set; }
    public bool EnListado { get; set; }
    public bool EnExportacion { get; set; }
    public bool Activo { get; set; }
}
```

- Las 4 entidades reciben una columna **`datos_adicionales jsonb`** (PostgreSQL → EF Core 8 la mapea
  con `OwnsOne(...).ToJson()` o como `JsonDocument`/`Dictionary<string, object>`).
- Partial Razor `_CamposPersonalizados.cshtml` que se incluye en `Nuevo/Editar/Ver` de las 4 entidades.
- La exportación Excel y los listados añaden columnas dinámicas para `EnListado/EnExportacion`.
- La API móvil devuelve `datosAdicionales` tal cual.
- **Regla**: un campo va a JSONB si es *dato* (se captura y se muestra). Si participa en lógica
  (filtros complejos, FK a catálogo, cálculos), va como columna real en un módulo (§3.1).

### 3.3 Estados y vocabulario (categoría D)

- Un **único enum canónico** (`EstadoAviso`, `EstadoOrdenTrabajo`, `TipoAviso`) en `main`. No se
  renombran valores por cliente.
- Tabla `EtiquetaEstado(EmpresaId, Enum, Valor, Etiqueta, Habilitado, Color)` → caja ve
  `CERRADO` donde el core guarda `FINALIZADO`.
- Mapeo de convergencia caja_arequipa: `ABIERTO→EMITIDO`, `CERRADO→FINALIZADO`,
  `CANCELADO→RECHAZADO`, `CIERRE_PARCIAL→CIERRE_TECNICO`, OT `CANCELADO→ANULADO`.
  ⚠️ Validar significado con el cliente antes: ver `D-MC-03`.
- Respeta las decisiones vinculantes ya tomadas (`D-02`: no anular en `CIERRE_TECNICO`).

### 3.4 Reportes

Tres niveles, de menor a mayor costo:
1. **Plantilla por cliente**: `wwwroot/clientes/<codigo>/reportes/formatoX.xlsx` con fallback a
   `wwwroot/reportes/formatoX.xlsx`. Resuelve pyme, eulen, caja (sólo cambian formatos).
2. **Reporte parametrizado único**: MTBF/MTTR/Disponibilidad y `ReportePDF` de OT se unifican en una
   sola implementación con opciones (columnas, agrupación, logo). Tomar como base la versión más
   completa (probablemente `oterra`, la más reciente) y comparar contra `rentanor`/`agchavin`.
3. **Reporte exclusivo**: interfaz `IReporteCliente` registrada sólo si el módulo está activo.
   Último recurso.

### 3.5 Branding
`Empresa` (o `Configuracion`) gana `CodigoCliente`, `NombreComercial`, `ColorPrimario`.
`_Layout.cshtml` y los PDF leen logo/cabecera/pie de `wwwroot/clientes/<codigo>/`.

### 3.6 Extensiones de lógica (categoría F)
Si tras la clasificación (MC-02) queda lógica que no es producto, se aísla detrás de interfaces del core
(`IAvisoExtension.AlCrear(aviso)`, `IOrdenTrabajoExtension.AlNotificar(ot)`) con implementaciones
registradas sólo para ese cliente. Evitar `if (EmpresaId == X)` en el código (la rama `pyme` ya
introdujo `EmpresaMaestro.PANASERVICE = 1` — es el anti-patrón a eliminar).

---

## 4. Propuesta de módulos (categoría B y F) — a validar en MC-02

| Módulo | Origen | Contenido |
|--------|--------|-----------|
| `SOLICITUDES` (mesa de ayuda) | eulen + caja_arequipa (código idéntico) | `Cliente`, `CategoriaAviso`, `TipoSolicitudAviso`, `NotificacionAviso`, envío de correo (`CorreoA/CopiaA/Solicitante` en Aviso), correlativo |
| `ELIMINACION_LOGICA` | eulen, caja, rentanor (`BaseEntity`) | Soft delete. Candidato a **core para todos**, no a módulo |
| `INDICADORES_CONFIABILIDAD` | oterra, rentanor, agchavin | MTBF, MTTR, Disponibilidad, `IndicadorGrupo`, `IndicadorMundial` (agchavin) |
| `REPORTE_PDF_OT` | oterra, rentanor, agchavin | Formato imprimible de OT con branding |
| `CONFORMIDAD_AVISO` | oterra | `Conformidad`, `EstaConforme`, `_CambiarConformidad` |
| `CALIFICACION_OT` | caja_arequipa | `OrdenTrabajoCalificacion` + opciones |
| `AREAS_IMPACTO` | oterra | `Area`, `ImpactoProceso`, `AvisoPadre` (avisos hijos) |
| `TURNOS_PROGRAMACION` | oterra | `Turno`, cambios a `ProgramacionEmpleado` |
| `FERIADOS` | caja_arequipa | `Feriado` (¿afecta cálculo de fechas de plan?) |
| `COSTOS_OT_AVANZADO` | pyme | cambios en `OrdenTrabajoCosto` + reporte de costo |

---

## 5. Hoja de ruta

> Regla de oro: **no se migra un cliente hasta que `main` puede representar todo lo que ese cliente usa.**
> Se avanza cliente por cliente, del menos al más divergente.

### Fase 0 — Contención (1 semana)
| Tarea | Descripción |
|-------|-------------|
| **MC-00** | 🔴 **Seguridad**: rotar token SendGrid y contraseña SMTP versionados (`eulen` y revisar todas las ramas). Mover secretos a variables de entorno / `dotnet user-secrets` / `appsettings.<Cliente>.json` fuera de git |
| **MC-01** | Etiquetar cada rama (`cliente/<x>/pre-unificacion`) y respaldo de cada BD de producción (`BackupPG`) |
| **MC-02** | Matriz de funcionalidades: por cada rama, clasificar **cada archivo** del diff en A/B/C/D/E/F (§1.1). Entregable: `ai/analysis/clientes/<x>.md`. Sin tocar código |
| **MC-03** | Regla de trabajo: **toda funcionalidad nueva se hace en `main`**, nunca en la rama del cliente. Las ramas sólo reciben hotfix críticos hasta su migración |

### Fase 1 — Fundaciones en `main` (2–3 semanas)
| Tarea | Descripción |
|-------|-------------|
| **MC-10** | `CodigoCliente` + branding en `Empresa`/`Configuracion`; assets en `wwwroot/clientes/<codigo>/` con fallback |
| **MC-11** | `EmpresaModulo` + `IConfiguracionCliente` + filtrado de menú y tag helper |
| **MC-12** | Resolución de plantillas Excel por cliente (fallback) |
| **MC-13** | `EtiquetaEstado` + helper de visualización en vistas, listados, Kanban y exportaciones |
| **MC-14** | Proyecto de **tests** mínimo (no existe ninguno) cubriendo los flujos críticos de `analysis/orders.md` §9 — sin esto la unificación es a ciegas |
| **MC-15** | CI en GitHub Actions: build + tests en cada push a `main` |

### Fase 2 — Campos personalizados (2 semanas)
| Tarea | Descripción |
|-------|-------------|
| **MC-20** | `CampoPersonalizado` + columna `datos_adicionales jsonb` en Equipo, Ubicacion, OrdenTrabajo, Aviso (una migración) |
| **MC-21** | Pantalla de administración de campos (Área Administración) |
| **MC-22** | Partial `_CamposPersonalizados` en Nuevo/Editar/Ver de las 4 entidades + validación de requeridos en servidor |
| **MC-23** | Columnas dinámicas en listados y exportación Excel; exposición en API móvil |

### Fase 3 — Promover módulos compartidos a `main` (iterativo)
Una tarea por módulo de §4, empezando por los de código idéntico entre ramas:
**MC-30** `ELIMINACION_LOGICA` → **MC-31** `SOLICITUDES` → **MC-32** `INDICADORES_CONFIABILIDAD` →
**MC-33** `REPORTE_PDF_OT` → resto según el orden de migración de clientes.

### Fase 4 — Migración de clientes (uno por uno)
Para cada cliente:
1. Verificar que la matriz MC-02 del cliente está 100 % cubierta por `main`.
2. Escribir **script de convergencia de BD** (`tools/clientes/<x>/convergencia.sql`): llevar su
   esquema al de `main`, mover campos de categoría C a `datos_adicionales`, mapear estados (§3.3),
   e insertar la fila `__EFMigrationsHistory` correspondiente para alinear la cadena de migraciones.
3. Ensayarlo sobre una **copia** del backup; comparar conteos y totales (OT, avisos, costos).
4. Configurar `EmpresaModulo`, `CampoPersonalizado`, `EtiquetaEstado`, branding.
5. Prueba de aceptación con el cliente en un entorno de staging.
6. Desplegar `main` en su servidor. Archivar la rama (tag) y eliminarla.

**Orden sugerido** (menor riesgo primero, para validar el proceso):

| Ola | Clientes | Por qué |
|-----|----------|---------|
| 1 | `ares`, `energiaycombustion`, `itc`, `pyme` | 0–1 migraciones propias; cambios de branding, dashboard, plantillas |
| 2 | `eulen`, `caja_arequipa` | Comparten base y el módulo `SOLICITUDES`; se migran juntos |
| 3 | `agchavin`, `rentanor` | Comparten Home, indicadores y reportes de plan |
| 4 | `oterra` | Base de 2023, 120 commits atrás, la mayor lógica propia. Último |

### Fase 5 — Despliegue unificado
- Un solo artefacto de build (CI) → N despliegues con `appsettings.<Cliente>.json` / variables de entorno.
- Migraciones aplicadas con un paso explícito por cliente (respetando la regla actual de `/ai`:
  **el agente no ejecuta migraciones**).
- Opcional a futuro: consolidar en una instancia multi-tenant (Opción 4).

---

## 6. Sobre el frontend: ¿un front por cliente?

**Recomendación: no.** Un solo front configurable.

- Lo que el cliente percibe como "su sistema" es: logo, colores, nombres de estados, algunos campos
  y sus reportes. Todo eso es configuración (§3).
- Los fronts por cliente sólo se justifican con UX radicalmente distinta; aquí cambian campos.
- Si en el futuro se quiere modernizar el front (SPA/React/Blazor), hacerlo **una vez**, consumiendo
  la API (`AMSYS.WebAdmin/Api`, que ya es el código mejor construido y filtra por `EmpresaId`),
  y con el mismo mecanismo de configuración. La app móvil ya sigue este modelo.

---

## 7. Decisiones pendientes del propietario

| ID | Pregunta | Recomendación |
|----|----------|---------------|
| `D-MC-01` | ¿Una instancia + BD por cliente (como hoy) o una instancia multi-tenant? | Instancia por cliente con el mismo artefacto; multi-tenant después |
| `D-MC-02` | ¿Campos de categoría C en JSONB o como columnas reales opcionales? | JSONB (sin migraciones por cliente) |
| `D-MC-03` | ¿Los estados renombrados de `caja_arequipa` significan lo mismo que los canónicos? (`CIERRE_PARCIAL` ≡ `CIERRE_TECNICO`?) | Confirmar con el cliente antes de MC-13 |
| `D-MC-04` | Módulos de `oterra` (Área, Impacto, Conformidad, Turnos): ¿producto o exclusivos? | Producto, si otro cliente podría usarlos |
| `D-MC-05` | ¿Soft delete (`BaseEntity`) para todos? | Sí, core |
| `D-MC-06` | ¿Qué versión de MTBF/MTTR/Disponibilidad es la "buena"? | Partir de la de `oterra` y revisar con cada cliente |
| `D-MC-07` | ¿Se puede congelar el desarrollo en ramas de cliente (MC-03)? | Sí; sólo hotfix |

---

## 8. Relación con el resto de `/ai`

- Las tareas `MNT-NNN` y los `PLAN-UX-*` siguen aplicando a `main`; **esta unificación es la que hace
  que esas mejoras lleguen a los clientes**.
- Las decisiones vinculantes `D-02`, `D-03`, `D-05` aplican también a los clientes al migrar.
  Si una rama de cliente las contradice (p. ej. generación automática de OT), se documenta en
  `ai/analysis/clientes/<x>.md` y se consulta.
- Al completar cada tarea `MC-NN`, actualizar `CURRENT-STATE.md`.
