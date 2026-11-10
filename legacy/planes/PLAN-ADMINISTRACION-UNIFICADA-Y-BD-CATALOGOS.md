# Plan – Administración unificada en todas las ramas y BD de catálogos

> **Estado**: PROPUESTA — requiere las decisiones `DU-NN` (§4) antes de ejecutar.
> **Fecha**: 2026-11-10 · **Base**: `main` (`5d228c9` local) · **Prefijos**: `UA-NN` (Parte A), `BC-NN` (Parte B)
> **Ramas vigentes**: main, akdrilling, agchavin, caja_arequipa, eulen, oterra, pyme
> (`ares` y `energiaycombustion` se borraron en local el 2026-11-10; siguen en `origin`).

Dos objetivos encadenados:

1. **Parte A** — que el módulo de Administración sea **el mismo código en todas las ramas** (el de `main`,
   con el plan AD-01…AD-20 aplicado). Los campos y catálogos propios de un cliente pasan a `main` como
   **opcionales** (columnas nulas, tablas vacías para quien no las use).
2. **Parte B** — sacar esas tablas a **una BD de catálogos común**, donde la única llave de separación
   entre clientes sea `empresaid`.

La Parte A es requisito de la B: no se puede compartir una tabla si cada rama la define distinta.

---

## 1. Punto de partida (medido el 2026-11-10)

Comparación de las 6 capas (`Configuraciones`, `Entidades`, `Logicas`, `Repositorios`, `Servicios`,
`WebAdmin/Areas/Administracion`) contra `main`, ignorando espacios y fin de línea: 383 archivos,
67 idénticos en todas las ramas.

| Rama | Estado del módulo | Propio del cliente |
|---|---|---|
| akdrilling | **Idéntica a `main`** | — |
| agchavin | UI de `main` (`helper.catalogo`), **backend antiguo** (sin AD-01/05/10/11/17, sin `UsoCatalogo`) | `MaterialServicio.GuardarAsync(List<Material>)` (importación por lotes) |
| pyme | Backend y UI antiguos | — (le faltan `Material.Precio`, `Ids`/`Agrupador` en filtros de Sistema y Servicio) |
| eulen | Backend y UI antiguos | `Cliente`, `CategoriaAviso`, `TipoSolicitudAviso`; `Material.Marca`, `Precio` con precisión (20,2); `Adjunto.Token` (obligatorio, GUID) |
| caja_arequipa | Backend y UI antiguos | `Cliente`, `CategoriaAviso`, `TipoSolicitudAviso`, `Feriado`; `Prioridad.HorasAtencion`, `Prioridad.DespuesDelDia` |
| oterra | Backend y UI antiguos; configs `Sistema`/`Parte` con `IEntityTypeConfiguration` | `Area`, `Conformidad`, `ImpactoProceso`; `Material` con relaciones y conteo de uso (`_Relaciones`, `ContarUsoAsync`). **No tiene** `Calificacion`, `Material.Precio` ni `Codigo` en los 4 catálogos de falla |

Lo que tiene `main` y falta en el resto: AD-01 (lectura filtrada por empresa en 18 servicios), AD-02/03
(escritura entre empresas), AD-04 (temporales seguros), AD-05 (`ActualizarAsync → bool`), AD-06…09
(validación y `helper.catalogo`), AD-10/11 (*En uso* y aviso al desactivar, `UsoCatalogo`), AD-17
(biblioteca de adjuntos), AD-18 (código duplicado); `Codigo` en CausaFalla/Impacto/MecanismoFalla/
MetodoDeteccion, `Material.Precio`.

---

## 2. Parte A — Unificar Administración, rama por rama

### 2.1 Reglas

- **Un solo código.** Al terminar, `git diff main <rama> -- <6 carpetas del módulo>` debe salir **vacío**
  en todas las ramas. Esa es la prueba de aceptación.
- **`main` es el superconjunto.** Todo campo o catálogo de un cliente se agrega primero a `main`; las
  ramas luego copian el módulo entero. Nunca se edita el módulo dentro de una rama de cliente.
- **Lo extra es opcional**: columnas nuevas `NULL` y sin `IsRequired()`; tipos C# nulos (`decimal?`,
  `bool?`, `string?`). Un catálogo extra existe en todas las BD pero sólo se ve donde se use
  (página/menú sembrado sólo para ese cliente, o flag por empresa — `DU-02`).
- **Lo que no es del módulo no se toca aquí.** Las FK desde Aviso/OT/Usuario hacia `Cliente`, `Area`,
  `Conformidad`, etc. son de Gestión/Seguridad; siguen como están en cada rama. Si el código de una
  rama las necesita, la entidad del catálogo ya estará (vendrá de `main`).
- **Migraciones**: en cada rama se genera **su propia** migración (las cadenas son incompatibles entre
  ramas, ver `ramas.md`). Script SQL sólo de esa migración para el servidor; aplicarlo es decisión del
  propietario.

### 2.2 Fase 0 — `main` como superconjunto (UA-01…UA-06)

| Paso | Qué | Detalle |
|---|---|---|
| **UA-01** | Campos extra opcionales | `Material.Precio decimal?` **ya es opcional en `main`** (sólo falta la columna en pyme y oterra) · `Prioridad.HorasAtencion decimal?`, `Prioridad.DespuesDelDia bool?` (caja) · `Material.Marca string?` y `Precio` con `HasPrecision(20,2)` (eulen; `DU-03`) · `Adjunto.Token string?` (eulen; se genera con GUID al crear, columna nula) |
| **UA-02** | Catálogos de eulen/caja | `Cliente` (Nombre, Correos), `CategoriaAviso`, `TipoSolicitudAviso` (Codigo, Descripcion) — tomar la versión de `eulen` (idéntica a caja) y llevarla al patrón de `main`: `BuscarPorIdAsync(id, empresaId)`, `ActualizarAsync → bool`, `helper.catalogo`, *En uso*, código duplicado |
| **UA-03** | Catálogo `Feriado` (caja) | Igual que UA-02. Mantener `BaseEntity` sólo si `main` ya la tiene; si no, campos explícitos |
| **UA-04** | Catálogos de oterra | `Area`, `Conformidad`, `ImpactoProceso` al patrón de `main`. `Area.Codigo` pasa a `string?` en `main` (en oterra es obligatorio: la validación de obligatoriedad se hace en el formulario si `DU-02` lo marca) |
| **UA-05** | Funciones útiles de ramas | `MaterialServicio.GuardarAsync(List<Material>)` (agchavin). Panel `_Relaciones` de Material (oterra): comparar con *En uso* de `main` (AD-10) y quedarse con uno (`DU-04`) |
| **UA-06** | Migración en `main` | `Administracion_Superconjunto`: columnas nulas + tablas nuevas, con índice `(empresaid)` en cada tabla nueva. Páginas/elementos de Seguridad de los catálogos nuevos **no** se siembran por defecto |

Prueba: compila la solución, los catálogos de `main` siguen funcionando, los nuevos se ven sólo al dar
permiso a la página.

### 2.3 Rama por rama (en orden de menor a mayor riesgo)

Pasos comunes a cada rama (`PORTE-ADMINISTRACION-MAIN-<RAMA>.md` con el formato de `ramas.md`):

1. `git checkout <rama> && git checkout -b admin-desde-main`
2. `git checkout main -- AMSYS.Configuraciones/Administracion AMSYS.Entidades/Administracion AMSYS.Logicas/Administracion AMSYS.Repositorios/Administracion AMSYS.Servicios/Administracion AMSYS.WebAdmin/Areas/Administracion`
3. Borrar los archivos que la rama tenía con otro nombre (p. ej. `SistemaConfig.cs`, `ParteConfig.cs` en oterra; `*Logica.cs` sin punto en eulen/caja).
4. Registrar en `AMSYSContexto.OnModelCreating` las configs/`DbSet` nuevos.
5. Compilar y corregir **fuera del módulo** los llamadores: `BuscarPorIdAsync(id)` → `(id, empresaId)`;
   `ActualizarAsync` ahora devuelve `bool`; uso de `Codigo`/`Precio`; filtros con `Ids`/`Agrupador`.
6. Si la rama no tiene el marco de UI de `main` (`helper.catalogo` en `wwwroot/js/helper.js`, parciales
   compartidos, `columnas.js`), traerlo antes (ver *Prerrequisito UI*).
7. Migración de la rama (`Administracion_DesdeMain`), probar en una copia local de su BD, script para el servidor.
8. Prueba de aceptación: diff vacío del módulo contra `main`; checklist de AD-01/05/10/11/18 en el navegador.
9. Bitácora en `clientes/<rama>.md` y `ESTADO.md`.

| # | Rama | Trabajo específico | Esfuerzo | Riesgo |
|---|---|---|---|---|
| 1 | **akdrilling** | Nada en el módulo; sólo aplicar la migración UA-06 (columnas/tablas vacías). Sirve de prueba del procedimiento | S | Bajo |
| 2 | **agchavin** | La UI ya es la de `main`: es sobre todo backend. Migración: `codigo` en 4 catálogos de falla (nulo). Revisar llamadores de `BuscarPorIdAsync` en Gestión/WebAPI. La importación que use `GuardarAsync(List<Material>)` sigue funcionando (UA-05) | M | Bajo |
| 3 | **pyme** | Requiere **prerrequisito UI**. Migración: `material.precio`. Sin catálogos propios | M | Bajo |
| 4 | **eulen** | Prerrequisito UI. Sus 3 catálogos ya vienen de `main` (UA-02): verificar que los datos existentes se lean igual (mismas tablas/columnas). `Adjunto.Token` pasa a nulo: **comprobar** dónde se usa el token (enlaces públicos de adjuntos de aviso) antes de migrar. Migración: `codigo` en catálogos de falla si falta, `material.marca` ya existe | M | Medio |
| 5 | **caja_arequipa** | Prerrequisito UI. Igual que eulen + `Feriado` y `Prioridad.HorasAtencion/DespuesDelDia` (pasan a nulos: revisar la lógica de SLA de avisos que los lee y tratar `null` como 0/false) | M | Medio |
| 6 | **oterra** | Prerrequisito UI (la más lejana, 120 commits atrás). Configs de Sistema/Parte cambian de forma (mismo mapeo, verificar con `migrations add` que la migración no recree tablas). Migración: tabla `calificacion`, `codigo` en 4 catálogos, `material.precio`. Decidir el panel de relaciones (`DU-04`) | L | Alto |

**Prerrequisito UI** (pyme, eulen, caja_arequipa, oterra): las vistas de `main` dependen de
`helper.catalogo`, parciales de pie de modal y estilos que esas ramas no tienen. Opciones: portar antes
la UI de `main` como se hizo en agchavin (`legacy/portes/PORTE-UI-MAIN-AGCHAVIN.md`), o traer sólo
`helper.js` + parciales que usa Administración (`DU-01`).

---

## 3. Parte B — Mover los catálogos a una BD propia

### 3.1 El problema real: hoy los catálogos no están aislados

Medido en `main` (2026-11-10):

- **66** propiedades de navegación desde Gestión/Logística/Seguridad hacia catálogos (OT, Aviso, Tarea, Equipo, Confiabilidad, Notas de entrada/salida…).
- **61** FK (`HasOne`) en configuraciones fuera de Administración apuntando a catálogos.
- **111** `Include(...)` de catálogos en lógicas/repositorios de otros módulos.
- SQL crudo en Logística y en repositorios de Equipo/Ubicación/ContadorHistorial.
- `Empresa` tiene colecciones de casi todos los catálogos; `Usuario.EmpleadoId` → `Empleado`.

PostgreSQL **no permite FK ni JOIN entre bases distintas**. Separar la BD sin más rompe todo lo anterior.

Además, cada cliente tiene su BD con sus propias secuencias: **`empresa.id = 1` existe en varios clientes**
y **`causafalla.id = 5` también**. Juntar las tablas en una sola BD choca en las dos llaves.

### 3.2 Opciones

| Opción | Cómo | A favor | En contra |
|---|---|---|---|
| **B1. BD central + réplica local** ⭐ | BD `amsys_catalogos` es la dueña. Cada BD de cliente recibe **por replicación lógica** sólo las filas de su `empresaid` (`CREATE PUBLICATION … WHERE (empresaid = X)`, PostgreSQL 15+) | FK, JOIN e `Include` siguen funcionando contra la copia local; casi no cambia el código de Gestión | Se escribe en la central y se lee en la local (latencia de segundos); operar la replicación |
| B2. Dos `DbContext` sin réplica | `CatalogosContexto` aparte; quitar las 66 navegaciones y 61 FK; completar nombres en memoria con caché | Separación limpia, sin infraestructura extra | Reescribir 111 `Include`, SQL crudo, reportes y exportaciones. Es casi rehacer Gestión |
| B3. `postgres_fdw` | Las tablas de la central se ven como tablas foráneas en cada BD | Cero código | Rendimiento pobre en JOIN grandes (reportes, dashboard), FK imposibles, filtro por empresa a mano |

**Recomendación: B1**, preparada con un esquema `catalogo` en cada BD actual para fijar el límite antes
de mover nada. B2 tiene sentido sólo como destino en la nueva plataforma, donde el código se escribe ya
sin esas navegaciones.

### 3.3 Fases (BC-01…BC-08)

| Paso | Qué | Detalle |
|---|---|---|
| **BC-01** | Parte A terminada | Mismas tablas y columnas en todas las ramas; requisito duro |
| **BC-02** | Identidad global de empresa | Cada `Empresa` recibe un id **único entre clientes**. Opciones (`DU-05`): a) usar `Empresa.Llave` (GUID) como llave global y agregar `empresaid` global entero en la central; b) asignar rangos: renumerar `empresa.id` en cada BD de cliente (eulen 1xx, caja 2xx…) con script que actualiza todas las FK. **a)** evita tocar datos de producción |
| **BC-03** | Identidad global de registros | Llave en la central: **`(empresaid, id)` compuesta** — el `id` de cada cliente se conserva tal cual, así no hay que reescribir las FK de OT/Aviso/Equipo. Alternativa: `id` global nuevo + tabla de mapeo por cliente (más limpio, mucho más riesgo) |
| **BC-04** | Esquema `catalogo` en cada BD actual | Mover las tablas del módulo a `catalogo.*` (`ToTable("x", "catalogo")` + migración `ALTER TABLE … SET SCHEMA`). No cambia el comportamiento; deja claro qué se replicará |
| **BC-05** | Cerrar la escritura | Sólo el área Administración (y la API de catálogos) escribe en `catalogo.*`. Buscar y redirigir cualquier escritura desde otros módulos (p. ej. importaciones de `DemonApp`/`AddDataApp`, `Material` desde Logística) |
| **BC-06** | Crear `amsys_catalogos` | Mismo esquema `catalogo` con PK `(empresaid, id)`, tabla `empresa` mínima (id global, llave, nombre) y nada más. Carga inicial: ETL desde cada BD de cliente (`tools/catalogos/cargar.sql`) |
| **BC-07** | Replicación | En la central: una publicación por cliente con `WHERE (empresaid = …)`. En cada BD de cliente: `SUBSCRIPTION` con `copy_data = false` (los datos ya están). Las tablas locales pasan a ser de sólo lectura para la app |
| **BC-08** | Escritura en la central | Las lógicas de Administración usan un `CatalogosContexto` (cadena `AMSYS_CATALOGOS`) para escribir; las lecturas del resto del sistema siguen en `AMSYSContexto` contra la copia local. Tras guardar, la pantalla relee de la central para no mostrar datos viejos |

Tablas que **no** deben ir en la primera ola (`DU-06`):
- `Adjunto` — sus archivos están en disco de cada servidor; moverlo exige almacenamiento compartido primero.
- `Empleado`/`EmpleadoHorario` — los usa Seguridad (`Usuario.EmpleadoId`) y la programación de OT; son datos de personal más que catálogo.
- `Material` — Logística mantiene stock y precios sobre él (`AlmacenMaterial`, notas); si sus precios cambian por cliente, la central se vuelve transaccional.
- `DatoTecnico`, `TipoEquipo`, `ModoFallaClaseEquipo`, `Parte` y `EmpleadoHorario` no tienen `empresaid` propio (cuelgan de su padre): en la central necesitan `empresaid` agregado o se replican siempre con su padre.

Primera ola sugerida (catálogos puros, poco tráfico): Prioridad, Criticidad, Especialidad, TipoTarea,
TipoMantenimiento, UnidadMedida, UnidadMedidaServicio, CentroCosto, CuentaContable, CausaFalla, Impacto,
MecanismoFalla, MetodoDeteccion, ModoFalla, Aspecto, Calificacion, TallerResponsable, Servicio,
Sistema/Parte, ClaseEquipo (+hijos), y los opcionales de clientes (Cliente, CategoriaAviso,
TipoSolicitudAviso, Feriado, Area, Conformidad, ImpactoProceso).

### 3.4 Relación con la nueva plataforma

`migracion/PLAN-NUEVA-PLATAFORMA.md` ya pone los catálogos en **NP-1 Maestros**, con filtro global por
`EmpresaId`. Si la nueva plataforma va a reemplazar al legacy cliente por cliente, la BD de catálogos
puede ser **directamente la de la nueva plataforma** (B2 nativo allí) y el legacy sólo la consume por
réplica (B1). Así el trabajo de la Parte B no se hace dos veces (`DU-07`).

---

## 4. Decisiones del propietario

| Id | Pregunta | Opciones | Recomendación |
|---|---|---|---|
| `DU-01` | Ramas sin UI de `main` | a) Portar antes toda la UI (como agchavin) · b) Sólo `helper.js` + parciales que usa Administración | 🟢 **b** (propietario, 2026-11-10) — HECHO |
| `DU-02` | Cómo se ocultan los catálogos extra | a) Página de Seguridad sólo sembrada para el cliente · b) Flag por empresa (`EmpresaModulo`, `PLAN-MULTICLIENTE` §3.1) | **a** ahora (no requiere código nuevo) |
| `DU-03` | Precisión de `Material.Precio` | a) (20,2) de eulen en todas · b) Sin precisión fija | **a** |
| `DU-04` | Uso de Material | a) *En uso* de `main` (AD-10) · b) Panel `_Relaciones` de oterra · c) Ambos | **c** si oterra lo usa, migrando el panel al patrón de `main` |
| `DU-05` | Id global de empresa | a) Llave GUID + id global sólo en la central · b) Renumerar `empresa.id` por rangos | **a** |
| `DU-06` | Tablas de la primera ola | Lista de §3.3 | Excluir Adjunto, Empleado y Material |
| `DU-07` | Dueña de la BD de catálogos | a) BD nueva propia del legacy · b) La de la nueva plataforma | **b** si la nueva plataforma entra en producción antes de 6 meses |

---

## 5. Registro de avance

| Paso | Estado | Fecha | Commit | Nota |
|---|---|---|---|---|
| — | PROPUESTA | 2026-11-10 | | Plan redactado tras comparar el módulo en las 7 ramas |
| DU-01 | HECHO (local, sin push) | 2026-11-10 | pyme `b708cef`, eulen `2000173`, caja_arequipa `198b230`, oterra `136a9dc` | pyme/eulen/caja: `helper.js`, `site.css` y `_PieModalCatalogo.cshtml` = los de `main` (las ramas eran un subconjunto: sólo se agregan clases y funciones; cambia el texto de paginación a «Mostrando x - y de n registros» y el botón de cerrar del error pasa a Bootstrap 5). oterra: sólo se agregó `helper.codigoDuplicado`, `.nav-link.con-error`, `.select2-selection.is-invalid` y el parcial (ya tenía `catalogo`, `filtros`, `tabla`, `html`; se conserva su tema y su persistencia de filtros). agchavin ya era idéntica. `constantes.js` y `columnas.js` no hacen falta (las constantes que usa Administración ya existen en todas). Falta probar en navegador cuando lleguen las vistas |
