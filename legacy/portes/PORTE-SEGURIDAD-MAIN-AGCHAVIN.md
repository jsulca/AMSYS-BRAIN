# Porte del módulo de Seguridad de `main` a la rama `agchavin`

Estado al 2026-10-31. **Sin commit** (convive en el árbol con el trabajo sin commit de programación de OT). Compila
con 0 errores. **Migración aplicada en localhost** (`amsys_v3_agchavin`, 2026-10-31); falta servidor/producción.
**No se ha probado en el navegador.**

### Localhost preparado (2026-10-31)

- Migración `20261101015429_Seguridad_PortarDesdeMain` aplicada (la tabla `elemento` estaba vacía: sin claves provisionales).
- Rol de instalación: en agchavin se llama **`SUPER ADMIN`** → `appsettings.json` lleva `"RolInstalacion": "SUPER ADMIN"`
  (no `SUPERADMINISTRADOR` como en `main`). Comprobado al arrancar: sin error.
- Perfiles: SUPER ADMIN y ADMINISTRADOR → ADMINISTRADOR (0); TECNICO → MANTENIMIENTO (1).
- Límites **de prueba** 10 / 10 / 0 / 0 (administrador / mantenimiento / operador / cliente). En producción, los contratados.

Objetivo: que todos los clientes tengan la misma seguridad que `main` (plan `legacy/planes/PLAN-UX-SEGURIDAD.md`,
SG-01…SG-25, aplicado en `main` el 2026-09-19/21). En `PORTE-UI-MAIN-AGCHAVIN.md` la seguridad había quedado fuera.

## Diagnóstico previo

- `agchavin` no tenía **ningún** paso SG: ni `Perfil` (migración `Add_Perfil` de `main`, 2025-02), ni licencias,
  ni contraseñas con sal, ni filtro global de autorización, ni rastro.
- Lo propio de `agchavin` en seguridad desde la bifurcación (`a69f854`) era solo `BuscarOrganizacionIdsAsync`, que
  `main` también tiene. Por eso casi todo se trajo **tal cual** de `main`.

## Qué se hizo

| Parte | Cómo |
|---|---|
| 115 archivos de seguridad (`Areas/Seguridad`, `*/Seguridad/*`, `Commons/Session`, `Commons/Token`, `Account`, `Api/UsuarioController`, `Clave/Token/Criptografia.Utilitario`, `AppSettings`, `Perfil`, `Licencia`, DTOs de uso/sesión/límites) | Copiados de `main` (sin cambios propios de agchavin en ellos) |
| `Usuario.Logica.cs` | De `main`, **sin** `IEmailService` (correo al crear usuario: función de eulen que agchavin no tiene) |
| `Usuario.cs` | De `main`, **sin** la navegación `NotificacionesMaterial` (otra función; generaba una columna ajena en la migración) |
| `BaseRepositorio` | Añadidos `Queryable()` y `Detach()` (aditivos, de `main`) |
| `Program.cs` | Fusión a mano: catálogos (páginas, rutas, elementos), `ControlIntentos`, `ClaveUtilitario.Iteraciones`, filtro global `FiltroAutorizacion`, comprobación del rol de instalación al arrancar, `ISeguridadLogServicio`, `IElementoServicio` |
| `appsettings.json` | Solo las 5 claves: `RolInstalacion=SUPERADMINISTRADOR`, `AutorizacionSoloRegistra=true`, `IteracionesClave`, `IntentosMaximosAcceso`, `MinutosBloqueoAcceso`. **No** se trajo la sección `Email` de `main` (tiene contraseña SMTP versionada) |
| `AMSYSContexto` | `DbSet<SeguridadLog>` y su configuración |
| Logística (SG-16) | `[ExigeElemento]` en anular nota de entrada, de salida y hoja de aceptación; `Html.Elemento` / `OcultarSinElemento` en `NotaEntrada` y `NotaSalida` (`Index`, `Ver`), donde el porte de UI había dejado `puedeAnular = true` |
| Excepciones (SG-01) | `[SinAutorizacion]` en `HomeController`, `ErrorController` y `VistaListaController`, como en `main` |
| `AMSYS.WebAPI/Filtros/FiltroToken.cs` (proyecto que solo existe en agchavin) | `ValidarToken` → `ValidarSesion(...).Valida`, leyendo también el claim `empresaid` (lo emite el login de `WebAdmin/Api`) |
| Migración `20261101015429_Seguridad_PortarDesdeMain` | Equivale a las 6 de `main` (`Add_Perfil`, `Usuario_AgregarClaveTemporal`, `Rol_AgregarVersion`, `SeguridadLog_Crear`, `Elemento_AgregarClave`, `Organizacion_AgregarOrden`). Añade un `UPDATE elemento SET clave = 'elemento-' \|\| id` antes del índice único `(paginaid, clave)`: sin él, una página con dos elementos haría fallar la migración (en `main` el riesgo sigue) |

Diferencias que quedan con `main` en seguridad: solo las dos marcadas arriba (correo y `NotificacionesMaterial`).

## Siguientes pasos (en orden)

1. ~~Aplicar la migración en localhost~~ (hecho). En servidor/producción: script solo de esta
   migración (`dotnet ef migrations script 20261030152417_OrdenTrabajo_AgregarProgramacion -p AMSYS.Contextos -s AMSYS.WebAdmin -o seguridad.sql`;
   depende de que la de programación vaya antes). Decisión del propietario.
2. **Datos, antes de que entre nadie** (si no, se bloquean altas o la administración):
   - Crear el rol `SUPERADMINISTRADOR` y asignarlo a quien administre la instalación (SG-02).
   - Asignar **perfil** a cada rol existente (`rol.perfil` llega `NULL`).
   - Cargar los **límites por perfil** de la empresa: con 0, SG-06 **bloquea todas las altas de usuario**
     (`legacy/analisis/sg-07-limites-empresa.sql`).
   - Página del rastro: `legacy/analisis/sg-13-pagina-rastro.sql`. Controles: `sg-16-controles.sql` y concederlos.
   - Estados por rol: informe `sg-15-estados-por-rol.sql` y recortar.
3. **Registrar las pantallas propias de agchavin** en Seguridad → Páginas (indicadores, indicador mundial, reportes
   extra, Programación de empleados, Notificación de tareas). Con `AutorizacionSoloRegistra=true` no se bloquea:
   revisar el log unos días ("Autorización (sólo registro)") y solo entonces ponerlo en `false`.
4. Contraseñas: las SHA antiguas siguen valiendo y se regraban a PBKDF2 al entrar (SG-08). **No hay vuelta atrás**
   para un usuario que ya entró: si se despliega y se revierte el código, ese usuario no podrá entrar con la versión
   anterior.
5. Probar en el navegador (checklist abajo) y commit.

## Checklist de pruebas

- [ ] Login correcto, login fallido 5 veces → bloqueo 15 min; mensaje de por qué falla la sesión.
- [ ] Usuario existente entra con su clave antigua y queda regrabado en `pbkdf2$…`.
- [ ] Restablecer contraseña → temporal mostrada una vez → obliga a `Account/CambiarClave`.
- [ ] Cambiar un permiso de rol → el usuario conectado lo ve sin volver a entrar (SG-12).
- [ ] Rastro (`Seguridad/SeguridadLog`) registra accesos, altas, cambios de rol y de clave.
- [ ] Editor de permisos por módulo (`Rol/_Permisos`), duplicar rol, estados visibles.
- [ ] Organizaciones en árbol, arrastrar y desactivar con aviso de uso.
- [ ] Empresas: licencia, límites por perfil, renovación.
- [ ] Anular nota de entrada/salida y hoja de aceptación: oculto sin el control, 403 por POST directo.
- [ ] App móvil: login (`WebAdmin/Api`) y llamadas a `AMSYS.WebAPI` con el token (ahora validan usuario activo y vencimientos).

## Pendiente fuera de este porte

- `appsettings.json` de agchavin tiene secretos versionados (token SendGrid, `SecretKeyToken`): rotarlos y moverlos
  a user-secrets (MC-00 de `legacy/planes/PLAN-MULTICLIENTE.md`).
