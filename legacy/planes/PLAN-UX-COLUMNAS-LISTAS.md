# Plan de mejora – Columnas configurables en las listas de avisos y órdenes de trabajo

> Documento **ejecutable paso a paso**, con la misma mecánica que los demás `legacy/planes/PLAN-UX-*.md`: cada paso
> es pequeño, verificable y reversible por sí solo. Marca la casilla al terminarlo y anótalo en el
> *Registro de avance* del final.

- **Alcance**: exactamente tres pantallas del área `Gestion`:
  | Pantalla | Vista | Endpoint de datos |
  |---|---|---|
  | Mis avisos | `Views/Aviso/MisAvisos.cshtml` | `/Gestion/Aviso/ListarMisAvisos` |
  | Todos los avisos | `Views/Aviso/Index.cshtml` | `/Gestion/Aviso/Listar` |
  | Órdenes de trabajo | `Views/OrdenTrabajo/Index.cshtml` | `/Gestion/OrdenTrabajo/Listar` |
- **Qué se quiere**:
  1. Elegir qué columnas se ven y en qué orden.
  2. Que esa configuración **se guarde por usuario** y se recupere al volver a entrar.
  3. Guardar configuraciones con nombre (**vistas**) y **compartirlas** para que otros usuarios de la
     empresa las reutilicen.
- **Fuera de alcance**: el resto de listas del sistema, el ancho de las columnas, el orden de las filas
  y los filtros guardados. El diseño deja la puerta abierta a extenderlo (sección 8), pero no se toca
  nada fuera de esas tres vistas.
- **Fecha**: 2026-10-15 · **Decisiones `DC-01` … `DC-06` resueltas el 2026-10-15** (sección 7)

---

## 1. ¿Es posible? Sí, y el terreno está preparado

| Lo que hace falta | Lo que ya existe |
|---|---|
| Pintar la tabla según una lista de columnas | Las tres tablas **ya se pintan en el cliente**: `GenerarTabla` arma cada `<tr>` con una plantilla. Basta con convertir cada `<td>` en una función de una lista de columnas. |
| Reordenar columnas arrastrando | `Sortable.min.js` ya se carga en `_Layout.cshtml` y se usa en `OrdenTrabajo/Kanban.cshtml`. |
| Datos para columnas nuevas | `AvisoRepositorio.QueryListar` ya incluye `Usuario`, `MetodoDeteccion`, `OrdenTrabajo`, `Sistema` y `Parte`; `OrdenTrabajoRepositorio` ya incluye `Prioridad`, `CentroCosto`, `CuentaContable`, `Aviso`, `OrdenTrabajoPadre` y `Usuario`. Llegan en el JSON y hoy no se muestran. |
| Guardar algo por usuario en JSON | Precedente: `IndicadorGrupo` (`usuarioid` + columna `jsonb`) en `AMSYS.Configuraciones/Usuarios`. |
| Acciones nuevas sin página propia en permisos | Precedente: `[FiltroAccion(Accion = "Index")]` («requiere acceso a la lista») en `Seccion`, `Equipo`, `Ubicacion`… |
| Restringir quién comparte | `ExigeElementoAttribute` + `CatalogoElementos` (SG-16): un control concedible por rol. |

**Ningún cambio de servidor es obligatorio para mostrar u ocultar columnas**: el endpoint `Listar` ya
devuelve las entidades completas. El servidor sólo se toca para **guardar** las vistas.

---

## 2. Diseño

### 2.1 Conceptos

- **Lista**: cada una de las tres pantallas, identificada por una clave fija:
  `AVISO_MIOS`, `AVISO_TODOS`, `ORDEN_TRABAJO`.
- **Catálogo de columnas**: todas las columnas que una lista *puede* mostrar, cada una con una clave
  estable (`codigo`, `estado`, `equipo`, `centroCosto`…). Vive en el JavaScript de la vista (cómo se
  pinta) y su lista de claves se repite en C# (para validar lo que se guarda).
- **Disposición** (*layout*): lista ordenada de `{ clave, visible }`. Es lo que se guarda.
- **Vista guardada**: una disposición con nombre. Puede ser **personal** o **compartida** con la empresa.
- **Preferencia del usuario**: para cada lista, qué está usando ahora:
  - una vista guardada (propia o compartida) **por referencia**, o
  - una disposición propia sin nombre (lo que resulta de tocar columnas sin guardar como vista).
- **Predeterminada del sistema**: las columnas de hoy, en el orden de hoy. Quien no configure nada
  ve exactamente lo mismo que ahora.

### 2.2 Columnas fijas

`ACCIONES` y `#` no se ocultan ni se mueven: siempre van primero. Todo lo demás es configurable,
salvo que una lista deba quedarse con al menos una columna de datos visible.

### 2.3 Modelo de datos (PostgreSQL)

```
vistalista                                  usuariolista  (preferencia, 1 fila por usuario y lista)
───────────────────────────────             ──────────────────────────────────────────────────────
id            serial PK                      usuarioid     int  FK usuario   ┐ PK compuesta
empresaid     int  FK empresa                lista         smallint (enum)   ┘
usuarioid     int  FK usuario (autor)        vistalistaid  int? FK vistalista ON DELETE SET NULL
lista         smallint (enum ListaConfigurable)  columnas  jsonb?  (disposición propia sin nombre)
nombre        varchar(80)                    actualizado   timestamp
columnas      jsonb   [{ "clave": "codigo", "visible": true }, …]
compartida    bool
registro      timestamp
actualizado   timestamp
UNIQUE (empresaid, lista, usuarioid, nombre)
```

Regla de lectura de la preferencia: `vistalistaid` → esa vista; si no, `columnas` → disposición
propia; si no, la predeterminada del sistema.

### 2.4 Comportamiento ante cambios

- **Si se borra o se deja de compartir una vista** que otros usan: su preferencia cae a la
  predeterminada (`ON DELETE SET NULL` + comprobación de visibilidad al leer).
- **Si se añade una columna nueva al catálogo**: aparece al final y **oculta** en las disposiciones
  guardadas; visible sólo si está en la predeterminada y el usuario no tiene nada guardado.
- **Si se retira una columna del catálogo**: se ignora al leer (la clave desconocida se descarta).
- **Usar una vista compartida y tocarle columnas** la convierte en disposición propia del usuario; la
  vista compartida no cambia. Sólo el autor puede sobrescribirla.

### 2.5 Interfaz

Botón **«Columnas»** (`fa-columns`) en la barra de botones de cada lista, junto a Excel/Nuevo. Abre
un `offcanvas` lateral (Bootstrap ya cargado) con:

```
┌ Columnas ─────────────────────────────┐
│ Vista: [ Mi disposición        ▾ ]     │   ← predeterminada · mis vistas · compartidas
│                                        │
│ ☰ ☑ Estado                             │   ← arrastrar ☰ para ordenar (Sortable)
│ ☰ ☑ Código                             │
│ ☰ ☐ Código externo                     │
│ ☰ ☑ Descripción                        │
│ …                                      │
│ [Mostrar todas] [Restablecer]          │
│ ────────────────────────────────────── │
│ [Aplicar]   [Guardar como vista…]      │
│             ☐ Compartir con la empresa │
└────────────────────────────────────────┘
```

- **Aplicar**: repinta la tabla al momento (sin volver a pedir datos) y guarda la preferencia.
- **Guardar como vista…**: pide nombre; con la casilla marcada (si el rol tiene el control) la
  comparte. En el selector, las vistas compartidas muestran autor y un icono `fa-users`.
- Las vistas propias tienen **Renombrar / Eliminar / Dejar de compartir** en un menú `⋯`.
- La tabla repinta `<thead>` y `<tbody>` desde la disposición: un solo sitio define cada columna.

### 2.6 Endpoints (controlador nuevo `Gestion/VistaListaController`)

| Método | Ruta | Uso |
|---|---|---|
| GET | `/Gestion/VistaLista/Obtener?lista=` | preferencia activa + vistas propias + compartidas |
| POST | `/Gestion/VistaLista/Preferencia` | guarda la preferencia (vista elegida o disposición propia) |
| POST | `/Gestion/VistaLista/Guardar` | crea o sobrescribe una vista propia (nombre, columnas, compartida) |
| POST | `/Gestion/VistaLista/Eliminar` | elimina una vista propia |

- **Permisos**: no se registran páginas nuevas. Cada acción se protege con el acceso a la lista
  correspondiente (`Aviso/MisAvisos`, `Aviso/Index`, `OrdenTrabajo/Index`) según el valor de `lista`,
  comprobado en el propio controlador, porque `[FiltroAccion(Accion = …)]` es estático y aquí la
  página depende del parámetro.
- **Compartir** exige el control `Vista.Compartir` (`ExigeElementoAttribute`), que se registra en el
  catálogo de elementos. Mientras nadie lo dé de alta, el modo de sólo registro de SG-16 deja pasar.
- **Validación**: la lista existe; cada clave pertenece al catálogo de esa lista; sin claves
  repetidas; al menos una visible; nombre obligatorio, máx. 80; sólo el autor modifica o elimina; una
  vista compartida sólo es visible dentro de su `empresaid`.

---

## 3. Catálogo de columnas propuesto

Negrita = visible en la predeterminada (las de hoy). El resto, nuevas y ocultas por defecto; todas
salen de datos que el endpoint **ya devuelve**.

### 3.1 Avisos (Mis avisos y Todos)

**Tipo · Registro · Estado · Prioridad · Código · Descripción · Ubicación · Equipo** ·
**Usuario**¹ · **Inicio parada**¹ · **Fin parada**¹ · Método de detección · Sistema · Parte · Orden de
trabajo (código) · Fecha del evento · Tiene parada · Tiempo de parada · Comentario · Motivo

¹ Visibles por defecto sólo en *Todos los avisos*, como hoy; en *Mis avisos* existen pero ocultas.

### 3.2 Órdenes de trabajo

**Estado · Registro · Código · Código ext. · Descripción · Equipo · Ubicación · Código plan · Tipo
mtto. · UMS · Valor lanzamiento · Taller responsable · Inicio prog. · Inicio ejec. · Fin ejec. ·
Duración mtto.** · Prioridad · Centro de costo · Cuenta contable · Aviso (código) · OT padre · Usuario ·
Fin programado · Valor lanz. plan · Valor posición plan · Valor ejecución · Fecha lanzamiento · Avance
de tareas (%) · Detenido · Liberado

> Antes de cerrar el catálogo se revisa en el JSON real que cada propiedad llega serializada (la
> lista devuelve entidades, no DTO; una referencia circular o un `[JsonIgnore]` dejaría una columna
> vacía).

---

## 4. Fases y pasos

### Fase 0 – Preparar las vistas sin cambiar nada visible
- [x] **0.1** Crear `wwwroot/js/columnas.js` (cargado en `_Layout`, junto a `helper.js`) con
      `helper.columnas`: `pintarCabecera(tabla, columnas, disposicion)`,
      `pintarFila(item, columnas, disposicion, ctx)`, `fusionar(catalogo, guardada)` (aplica 2.4) y
      `predeterminada(catalogo)`.
- [x] **0.2** `OrdenTrabajo/Index.cshtml`: definir `COLUMNAS = [{ clave, titulo, ancho, clase,
      render(item, ctx), visible }]` con las 16 columnas de hoy; `GenerarTabla` y el `<thead>` pasan
      a salir de ahí. El `<thead>` del HTML queda sólo con ACCIONES y #.
- [x] **0.3** Lo mismo en `Aviso/Index.cshtml` (12 columnas) y `Aviso/MisAvisos.cshtml` (8).
- [x] **0.4** Verificar en las tres: misma tabla, mismas clases (`emitido`, `texto-largo`,
      `codigo-ref`), paginación, «sin resultados» y escape de HTML (`helper.html.escape`) intactos.
      *Esta fase se puede publicar sola: no cambia nada para el usuario.*

### Fase 1 – Selección y orden en el navegador (sin guardar)
- [x] **1.1** Partial `Views/Shared/_ConfigurarColumnas.cshtml` con el `offcanvas` de 2.5 (sin la
      parte de vistas guardadas todavía).
- [x] **1.2** `helper.columnas.abrirEditor(...)`: lista con casillas + `Sortable.create` con asa ☰;
      «Mostrar todas», «Restablecer», «Aplicar». Mínimo una columna visible.
- [x] **1.3** Botón «Columnas» en las tres vistas; «Aplicar» repinta con los datos ya cargados.
- [x] **1.4** Añadir las columnas nuevas de la sección 3, ocultas por defecto.
- [ ] **1.5** Verificar en móvil: el `offcanvas` ocupa el ancho, el arrastre funciona al tacto.

### Fase 2 – Guardar la preferencia por usuario
- [x] **2.1** Enum `ListaConfigurable` y entidades `VistaLista` y `UsuarioLista` en
      `AMSYS.Entidades/Usuarios/Genericos` (junto a `IndicadorGrupo`).
- [x] **2.2** Configuraciones EF en `AMSYS.Configuraciones/Usuarios` (`jsonb`, índice único,
      `ON DELETE SET NULL`) y `DbSet` en `AMSYSContexto`.
- [x] **2.3** Migración `VistaLista_Crear`; revisar el SQL generado antes de aplicarlo.
- [x] **2.4** `CatalogoColumnas` (C#): claves válidas por lista, para validar.
- [x] **2.5** Repositorio → Lógica → Servicio siguiendo la cadena existente
      (`*.Repositorio.cs`, `*.Logica.cs`, `AMSYS.Servicios`).
- [x] **2.6** `VistaListaController` con `Obtener` y `Preferencia` + comprobación de acceso a la
      lista según `lista`.
- [x] **2.7** Las tres vistas leen la preferencia al cargar (antes del primer `Listar`, para no
      pintar dos veces) y la guardan al «Aplicar».
- [ ] **2.8** Verificar: dos usuarios con disposiciones distintas; cerrar sesión y volver; otro
      navegador; clave inventada enviada a mano → 400.

### Fase 3 – Vistas con nombre y compartidas
- [x] **3.1** `Guardar` y `Eliminar` en el controlador, con las reglas de autor y de empresa.
- [x] **3.2** Selector de vista en el `offcanvas`: Predeterminada · Mis vistas · Compartidas
      (con autor). Menú `⋯` en las propias: renombrar, eliminar, compartir/dejar de compartir.
- [x] ~~**3.3**~~ *Descartado por `DC-01`: cualquiera comparte; se guarda quién y cuándo (`compartidoporid`, `compartido`).* Registrar el control `Vista.Compartir` en el catálogo de elementos y protegerlo con
      `ExigeElementoAttribute`; ocultar la casilla «Compartir» a quien no lo tenga
      (`ElementoHtmlExtensiones`).
- [x] **3.4** Aplicar 2.4: vista borrada o descompartida → el usuario que la usaba vuelve a la
      predeterminada, con un aviso discreto la primera vez.
- [ ] **3.5** Verificar: usuario A comparte, B la usa; A la cambia y B ve el cambio; B la toca y pasa
      a disposición propia sin afectar a A; A la borra y B cae a la predeterminada; un usuario de otra
      empresa no la ve; B no puede borrarla ni sobrescribirla por POST directo.

### Fase 4 – Opcional: Excel con las columnas de la vista (según `DC-04`)
- [x] **4.1** `ExportarExcel` recibe la disposición activa y genera la hoja con esas columnas en ese
      orden (la plantilla `formato*Exportar.xlsx` deja de fijar las columnas: se usa sólo para
      cabecera y estilos).
- [x] **4.2** Verificar que el Excel sin disposición sigue siendo idéntico al actual.

---

## 5. Riesgos

| Riesgo | Mitigación |
|---|---|
| Romper el pintado de las tablas al refactorizar | Fase 0 aislada y publicable sola, comparando con la versión actual antes de seguir. |
| Columnas nuevas vacías porque el JSON no trae el dato | Revisión del JSON real antes de fijar el catálogo (sección 3). |
| Las listas pesan más si se añaden `Include` | El catálogo propuesto sólo usa lo que ya se incluye; ninguna columna nueva añade consultas. |
| Vista compartida que se queda huérfana | `ON DELETE SET NULL` + caída a la predeterminada. |
| Disposición guardada con claves basura | Validación contra `CatalogoColumnas` en servidor y `fusionar` tolerante en cliente. |
| Se ve la tabla vieja y luego se repinta | Leer la preferencia antes del primer `Listar` (paso 2.7). |

---

## 6. Estimación orientativa

| Fase | Esfuerzo |
|---|---|
| 0 – Refactor a catálogo de columnas | 1 día |
| 1 – Editor de columnas | 1–1,5 días |
| 2 – Preferencia por usuario (BD + endpoints) | 1,5 días |
| 3 – Vistas compartidas | 1,5 días |
| 4 – Excel (opcional) | 1 día |

---

## 7. Decisiones (resueltas el 2026-10-15)

| Id | Pregunta | Decisión |
|---|---|---|
| `DC-01` | ¿Quién puede compartir vistas? | **Cualquier usuario**, guardando quién la compartió y cuándo (`compartidoporid`, `compartido`). Sólo el autor la modifica, la deja de compartir o la elimina. |
| `DC-02` | ¿Alcance de una vista compartida? | **Toda la empresa.** |
| `DC-03` | ¿Mis avisos y Todos los avisos comparten vistas? | **No**: cada lista tiene las suyas. |
| `DC-04` | ¿El Excel respeta las columnas de la vista? | **Sí.** Con la disposición predeterminada sigue saliendo el Excel de siempre. |
| `DC-05` | ¿Vista predeterminada de empresa fijada por un administrador? | No en esta entrega (propuesta aceptada por omisión). |
| `DC-06` | ¿Se guarda el tamaño de página? | Sí (propuesta aceptada por omisión). El elegido a mano manda sobre el de la vista. |

### Ajustes respecto al diseño original
- **El catálogo vive en C#** (`AMSYS.Entidades/Usuarios/CatalogoColumnas.cs`): claves, títulos y
  columnas por defecto. La vista lo recibe en `ViewBag.ConfiguracionLista` (sin petición extra ni
  repintado) y sólo define cómo se pinta cada clave (`_ColumnasAviso.cshtml`, `COLUMNAS_OT`).
- **Permisos**: `VistaListaController` lleva `[SinAutorizacion]` porque `FiltroAutorizacion` le
  exigiría `/Gestion/VistaLista/Index`, que nadie tiene; cada acción comprueba en su lugar la página
  de la lista pedida (respetando `AutorizacionSoloRegistra`).
- **Borrado en cascada**: el contexto convierte todo `Cascade` en `Restrict` (región
  *Modificaciones*); se respeta. Lo importante se mantiene: `usuariolista.vistalistaid` es
  `ON DELETE SET NULL`.
- **Columna «Tiempo de parada»** retirada del catálogo: es un método (`ObtenerTiempoParada`), no
  llega en el JSON.
- **Excel de avisos con columnas**: incluye sólo columnas del catálogo; las de confiabilidad (modo,
  mecanismo, causa de falla, impacto) siguen saliendo únicamente en el Excel predeterminado.
- **Migración**: `20261016021938_VistaLista_Crear` aplicada el 2026-10-15 en `amsys_v3_demo` de 10.2.1.2 (Development). No aplicada en `localhost`.

---

## 8. Extensión futura (no incluida)

El diseño es genérico: llevar esto a otra lista es añadir un valor a `ListaConfigurable`, su
`CatalogoColumnas` y convertir su `GenerarTabla` al catálogo de columnas. Candidatas naturales:
Equipos, Ubicaciones, Planes de mantenimiento, Notas de entrada/salida.

---

## Registro de avance

| Fecha | Paso | Nota |
|---|---|---|
| 2026-10-15 | — | Plan redactado. Pendiente resolver `DC-01` … `DC-06`. |
| 2026-10-15 | 0.1 – 4.2 | Implementado. Compila (vistas incluidas). Migración creada sin aplicar. Pruebas sin BD: 28 comprobaciones del JS en jsdom (pintado, editor, vistas propias/compartidas, Excel, tamaño) y 22 del servidor (catálogo, validación, JSON, Excel con la plantilla real). Pendiente con BD aplicada: 1.5, 2.8 y 3.5. |
| 2026-10-15 | 2.3 | Migración aplicada en 10.2.1.2 (`amsys_v3_demo`, Development); era la única pendiente. |
