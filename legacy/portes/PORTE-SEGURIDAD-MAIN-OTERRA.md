# Porte del módulo de Seguridad de `main` a la rama `oterra`

Plan del 2026-11-06. **Sin implementar.** Base: `oterra` en `d07e32d` (2026-11-05), `main` en `5d228c9` (local; `origin/main`
en `be8869b`). Modelo: `legacy/portes/PORTE-SEGURIDAD-MAIN-AGCHAVIN.md` (commit `d527ecd`), que ya resolvió casi todo.

**Condición del propietario:** se conserva el **área del usuario** (`Usuario.AreaId`), propia de oterra.

## Por qué un porte y no `git merge main`

`oterra` se separó de `main` el 2023-10-18 (`050727c`): 122 commits detrás, 30 propios, 862 archivos distintos y
**cadenas de migraciones EF distintas** (20 propias de oterra frente a 42 de main). Un `git merge` traería todos los
módulos de main y migraciones que la base `amsys_v3_oterra` no puede aplicar. Se hace como en agchavin: rama nueva
desde `oterra`, archivos de Seguridad traídos de `main` con `git checkout main -- <ruta>`, fusiones a mano donde oterra
tiene algo propio y **una sola migración nueva generada en oterra**.

## Diagnóstico

- oterra no tiene **ningún** paso SG (SG-01 a SG-25 de `legacy/planes/PLAN-UX-SEGURIDAD.md`): ni `Perfil`, ni licencias,
  ni contraseñas con sal (sigue HMAC-SHA256 con clave fija), ni filtro global de autorización, ni rastro, ni
  `Menu.Orden`. Detalle en la comparación del 2026-11-06 (108 archivos de seguridad distintos).
- Lo **propio de oterra** en seguridad es solo el área del usuario (commit `32f78b7`, migración
  `20240601031435_Usuario_Aviso_Modificar_1`), más las navegaciones de `Empresa` hacia sus módulos propios
  (`Areas`, `ImpactosProceso`, `Conformidades`, `Paradas`).
- Diferencias con agchavin que cambian el porte:
  1. **Front**: agchavin ya tenía la UI de main (`PORTE-UI-MAIN-AGCHAVIN.md`). oterra **no**: las vistas de Seguridad
     de main usan funciones de `helper.js` que oterra no tiene (`mostrarErrores`, `limpiarErrores`, chips, `Listar`,
     cupo/uso…) y `Rol/Index` y `SeguridadLog/Index` usan `columnas.js` / `Sortable` / `VistaLista`. Ver decisión D1.
  2. **`menu.orden`** no existe en oterra (en main viene de `20240110231530_Menu_Modificar_1`): va en la migración.
  3. La **API móvil** de oterra (`WebAdmin/Api/Controllers/UsuarioController.cs`) llama a `LoginAsync` con la clave
     **ya cifrada** (`ToSHA526`). Con SG-08 hay que pasarle la clave en claro a `AutenticarAsync`.
  4. oterra no tiene `IEmailService` (igual que agchavin): `Usuario.Logica` sin el correo de alta.

## Decisiones

| Id | Decisión | Recomendación |
|---|---|---|
| D1 | Front de las vistas de Seguridad | **B**: traer las vistas de main y añadir a `helper.js` / `site.css` de oterra **solo** las funciones y clases que usan (aditivo; no cambia las demás pantallas). `Rol/Index` y `SeguridadLog/Index` sin columnas configurables (tabla fija). La alternativa A (portar antes toda la UI de main, como en agchavin) es un trabajo aparte de ~200 archivos |
| D2 | Nombre del rol de instalación (`AppSettings.RolInstalacion`) | Usar el rol que ya administra oterra en `amsys_v3_oterra` (consultar `select id, nombre from rol`), como se hizo con `SUPER ADMIN` en agchavin |
| D3 | `AutorizacionSoloRegistra` | `true` al desplegar; `false` solo tras revisar el log unos días |
| D4 | Navegación `Usuario.NotificacionesMaterial` de main | **No** traerla (igual que agchavin): no es de seguridad y generaría una FK ajena en la migración |

## Área del usuario: puntos que hay que conservar

Al traer cada archivo de main, volver a poner lo de oterra en estos puntos (todos verificados en `d07e32d`):

| # | Archivo | Qué conservar |
|---|---|---|
| A1 | `AMSYS.Entidades/Seguridad/Genericos/Usuario.cs` | `public int? AreaId`, `public Area? Area`, `using AMSYS.Entidades.Administracion.Genericos` (sobre la versión de main con `ClaveTemporal` e `[IgnoreDataMember]`) |
| A2 | `AMSYS.Configuraciones/Seguridad/Usuario.Config.cs` | `Property(x => x.AreaId).HasColumnName("areaid")` junto a `clavetemporal`. La relación sigue en `Administracion/Area.Config` (no se toca) |
| A3 | `AMSYS.Logicas/Seguridad/Usuario.Logica.cs` (`ActualizarAsync`) | `_.AreaId = entidad.AreaId`. En oterra solo se asigna cuando **no** es `comoAdministrador`; mantener esa regla dentro de la versión de main (SG-03, devuelve `bool`) |
| A4 | `AMSYS.Logicas/Seguridad/Usuario.Logica.cs` (`GuardarAsync`) | Comprobar que el alta guarda `AreaId` (viene en la entidad del modelo) |
| A5 | `AMSYS.WebAdmin/Areas/Seguridad/Models/Usuario.Model.cs` | `AreaId` en los modelos de nuevo y editar y su paso a la entidad |
| A6 | `AMSYS.WebAdmin/Areas/Seguridad/Controllers/Usuario.Controller.cs` | `IAreaServicio` en el constructor y `ViewBag.Areas` en `Nuevo` y `Editar` (GET) |
| A7 | `Areas/Seguridad/Views/Usuario/_Nuevo.cshtml`, `_Editar.cshtml` | Selector `asp-for="AreaId"` (lista `ViewBag.Areas`, `Id`/`Descripcion`) y `'areaId'` en el envío AJAX. Las vistas `*Admin` no lo llevan (tampoco en oterra) |
| A8 | `AMSYS.WebAdmin/Commons/Session/UserInformation.cs` | `public int? AreaId` y `AreaId = usuario.AreaId` en la carga. Lo usa `Gestion/Aviso.Controller.cs:85` para el área por defecto del aviso |
| A9 | `AMSYS.Repositorios/Seguridad/Usuario.Repositorio.cs` | Que la consulta del login/sesión de main siga trayendo `areaid` (es columna, no `Include`; revisar si main proyecta campos) |
| A10 | Migración nueva | **No** debe tocar `usuario.areaid` ni la FK a `area`. Si aparece un `DropColumn`/`DropForeignKey` de área, falta A1/A2 |

## Fases

### F0. Preparación
- Rama `seguridad-desde-main` desde `oterra` (`d07e32d`).
- Respaldo `pg_dump` de `amsys_v3_oterra` en localhost antes de migrar.

### F1. Entidades, DTOs y utilitarios (copiar de main)
- Tal cual: `Perfil.cs`, `Seguridad/Licencia.cs`, `SeguridadLog.cs`, filtros (`Rol`, `Empresa`, `SeguridadLog`), DTOs
  (`UsoRolDTO`, `ConsumoUsuariosDTO`, `LimitesUsuariosDTO`, `UsoEmpresaDTO`, `UsoOrganizacionDTO`, `SesionDTO`),
  constantes `EstadoLicencia` (y `TipoPlan` si difiere), `Elemento.cs`, `Rol.cs`, `Menu.cs`, `Organizacion.cs`.
- `Limitacion.cs`: base de oterra + las 4 cantidades por perfil.
- `Empresa.cs`: base de **oterra** (conserva `Areas`, `ImpactosProceso`, `Conformidades`, `Paradas`); añadir solo lo
  que main use de seguridad.
- `Usuario.cs`: main + A1 − D4.
- `AMSYS.Utilitarios`: `Clave.Utilitario.cs`, `Criptografia.Utilitario.cs` (comentarios), `Token.Utilitario` si
  difiere, `AppSettings.cs` (claves de seguridad).

### F2. Configuración EF, contexto y migración
- `AMSYS.Configuraciones/Seguridad/*` de main, con A2. Quitar `sealed` no importa; conservar lo de oterra en
  `Limitacion.Config` (añadir las 4 columnas).
- `AMSYSContexto`: `DbSet<SeguridadLog>` y su configuración.
- `dotnet ef migrations add Seguridad_PortarDesdeMain -p AMSYS.Contextos -s AMSYS.WebAdmin`. Debe contener **solo**:
  `rol.perfil`, `rol.version` (default 1), 4 columnas en `limitacion`, `usuario.clavetemporal`, tabla `seguridadlog`,
  `elemento.clave` + índice único `(paginaid, clave)`, `organizacion.orden`, `menu.orden`.
- Añadir a mano, antes del índice, `UPDATE elemento SET clave = 'elemento-' || id` (como en agchavin).
- Comprobar A10.

### F3. Repositorios, lógicas y servicios (copiar de main)
- `AMSYS.Repositorios/Seguridad/*`, `AMSYS.Logicas/Seguridad/*`, `AMSYS.Servicios/Seguridad/*` de main.
- `BaseRepositorio`: añadir `Detach()` (aditivo; `Queryable()` ya existe en oterra — verificar firma).
- `Usuario.Logica.cs`: main sin `IEmailService` + A3/A4.
- `Empresa.Logica.cs`: desaparece `PuedeAgregarUsuario`; revisar que nada más de oterra lo llame.

### F4. WebAdmin: sesión, autorización y arranque
- De main: `Commons/Session/*` (catálogos, `FiltroAutorizacion`, `FiltroInstalacion`, `ExigeElemento`, `ControlIntentos`,
  `RolInstalacion`, `SinAutorizacion`…), `Commons/Token/FiltroToken.cs`, `Commons/RespuestaValidacion.cs`,
  `AccountController` + `Account.Model` + vistas `Account/Login`, `CambiarClave`, `Perfil`, `ErrorController` y
  vistas de error.
- `UserInformation.cs`: main + A8.
- `Program.cs` **a mano** (como agchavin): catálogos, `ControlIntentos`, `ClaveUtilitario.Iteraciones`, filtro global,
  comprobación del rol de instalación, `ISeguridadLogServicio`, `IElementoServicio`. Sin `IEmailService` ni `VistaLista`.
- `appsettings.json`: solo las 5 claves (`RolInstalacion` según D2, `AutorizacionSoloRegistra=true`,
  `IteracionesClave`, `IntentosMaximosAcceso`, `MinutosBloqueoAcceso`). **No** traer la sección `Email` de main.
- `[SinAutorizacion]` en `HomeController` y `ErrorController`. `HomeController` de oterra se conserva (dashboard
  propio); solo se le añade el atributo.

### F5. Área Seguridad (controladores, modelos, vistas)
- Todo `Areas/Seguridad` de main, incluidas `Rol/_Permisos`, `SeguridadLog/Index`, `Shared/_Vocabulario`,
  `_EnlaceVocabulario`, y `Views/Shared/_PieModalCatalogo.cshtml`.
- Usuario: A5, A6, A7.
- `_Sidebar.cshtml` / `_Layout.cshtml`: solo lo que necesita SG-12/SG-22 (orden de menú); el resto del layout de
  oterra se queda.

### F6. Front (según D1, opción B)
- Llevar a `wwwroot/js/helper.js` de oterra las funciones de main que usan las vistas de Seguridad y Account
  (`mostrarErrores`, `limpiarErrores`, chips, `Listar`, cupo/uso, generar/restablecer clave…), sin cambiar las que
  oterra ya usa (`guardar`, `limpiar`, `restaurar`, `controles`). Si un nombre choca, gana la de oterra y la de main se
  renombra en las vistas de Seguridad.
- `site.css`: solo las clases que aparecen en esas vistas.
- `Rol/Index`, `SeguridadLog/Index`: quitar `columnas.js`/`VistaLista` y dejar tabla fija.

### F7. Fuera del área Seguridad
- **API móvil** (`WebAdmin/Api/Controllers/UsuarioController.cs`): `AutenticarAsync(correo, clave)` con la clave
  **en claro** (hoy se cifra antes); el resto como en main (claim `empresaid`, `ValidarSesion`).
- Logística SG-16: `[ExigeElemento]` en anular de `NotaEntrada`, `NotaSalida` y `HojaAceptacion`, y
  `Html.Elemento(...)` en sus `Index` (oterra los tiene, con su propia UI: adaptar solo la condición del botón).
- `AMSYS.WebAPI`, `DemonApp`, `AddDataApp`: no usan login ni token en oterra (verificado); nada que cambiar.

### F8. Compilar y revisar
- `dotnet build` sin errores; `dotnet ef migrations has-pending-model-changes` limpio tras la migración.
- `git diff oterra -- '*Usuario*' '*UserInformation*'` para confirmar A1-A9.
- Commit separado: `feat: portar el modulo de seguridad de main conservando el area del usuario`.

### F9. Datos (antes de que entre nadie)
Scripts en `legacy/analisis/`:
1. Rol de instalación (D2) y asignarlo a quien administra.
2. **Perfil** a cada rol (`rol.perfil` llega `NULL`).
3. **Límites por perfil** de la empresa (`sg-07-limites-empresa.sql`): con 0, SG-06 bloquea todas las altas.
4. Página del rastro (`sg-13-pagina-rastro.sql`) y controles (`sg-16-controles.sql`), concedidos al rol de instalación.
5. Estados por rol (`sg-15-estados-por-rol.sql`).
6. **Pantallas propias de oterra** en Seguridad → Páginas: `Administracion/Area`, `Conformidad`, `ImpactoProceso`,
   `Gestion/Parada`, `EquipoSistema`, indicadores de confiabilidad, reporte PDF de OT, proyección. Con
   `AutorizacionSoloRegistra=true` no se bloquea: revisar el log "Autorización (sólo registro)".

### F10. Pruebas
Checklist de `PORTE-SEGURIDAD-MAIN-AGCHAVIN.md`, más:
- [ ] Alta de usuario con área → se guarda `usuario.areaid`.
- [ ] Editar usuario cambiando el área → se guarda; editar como administrador (`_EditarAdmin`) no la borra.
- [ ] Usuario con área crea un aviso → el aviso nace con su área (`Aviso.Controller:85`).
- [ ] Pantallas de Seguridad con el front de oterra: errores de validación, chips, modales, árbol de organizaciones
      y menús (arrastrar).
- [ ] App móvil: login con la clave en claro y llamadas posteriores con el token.

## Riesgos

- **Contraseñas sin vuelta atrás**: un usuario que entra queda regrabado en PBKDF2; si se revierte el código, ya no
  puede entrar con la versión anterior.
- **Altas bloqueadas** si no se cargan los límites por perfil (F9.3).
- **Pantallas propias sin página**: con `AutorizacionSoloRegistra=false` se negarían; por eso D3.
- Main local (`5d228c9`) está por delante de `origin/main` (`be8869b`); los commits nuevos no tocan Seguridad.

## Bitácora

| Fecha | Qué |
|---|---|
| 2026-11-06 | Plan escrito (sin implementar). Pendientes D1 y D2 |
