# Plan de mejora – Módulo de Seguridad

> Documento **ejecutable paso a paso**, con la misma mecánica que `PLAN-UX-PLANMANTENIMIENTO.md`,
> `PLAN-UX-HOJARUTA-SECCION.md`, `PLAN-UX-EQUIPO-UBICACION.md`, `PLAN-UX-ADMINISTRACION.md` y
> `PLAN-UX-LOGISTICA.md`: cada paso es pequeño, verificable y reversible por sí solo. Marca la casilla
> al terminarlo y anótalo en el *Registro de avance* del final.

- **Alcance**: el área `Areas/Seguridad` completa — 7 controladores: **Usuario** (usuarios de la
  empresa y usuarios de toda la instalación), **Rol** (menús, páginas, elementos y estados),
  **Empresa** (plan y límites), **Renovación** (licencia), **Organización** (jerarquía y alcance del
  usuario), **Página** (catálogo de rutas protegidas) y **Menú** (árbol de navegación); más sus
  lógicas y repositorios, el inicio de sesión y el perfil propio (`AccountController`) y los dos
  filtros que sostienen todo el sistema (`FiltroSession`, `FiltroAccion`).
- **Incluye la tarea aplazada en `DA-04`**: los POST de todos los módulos no comprueban permisos. Se
  resuelve aquí porque el arreglo es del área de Seguridad, no de cada catálogo.
- **Fuera de alcance**: `FiltroToken` y la autorización de la API móvil (`AMSYS.Servicios`,
  `AMSYS.WebAPI`) salvo lo que comparte el hash de contraseña; CSRF (`MNT-035`); el `AMSYS.DemonApp`
  (script de importación de usuarios); y las pantallas de los demás módulos, que sólo se tocan para
  registrar sus páginas y elementos.
- **Fecha**: 2026-09-19 · **Decisiones `DS-01` … `DS-08` resueltas el 2026-09-19** (sección 7)
- **Relación con `/ai`**: continúa `analysis/permissions.md` (matriz de protección real) y reutiliza
  lo construido en Administración y Logística (`helper.catalogo`, `helper.filtros`,
  `RespuestaValidacion`, `IUsoCatalogo`, `.barra-acciones`, `.tabla-apilable`).

---

## 1. Qué es el módulo y qué tiene que transmitir

Seguridad decide **quién entra, qué ve y qué puede hacer** en una instalación multiempresa:

```
Empresa ──► Limitación (cuántos usuarios por perfil, cuánto almacenamiento)
        └─► Renovación ──► Vencimiento  ──► el login rechaza la empresa caducada
        └─► Organización (árbol) ──► UsuarioOrganizacion ──► qué parte de la planta ve el usuario

Rol ──┬─► RolMenu     ──► qué entradas de navegación ve
      ├─► RolPagina   ──► a qué /Area/Controlador/Accion puede entrar   ← lo que FiltroAccion comprueba
      ├─► RolElemento ──► qué botones ve dentro de una página           ← hoy no lo lee ninguna vista
      ├─► RolEstadoOrdenTrabajo / RolEstadoAviso ──► a qué estados puede mover una OT o un aviso
      └─► Perfil (ADMINISTRADOR · MANTENIMIENTO · OPERADOR · CLIENTE) ──► cuenta contra el límite

Usuario ──► Rol (uno solo) ──► sus permisos se copian a la sesión AL INICIAR SESIÓN
```

La interfaz tiene que responder a tres preguntas que hoy no responde: **¿qué puede hacer realmente
este rol?**, **¿a quién afecta si lo cambio?** y **¿desde cuándo tiene efecto?**

Hechos verificados que condicionan el diseño:

| Hecho | Evidencia | Consecuencia |
|-------|-----------|--------------|
| **Ningún POST del área tiene `[FiltroAccion]`**, y `Pagina` y `Renovacion` no lo tienen en ninguna acción | `Usuario`, `Rol`, `Empresa`, `Organizacion`, `Menu`, `Pagina`, `Renovacion` (`[HttpPost]`); `Pagina.Controller.cs:23,25,50,82`; `Renovacion.Controller.cs:28,36` | Cualquier usuario autenticado —un operador, un cliente— puede **crear un usuario en cualquier empresa con cualquier rol** (`POST /Seguridad/Usuario/NuevoAdmin`), **cambiar la empresa, el rol y la clave de cualquier usuario** (`POST …/EditarAdmin`), editar cualquier rol, editar el catálogo de páginas y renovar la licencia de cualquier empresa. Es una escalada de privilegios completa |
| `UsuarioLogica.ActualizarAsync` busca el usuario **sólo por `Id`** | `Usuario.Logica.cs:14` | `POST /Seguridad/Usuario/Editar` con el id de un usuario de otra empresa le cambia nombre, correo, clave y estado, y le asigna organizaciones ajenas |
| `Usuario.Listar` no filtra por empresa | `Usuario.Controller.cs:245` (`ListarMisUsuarios` sí lo hace) | Devuelve los usuarios de **todas** las empresas |
| Las listas de usuarios serializan la entidad completa: `Clave`, `TokenWeb`, `TokenMovil` | `Usuario.Controller.cs:238,250` (`Ok(new { lista, total })` sobre `List<Usuario>`), sin `[JsonIgnore]` en `Usuario.cs` | El hash de la contraseña y los tokens de sesión de todos los compañeros viajan al navegador de cualquier usuario |
| La contraseña se guarda como **HMAC-SHA256 con una clave fija escrita en el código**, sin sal por usuario | `CriptografiaUtilitario.ToSHA526` (`_CryptoKey`) | Dos usuarios con la misma contraseña tienen el mismo hash; con el repositorio a la vista, el ataque por diccionario es inmediato. No hay derivación lenta |
| El token de sesión es el hash de la fecha y la hora | `AccountController.cs:64-65` (`ToSHA526(ahora.ToString("yyyyMMddHHmmss"))`) | Es predecible y dos inicios de sesión en el mismo segundo obtienen el mismo token |
| `ValidarToken` no comprueba `Activo` ni `Usuario.Vencimiento` | `Usuario.Logica.cs:133-139`; `Vencimiento` no se usa en ningún sitio | **Desactivar un usuario no lo expulsa**: sigue trabajando hasta que cierre sesión |
| Los permisos se copian a la sesión **una sola vez, al iniciar sesión** | `AccountController.cs:79-83`, `FiltroAccion.cs:16` | Quitar un permiso no surte efecto hasta que el usuario vuelve a entrar, y la pantalla no lo advierte en ningún momento |
| La pestaña *Estados* del rol está oculta y en el alta **nace con todas las casillas marcadas** | `Rol/Nuevo.cshtml:64` y `Rol/Editar.cshtml:62` (`hidden="hidden"`), casillas con `checked` fijo en el alta | Todo rol nuevo puede mover una OT y un aviso a **cualquier** estado, sin que nadie lo haya decidido ni pueda verlo |
| `RolLogica.ActualizarAsync` sólo escribe `Nombre` y `Activo`; `RolModel.Editar` no lleva `Perfil` | `Rol.Logica.cs:63-64`, `Rol.Model.cs` (clase `Editar`), `Rol/Editar.cshtml` (campo `readonly`) | **El perfil de un rol no se puede corregir nunca**, y el perfil es lo que decide el límite de usuarios contratado |
| `Rol` no tiene `EmpresaId` | `Rol.cs` | Los roles son globales: el rol que crea una empresa aparece en el desplegable de todas las demás → `DS-02` |
| Los permisos a nivel de **elemento** no se pueden configurar ni se leen | `RolModel.*.ElementoIds` nunca se envía (columna *CONTROLES* vacía en `Rol/Nuevo.cshtml:101`); `ViewBag.Elements` que rellena `FiltroAccion.cs:33` no aparece en ninguna vista | Función muerta que ocupa la mitad del editor de roles → `DS-06` |
| Menú y página se conceden por separado y nada comprueba la coherencia | `RolMenu` y `RolPagina` son independientes | Dar el menú sin la página produce un 401 al hacer clic; dar la página sin el menú deja la pantalla accesible sólo escribiendo la URL |
| `EmpresaLogica.ActualizarAsync` guarda `Nombre` y los límites, pero **descarta `TipoPlan`** | `Empresa.Logica.cs:72-74` (nunca asigna `_.TipoPlan`) | El desplegable *Plan* de la ficha de empresa no hace nada |
| El formulario de empresa no envía los cuatro límites por perfil, y la lógica los escribe como `?? 0` | `Empresa/Editar.cshtml:105-113` (envía `cantidadUsuario`, `cantidadAlmacenamiento` y un inexistente `cantidadEquipo`), `Empresa.Logica.cs:51-54` | **Cada vez que se guarda una empresa, sus límites de administradores, mantenimiento, operadores y clientes vuelven a 0** |
| `PuedeAgregarUsuario` se llama sin perfil y sólo al **abrir** el modal | `Usuario.Controller.cs:130`; el `POST Nuevo` no lo comprueba | Cuenta los usuarios cuyo rol tiene `Perfil` nulo contra `CantidadUsuario`, ignora el perfil del rol que se va a asignar, y el límite se salta enviando el POST directamente. Además `Empresa.Logica.cs:114` revienta con `NullReferenceException` si la empresa no tiene fila de límites |
| `LoginAsync` busca por correo con `SingleOrDefaultAsync` y sin empresa | `Usuario.Repositorio.cs:17-22` | Dos usuarios con el mismo correo en empresas distintas hacen **fallar el inicio de sesión con un error 500** |
| No existe ninguna forma de recuperar la contraseña | `AccountController` (`GetPassword()` es código muerto, con nueve `Thread.Sleep(100)`) | Toda contraseña olvidada pasa por un administrador, que además puede fijarla a mano y conocerla |
| El `callBack` llega por la URL y se escribe dentro de un `<script>` sin validar | `Usuario`, `Organizacion`, `Menu`, `Pagina`, `Empresa` y `Renovacion` (`ViewBag.CallBack` → `@string.Format("{0}(result)", callBack)`) | XSS reflejado; Administración ya lo resolvió con `RespuestaValidacion.CallBack` |
| Las 7 listas interpolan los datos en HTML sin escapar | `${nombre}`, `${correo}`, `${rol.nombre}`, `${empresa.nombre}` en los `Index` y en `Usuario/Todos` | XSS almacenado, precisamente en las pantallas que abre un administrador |
| `$('#btnGuadar')` (sin la *r*) en tres vistas | `Rol/Nuevo.cshtml:253`, `Rol/Editar.cshtml:255`, `Empresa/Editar.cshtml:166` | Si el guardado falla, el botón **queda deshabilitado para siempre**: hay que recargar la página |
| El árbol de menús y el de organizaciones llevan el plugin `dnd` sin guardar nada | `Menu/Index.cshtml:69`, `Usuario/_Nuevo.cshtml:101`, `Usuario/_Editar.cshtml:106` | Se pueden arrastrar nodos y el cambio se pierde al recargar, sin aviso |
| `FiltroAccion` se salta el control en los controladores `Home` y `Account` | `FiltroAccion.cs:26` | Decisión no documentada; hay que confirmarla o acotarla |

## 2. Pantallas afectadas

| Pantalla | Archivos | Patrón actual |
|----------|----------|---------------|
| Usuarios de la empresa | `Usuario/{Index,_Nuevo,_Editar}` | Lista antigua + modal con árbol de organizaciones; el rol se muestra **de sólo lectura** |
| Usuarios de la instalación | `Usuario/{Todos,_NuevoAdmin,_EditarAdmin}` | Ídem, con empresa y rol; sin `[FiltroAccion]` en `NuevoAdmin` |
| Roles | `Rol/{Index,Nuevo,Editar}` | Pantalla completa: cabecera + pestañas *Menus* (árbol) y *Páginas* (rutas crudas); *Estados* oculta |
| Empresas | `Empresa/{Index,_Nuevo,Editar}` | Lista con el nombre y nada más; ficha con plan, límites y renovaciones |
| Renovaciones | `Renovacion/_Nuevo` | Modal abierto desde la ficha de empresa |
| Organizaciones | `Organizacion/{Index,_Nuevo,_Editar}` | Lista **plana** con columna *Padre*; el árbol sólo existe dentro del modal de usuario |
| Páginas | `Pagina/{Index,_Nuevo,_Editar}` | Catálogo de rutas `Area/Controlador/Accion` escritas a mano |
| Menús | `Menu/{Index,_Nuevo,_Editar}` | Árbol jstree con *Nuevo* y *Editar*; sin eliminar ni reordenar |
| Inicio de sesión y perfil | `Controllers/AccountController`, `Views/Account/{Login,Perfil}` | Login sin recuperación; perfil con nombre, foto y clave |

## 3. Diagnóstico corto

1. **🔴 Escalada de privilegios total**: sin `[FiltroAccion]` en los POST, cualquier usuario
   autenticado se concede el rol que quiera, en la empresa que quiera.
2. **🔴 Fuga de credenciales**: las listas de usuarios devuelven el hash de la contraseña y los
   tokens de sesión.
3. **🔴 Datos de otras empresas**: editar usuarios y organizaciones sólo comprueba el `Id`.
4. **🔴 Almacenamiento de contraseñas obsoleto**: HMAC con clave en el código, sin sal ni derivación
   lenta, y sin ninguna política ni forma de recuperación.
5. **🔴 Sesión que no se puede revocar**: desactivar un usuario o quitarle un permiso no tiene efecto
   hasta que vuelve a entrar, y nada lo advierte.
6. **🔴 Configuración que se pierde al guardar**: los límites por perfil vuelven a 0 en cada edición
   de empresa y el plan elegido se descarta.
7. **Permisos incomprensibles**: se conceden por ruta cruda (`/Gestion/OrdenTrabajo/Notificar`), en
   una lista plana sin buscador ni agrupación, separados del menú, con una columna vacía y una
   pestaña oculta que además concede todos los estados por defecto.
8. **Consecuencias invisibles**: guardar un rol no dice a cuántos usuarios afecta; desactivar una
   organización no dice qué deja sin alcance; el límite de usuarios sólo aparece al abrir el modal.
9. **Listas y formularios en el patrón antiguo**: filtros en el `<thead>`, sin escapado, sin estado
   de carga, errores agrupados, `callBack` sin validar, botón que se queda deshabilitado, cabeceras
   `bg-primary` y *Regresar* en ámbar.

## 4. Principios

- Los de los planes anteriores y **lo ya construido en Administración y Logística**:
  `helper.catalogo.lista` / `modal`, `helper.filtros` con chips, `RespuestaValidacion`,
  `IUsoCatalogo`, `.barra-acciones`, `.tabla-apilable`, convención de color.
- **El servidor decide, la pantalla sólo acompaña.** Ocultar un botón no es un permiso: toda acción
  que escribe comprueba permiso, empresa y pertenencia.
- **Ningún secreto sale del servidor.** Ni hashes, ni tokens, ni claves: las listas devuelven
  proyecciones explícitas, nunca la entidad.
- **Un permiso se concede en el idioma del negocio**, no en el de las rutas: *Puede notificar una
  orden de trabajo*, no `/Gestion/OrdenTrabajo/Notificar`.
- **Lo que cambia un permiso se dice antes de guardarlo**: a cuántos usuarios afecta y desde cuándo.
- **Todo cambio de seguridad deja rastro**: quién, cuándo, sobre quién.
- Un paso = un commit.

---

## 5. Pasos

### FASE 0 — Lo que hoy permite tomar el control del sistema

#### [x] SG-01 · Autorización en todas las escrituras del sistema

- **Hoy**: `[FiltroAccion]` sólo está en algunos GET. Ningún POST de Seguridad, Administración,
  Gestión o Logística comprueba permisos (`analysis/permissions.md` SEC-01, `DA-04`).
- **Archivos**: `Commons/Session/FiltroAccion.cs` y **todos** los controladores de la aplicación
  (`Seguridad`, `Administracion`, `Gestion`, `GestionActivo`, `Logistica`, `Reporte`) — `DS-01`.
- **Hacer**:
  - Invertir el modelo (`DS-01`): autorización **por defecto** para toda acción, declarada una vez
    (filtro global o `[FiltroAccion]` a nivel de clase), y las excepciones marcadas explícitamente
    con un atributo de exclusión que obligue a justificarlas. Una acción nueva nace protegida.
  - Inventariar y declarar las excepciones actuales: `Account` y `Home` (`FiltroAccion.cs:26`), las
    páginas de error y los selectores compartidos que hoy no están en el catálogo de páginas.
  - Que el POST se compruebe contra la **página de su formulario** (`Nuevo`, `Editar`), no contra una
    página inexistente; el atributo ya admite `Accion = "Nuevo"`.
  - Responder 403 con un mensaje entendible (hoy un 401 sin cuerpo en las peticiones normales).
  - Registrar en el catálogo de páginas las acciones que hoy no existen en él.
- **Aceptación**:
  - [ ] Un usuario sin el permiso de una pantalla recibe 403 al enviar su POST, no un 200.
  - [ ] Ninguna acción que escribe queda sin comprobación (inventario en `analysis/permissions.md`).
- **Esfuerzo** L · **Riesgo** ALTO (puede dejar sin acceso a usuarios legítimos: desplegar con el
  inventario de páginas ya cargado y revisar rol por rol) · **Ref.** `DA-04`, `MNT-034`

#### [x] SG-02 · Separar lo que es de la instalación de lo que es de la empresa

- **Hoy**: `Usuario/Todos`, `NuevoAdmin`, `EditarAdmin`, `Empresa`, `Renovacion`, `Pagina` y `Menu`
  administran **toda la instalación**, pero se protegen con el mismo mecanismo que una pantalla
  cualquiera, y `NuevoAdmin` (GET y POST) no se protege en absoluto.
- **Hacer** (`DS-03`: **un rol reservado por nombre** identifica al administrador de la instalación):
  - Definir el nombre reservado en configuración (`AppSettings`), no escrito en el código, y
    resolverlo una sola vez: `UserInformation.EsDeInstalacion`.
  - Exigirlo, además del permiso de página, en `Usuario/{Todos,NuevoAdmin,EditarAdmin}`, `Empresa`,
    `Renovacion`, `Pagina`, `Menu` y —por `DS-02`— en **todas** las acciones de `Rol`, que pasan a
    ser de instalación porque los roles son globales.
  - `EditarAdmin` sólo puede cambiar la empresa de un usuario si quien lo hace es de instalación.
  - **Proteger el rol reservado**, porque identificar por nombre es frágil: no se puede renombrar,
    desactivar, ni quedarse sin usuarios activos; el editor de roles lo impide y lo señala. Si el
    nombre configurado no corresponde a ningún rol, la aplicación lo registra como error al arrancar
    en lugar de dejar las pantallas de instalación abiertas o cerradas sin explicación.
  - Separar visualmente las dos zonas en la navegación: *Mi empresa* y *Administración del sistema*.
- **Aceptación**:
  - [ ] Un administrador de empresa no puede listar, crear ni editar usuarios de otra empresa, ni
    entrar en Roles, Empresas, Páginas o Menús, ni por pantalla ni por POST directo.
  - [ ] No se puede renombrar ni desactivar el rol reservado, ni dejarlo sin ningún usuario activo.
- **Esfuerzo** M · **Riesgo** MEDIO (quien no tenga el rol reservado pierde el acceso a esas
  pantallas: confirmar antes quién debe tenerlo)

#### [x] SG-03 · Empresa en todas las lecturas y escrituras

- **Hoy**: `UsuarioLogica.ActualizarAsync` y `OrganizacionLogica.{BuscarPorIdAsync,ActualizarAsync}`
  buscan sólo por `Id`; `Usuario.Listar` no filtra por empresa; `Empresa.Editar` y
  `Renovacion.Nuevo` aceptan cualquier `EmpresaId`.
- **Hacer**:
  - Añadir `EmpresaId` a la búsqueda de todas las actualizaciones y a `Usuario.Listar`.
  - Devolver `RespuestaValidacion.NoEncontrado` cuando el registro no es de la empresa, en lugar de
    responder éxito sin guardar nada.
  - Comprobar que el `RolId` que se asigna existe y está activo (por `DS-02` los roles son globales,
    así que no se filtran por empresa) y que las `OrganizacionIds` son de la empresa del usuario
    editado.
- **Aceptación**:
  - [ ] Un POST con el id de un usuario o una organización de otra empresa devuelve «No se encontró el
    registro» y no modifica nada.
- **Esfuerzo** M · **Riesgo** BAJO · **Ref.** `MNT-021`, `MNT-022`, AD-02, LG-02

#### [x] SG-04 · Las listas dejan de devolver secretos

- **Hoy**: `ListarMisUsuarios` y `Listar` serializan `Usuario` completo: `Clave`, `TokenWeb`,
  `TokenMovil`, `Empresa` y `Empleado` anidados.
- **Hacer**:
  - Proyección explícita en los dos endpoints: `id`, `nombre`, `correo`, `activo`, `rol.nombre`,
    `empresa.nombre` y lo que la lista muestre de verdad.
  - `[JsonIgnore]` en `Clave`, `TokenWeb` y `TokenMovil` como segunda barrera, y repasar el resto de
    endpoints que devuelven `Usuario` (perfil, selectores, API).
- **Aceptación**:
  - [ ] La respuesta de las dos listas no contiene `clave`, `tokenWeb` ni `tokenMovil`.
- **Esfuerzo** S · **Riesgo** BAJO · **Prioridad**: alta, es un cambio de dos líneas

#### [x] SG-05 · `callBack` validado y datos escapados

- **Hoy**: seis controladores escriben el `callBack` de la URL dentro de un `<script>`; las siete
  listas interpolan nombres y correos sin escapar.
- **Hacer**: `RespuestaValidacion.CallBack` en `Usuario`, `Organizacion`, `Menu`, `Pagina`, `Empresa`
  y `Renovacion`; `helper.html.escape` en todas las celdas generadas.
- **Aceptación**:
  - [ ] Un usuario llamado `<img src=x onerror=alert(1)>` aparece como texto en las tres listas donde
    se ve.
  - [ ] `?callBack=alert(1)//` no ejecuta nada.
- **Esfuerzo** S · **Riesgo** BAJO · **Ref.** AD-05, AD-06

#### [x] SG-06 · El límite de usuarios cuenta bien y se comprueba al guardar

- **Hoy**: `PuedeAgregarUsuario(empresaId)` se llama sin perfil y sólo al abrir el modal; cuenta los
  usuarios cuyo rol tiene `Perfil` nulo; revienta si la empresa no tiene fila de límites.
- **Hacer**:
  - Recibir el `RolId` elegido, resolver su `Perfil` y contar contra el límite de **ese** perfil.
  - Comprobarlo también en el `POST Nuevo` y al **activar** un usuario desactivado.
  - Tratar la ausencia de `Limitacion` como límite cero, con mensaje, en lugar de excepción.
  - Mostrar el consumo en la pantalla: «Administradores 3 de 5» junto al desplegable de rol, y
    deshabilitar los roles cuyo perfil ya está al límite explicando por qué.
- **Aceptación**:
  - [x] Con el límite de operadores agotado, el alta de un operador se rechaza también por POST
    directo, y el modal lo dice antes de rellenar el formulario.
- **Esfuerzo** M · **Riesgo** MEDIO (puede bloquear altas que hoy pasan: revisar antes los límites
  reales de cada empresa)

#### [x] SG-07 · Guardar una empresa deja de borrar su configuración

- **Hoy**: el formulario no envía los límites por perfil y `ActualizarAsync` los escribe como `?? 0`;
  `TipoPlan` se envía y se descarta; el formulario manda un `cantidadEquipo` que no existe.
- **Hacer**:
  - Añadir al formulario y al modelo los cuatro límites por perfil (administradores, mantenimiento,
    operadores, clientes), con el consumo actual al lado de cada uno.
  - Guardar `TipoPlan`, que hoy se envía y se descarta. El **vencimiento** no se toca aquí: lo
    lleva la renovación de la licencia.
  - Quitar `cantidadEquipo`.
  - Diagnóstico previo: listar las empresas cuyos límites por perfil están a 0 para restaurarlos.
- **Aceptación**:
  - [ ] Guardar la ficha de una empresa sin tocar nada deja exactamente los mismos límites y el mismo
    plan.
- **Esfuerzo** S · **Riesgo** MEDIO (hay datos ya corrompidos; entregar el informe antes del cambio)

---

### FASE 1 — Credenciales y sesión

#### [x] SG-08 · Contraseñas con sal y derivación lenta

- **Hoy**: `CriptografiaUtilitario.ToSHA526` = HMAC-SHA256 con una clave literal en el repositorio,
  igual para todos los usuarios y todas las instalaciones.
- **Hacer** (`DS-04`: **PBKDF2 del propio .NET**, sin dependencias nuevas):
  - `Rfc2898DeriveBytes` con HMAC-SHA256, sal aleatoria de 16 bytes por usuario y un número de
    iteraciones configurable; guardar en el propio campo el formato, las iteraciones, la sal y el
    hash (`pbkdf2$sha256$<iteraciones>$<sal>$<hash>`), para poder subir el coste más adelante sin
    otra migración.
  - Comparación en tiempo constante (`CryptographicOperations.FixedTimeEquals`).
  - **Migración progresiva**: al iniciar sesión correctamente con el hash antiguo, volver a guardar la
    contraseña con el algoritmo nuevo. Sin pedir a nadie que la cambie.
  - Mantener `ToSHA526` sólo como verificador del formato antiguo, marcado como obsoleto, y revisar
    los otros puntos que lo usan (`AMSYS.DemonApp`, API móvil).
  - **No hace falta migración de esquema**: `usuario.clave` es `text`
    (`AMSYSContextoModelSnapshot.cs:4614-4617`), así que admite el formato nuevo, más largo.
- **Aceptación**:
  - [x] Dos usuarios con la misma contraseña tienen hashes distintos.
  - [x] Un usuario creado antes del cambio sigue entrando y su fila queda migrada tras la primera
    entrada.
- **Esfuerzo** M · **Riesgo** ALTO (si falla, nadie entra: probar el camino antiguo y el nuevo en un
  entorno de pruebas con datos reales antes de desplegar)

#### [x] SG-09 · Política de contraseña y formularios de credencial

- **Hoy**: los cuatro modales de usuario piden la clave en un único campo, sin confirmación, sin
  mínimo, sin mostrarla; el administrador la escribe y por tanto la conoce.
- **Hacer**:
  - Política de `DS-04`: **mínimo 8 caracteres, con al menos una mayúscula y un número**, comprobada
    en el **servidor** (los cuatro modales de usuario, el perfil propio y el restablecimiento) y con
    indicador en vivo en el formulario.
  - Confirmación de contraseña, botón *mostrar* y *generar una segura* en el alta.
  - En la edición, separar *Cambiar contraseña* del resto de los datos, con el campo vacío y la
    advertencia de que se cierran las demás sesiones del usuario.
  - Dejar explícito lo que hoy es implícito: **si el campo se deja vacío, la contraseña no cambia**
    (hoy depende de que el enlazador convierta la cadena vacía en nulo).
- **Aceptación**:
  - [x] Guardar la edición de un usuario sin tocar la clave no altera su hash.
  - [x] Una contraseña que no cumple la política se rechaza también por POST directo.
- **Esfuerzo** M · **Riesgo** BAJO

#### [x] SG-10 · Restablecer la contraseña desde la administración

- **Hoy**: no hay ninguna forma de recuperar la contraseña y el restablecimiento se hace escribiendo
  la clave nueva dentro del modal de edición del usuario. `GetPassword()` es código muerto.
- **Hacer** (`DS-05`: **sin autoservicio**; sólo un administrador restablece):
  - Acción explícita *Restablecer contraseña* en la ficha del usuario, separada de la edición de sus
    datos, que genera una contraseña aleatoria que cumpla la política de SG-09 y la muestra **una
    sola vez** para entregarla al usuario.
  - Marcarla como **temporal**: el usuario debe cambiarla en su primer acceso, de modo que el
    administrador deje de conocer la contraseña en uso.
  - Restablecer cierra las sesiones abiertas de ese usuario (SG-11) y deja rastro (SG-13).
  - La pantalla de inicio de sesión indica a quién dirigirse, en lugar de no decir nada.
  - Eliminar `GetPassword()` (código muerto, con nueve `Thread.Sleep(100)`).
- **Aceptación**:
  - [x] Tras un restablecimiento, el usuario entra con la contraseña entregada y el sistema le exige
    cambiarla antes de seguir.
  - [x] La contraseña generada no vuelve a mostrarse al recargar la pantalla.
- **Esfuerzo** M · **Riesgo** BAJO

#### [x] SG-11 · Sesión revocable y token impredecible

- **Hoy**: el token es el hash de la fecha y la hora; `ValidarToken` no mira `Activo` ni
  `Usuario.Vencimiento`; cambiar la contraseña no cierra las demás sesiones.
- **Hacer**:
  - Token aleatorio criptográfico (`RandomNumberGenerator`), distinto en cada inicio de sesión.
  - `ValidarToken` comprueba también `Activo`, `Usuario.Vencimiento` y el vencimiento de la empresa;
    si falla, cierra la sesión con el motivo en la pantalla de login.
  - Cambiar la contraseña, desactivar al usuario o cambiarle el rol renueva el token (`DS-08`).
  - Usar o retirar `Usuario.Vencimiento`: hoy está en la entidad y en la base, y no lo mira nadie.
  - Limitar los intentos de inicio de sesión (bloqueo temporal por correo y por origen).
- **Aceptación**:
  - [x] Desactivar a un usuario conectado lo deja fuera en la siguiente petición, con el motivo.
  - [x] Dos inicios de sesión en el mismo segundo obtienen tokens distintos.
- **Esfuerzo** M · **Riesgo** MEDIO (cierra sesiones en curso al desplegar)

#### [x] SG-12 · Los cambios de permiso surten efecto

- **Hoy**: `UserInformation.Paginas/Menus/Elementos/Estados` se copia una sola vez, al iniciar
  sesión. Un permiso quitado sigue funcionando; uno concedido no aparece.
- **Hacer** (`DS-08`: **recargar los permisos en la siguiente petición**, sin cerrar la sesión):
  - Marca de versión en el rol, que se incrementa al guardarlo; `FiltroSession` la compara con la de
    la sesión y **vuelve a cargar páginas, menús, elementos y estados** cuando difieren, sin que el
    usuario note nada más que el cambio de sus opciones.
  - Comprobar la versión con una sola consulta (`ValidarToken` ya va a la base en cada petición: se
    aprovecha esa misma lectura, no se añade otra).
  - La pantalla de rol dice qué va a pasar antes de guardar: «Afecta a 14 usuarios, que verán el
    cambio de inmediato».
  - Cambiar el rol **de un usuario** tiene el mismo efecto inmediato.
- **Aceptación**:
  - [x] Quitar una página a un rol deja fuera de esa pantalla a un usuario con la sesión abierta, sin
    que tenga que volver a entrar.
- **Esfuerzo** M · **Riesgo** MEDIO

#### [x] SG-13 · Rastro de los cambios de seguridad

- **Hoy**: no queda registro de quién creó un usuario, le cambió el rol o la contraseña, ni de quién
  tocó un rol. `Renovacion` sí guarda el usuario que renovó.
- **Hacer**: registro de alta, baja, cambio de rol, restablecimiento y cambio de contraseña, cambio
  de permisos de un rol, e inicio de sesión fallido y correcto, con usuario, fecha y origen; consulta
  filtrable desde Seguridad. Reutilizar el patrón de `OrdenTrabajoLog` / `AvisoLog`.
- **Aceptación**:
  - [x] Cada una de esas acciones deja una fila consultable desde la pantalla.
- **Esfuerzo** M · **Riesgo** BAJO

---

### FASE 2 — Que el administrador entienda lo que concede

#### [x] SG-14 · Editor de rol por módulo, no por ruta

- **Hoy**: pestaña *Menus* (árbol) y pestaña *Páginas* (lista plana de `/Area/Controlador/Accion`,
  sin buscador, sin agrupar, sin paginar, con una columna *CONTROLES* vacía), independientes entre
  sí.
- **Hacer**:
  - Una sola vista de permisos, agrupada por **módulo y pantalla**, con el nombre funcional delante y
    la ruta como detalle secundario.
  - Cada pantalla despliega sus **controles** (los elementos que registra SG-16, `DS-06`): la columna
    *CONTROLES* deja de estar vacía y se envían sus `ElementoIds`.
  - Buscador y contador por grupo («Logística: 12 de 24»), *marcar todo el módulo*, y resumen fijo de
    lo concedido.
  - Conceder una pantalla concede su entrada de menú y sus acciones dependientes, o al menos lo avisa
    (hoy son dos listas que hay que cuadrar a mano).
  - Señalar las páginas registradas que ya no corresponden a ninguna ruta real y las rutas sin
    registrar.
- **Aceptación**:
  - [x] Se puede dar «todo Logística menos anular notas» sin conocer ninguna ruta.
  - [x] No se puede guardar un rol con un menú cuya página no está concedida sin ver la advertencia.
- **Esfuerzo** L · **Riesgo** MEDIO

#### [x] SG-15 · Estados de OT y de aviso, visibles y con un valor inicial deliberado

- **Hoy**: la pestaña está oculta en las dos vistas y el alta manda todas las casillas marcadas.
- **Hacer**: mostrar la pestaña, agrupar los estados por flujo, explicar qué significa conceder cada
  uno y, según `DS-07`, **partir de nada concedido** en el alta: ningún preseleccionado, ni por
  perfil. Diagnóstico previo: listar los roles que hoy tienen todos los estados por este motivo, para
  que el propietario decida cuáles recortar.
- **Aceptación**:
  - [x] Un rol nuevo no puede mover una OT a ningún estado que no se haya marcado.
- **Esfuerzo** S · **Riesgo** MEDIO (cambia lo que pueden hacer los roles creados hasta ahora:
  revisar los existentes antes de desplegar)

#### [x] SG-16 · Permisos por elemento, completos

- **Hoy**: `Elemento` y `RolElemento` existen en la base, se cargan en cada petición
  (`FiltroAccion.cs:33`) y **ninguna vista los lee**; la columna *CONTROLES* del editor de rol está
  siempre vacía y `ElementoIds` no se envía nunca.
- **Hacer** (`DS-06`: **completar el ciclo**):
  - Mantenimiento de elementos por página, dentro de la ficha de la página (`Pagina/_Editar`): un
    elemento es un botón o una pestaña, con nombre funcional («Anular nota de salida»).
  - Registrar primero los **botones destructivos y de dinero** de Gestión y Logística: anular una
    nota, anular una OT, generar órdenes, eliminar una tarea, renovar una licencia.
  - Un ayudante de vista (`@Html.Elemento("…")` o equivalente) que lea el `ViewBag.Elements` que ya
    rellena `FiltroAccion.cs:33` y oculte el control cuando el rol no lo tenga.
  - **Y la comprobación en el servidor**: ocultar el botón no es el permiso. La acción asociada lo
    verifica, con el mismo mecanismo de SG-01.
  - Enviar `ElementoIds` desde el editor de rol (columna *CONTROLES*, hoy vacía) — se construye en
    SG-14, que pasa a depender de este paso.
- **Aceptación**:
  - [x] Un rol sin el elemento *Anular nota de salida* no ve el botón **y** recibe 403 si envía la
    petición a mano.
  - [x] No queda ninguna casilla ni columna del editor de rol que no haga nada. → cerrado por SG-14.
- **Esfuerzo** L · **Riesgo** MEDIO (toca vistas de Gestión y Logística; empezar por un solo elemento
  de punta a punta antes de registrar el resto)

#### [x] SG-17 · Ficha de rol completa

- **Hoy**: el perfil no se puede cambiar, no se ve quién usa el rol, no se puede duplicar, y guardar
  borra y reinserta todos los permisos sin decir nada.
- **Hacer**:
  - Permitir cambiar el `Perfil` (añadirlo a `RolModel.Editar` y a `RolLogica.ActualizarAsync`),
    avisando de que cambia el límite contra el que cuentan sus usuarios y bloqueándolo si el destino
    ya está al límite.
  - Columna *Usuarios* en la lista de roles y enlace a esos usuarios desde la ficha.
  - **Duplicar rol**, que es como se crean los roles parecidos hoy (a mano, casilla por casilla).
  - No permitir desactivar un rol con usuarios activos sin decir cuántos son.
  - Confirmación de guardado que resuma el cambio («+3 páginas, −1 menú, afecta a 14 usuarios») en
    lugar del «¿Estás seguro de actualizar el registro?» actual.
- **Aceptación**:
  - [x] Se puede corregir el perfil de un rol mal creado.
  - [x] Desactivar un rol con usuarios muestra cuántos y qué les pasa.
- **Esfuerzo** M · **Riesgo** BAJO · **Ref.** AD-10 (`IUsoCatalogo`)

#### [x] SG-18 · Los roles son de la instalación, y se dice

- **Hoy**: `Rol` no tiene `EmpresaId`; los roles son globales y todos aparecen en el desplegable de
  todas las empresas, pero la pantalla de roles se presenta como si fuera de la empresa.
- **Hacer** (`DS-02`: **siguen siendo globales**, sin migración; la pantalla se restringe):
  - Roles queda como pantalla **de instalación** (el control lo pone SG-02); ninguna empresa edita
    roles por su cuenta.
  - Decirlo donde importa: la lista y la ficha de rol advierten de que **un cambio afecta a todas las
    empresas que lo usan**, y la confirmación de guardado detalla cuántos usuarios y **de cuántas
    empresas** (SG-17).
  - El desplegable de rol del alta de usuario sigue ofreciendo todos los roles activos, con el número
    de empresas que ya lo usan como pista, y el nombre del rol se muestra junto a su perfil para
    distinguir roles parecidos de clientes distintos.
  - Convención de nombres recomendada al propietario para los roles nuevos, ya que el catálogo es
    compartido.
- **Aceptación**:
  - [x] Un usuario que no es de instalación no puede entrar en ninguna acción de `Rol`.
  - [x] Guardar un rol usado por dos empresas muestra las dos antes de confirmar.
- **Esfuerzo** S · **Riesgo** BAJO (no hay migración: `DS-02` descarta el `EmpresaId`)

#### [x] SG-19 · Ficha de usuario

- **Hoy**: el rol se muestra de sólo lectura y no se puede cambiar desde la empresa
  (`UsuarioModel.Editar.RolId` está comentado); el árbol de organizaciones aparece sin explicación;
  no se ve el empleado enlazado, ni el estado de la licencia, ni la última entrada.
- **Hacer**:
  - Permitir cambiar el rol desde la empresa (con la comprobación de límite de SG-06 y el efecto de
    SG-12), o explicar por qué no se puede.
  - Encabezado con rol, perfil, empleado enlazado, estado y última entrada.
  - El árbol de organizaciones con su ayuda: «determina qué equipos, ubicaciones y órdenes ve»; con
    un contador de lo seleccionado y la opción *toda la empresa*.
  - Acciones claras: *Desactivar* (con el efecto de SG-11), *Restablecer contraseña* (SG-10),
    *Cerrar sus sesiones*.
- **Aceptación**:
  - [x] Cambiar el rol de un usuario se puede hacer desde su empresa y se registra (SG-13).
- **Esfuerzo** M · **Riesgo** BAJO

#### [x] SG-20 · Organizaciones como árbol

- **Hoy**: lista plana con columna *Padre*; el árbol sólo existe dentro del modal de usuario, con un
  `dnd` que no guarda nada.
- **Hacer**: pantalla de árbol con alta sobre el nodo seleccionado, reordenación que se **guarda**,
  columna *En uso* (usuarios, equipos, ubicaciones que dependen de ella), y desactivación que explica
  a cuántos usuarios deja sin alcance. Validar que el padre es de la empresa y que no se crean
  ciclos.
- **Aceptación**:
  - [x] Mover un nodo persiste; desactivar uno con usuarios avisa de cuántos son.
- **Esfuerzo** M · **Riesgo** BAJO · **Ref.** el árbol de ubicaciones de `PLAN-UX-EQUIPO-UBICACION.md`

#### [x] SG-21 · Empresas y licencia

- **Hoy**: la lista muestra sólo el nombre; la ficha no dice cuántos usuarios se consumen ni cuándo
  vence de un vistazo; la renovación se hace desde un modal sin contexto.
- **Hacer**: lista con plan, vencimiento (con aviso de próximo a caducar y caducada), usuarios
  consumidos sobre el límite y almacenamiento usado; ficha con el histórico de renovaciones y el
  efecto de renovar («la licencia pasará del 12/01/2027 al 12/01/2028»).
- **Aceptación**:
  - [x] Se identifican de un vistazo las empresas caducadas o al límite de usuarios.
- **Esfuerzo** M · **Riesgo** BAJO

#### [x] SG-22 · Páginas y menús mantenibles

- **Hoy**: las páginas se escriben a mano (área, controlador y acción, sin validación de que existan)
  y el árbol de menús no permite eliminar ni reordenar (el `dnd` no guarda).
- **Hacer**:
  - Detectar las rutas reales de la aplicación y ofrecerlas al registrar una página, marcando las
    registradas que ya no existen y las rutas protegidas sin registrar.
  - Menús: eliminar (sólo si ningún rol lo usa, o avisando de cuántos), reordenar guardando el
    `Orden`, y validar que la ruta corresponde a una página registrada.
  - Que *Nuevo* sin nodo seleccionado deje de no hacer nada en silencio.
- **Aceptación**:
  - [x] Una página registrada que ya no corresponde a ninguna ruta aparece marcada.
  - [x] Arrastrar un menú guarda el nuevo orden.
- **Esfuerzo** M · **Riesgo** BAJO

---

### FASE 3 — Listas y formularios al patrón vigente

#### [x] SG-23 · Las siete listas

- **Archivos**: `Usuario/{Index,Todos}`, `Rol/Index`, `Empresa/Index`, `Organizacion/Index`,
  `Pagina/Index`, `Menu/Index`.
- **Hacer**: `helper.catalogo.lista` con panel de filtros y chips, estado de carga y fila vacía
  correcta (hoy `colspan=7` en tablas de 6 columnas), escapado (SG-05), badges de estado y perfil, y
  las columnas que faltan (usuarios por rol, perfil del usuario, vencimiento de la empresa).
- **Esfuerzo** M · **Riesgo** BAJO · **Ref.** AD-07, AD-08

#### [x] SG-24 · Los formularios

- **Hacer**:
  - `RespuestaValidacion.Errores` en los 7 controladores, con el error marcado **en su campo** en
    lugar del bloque `_Error`.
  - Corregir `$('#btnGuadar')` en las tres vistas: hoy, si el guardado falla, el botón se queda
    deshabilitado.
  - Quitar el `Swal` de «¿Estás seguro de guardar?» de las altas (no es una acción destructiva) y
    reservarlo para desactivar, restablecer contraseña y cambiar permisos, explicando la
    consecuencia.
  - Aviso de cambios sin guardar en `Rol/{Nuevo,Editar}` y `Empresa/Editar`, que son pantallas
    completas y hoy se abandonan con el botón ámbar *Regresar* sin preguntar.
  - Tras guardar un rol, ir a su ficha en lugar de volver a la lista.
  - Retirar el plugin `dnd` de los árboles donde arrastrar no significa nada (`Usuario/_Nuevo`,
    `Usuario/_Editar`) y hacerlo funcionar donde sí (SG-20, SG-22).
- **Esfuerzo** M · **Riesgo** BAJO

#### [x] SG-25 · Color, vocabulario y móvil

- **Hacer**: convención de color de los planes anteriores (sin `bg-primary` indiscriminado en las
  cabeceras, *Regresar* sin `btn-warning`); un solo vocabulario para *Rol*, *Perfil*, *Página*,
  *Menú*, *Elemento* y *Organización*, explicado una vez en la pantalla de roles;
  `.tabla-apilable` con `data-label` y comprobación a 400 px.
- **Esfuerzo** S · **Riesgo** BAJO

---

## 6. Orden recomendado

| Orden | Paso | Esfuerzo | Riesgo | Por qué en este orden |
|-------|------|----------|--------|-----------------------|
| 1 | **SG-04** Secretos fuera de las listas | S | BAJO | Dos líneas, corta la fuga de hashes y tokens |
| 2 | **SG-02** Instalación vs. empresa | M | MEDIO | Cierra `NuevoAdmin` / `EditarAdmin`, la vía más directa de escalada |
| 3 | **SG-01** Autorización en las escrituras | L | ALTO | El agujero de fondo; tras `DS-01` |
| 4 | **SG-03** Empresa en todas las consultas | M | BAJO | Cierra el acceso entre empresas |
| 5 | SG-05 `callBack` y escapado | S | BAJO | XSS en las pantallas del administrador |
| 6 | **SG-07** La empresa deja de perder su configuración | S | MEDIO | Hay datos ya corrompidos |
| 7 | SG-18 Los roles son de la instalación | S | BAJO | `DS-02` lo deja en un cambio pequeño; se apoya en SG-02, ya hecho |
| 8 | SG-06 Límite de usuarios | M | MEDIO | Depende de SG-07 |
| 9 | **SG-08** Contraseñas con PBKDF2 | M | ALTO | `DS-04`; probar el camino antiguo y el nuevo |
| 10 | SG-11 Sesión revocable | M | MEDIO | |
| 11 | SG-09 Política de contraseña | M | BAJO | |
| 12 | SG-12 Permisos que surten efecto | M | MEDIO | `DS-08`; comparte la lectura de `ValidarToken` con SG-11 |
| 13 | SG-13 Rastro de cambios | M | BAJO | Conviene antes de tocar la UI de roles |
| 14 | SG-10 Restablecer contraseña | M | BAJO | `DS-05`; después de SG-09 y SG-11 |
| 15 | **SG-15** Estados visibles | S | MEDIO | Revisar antes los roles existentes |
| 16 | SG-22 Páginas y menús | M | BAJO | El catálogo de páginas sostiene a SG-16 y SG-14 |
| 17 | SG-16 Controles por elemento | L | MEDIO | `DS-06`; antes de SG-14, que los muestra |
| 18 | SG-14 Editor de rol por módulo | L | MEDIO | El cambio de UX más grande |
| 19 | SG-17 Ficha de rol | M | BAJO | |
| 20 | SG-19 Ficha de usuario | M | BAJO | |
| 21 | SG-20 Árbol de organizaciones | M | BAJO | |
| 22 | SG-21 Empresas y licencia | M | BAJO | |
| 23 | SG-23 Listas | M | BAJO | |
| 24 | SG-24 Formularios | M | BAJO | |
| 25 | SG-25 Color y móvil | S | BAJO | |

> [!CAUTION]
> **SG-01, SG-02 y SG-08 pueden dejar a los usuarios fuera del sistema.** Antes de SG-01, obtener el
> inventario de páginas registradas por rol y comprobar que cada rol conserva las pantallas que usa;
> antes de SG-02, acordar con el propietario **qué rol es el reservado** (`DS-03`) y quién lo tiene,
> porque sin él nadie podrá entrar en Empresas, Roles, Páginas ni Menús; antes de SG-08, probar en un
> entorno de pruebas con hashes reales que el camino antiguo y el nuevo funcionan.

> [!CAUTION]
> **SG-15 y SG-07 corrigen datos ya guardados.** SG-15 quita estados que los roles tienen concedidos
> hoy sin que nadie lo decidiera; SG-07 no recupera por sí solo los límites que ya se pusieron a 0.
> Los dos empiezan con un informe de lo que hay.

## 7. Decisiones del propietario 🟢 RESUELTAS (2026-09-19)

| Id | Pregunta | Opciones | Decisión | Afecta a |
|----|----------|----------|----------|----------|
| `DS-01` | La autorización sólo protege pantallas, no escrituras, en **todos** los módulos. ¿Se invierte el modelo (proteger por defecto y declarar las excepciones) o se añade el filtro acción por acción? | a) Invertir: filtro por defecto en todos los controladores · b) Acción por acción, con un inventario cerrado · c) Sólo en Seguridad ahora, el resto en una fase posterior | **a)** Invertir el modelo: toda acción nace protegida y las excepciones se declaran. | SG-01 |
| `DS-02` | Los roles son globales a toda la instalación (`Rol` no tiene `EmpresaId`). ¿Pasan a ser por empresa? | a) `EmpresaId` anulable: nulo = plantilla, con valor = rol de la empresa · b) Seguir globales y restringir la pantalla a la administración del sistema · c) Duplicar las plantillas en cada empresa | **b)** Siguen globales; la pantalla de roles pasa a ser de instalación. **Sin migración.** | SG-18, SG-02, SG-03, SG-19 |
| `DS-03` | ¿Qué identifica a un administrador **de la instalación** (quien gestiona empresas, licencias, páginas y menús)? | a) El perfil `ADMINISTRADOR` de una empresa marcada como propietaria · b) Un indicador nuevo en `Usuario` · c) Un rol reservado por nombre | **c)** Un rol reservado por nombre, configurable y protegido contra renombrado y desactivación. | SG-02 |
| `DS-04` | Contraseñas: ¿qué algoritmo y qué política mínima? | a) PBKDF2 del propio .NET, 8 caracteres con mayúscula y número · b) BCrypt · c) Otra política que indique el propietario | **a)** PBKDF2 de .NET con sal por usuario; mínimo 8 caracteres con mayúscula y número. | SG-08, SG-09 |
| `DS-05` | ¿Se habilita la recuperación de contraseña por correo? El envío ya existe (`IEmailService`). | a) Sí, con enlace de un solo uso y caducidad · b) No: sólo un administrador restablece · c) Sí, y además invitación en el alta | **b)** Sin autoservicio: sólo un administrador restablece, con contraseña temporal. | SG-10 |
| `DS-06` | Los permisos a nivel de **elemento** (botones) están en la base y no los lee nadie. ¿Se completan o se retiran? | a) Retirar y documentar · b) Completar, empezando por los botones destructivos de Gestión y Logística | **b)** Completar el ciclo, empezando por los botones destructivos y de dinero. | SG-16, SG-14, SG-22 |
| `DS-07` | Un rol nuevo, ¿con qué debe nacer? | a) Sin nada concedido · b) Con un conjunto por perfil · c) Como hoy: todos los estados concedidos | **a)** Sin nada concedido: ningún estado preseleccionado, tampoco por perfil. | SG-15 |
| `DS-08` | Cuando se cambian los permisos de un rol, ¿qué pasa con las sesiones abiertas? | a) Recargar los permisos en la siguiente petición · b) Cerrar la sesión de los usuarios afectados · c) Como hoy: hasta la próxima entrada, diciéndolo en pantalla | **a)** Se recargan en la siguiente petición, sin cerrar la sesión. | SG-12, SG-11 |

> [!NOTE]
> **Consecuencias de `DS-02` y `DS-06` sobre el esfuerzo del plan.** `DS-02` (roles globales) elimina
> la migración más invasiva: SG-18 pasa de L/ALTO a S/BAJO y sube al séptimo lugar. `DS-06`
> (completar los elementos) añade trabajo en las vistas de Gestión y Logística: SG-16 pasa a L/MEDIO y
> se adelanta por delante de SG-14, que ahora muestra sus controles.

> [!CAUTION]
> **`DS-03` deja el acceso de instalación colgando de un nombre.** Si alguien renombra o desactiva el
> rol reservado, nadie puede entrar en Empresas, Roles, Páginas ni Menús. SG-02 lo protege en el
> editor de roles y comprueba al arrancar que el nombre configurado existe; aun así, **el nombre debe
> acordarse con el propietario antes de ejecutar SG-02** y quedar anotado aquí.

## 8. Hallazgos durante la ejecución

- **SG-04.** La segunda barrera de la entidad no puede ser `[JsonIgnore]`: la aplicación serializa con
  Newtonsoft (`AddNewtonsoftJson`), que no respeta el atributo de `System.Text.Json`, y meter
  Newtonsoft en `AMSYS.Entidades` —hoy sin ninguna dependencia— sólo por esto no compensa. Se usa
  `[IgnoreDataMember]`, que Newtonsoft sí respeta y viene con el framework.
- **SG-04.** La API móvil no se ve afectada: `Api/Controllers/UsuarioController` devuelve su propio
  `UsuarioPostResponse` con el JWT, no la entidad. La sesión web tampoco: serializa
  `UserInformation`, no `Usuario`.
- **SG-02.** `Usuario/Listar` también pasa a ser de instalación, aunque el paso sólo nombraba *Todos*,
  *NuevoAdmin* y *EditarAdmin*: es la lista que alimenta *Todos* y devuelve usuarios de todas las
  empresas, así que protegerla es parte del mismo cierre.
- **SG-02.** La separación visual de la navegación se resuelve **ocultando** las entradas de
  instalación a quien no las puede abrir (`_Sidebar.cshtml` + `RutasInstalacion`). Agruparlas bajo un
  título *Administración del sistema* es un cambio de **datos** del árbol de menús, no de código:
  queda para SG-22, cuando el árbol se pueda reordenar y guardar.
- **SG-02.** `UserInformation` gana `EsDeInstalacion` y `RolId`. Las sesiones abiertas en el momento
  del despliegue deserializan `EsDeInstalacion` como `false`: pierden esas pantallas hasta volver a
  entrar. Es el lado seguro, pero conviene desplegar avisando.
- **SG-02.** La autorización de instalación vive en dos sitios que hay que mantener a la par:
  `FiltroInstalacion` (lo que se aplica a cada controlador) y `RutasInstalacion` (lo que consulta el
  menú). Está anotado en el XML de ambos.
- **SG-03 corrige el plan.** El paso pedía filtrar `Usuario.Listar` por empresa, pero después de
  SG-02 esa lista **es** la de la instalación (la que alimenta *Todos*) y exige el rol reservado:
  filtrarla por la empresa de la sesión dejaría la pantalla sin datos. El filtro por empresa sigue
  estando, pero como criterio que elige quien consulta. Lo mismo vale para `Empresa.Editar` y
  `Renovacion.Nuevo`, que aceptan cualquier `EmpresaId` porque administrar cualquier empresa es
  justamente su función; lo que faltaba era la autorización, y la puso SG-02.
- **SG-03.** `ActualizarAsync` de usuario y de organización pasa a devolver `bool`: antes respondían
  «se guardó» sin haber guardado nada cuando el registro no existía. Es el mismo defecto que
  `AD-06` corrigió en los catálogos de Administración.
- **SG-05.** Las listas no eran el único punto de inyección: **jstree pinta el texto del nodo como
  HTML** (`force_text` viene en `false`), así que el árbol de menús, el de permisos del rol y el de
  organizaciones del modal de usuario ejecutaban lo que llevara el nombre. Los cinco árboles del área
  pasan a `force_text: true`.
- **SG-07 corrige el plan.** El paso remitía a `DS-07` para decidir si el plan preselecciona los
  límites; `DS-07` trata de otra cosa (con qué nace un rol). No hay ninguna decisión pendiente ahí:
  el plan se guarda y los límites se escriben tal como se introduzcan.
- **SG-07.** El **alta** de empresa tenía el mismo agujero que la edición: no pedía los límites por
  perfil, así que toda empresa creada desde la aplicación nace con los cuatro en 0. Entra en el
  paso, porque si no, SG-06 dejaría sin usuarios a cada empresa nueva.
- **SG-07.** `EmpresaModel.Editar` llevaba `Vencimiento`, que el formulario no envía y la lógica no
  guarda. Se retira del modelo: la fecha de licencia la cambia la renovación, y tenerla ahí sólo
  invitaba a que alguien la «arreglara» y borrara la licencia al guardar la ficha.
- **SG-07.** `EmpresaLogica.ActualizarAsync` conserva el `else return Task.CompletedTask`, así que
  editar una empresa inexistente sigue respondiendo éxito. Es el mismo defecto que SG-03 corrigió en
  usuario y organización; queda para SG-24, que pasa los 7 controladores a `RespuestaValidacion`.
- **SG-01: cómo se resolvió sin anotar 277 acciones.** El paso hacía temer una anotación acción por
  acción. No hace falta: el filtro global distingue **rutas registradas** de **auxiliares**
  consultando el catálogo de páginas (`CatalogoPaginas`). Una ruta registrada exige su propia página
  —así un POST `Nuevo` pide el mismo permiso que su formulario, y conceder sólo `Index` no da de
  alta—; una auxiliar que nunca se registró (las 62 `Listar`, las exportaciones, los `ListarPor…`)
  exige el `Index` de su propio controlador. Sólo hubo que declarar 10 excepciones.
- **SG-01.** Una consecuencia que conviene tener presente: con esa regla, tener el `Index` de un
  controlador habilita **todas** sus acciones auxiliares, incluidos POST sin página propia como
  `Eliminar` o `Anular`. Es mucho más estricto que hoy (donde están abiertas a cualquiera), pero no
  es control por botón: eso llega con SG-16 y los elementos.
- **SG-01.** El `[FiltroAccion]` **comentado** del Kanban (`analysis/permissions.md` §2.6) ya no deja
  la acción abierta: al no declarar nada, entra en la protección por defecto.
- **SG-01.** Las 201 acciones que ya tenían `[FiltroAccion]` se quedan como están: el filtro global
  las reconoce y no las comprueba dos veces. El atributo pasa a ser la forma de **declarar** un
  permiso distinto del de la propia ruta (su propiedad `Accion`), no el modo de activarlo.
- **SG-01.** El modo de sólo registro (`AutorizacionSoloRegistra`) no existía en el plan y es lo que
  permite cumplir su propio aviso: desplegar, recoger del log qué se usaba sin permiso, corregir el
  catálogo y sólo entonces aplicar. Afecta únicamente a la protección nueva; `FiltroAccion` sigue
  bloqueando como hasta ahora.
- **SG-01.** Denegar pasa de `401` a **403**, que es lo que corresponde a un usuario autenticado sin
  permiso, y la pantalla deja de decir «¿Qué hace usted aquí?» para decir qué pantalla falta y a
  quién pedirla. `401` se sigue atendiendo por las rutas antiguas.
- **SG-18.** La primera aceptación («un usuario que no es de instalación no puede entrar en ninguna
  acción de `Rol`») ya la cumplía SG-02: el `[FiltroInstalacion]` está a nivel de clase, así que cubre
  también `Listar` y los dos POST. Lo que faltaba de este paso era **decirlo**, no protegerlo.
- **SG-18.** El uso de un rol se resuelve con **una sola consulta** agrupada por rol y empresa
  (`UsoRolRepositorio`), igual que el `UsoCatalogoRepositorio` de `AD-10`, y no una consulta por fila.
- **SG-18.** El desplegable de rol del alta de usuario recibe **sólo el número** de empresas, nunca sus
  nombres: un administrador de empresa no tiene por qué saber qué otras empresas usan el rol. Los
  nombres aparecen únicamente en las pantallas de instalación, que ya exigen el rol reservado (SG-02).
- **SG-18.** La confirmación de guardado dice «lo verán la próxima vez que inicien sesión», que es lo
  que ocurre **hoy**. Cuando entre SG-12 (`DS-08` a) habrá que cambiar esa frase por «lo verán de
  inmediato»: está en `Rol/Editar.cshtml`, en `resumenUso()`.
- **SG-18.** `UsoRolDTO` cuenta también los **usuarios activos**, que este paso sólo muestra en el
  *title* de la columna: lo necesita SG-17 para impedir desactivar un rol con usuarios activos.
- **SG-18.** La fila «No existen registros» de la lista de roles llevaba `colspan=7` en una tabla de 5
  columnas (uno de los defectos que recoge SG-23); con las dos columnas nuevas queda correcta sola.
- **SG-18.** Lo que **no** entra aquí, aunque lo roce: el resumen del cambio («+3 páginas, −1 menú»),
  la columna *Usuarios* enlazada a esos usuarios y el bloqueo al desactivar un rol en uso son de SG-17,
  que ya tiene el conteo hecho. El `$('#btnGuadar')` sin la *r* de `Rol/Editar.cshtml` sigue ahí: es
  de SG-24.
- **SG-06.** El cupo pasa a contar **usuarios activos**, no todos. El anterior contaba también a los
  desactivados, así que una empresa podía quedarse sin poder dar de alta por gente que ya no entra.
  Es además lo que muestra la ficha de empresa desde SG-07, así que ahora las dos cifras coinciden.
- **SG-06.** El alta de empresa **ya no se bloquea al abrir el modal**. Antes, superado el límite, no
  se podía ni mirar el formulario, y el mensaje —«Usted ya superó el límite de usuarios»— contaba
  contra el límite equivocado. Ahora el modal abre siempre, dice el consumo de los cuatro perfiles y
  deshabilita los roles sin cupo explicando por qué; el que decide sigue siendo el servidor.
- **SG-06.** Los modales de instalación (`_NuevoAdmin`, `_EditarAdmin`) eligen la empresa en el propio
  formulario, así que el cupo se consulta al cambiarla: acción nueva `Seguridad/Usuario/Limites`, que
  lleva **su propia autorización** (sólo la empresa de la sesión, salvo que el usuario sea de
  instalación). Como ruta auxiliar, SG-01 le exige el `Index` de `Usuario`: quien administre usuarios
  desde *Todos* necesita también esa página, o el cupo aparecerá como no consultable. Conviene
  comprobarlo al revisar el log del modo de sólo registro.
- **SG-06.** Al **editar**, el cupo sólo se comprueba si el cambio ocupa una plaza que antes no
  ocupaba: activar a un usuario desactivado, moverlo a otra empresa o pasarlo a un rol de otro perfil.
  Guardar una ficha sin tocar nada no puede fallar por el límite, aunque la empresa esté al tope.
- **SG-06.** El error del límite se marca en `RolId` (o en `Activo` cuando el rol no se toca), pero
  los cuatro POST de usuario todavía responden con el bloque `_Error` agrupado en lugar de
  `RespuestaValidacion.Errores`: el mensaje se ve, pero no señala el campo. Es de SG-24.
- **SG-06 corrige el plan.** El paso pedía comprobarlo «también en el `POST Nuevo` y al activar un
  usuario desactivado», pero faltaban dos puertas más: el alta de instalación (`NuevoAdmin`) y el
  cambio de empresa o de perfil en `EditarAdmin`, que consumen plaza igual. Entran las cuatro.
- **SG-10 se adelanta a SG-09, SG-11 y SG-13**, de los que el orden lo hacía depender. De SG-09 y
  SG-11 se hace aquí la parte mínima que este paso necesita, en el sitio donde luego crecerá:
  `ClaveUtilitario` (política de `DS-04` y generación), que SG-09 reutilizará en los cuatro modales y
  en el perfil; y el cierre de sesiones borrando `TokenWeb`/`TokenMovil`, que SG-11 sustituirá por
  token aleatorio y revocación completa. De SG-13 **no se hace nada**: quedan dos `TODO SG-13`
  marcados —restablecimiento y cambio de contraseña—, así que hoy **no se sabe quién restableció a
  quién**. Es la carencia consciente de este paso.
- **SG-10.** Hace falta **migración**: `usuario.clavetemporal` (`boolean not null default false`).
  Al generarla, `dotnet ef` regeneró `AMSYSContextoModelSnapshot.cs`, al que le faltaba
  `almacen.activo` de la migración anterior: el fichero estaba desfasado y queda corregido de paso.
- **SG-10.** La contraseña se genera con `RandomNumberGenerator`, no con `Random`, y sin los
  caracteres que se confunden al dictarla (`O`/`0`, `l`/`I`/`1`), porque se entrega a mano.
  Comprobado con 2000 generaciones: todas cumplen la política y ninguna baja de 8 caracteres.
- **SG-10.** **El alta de usuario sigue pidiéndole la contraseña al administrador**, así que sigue
  conociendo la de los usuarios que crea. Este paso sólo cierra el camino del restablecimiento; el
  del alta lo cierra SG-09, con su botón de *generar una segura*.
- **SG-10.** `Account/Perfil` también cambia la contraseña y **no** comprueba la política: el filtro
  no deja llegar ahí con una contraseña temporal, así que no hay agujero, pero la política le falta
  hasta SG-09. `CambiarClave` sí la comprueba, y exige además que la nueva sea distinta de la actual.
- **SG-10.** Nadie puede restablecerse la contraseña a sí mismo desde la lista: cerraría su propia
  sesión y le obligaría a cambiarla otra vez. Se remite al perfil, con el motivo.
- **SG-10.** `RestablecerClave` es ruta auxiliar, así que SG-01 le exige el `Index` de `Usuario`,
  igual que `Limites` de SG-06. No es control por botón —restablecer la contraseña de cualquiera con
  el permiso de ver la lista—: eso llega con SG-16, y es de los primeros elementos que registrar.
- **SG-10.** Se retiran `AccountModel.Recovery` y `AccountModel.ChangePassword`, muertos desde
  siempre como el `GetPassword()` que nombraba el paso.
- **SG-11 corrige el plan.** El paso decía que «cambiarle el rol» a un usuario debía renovar el
  token, es decir, cerrarle la sesión; pero `DS-08` a) —y SG-12— dicen lo contrario: los permisos se
  recargan en la siguiente petición **sin** cerrar la sesión. Se resuelve así: desactivar al usuario
  o cambiarle la contraseña cierra sus sesiones; cambiarle el rol sólo recarga sus permisos.
- **SG-11.** Cambiarse uno mismo la contraseña **renueva** el token en lugar de borrarlo: cierra las
  demás sesiones del usuario y deja abierta la de quien acaba de demostrar que la conoce. Sólo hay un
  `tokenweb` por usuario, así que no se puede distinguir sesión por sesión; esto es lo más cerca que
  se llega sin una tabla de sesiones.
- **SG-11.** `usuario.vencimiento`, que no miraba nadie, pasa a comprobarse en el inicio de sesión y
  en cada petición. **No hay pantalla para ponerlo**: se edita en la base hasta que SG-19 rehaga la
  ficha de usuario. Era «usar o retirar»; queda usado.
- **SG-11.** El límite de intentos cuenta en **memoria** (`IMemoryCache`): con varias instancias cada
  una lleva la suya. Basta para encarecer la fuerza bruta y no añade infraestructura; si algún día se
  despliega en varias instancias, conviene revisarlo. Sólo cuenta el intento que llegó a comprobar
  credenciales: un campo vacío no gasta cupo.
- **SG-12.** La recarga de permisos se hace **dentro de `FiltroSession`**, que es síncrono, con
  `GetAwaiter().GetResult()` sobre la búsqueda del rol. En ASP.NET Core no hay contexto de
  sincronización, así que no hay riesgo de bloqueo, pero sólo ocurre cuando la versión cambió: en una
  petición normal no se hace ninguna consulta extra.
- **SG-12.** `rol.version` sube **siempre** que se guarda el rol, aunque no cambie ningún permiso:
  `ActualizarAsync` borra y reinserta todo, así que no hay forma barata de saber si hubo cambio real.
  El coste de pasarse es una recarga de permisos de más, que es inocua.
- **SG-13.** La pantalla existe, pero **el permiso es un dato**: con la autorización invertida de
  SG-01, `Seguridad/SeguridadLog/Index` tiene que estar en el catálogo de páginas y concedida a
  algún rol, o no la abre nadie. El alta está en `ai/analysis/sg-13-pagina-rastro.sql`, con la
  entrada de menú opcional. Hoy no se nota porque `AutorizacionSoloRegistra` sigue en `true`.
- **SG-13.** El rastro es **de la empresa**: un administrador ve el suyo, el rol reservado los ve
  todos. Un acceso fallido con un correo que no existe se anota sin empresa ni usuario, sólo con el
  correo intentado y el origen.
- **SG-13.** El registro se guarda con `await`, no en segundo plano: si falla la escritura del
  rastro, falla la acción. Es deliberado para un rastro de seguridad —mejor no hacerlo que hacerlo
  sin constancia—, pero conviene saberlo: una caída de la base al anotar impide iniciar sesión.
- **SG-13.** Lo que **no** registra: los cambios de empresa, renovación, organización, página y menú.
  El paso pedía «los cambios de seguridad» y se ha interpretado como usuarios, roles y accesos;
  ampliarlo a las pantallas de instalación es añadir llamadas a `RegistrarAsync`, no infraestructura.
- **SG-08.** La comparación de la contraseña **sale del SQL**. Con sal por usuario el hash no se
  puede buscar en la consulta, así que `LoginAsync(correo, hash)` pasa a ser
  `AutenticarAsync(correo, claveEnClaro)`: el repositorio devuelve los usuarios activos con ese
  correo y la lógica comprueba uno por uno. El cambio de nombre es deliberado, para que ninguna
  llamada antigua siga pasando un hash sin que el compilador lo note.
- **SG-08 arregla de paso el 500 del correo repetido.** `LoginAsync` usaba `SingleOrDefaultAsync`, y
  dos usuarios con el mismo correo en empresas distintas hacían reventar el inicio de sesión con un
  error 500 (está en la tabla de hechos de la sección 1, sin paso asignado). Ahora se recuperan todos
  y entra aquel cuya contraseña coincide. **Queda un caso sin decidir**: si el mismo correo **y** la
  misma contraseña existen en dos empresas, entra en la de menor `id`. Merece una decisión del
  propietario —preguntar la empresa, o prohibir el correo repetido— y no la toma este paso.
- **SG-08.** El despliegue **no se puede deshacer una vez que alguien entra**. En cuanto un usuario
  inicia sesión, su fila se regraba en el formato nuevo, que el código anterior no sabe leer: volver
  atrás deja fuera a todos los que hayan entrado. Conviene desplegarlo con copia de seguridad de la
  tabla `usuario` y no revertir sin restaurarla.
- **SG-08.** Comprobar una contraseña cuesta unos **70 ms** (210.000 iteraciones). Es el objetivo
  —encarecer el diccionario—, y se combina con el límite de intentos de SG-11. Si el inicio de sesión
  se notara lento, se baja `IteracionesClave`; las contraseñas ya guardadas siguen valiendo porque
  cada hash lleva dentro las suyas.
- **SG-08.** `AMSYS.DemonApp` y la API móvil quedan adaptados, como avisaba el paso. La API comparte
  `AutenticarAsync`, así que un usuario que sólo use el móvil también migra su hash al entrar.
- **SG-08.** `ToSHA526` está marcado `[Obsolete]` y la compilación queda en **0 avisos**: no quedaba
  ningún uso más que el verificador del formato antiguo. Cuando no queden filas antiguas —se ve con
  `SELECT count(*) FROM usuario WHERE clave NOT LIKE 'pbkdf2$%'`— se puede borrar el método.
- **SG-15.** El paso cambia lo que pasa **de aquí en adelante**; no recorta nada de lo ya
  concedido. El informe (`sg-15-estados-por-rol.sql`) trae tres consultas: qué tiene cada rol, cuáles
  los tienen todos —señal de que fue el valor por defecto, no una decisión— y **quién puede anular
  una OT o rechazar un aviso**, que es lo más caro de haber concedido por descuido.
- **SG-15.** Cuidado al corregir en la base: guardar un rol desde la pantalla **reescribe todos sus
  estados**, así que si alguien lo guarda después de un `DELETE`, quedará lo que muestre la pantalla.
  Lo seguro es corregirlo desde la pantalla, que ahora ya deja verlos.
- **SG-15.** Sólo se agrupan por entidad —órdenes de trabajo y avisos—, no «por flujo» como sugería
  el paso: los enumerados son cuatro y cinco estados lineales, y una agrupación adicional habría sido
  decorado. Lo que faltaba de verdad era explicar qué concede cada casilla.
- **SG-22.** Las rutas reales no se listan con un script ni se copian del CSV de SG-01: se leen del
  enrutado en marcha (`IActionDescriptorCollectionProvider`), así que **no se pueden quedar
  desfasadas**. Una acción nueva aparece en la lista sin tocar nada; una que se borra hace que su
  página registrada salga marcada como *sin ruta*.
- **SG-22.** Se distingue **pantalla** de **acción auxiliar** por el método HTTP: lo que se sirve por
  GET es una pantalla y es lo que se ofrece al registrar; los POST y las listas por AJAX no, porque
  con la regla de SG-01 se sirven con el `Index` de su controlador. La API móvil se excluye entera.
- **SG-22.** Registrar una ruta que no existe **pasa a rechazarse**, no sólo a avisarse: creaba un
  permiso inútil y ensuciaba el catálogo del que depende `FiltroAutorizacion`.
- **SG-22.** La ruta de un menú se elige entre las **páginas registradas** y se valida en el
  servidor. Era el descuadre que describe la sección 1: dar el menú sin la página produce un 403 al
  hacer clic. No se arregla la otra mitad —conceder la página al conceder el menú—, que es de SG-14.
- **SG-22.** Eliminar un menú **borra también las concesiones** de los roles que lo tenían; si no,
  quedarían filas de `rolmenu` apuntando a un menú inexistente. No se borra un nodo con hijos: hay
  que mover o borrar antes lo que cuelga.
- **SG-22.** El árbol de menús ya tenía el plugin `dnd` puesto y arrastrar no guardaba nada. Ahora el
  movimiento saca un botón *Guardar el orden* que manda el árbol entero aplanado —padre y posición de
  cada nodo—. Retirar el `dnd` de los árboles donde no significa nada (`Usuario/_Nuevo`,
  `Usuario/_Editar`) sigue siendo de SG-24.
- **SG-16: por qué nunca funcionó.** No era sólo que faltara la vista. `FiltroAccion` —y
  `FiltroAutorizacion`, que heredó el contrato— filtraban los controles con
  `user.Elementos.Where(x => x.Id == page.Id)`: comparaban el identificador del **elemento** con el
  de la **página**. Aunque alguna vista los hubiera leído, la lista habría llegado vacía o con lo que
  no era. Corregido a `x.PaginaId == page.Id` en los dos.
- **SG-16.** El elemento gana una **clave** (`anular-nota-salida`) además del nombre visible. El paso
  sólo hablaba del nombre funcional, pero identificar por el nombre es justo lo que `DS-03` dejó
  frágil en el rol reservado: renombrarlo rompería el permiso en silencio. La clave es lo que escribe
  el código; el nombre, lo que lee quien reparte permisos.
- **SG-16.** `ExigeElemento` **deja pasar las claves que nadie ha registrado**, anotándolo en el log.
  Es deliberado y es lo que permite desplegar sin romper nada: una clave sin registrar no la puede
  tener nadie, así que bloquear dejaría la acción fuera de servicio para todos. El control empieza a
  proteger el día que se da de alta, no el del despliegue. Es el mismo criterio que
  `AutorizacionSoloRegistra` en SG-01.
- **SG-16.** Los controles se editan **dentro de la ficha de su página**, como pedía el paso, con
  una tabla en el propio modal en lugar de un modal dentro de otro. Quitar uno borra también sus
  concesiones, y se avisa antes.
- **SG-16.** `@Html.Elemento(...)` hacía falta en las vistas de **todas** las áreas, así que el
  `using` entra en los cinco `_ViewImports` de área: los de área no heredan del de la raíz.
- **SG-16.** Quedan sin control por botón las otras acciones que nombraba el paso —anular una OT,
  generar órdenes, eliminar una tarea—: no tienen un `Anular`/`Eliminar` equivalente en su
  controlador y merecen mirarse una a una. El mecanismo está, añadirlas es una línea por acción más
  su alta en el catálogo.
- **SG-14.** El editor es una sola parcial (`Rol/_Permisos.cshtml`) que usan el alta y la ficha, en
  lugar de dos copias del mismo marcado. Recibe lo concedido por `ViewBag` y expone en JS
  `permisos.PaginaIds()` y `permisos.ElementoIds()`, que es lo que arma el modelo en las dos vistas.
- **SG-14.** El control **se deshabilita y se desmarca con su pantalla**: conceder «anular nota de
  salida» sin conceder la pantalla de notas de salida no significa nada, porque para llegar al botón
  hay que poder abrir la pantalla. Así la casilla no miente.
- **SG-14.** El aviso de menú sin página se calcula en el cliente con el mapa *menú → página* que
  arma el controlador. Cubre los dos sentidos que importan: el menú cuya ruta **no está registrada**
  como página (`paginaId = 0`) y el menú cuya página existe pero **no se ha concedido**.
- **SG-14 cambia lo que se pregunta al guardar.** En el alta, el «¿Estás seguro de guardar el
  registro?» —que no aportaba nada, porque crear un rol no destruye nada— sólo aparece ahora cuando
  hay un descuadre que advertir. Es lo que SG-24 pide para todas las altas; aquí entra de paso.
- **SG-14.** Lo que **no** hace, y el paso mencionaba: conceder una pantalla no concede
  automáticamente su entrada de menú. Se avisa, que es la otra opción que daba el paso. Automatizarlo
  exigiría decidir qué hacer cuando la misma página cuelga de dos entradas distintas, y eso no está
  decidido.
- **SG-14.** Desaparece el *marcar todo* global de la cabecera de la tabla: ahora es por módulo, que
  es lo que se quiere de verdad («todo Logística»). Marcar las 487 rutas de golpe no era una
  operación que nadie necesitara.
- **SG-17.** Cambiar el perfil de un rol se comprueba **empresa por empresa**. Es la consecuencia de
  `DS-02` que no salta a la vista: como los roles son de toda la instalación, pasar un rol de
  OPERADOR a MANTENIMIENTO mueve de cupo a los usuarios de **todas** las empresas que lo usan, y a
  una le puede caber y a otra no. El error dice en cuál falta cupo y cuánto.
- **SG-17.** Desactivar un rol con usuarios activos **avisa pero no bloquea**, que es lo que pedía el
  paso («no permitir… sin decir cuántos son»). El aviso dice además lo que no es obvio: desactivar el
  rol no desactiva a sus usuarios, sólo impide asignarlo.
- **SG-17.** El resumen del cambio se calcula en el cliente comparando lo concedido al abrir la ficha
  con lo marcado al guardar. Es honesto con lo que hay: `RolLogica.ActualizarAsync` borra y reinserta
  todos los permisos, así que el servidor no sabe qué cambió, sólo cómo queda.
- **SG-17.** Duplicar copia también los **estados** de OT y aviso, no sólo páginas y menús. Con
  SG-15 los roles nuevos nacen sin ningún estado, así que duplicar es ahora la vía natural para
  partir de un rol que ya funciona en lugar de marcar las casillas una a una.
- **SG-17.** El nombre del rol se comprueba que no exista ya al duplicar. **No se comprueba al
  editar ni al crear**, que es un hueco anterior a este paso: con el catálogo compartido entre
  empresas (`DS-02`), dos roles con el mismo nombre son una trampa, y además el rol reservado se
  identifica por nombre (`DS-03`). Merece cerrarse en SG-24.
- **SG-19.** El rol volvió a la ficha de empresa, pero la lógica también hubo que tocarla: escribía
  `RolId` **sólo** en el camino de administración de la instalación, así que aunque el modelo lo
  enviara se habría descartado en silencio. Ahora se escribe siempre que llegue.
- **SG-19.** La *última entrada* no exigió columna nueva: sale del rastro de SG-13, buscando el
  último `AccesoCorrecto` de ese usuario. Un usuario anterior a SG-13 aparecerá como «Nunca ha
  entrado» hasta que vuelva a entrar; es el precio de no añadir una columna a `usuario`.
- **SG-19.** *Cerrar sus sesiones* es distinto de restablecer la contraseña: deja fuera al usuario
  sin cambiársela, para cuando se sospecha que alguien más la conoce o para que un cambio surta
  efecto ya. Comparte la regla de alcance de SG-03: sólo usuarios de la propia empresa, salvo que
  quien lo hace sea de instalación.
- **SG-19.** *Toda la empresa* marca el árbol entero en vez de guardar un «sin restricción». Es lo
  que la base soporta hoy —`UsuarioOrganizacion` es una lista de nodos, no hay concepto de «todos»—,
  y tiene un efecto secundario que conviene conocer: una organización creada **después** no queda
  incluida, hay que volver a marcarla.
- **SG-20.** Reordenar exigía la única columna nueva del paso: `organizacion.orden` (migración
  `Organizacion_AgregarOrden`). Nace en `0`, y el árbol ordena por `Orden` y luego por `Id`, así que
  **antes de tocar nada el árbol se ve exactamente igual que hoy**: no hace falta rellenar la columna.
- **SG-20.** El arrastre reutiliza tal cual la mecánica de SG-22: el árbol se aplana en el navegador
  (padre y posición de cada nodo), el botón *Guardar el orden* aparece sólo cuando algo se movió, y el
  servidor descarta los nodos —y los padres— que no son de la empresa de la sesión (SG-03).
- **SG-20.** La «columna *En uso*» del plan no cabe en un árbol: es un **panel a la derecha** que
  muestra el desglose del nodo seleccionado (usuarios, ubicaciones, equipos, avisos, órdenes de
  trabajo y organizaciones debajo). El conteo va en el propio árbol, en una consulta agrupada por
  tabla para todos los nodos (`UsoOrganizacionRepositorio`), no una por nodo.
- **SG-20.** Desactivar deja de ser una casilla del formulario y pasa a ser una **acción propia**: la
  casilla *Activo* no decía nada de sus consecuencias y se marcaba sin pensarlo. `Activo` sale de
  `OrganizacionModel.Editar` y de `ActualizarAsync`; lo escribe `CambiarEstadoAsync`, y la pantalla
  avisa antes de a cuántos usuarios activos se lo quita y a cuántos **los deja sin ningún alcance**
  porque no tienen otra organización asignada.
- **SG-20.** No se desactiva una organización de la que cuelgan otras: se quedarían colgando de un
  nodo inactivo. Es el mismo criterio con el que SG-22 impide borrar un menú con hijos.
- **SG-20.** Los ciclos se cierran por los dos lados: la ficha ya no **ofrece** como superior una
  organización que cuelga de la que se edita, el POST lo comprueba recorriendo los descendientes, y
  `Reordenar` rechaza el árbol entero si el aplanado que llega se cierra sobre sí mismo.
- **SG-20.** Lo que **no** entra aquí: quitar el `dnd` del árbol de organizaciones de los modales de
  usuario, donde arrastrar sigue sin significar nada. Es de SG-24, que lo nombra explícitamente.
- **SG-21.** El almacenamiento consumido no necesitó columna nueva: sale de `SUM(adjunto.tamano)` por
  empresa, que ya se guarda en bytes. El límite (`Limitacion.CantidadAlmacenamiento`) está en Mb, y
  esa es la unidad que se compara y se muestra.
- **SG-21.** El estado de la licencia se calcula en **un solo sitio** (`Licencia.Estado`, con
  `DiasAviso` en 30) para que la lista, la ficha y el filtro digan lo mismo. El inicio de sesión sigue
  con su propia comprobación de `Vencimiento` (SG-11): no se tocó, pero el corte es el mismo día.
- **SG-21.** La lista gana además un **filtro** por plan, por estado de licencia y por «al límite de
  usuarios». Sin él, «de un vistazo» sólo funciona en la primera página: la acepción del paso se
  cumple con las columnas, pero con 15 filas por página una empresa caducada puede estar en la tercera.
  *Al límite* incluye a las que no tienen fila de límites, que tampoco admiten altas (SG-06).
- **SG-21.** Renovar decía sólo «Nuevo Vencimiento». Ahora el modal trae la empresa, **desde cuándo
  cuenta** la renovación —el vencimiento actual, o hoy si nunca la hubo— y escribe el efecto mientras
  se elige la fecha: «la licencia pasará del 12/01/2027 al 12/01/2028 — 365 día(s), unos 12 mes(es)».
  Propone un año más sobre el vencimiento actual en lugar de un año desde hoy, que era lo que hacía y
  **regalaba o perdía** los meses que quedasen.
- **SG-21.** El rechazo de una fecha menor al vencimiento vigente pasa a decir **cuál es** esa fecha, y
  se añade el caso que faltaba: una empresa sin licencia a la que se renueva con una fecha ya pasada
  quedaba caducada en el mismo acto de renovarla. El error se marca en `Hasta`, no en un `Cantidad`
  que no existe desde que el campo de meses se comentó.
- **SG-21.** El `$('#btnGuadar')` de `Empresa/Editar` (sin la *r*) se corrige de paso: estaba en la
  misma línea que se tocó y dejaba el botón deshabilitado para siempre si el guardado fallaba. Los
  otros dos, en `Rol/{Nuevo,Editar}`, siguen siendo de SG-24.
- **SG-19.** Queda fuera lo que el paso no pedía pero la ficha sigue sin tener: `Vencimiento` del
  usuario, que SG-11 ya comprueba en cada petición y sólo se puede poner en la base.
- **SG-23.** Las «siete listas» no son siete tablas: **SG-20 y SG-22 convirtieron Organización y
  Menú en árboles**, así que a `helper.catalogo.lista` pasan cinco —`Usuario/{Index,Todos}`,
  `Rol`, `Empresa` y `Página`— y los dos árboles reciben lo que sí les cabe: cuántos nodos hay,
  cuántos están desactivados o no abren ninguna pantalla, y qué hacer cuando no hay ninguno.
- **SG-23.** El `colspan=7` sobre tablas de 6 columnas desaparece solo: `helper.tabla.vacia` cuenta
  las columnas de la cabecera. Con él llega el **estado de carga**, que ninguna de las siete tenía:
  la tabla se quedaba con los datos anteriores mientras cargaba los nuevos.
- **SG-23.** La columna que faltaba de verdad era el **perfil del usuario**: `ListarMisUsuarios` y
  `Listar` devolvían sólo el nombre del rol, y el perfil es lo que decide contra qué cupo contratado
  cuenta esa persona. Se añade a las dos proyecciones (sin tocar SG-04: sigue siendo explícita).
  Las otras dos columnas del plan ya estaban: *usuarios por rol* la puso SG-18 y *vencimiento de la
  empresa*, SG-21.
- **SG-23.** `helper.catalogo.lista` gana `filaClase`: sin él, pasar `Página` al patrón habría
  perdido el resaltado en ámbar de las rutas huérfanas que SG-22 acababa de introducir.
- **SG-24.** Los 23 `PartialView("_Error")` de los POST pasan a `RespuestaValidacion.Errores`. Los de
  los **GET se quedan**: un GET de modal devuelve el cuadro entero, no un formulario que marcar.
- **SG-24.** Cinco de esos POST no fallaban por validación sino por una regla de negocio y escribían
  en `ViewBag.Message` (menú con hijos, organización con hijas, árbol con ciclo, restablecer la
  propia contraseña, registro no encontrado). Pasan a `ModelState.AddModelError("", …)`: el mensaje
  se sigue viendo igual, pero ahora viaja por el mismo canal que los demás.
- **SG-24.** Marcar el error en su campo obligó a llevar los **doce modales del área** a
  `helper.catalogo.modal`, que es quien lo hace. De paso *Guardar* pasa a ser `submit` —Enter guarda
  sin abandonar la página—, el botón dice «Guardando…» y *Cancelar* deja de ser rojo.
- **SG-24.** La confirmación no se quita de todas partes: se quita **de las altas**, que no destruyen
  nada. Se queda donde hay algo que perder y diciendo qué —cambiar permisos de un rol (SG-17),
  quitar un control a las pantallas que lo conceden, eliminar un menú, desactivar una organización,
  restablecer una contraseña, cerrar sesiones—.
- **SG-24.** *Regresar* no cabía en el pie centrado de `Rol/{Nuevo,Editar}` y `Empresa/Editar` junto
  al aviso de cambios sin guardar: las tres pasan a `.barra-acciones`, la barra fija que ya usan
  Administración y Gestión, con el indicador «Cambios sin guardar» a la izquierda.
- **SG-24.** Tras guardar, `Rol/Nuevo` abre la **ficha del rol recién creado** —que es donde se
  reparten los permisos, así que volver a la lista obligaba a entrar otra vez— y `Rol/Editar` se
  queda en la ficha en lugar de salir a la lista.
- **SG-24.** Dos bugs latentes de los que sólo se ve el efecto con datos vacíos: un usuario sin
  ninguna organización marcada y un rol sin ningún menú concedido dejaban `var x = ` sin valor en el
  `<script>`. Se cierran con `?? "[]"`.
- **SG-25.** `bg-primary` **se queda** en la cabecera de las listas: la convención de `site.css` dice
  azul = configuración, y las siete pantallas del área lo son. Lo indiscriminado era usarlo también
  en el **histórico de renovaciones** de `Empresa/Editar`, que no es configuración sino un registro
  de lo que pasó: pasa a `table-light`, como las demás sub-tablas de formulario.
- **SG-25.** El vocabulario se explica **una sola vez**, en un panel plegable de la pantalla de roles
  (`Shared/_Vocabulario.cshtml`), y las otras seis pantallas enlazan a él
  (`Shared/_EnlaceVocabulario.cshtml`). La palabra que más falta hacía era *control*: en la base de
  datos se llama `elemento` y en las pantallas se le llamaba de las dos maneras.
- **SG-25.** La convención de color de `site.css` se amplía con lo que hasta ahora sólo estaba en la
  cabeza de quien lo escribió: qué lleva `table-light` y de qué color es cada botón. *Regresar* deja
  de ser ámbar en las tres pantallas completas: salir no es una advertencia.
- **Finales de línea.** El repositorio está en CRLF (`core.autocrlf=true`). Los ficheros reescritos
  con script pierden el CRLF si no se cuida: quedan restaurados, pero conviene revisarlo si algún
  paso vuelve a editar en lote.

## 9. Fuera de alcance, con referencia

- **Protección CSRF**: los formularios llevan `asp-antiforgery="true"` pero ningún POST valida el
  token (`MNT-035`). Afecta a todos los módulos; especialmente grave aquí (un enlace basta para crear
  un usuario administrador), pero el arreglo es transversal.
- **Autorización de la API móvil**: `FiltroToken` autentica y no autoriza nada
  (`analysis/permissions.md` §1.2). Comparte con SG-08 el hash de la contraseña y con SG-11 el token.
- **`AMSYS.DemonApp`**: script de importación de usuarios; usa `ToSHA526` y habrá que adaptarlo en
  SG-08.
- **Cabeceras de seguridad y cookies** (`HttpOnly`, `Secure`, `SameSite`, HSTS): revisión aparte de
  `Program.cs`.
- ~~**`FiltroAccion` se salta `Home` y `Account`**~~ (`FiltroAccion.cs:26`): con `DS-01` a) entra en
  el alcance de SG-01, que lo convierte en una excepción declarada en lugar de una condición escrita
  dentro del filtro.

## 10. Cómo verificar cada paso

1. `dotnet build AMSYS.sln` sin nuevos avisos.
2. **Matriz de permisos**: para cada acción del área, comprobar con dos usuarios —uno con permiso y
   otro sin él— que el GET y el POST responden lo mismo que dice `analysis/permissions.md`
   actualizado. Repetir con la petición enviada directamente, sin pasar por la pantalla.
3. **Dos empresas**: crear un usuario, un rol y una organización en cada una y comprobar que ninguna
   ve ni modifica nada de la otra, ni por lista, ni por modal, ni por POST con el id ajeno.
4. **Credenciales**: entrar con un usuario creado antes de SG-08 y con otro creado después; cambiar
   la contraseña; dejar el campo vacío al editar; desactivar a un usuario conectado.
5. **Permisos**: quitar una página a un rol con un usuario conectado y comprobar que la pierde en su
   **siguiente petición**, sin que se le cierre la sesión (`DS-08`); dar un menú sin su página y
   comprobar el aviso; entrar con el rol reservado y con uno que no lo es (`DS-03`).
6. **Límites**: agotar el límite de un perfil y comprobar el rechazo en el modal y en el POST;
   guardar la ficha de empresa dos veces seguidas y comprobar que los límites no cambian.
7. Consola del navegador sin errores; ancho de 400 px; y la respuesta de las listas revisada en la
   pestaña de red para confirmar que no viaja ningún secreto.

## 11. Registro de avance

| Paso | Estado | Fecha | Commit | Notas |
|------|--------|-------|--------|-------|
| SG-01 | APLICADO | 2026-09-20 | | `DS-01` a): `FiltroAutorizacion` global — toda acción nace protegida; 10 excepciones declaradas con `[SinAutorizacion]` (login, perfil, errores, tablero). Una ruta registrada exige su propia página; una auxiliar exige el `Index` de su controlador. Denegar responde 403 con una página que explica qué hacer. Inventario en `ai/analysis/sg-01-rutas.csv` (487 rutas) y consultas en `sg-01-permisos-por-rol.sql`. **Se despliega con `AutorizacionSoloRegistra: true`** (ya está así); revisar el log unos días y sólo entonces ponerlo en `false` |
| SG-02 | APLICADO | 2026-09-19 | | `DS-03` c): el rol reservado es **SUPERADMINISTRADOR**, en `AppSettings.RolInstalacion`. `FiltroInstalacion` sobre Empresa, Renovación, Página, Menú, Rol (por `DS-02`) y las cuatro acciones de instalación de Usuario; el rol no se puede renombrar, desactivar ni quedarse sin usuarios activos; la aplicación lo comprueba al arrancar; el menú oculta lo que el usuario no puede abrir. **Falta crear el rol en la base y asignárselo a alguien antes de desplegar**, y probar con los dos tipos de usuario |
| SG-03 | APLICADO | 2026-09-19 | | Usuario y organización se buscan y actualizan dentro de su empresa, y `ActualizarAsync` devuelve si encontró el registro (antes respondía éxito sin guardar). Rol, empresa, organización superior y organizaciones asignadas se validan contra el servidor. `Usuario.Listar` **no** se filtra por empresa: tras SG-02 es la lista de la instalación (ver *Hallazgos*) |
| SG-04 | APLICADO | 2026-09-19 | | Proyección explícita en `ListarMisUsuarios` y `Listar`; `[IgnoreDataMember]` en `Clave`, `TokenWeb` y `TokenMovil`. Sólo esas dos vistas consumen los endpoints; la API móvil y la sesión no se ven afectadas |
| SG-05 | APLICADO | 2026-09-19 | | `RespuestaValidacion.CallBack` en los 12 puntos de los 6 controladores que lo reciben por la URL; `helper.html.escape` en las 6 listas con datos de usuario; `force_text: true` en los 5 árboles jstree del área. **Falta comprobarlo en el navegador** con un nombre que lleve marcado |
| SG-06 | APLICADO | 2026-09-20 | | `PuedeAgregarUsuario` se retira y la sustituye `ContarLimitesUsuariosAsync`: cuenta los usuarios **activos** contra el límite del **perfil del rol que se asigna**, y la falta de `Limitacion` es límite cero con mensaje, no excepción. El cupo se comprueba en los cuatro POST (alta de empresa y de instalación, y al activar, cambiar de perfil o mover de empresa al editar). Los tres modales muestran «Administradores 3 de 5» bajo el desplegable y deshabilitan los roles sin cupo (`helper.limiteUsuarios`). **Falta ejecutar `sg-07-limites-empresa.sql` y cargar los límites contratados**: con los límites a 0, este paso bloquea todas las altas |
| SG-07 | APLICADO | 2026-09-20 | | Los cuatro límites por perfil se piden en el alta y en la ficha, con el consumo al lado de cada uno, y ya no se pierden al guardar; `TipoPlan` se guarda; fuera el `cantidadEquipo` inexistente; el vencimiento sale del modelo de edición (lo lleva la renovación). Informe y plantilla de corrección en `ai/analysis/sg-07-limites-empresa.sql`. **Falta ejecutar el informe en la base y acordar los límites contratados antes de SG-06** |
| SG-08 | APLICADO | 2026-09-20 | | `DS-04` a): `ClaveUtilitario.Hash` guarda `pbkdf2$sha256$<iteraciones>$<sal>$<hash>` con sal de 16 bytes por usuario y 210.000 iteraciones configurables (`IteracionesClave`); `Verificar` compara en tiempo constante y entiende los dos formatos. `LoginAsync` pasa a `AutenticarAsync`, que recibe la clave **en claro** y, si la fila era antigua, la regraba con el formato nuevo en ese mismo inicio de sesión. `ToSHA526` queda `[Obsolete]` y sin un solo uso fuera del verificador. Comprobado ejecutándolo: hashes distintos para la misma clave, ambos caminos válidos, ~70 ms por comprobación. **Sin migración de esquema**: `usuario.clave` es `text` |
| SG-09 | APLICADO | 2026-09-20 | | `DS-04` a): `ClaveUtilitario.CumplePolitica` se comprueba en el **servidor** en los cuatro modales, el perfil y el cambio obligatorio; el formulario lleva indicador en vivo, confirmación, *mostrar* y *generar una segura* (`helper.clave.politica`). En la edición, *Cambiar contraseña* va en su propio bloque, con el campo vacío y la advertencia de que se cierran las demás sesiones; «vacío = no cambia» deja de depender del enlazador |
| SG-10 | APLICADO | 2026-09-20 | | `DS-05` b): sin autoservicio. Acción *Restablecer contraseña* en las dos listas de usuarios, aparte de editar; genera una temporal con `RandomNumberGenerator` que cumple la política, la muestra **una sola vez** y cierra las sesiones del usuario. `usuario.clavetemporal` (migración `Usuario_AgregarClaveTemporal`) obliga a cambiarla: `FiltroSession` sólo deja `Account/CambiarClave` y salir. El login dice a quién pedirlo. Fuera `GetPassword()` y los dos modelos muertos. **Falta aplicar la migración** y comprobarlo en el navegador. **Sin rastro hasta SG-13** (dos `TODO` marcados) |
| SG-11 | APLICADO | 2026-09-20 | | Token aleatorio de 256 bits (`TokenUtilitario`) en vez del hash de la fecha. `ValidarToken` (bool) pasa a `ValidarSesion`, que devuelve **por qué** falla —token, usuario desactivado, usuario o licencia caducados— y lo dice en la pantalla de login. Desactivar o cambiar la contraseña deja fuera las sesiones; cambiarse la propia renueva el token y cierra sólo las demás. `usuario.vencimiento` pasa a usarse. Límite de intentos por correo y origen (`ControlIntentos`, `IntentosMaximosAcceso`/`MinutosBloqueoAcceso`) |
| SG-12 | APLICADO | 2026-09-20 | | `DS-08` a): `rol.version` (migración `Rol_AgregarVersion`) sube al guardar el rol; `FiltroSession` la compara con la de la sesión y recarga páginas, menús, elementos y estados **sin cerrar la sesión**. Cambiarle el rol a un usuario tiene el mismo efecto. Va en la misma consulta de SG-11, sin añadir otra. La ficha de rol ya dice «lo verán de inmediato» |
| SG-13 | APLICADO | 2026-09-20 | | `seguridadlog` (migración `SeguridadLog_Crear`), patrón de `OrdenTrabajoLog`. Registra acceso correcto y fallido, alta, edición, baja, cambio de rol, restablecimiento y cambio de contraseña, y guardado de rol, con quién, sobre quién, cuándo, detalle y origen. Pantalla `Seguridad/SeguridadLog` filtrable por acción y fechas: cada empresa ve la suya, la instalación las ve todas. **Falta dar de alta la página en el catálogo**: `ai/analysis/sg-13-pagina-rastro.sql` |
| SG-14 | APLICADO | 2026-09-20 | | La lista plana de rutas crudas pasa a un editor agrupado por **módulo y pantalla** (`Rol/_Permisos.cshtml`, compartida por el alta y la ficha): nombre funcional delante, ruta como detalle, buscador, contador por módulo («Logística: 12 de 24»), *marcar todo el módulo* y resumen fijo. Los **controles de SG-16 cuelgan de su pantalla** y se envían: la columna *CONTROLES* deja de estar vacía. Un control se deshabilita con su pantalla. Las páginas sin ruta real salen marcadas (SG-22). Antes de guardar se avisa de los **menús concedidos cuya página no lo está** |
| SG-15 | APLICADO | 2026-09-20 | | `DS-07` a): la pestaña *Estados* deja de estar `hidden` en el alta y en la ficha, y el alta nace **sin nada marcado** en vez de con todo. El panel explica que marcar un estado es poder llevar la OT o el aviso hasta él, y los estados se muestran legibles (*CIERRE TÉCNICO*, no `CIERRE_TECNICO`). Informe previo en `ai/analysis/sg-15-estados-por-rol.sql`. **Falta ejecutarlo y recortar rol por rol** lo que ya está concedido |
| SG-16 | APLICADO | 2026-09-20 | | `DS-06` b): ciclo completo. `elemento.clave` (migración `Elemento_AgregarClave`) da un identificador estable; los controles se editan en la ficha de su página; `@Html.Elemento(...)` / `@Html.OcultarSinElemento(...)` ocultan el botón y `[ExigeElemento]` lo comprueba en el servidor. **Arreglado el fallo de fondo**: los dos filtros comparaban `Elemento.Id` con `Pagina.Id`, así que la lista de controles nunca llegaba a la vista. Cuatro controles de punta a punta: anular nota de salida, de entrada, hoja de aceptación y renovar licencia. Alta en `ai/analysis/sg-16-controles.sql`. **Falta ejecutarlo y conceder los controles** |
| SG-17 | APLICADO | 2026-09-20 | | El **perfil se puede corregir**: entra en `RolModel.Editar` y en `RolLogica.ActualizarAsync`, y el servidor rechaza el cambio si el perfil de destino no tiene cupo **en alguna de las empresas** que usan el rol. **Duplicar rol** copia páginas, menús, controles y estados. La columna *Usuarios* de la lista enlaza a esos usuarios (`Todos?rolId=`). La confirmación de guardado resume el cambio —«+3 páginas, −1 menú, perfil OPERADOR → MANTENIMIENTO»— y avisa si se está desactivando un rol con usuarios activos |
| SG-18 | APLICADO | 2026-09-20 | | `DS-02` b): siguen globales, sin migración. La lista y la ficha de rol dicen que el rol es de toda la instalación y **cuántos usuarios y de qué empresas** lo usan (columnas *Usuarios* y *Empresas*, aviso en la ficha); la confirmación de guardado los detalla antes de aceptar. El desplegable de rol del alta de usuario muestra `Nombre · PERFIL · N empresas`. Convención de nombres sugerida en el alta de rol: `<Empresa> · <Función>`. **Falta acordarla con el propietario** y comprobar la ficha en el navegador |
| SG-19 | APLICADO | 2026-09-20 | | El **rol se puede cambiar desde la empresa**: `UsuarioModel.Editar.RolId` deja de estar comentado, la lógica lo escribe, se valida contra el cupo (SG-06) y surte efecto en la siguiente petición del usuario (SG-12), quedando registrado (SG-13). Encabezado con estado, perfil, empleado enlazado, **última entrada** —del rastro de SG-13— y aviso de contraseña temporal. El árbol de organizaciones explica para qué sirve, cuenta lo marcado y trae *Toda la empresa*. Acciones separadas: *Restablecer contraseña* (SG-10) y *Cerrar sus sesiones* |
| SG-20 | APLICADO | 2026-09-20 | | La lista plana con columna *Padre* pasa a **árbol**, con el alta colgando del nodo seleccionado, **arrastrar que guarda** (`organizacion.orden`, migración `Organizacion_AgregarOrden`) y un panel de *En uso* con el desglose del nodo: usuarios, ubicaciones, equipos, avisos, órdenes y organizaciones debajo, en una consulta agrupada (`UsoOrganizacionRepositorio`). **Desactivar es acción aparte** y dice a cuántos usuarios activos se lo quita y a cuántos deja **sin ningún alcance**; no se desactiva una con hijas. Ciclos cerrados en la ficha, en el POST y en el reordenado. **Falta aplicar la migración**
| SG-21 | APLICADO | 2026-09-20 | | La lista de empresas mostraba **sólo el nombre**: ahora lleva plan, estado de licencia con la fecha y los días que quedan (vigente / por vencer a 30 días / caducada / sin licencia), usuarios activos sobre el límite y almacenamiento usado sobre el contratado, con filtros por los tres. El estado sale de `Licencia.Estado`, un solo sitio para toda la aplicación. La ficha abre con ese mismo encabezado y el histórico de renovaciones dice registro, desde, hasta y meses. El modal de renovación trae la empresa, encadena con el vencimiento actual y escribe el efecto: «la licencia pasará del 12/01/2027 al 12/01/2028»
| SG-22 | APLICADO | 2026-09-20 | | `CatalogoRutas` lee del propio enrutado las rutas que la aplicación tiene de verdad. Las páginas se registran **eligiéndolas de esa lista**, no escribiéndolas; la lista marca en ámbar las que ya no corresponden a ninguna ruta y un panel dice cuántas pantallas reales nadie registró. Menús: eliminar (diciendo a cuántos roles se lo quita y bloqueando si tiene hijos), **arrastrar que guarda** el padre y el orden, ruta elegida entre páginas registradas y validada en el servidor, y los botones dejan de no hacer nada en silencio |
| SG-23 | APLICADO | 2026-09-21 | | Las cinco listas de tabla (`Usuario/{Index,Todos}`, `Rol`, `Empresa`, `Página`) pasan a `helper.catalogo.lista`: **panel de filtros con chips**, estado de carga, fila vacía que cuenta bien las columnas (adiós al `colspan=7` sobre 6), badges de estado y de perfil, escapado en todas las celdas y pie con «Mostrando X – Y de Z». Nueva columna **PERFIL** en las dos listas de usuarios, con el perfil añadido a las dos proyecciones del controlador. `helper.catalogo.lista` gana `filaClase` para conservar el ámbar de las páginas sin ruta. Los dos árboles (Menú, Organización) reciben el recuento y el texto de «no hay ninguna» |
| SG-24 | APLICADO | 2026-09-21 | | Los **23 POST** de los siete controladores devuelven `RespuestaValidacion.Errores` y los **doce modales** pasan a `helper.catalogo.modal`: el error se marca **en su campo**, *Guardar* es `submit` (Enter guarda) y dice «Guardando…». Se quita el «¿Estás seguro de guardar?» de las altas y se conserva —explicando la consecuencia— donde hay algo que perder. `Rol/{Nuevo,Editar}` y `Empresa/Editar` estrenan `.barra-acciones` con **aviso de cambios sin guardar** y confirmación al salir; el `$('#btnGuadar')` que dejaba el botón muerto queda corregido en las dos. Tras guardar, un rol abre **su ficha**, no la lista. Fuera el `dnd` de los árboles de `Usuario/{_Nuevo,_Editar}`, donde arrastrar no significaba nada |
| SG-25 | APLICADO | 2026-09-21 | | `.tabla-apilable` con `data-label` en las cinco listas y en el histórico de renovaciones: por debajo de 992 px cada fila se lee como una tarjeta. Vocabulario del área explicado **una vez** en un panel plegable de la pantalla de roles, enlazado desde las otras seis. Color: el histórico de renovaciones deja el azul de configuración por `table-light`, *Editar* de los dos árboles pasa a `btn-light text-warning` y *Regresar* deja de ser ámbar. La convención de `site.css` se amplía con las reglas de sub-tablas y de botones |
