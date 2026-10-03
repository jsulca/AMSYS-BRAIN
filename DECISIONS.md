# Decisiones

## Tomadas

| ID | Fecha | Decisión | Motivo |
|----|-------|----------|--------|
| `D-NP-00` | 2026-10-02 | Nueva plataforma (Opción 3: un producto configurable); el repo actual pasa a legacy | Ramas por cliente no escalan: correcciones N veces, migraciones incompatibles |
| `D-NP-01` | 2026-10-02 | Front en **Blazor Server** (`InteractiveServer`). Se eliminó `Amsys.Web.Client` | Decisión del propietario. Sin descarga inicial, depuración simple. **Mitigar**: reconexión de circuito y, si hay varias réplicas (k8s), afinidad de sesión (sticky sessions) |
| `D-NP-01b` | 2026-10-02 | Aunque sea Server, el front **consume `Amsys.Api` por HTTP** (sólo referencia `Contracts`), no `Application` directamente | Una sola fuente de lógica y autorización, la misma que usa la app móvil. Revisable si la latencia lo exige |
| `D-NP-02` | 2026-10-02 | Repo **`amsys`**; el legacy se renombra a `AMSYS-legacy`. Namespaces `Amsys.*`, carpeta `D:\Documentos\Amsys`; se mantiene la marca AMSYS | Clientes conocen la marca; distinguir código nuevo del legacy |
| `D-NP-03` | 2026-10-02 | **Minimal APIs** agrupadas por módulo con `MapGroup` | Decisión del propietario |
| `D-NP-04` | 2026-10-02 | **Nueva versión de la app móvil** contra `/api/v1`; la API legacy sigue viva hasta el corte de cada cliente | Decisión del propietario |
| `D-NP-06` | 2026-10-02 | API separada (`Amsys.Api`) como único backend para web y móvil | Una sola fuente de lógica y autorización |
| `D-NP-08` | 2026-10-02 | `NombreUsuario` **único en toda la BD** (índice único parcial, los eliminados liberan el nombre) | El login ocurre antes de saber la empresa |
| `D-NP-09` | 2026-10-02 | Claves primarias `int` identity | Igual que el legacy: simplifica el ETL de migración de clientes |
| `D-NP-10` | 2026-10-02 | Sin empresa actual, las consultas de entidades por empresa devuelven vacío (seguro por defecto). Procesos del sistema (semillas, ETL) escriben con `EmpresaId` explícito | Imposible filtrar datos por olvido |
| `D-NP-11` | 2026-10-02 | Reloj = `TimeProvider` de .NET (no interfaz propia `IReloj`) | Estándar del framework, testeable |
| `D-NP-12` | 2026-10-02 | Application usa EF Core a través de `IAmsysDbContext` (sin repositorios) y devuelve DTOs de `Contracts` | Menos capas y mapeos; los filtros globales siguen aplicando |
| `D-NP-13` | 2026-10-02 | JWT de 15 min + token de refresco de 7 días, rotado en cada uso, guardado como hash, con detección de reuso | Sesiones largas sin tokens de acceso largos; un token robado se invalida al reutilizarse |
| `D-NP-14` | 2026-10-02 | Límite de 10 intentos/min por IP en login y refresco | Fuerza bruta. Pendiente: bloqueo por usuario |
| `D-NP-15` | 2026-10-02 | Errores de API como ProblemDetails con un `codigo` estable (`Auth.CredencialesInvalidas`, …) | El front y la app móvil deciden por código, no por texto |
| `D-NP-16` | 2026-10-02 | ~~Temporal: `seguridad/usuarios` sólo exige estar autenticado~~ → **resuelto 2026-10-03**: exige `seguridad.usuarios.ver` | — |
| `D-NP-17` | 2026-10-02 | Web: los tokens de la API **no** llegan al navegador; viven en el servidor web y la cookie sólo lleva un id de sesión | Un XSS no puede robar tokens; Blazor Server ya mantiene estado en servidor |
| `D-NP-18` | 2026-10-02 | Web: `InteractiveServer` **sin prerender** | Evita doble ejecución de páginas y llamadas a la API, y redirecciones durante el prerender |
| `D-NP-19` | 2026-10-02 | Usuario con cambio de clave pendiente sólo puede usar `auth/yo` y `auth/cambiar-clave` (API) y la página de cambio de clave (web) | Forzar el cambio de la clave inicial o restablecida |
| `D-NP-20` | 2026-10-03 | La configuración de cada cliente es un **archivo versionado** (`tools/clientes/<codigo>/configuracion.json`) aplicado con el Migrator; la pantalla de administración llega con los permisos (NP-1) | Reproducible, revisable en git, sirve para migrar cada cliente del legacy |
| `D-NP-21` | 2026-10-03 | Módulos definidos en código; el núcleo (Seguridad, Administración, Activos, Mantenimiento correctivo) siempre activo | Un módulo es funcionalidad programada; activar es configuración |
| `D-NP-22` | 2026-10-03 | Estados canónicos tomados del legacy `main`: Aviso (Emitido, Aprobado, Atendido, Finalizado, Rechazado), OT (Emitido, CierreTecnico, CierreTotal, Anulado), TipoAviso (SolicitudTrabajo, Falla) | Un solo modelo; cada cliente cambia nombres y colores con etiquetas |
| `D-NP-24` | 2026-10-03 | Permisos: catálogo en código (`Domain/Seguridad/Permisos.cs`, `modulo.recurso.accion`), un rol por usuario, rol Administrador por empresa con todo; **se evalúan en cada petición** (caché 1 min, invalidado al editar roles) en vez de copiarse al iniciar sesión | En el legacy quitar un permiso no surtía efecto hasta volver a entrar |
| `D-NP-25` | 2026-10-03 | Nadie puede asignar a un rol permisos que él mismo no tiene | Evita la escalada de privilegios |
| `D-NP-26` | 2026-10-03 | Toda política de endpoint parte de `ExigirSesionConClaveVigente`; `RequierePermiso` la incluye | Al declarar una política propia, ASP.NET deja de aplicar la del grupo |
| `D-NP-27` | 2026-10-03 | Al crear un usuario o restablecer su clave, el servidor genera una **contraseña temporal** (12 caracteres) que se muestra una sola vez; el usuario debe cambiarla | Nadie elige claves por otro; se fuerza el cambio |
| `D-NP-28` | 2026-10-03 | Bloqueo tras 5 intentos fallidos seguidos durante 15 min; durante el bloqueo no se comprueba la clave; el administrador puede desbloquear | Fuerza bruta por usuario (complementa el límite por IP) |
| `D-NP-29` | 2026-10-03 | Nadie puede desactivarse ni cambiarse el rol a sí mismo; sólo se asignan roles cuyos permisos tiene quien asigna | Evita quedarse sin acceso y la escalada de privilegios |
| `D-NP-30` | 2026-10-03 | Catálogos simples: una clase y una tabla por catálogo (herencia TPC) con un único código genérico, en vez de una tabla común | Cada FK futura apunta a su catálogo (integridad), sin repetir código 14 veces |
| `D-NP-31` | 2026-10-03 | Los catálogos no se eliminan: se desactivan (dejan de ofrecerse para elegir, los datos que los usan se conservan) | Igual que el legacy; evita referencias rotas |
| `D-NP-33` | 2026-10-03 | Equipo: datos generales (fabricante, marca, modelo, serie, activo fijo, fechas y valores) y horario de operación como **columnas**; lo propio de cada cliente, como campo personalizado | Lo tienen todos los clientes en el legacy (`EquipoGeneral`) |
| `D-NP-34` | 2026-10-03 | Un equipo se monta en una ubicación **o** en otro equipo, no en ambos; el montaje sólo cambia con montar/desmontar, que dejan historial | Regla del legacy hecha explícita; el legacy permitía ambos campos |
| `D-NP-35` | 2026-10-03 | El árbol muestra inactivos (atenuados); los equipos sin montar no aparecen en el árbol (sí en la lista) | DE-02 del legacy |
| `D-NP-36` | 2026-10-03 | Datos técnicos (por clase de equipo) y campos personalizados (por empresa y entidad) son mecanismos distintos y conviven | Los técnicos dependen de la clase del equipo; los personalizados, del cliente |
| `D-NP-37` | 2026-10-03 | Un tipo de equipo en uso no se quita (se desactiva); un dato técnico con valores no se quita | No perder datos ni dejar equipos con referencias rotas |
| `D-NP-38` | 2026-10-03 | Un solo contador **activo** por equipo y unidad de servicio | Los planes por contador no deben tener ambigüedad sobre qué contador leer |
| `D-NP-39` | 2026-10-03 | Lecturas de contador: no futuras, no anteriores a la última; acumuladas no bajan. Mediciones atrasadas sí se aceptan (sólo historial) | Un contador alimenta la programación; un punto de medida sólo informa |
| `D-NP-40` | 2026-10-03 | Registrar lecturas y mediciones es un permiso aparte de editar activos | Los técnicos registran en campo sin poder modificar equipos |
| `D-NP-07` | 2026-10-02 | .NET 10, `.slnx`, Central Package Management, xunit.v3 + Microsoft.Testing.Platform | Estándar actual; versiones centralizadas |

### Heredadas del legacy (vinculantes)

| ID | Decisión |
|----|----------|
| `D-05` | Generación de OT desde planes **a demanda**, nunca automática |
| `D-02` | No se puede anular una OT en `CIERRE_TECNICO` |
| `D-03` | Códigos no únicos: alerta, no bloqueo |

## Pendientes

| ID | Pregunta | Recomendación |
|----|----------|---------------|
| `D-NP-05` | ¿Qué se sigue haciendo en el legacy? | Sólo hotfix y seguridad crítica |
| `D-MC-01` | ¿Instancia + BD por cliente o multi-tenant único? | Por cliente al inicio (mismo artefacto); multi-tenant después |
| `D-MC-02` | Campos personalizados en JSONB o columnas | JSONB — **validador ya implementado sobre este supuesto**; confirmar |
| `D-NP-32` | ¿Se limita lo que ve cada usuario por organización (como `UsuarioOrganizacion` del legacy)? ¿Ver la organización y sus descendientes? | Sí, como filtro global adicional al de empresa |
| `D-NP-23` | ¿Se reincorporan `PROGRAMADO` (estado de OT) y `PARADA` (tipo de aviso)? Están comentados en el legacy | Decidir antes de NP-3 |
| `D-MC-03` | ¿Estados renombrados de caja_arequipa equivalen a los canónicos? | Confirmar con el cliente |
| `D-MC-04` | Módulos de oterra (Área, Impacto, Conformidad, Turnos): ¿producto o exclusivos? | Producto |
| `D-MC-05` | Soft delete para todos | Sí — **ya implementado así en `Entidad`**; confirmar |
| `D-MC-06` | Versión base de MTBF/MTTR/Disponibilidad | La de oterra, revisada con cada cliente |
