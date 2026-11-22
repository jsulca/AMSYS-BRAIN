# App móvil AG Chavín (Flutter): cambios de API respecto a main

> Rama de la API: `agchavin` (commit `3e49042`, 2026-11-22). Proyecto: `AMSYS.WebAdmin/Api`.
> Este documento es para el desarrollador de la app móvil Flutter.

## Contexto

La app móvil se hizo sobre la API de AMSYS (rama `main`). La API de AG Chavín se igualó a la de main el 2026-11-22:
**mismas rutas** (`api/[Controller]/...`), **mismo login** (`POST api/Usuario`), **mismo token JWT** y **mismos JSON**.

A diferencia de Oterra, AG Chavín **no agrega campos** en avisos ni en órdenes de trabajo. Solo hay tres diferencias:

1. `api/WorkOrderKanban` no existe.
2. `codigoExterno` ya no existe en la orden de trabajo.
3. El PDF de la OT tiene otro formato.

Todo lo que no aparece en este documento funciona igual que en main.

### Cómo crear la app de AG Chavín

1. En el repositorio de la app, crea la rama desde `main` (por ejemplo, `agchavin`).
2. Cambia la URL base de la API por la del servidor de AG Chavín. Pídela al equipo de AMSYS.
3. Aplica los cambios de la sección 2.
4. Cambia la marca (nombre, ícono y logo) si se requiere. La API no lo exige.

> ⚠️ **Despliegue:** la API de `3e49042` todavía no está desplegada en el servidor de AG Chavín. La versión publicada
> ahora es la antigua: no tiene `gestionar`, `editar`, `notificar` ni la mayoría de los controladores de notificaciones.
> Antes de probar contra el servidor, confirma con el equipo de AMSYS que ya se desplegó.

### Convenciones del JSON (igual que en main)

| Tema | Regla |
|---|---|
| Nombres | camelCase |
| Fechas en respuestas | Texto con formato `dd/MM/yyyy HH:mm` |
| Nulos | **No se envían**: si un campo es `null`, no aparece en el JSON. Decláralo nullable en Dart |
| Enums | Llegan como **número** |
| Errores de validación | HTTP 400 con un **arreglo de strings**. Muestra todos los mensajes |

---

## 1. Endpoints disponibles (iguales a main)

| Controlador | Endpoints |
|---|---|
| `Usuario` | `POST` (login) |
| `Aviso` | `listar`, `parametros`, `buscar`, `guardar`, `actualizar`, `gestionar/listar`, `gestionar/parametros`, `gestionar` |
| `AvisoAdjunto` | `listar`, `eliminar` |
| `OrdenTrabajo` | `listar`, `gestionar/listar`, `guardar`, `editar`, `buscar`, `notificar`, `parametros`, `pdf/{id}` |
| `OrdenTrabajoAdjunto` | `listar`, `eliminar` |
| `Adjunto` | `guardartemporales`, `eliminartemporal`, `buscar` |
| `Empleado`, `Ubicacion` | `listar` |
| `Equipo` | `listar`, `buscarubicacion` |
| `Seccion` | `buscar`, `tareas` |
| `NotificacionTarea` | `listar`, `buscar`, `guardar`, `eliminar`, `en-ejecucion`, `iniciar`, `detener` |
| `NotificacionEmpleado` | `listar`, `guardar`, `eliminar` |
| `NotificacionMaterial` | `listar`, `buscar`, `guardar`, `eliminar` |
| `NotificacionContador`, `NotificacionPuntoMedida`, `NotificacionEquipoAspecto` | `listar`, `buscar`, `guardar` |

Los parámetros, los cuerpos y las respuestas son **los mismos que en main**.

---

## 2. Cambios a hacer en la app

### 2.1 Quitar el Kanban

**`api/WorkOrderKanban` no existe en AG Chavín** (`tablero`, `columna`, `mover`): responde 404. Si la app lo
referencia, quita la pantalla o el acceso.

### 2.2 Quitar `codigoExterno` de la orden de trabajo

- `GET api/OrdenTrabajo/buscar`: `codigoExterno` **ya no viene**. Quítalo de la UI.
- `POST api/OrdenTrabajo/guardar` y `editar`: ya no se envía. Si se envía, la API lo ignora.

### 2.3 PDF de la OT (`GET api/OrdenTrabajo/pdf/{id}`)

- La ruta, la respuesta (`application/pdf`) y el nombre del archivo (`{codigo}.pdf`) son los mismos.
- El **contenido es distinto**: es el reporte de AG Chavín, con su logo, el mismo que descarga la web. No hay que
  cambiar nada en la app, salvo que se valide el diseño del PDF.

---

## 3. Comportamientos a tener en cuenta (iguales a main)

No son cambios, pero en AG Chavín aparecen con frecuencia:

- **Usuario sin empleado:** `NotificacionTarea/en-ejecucion`, `iniciar` y `detener` responden **400**
  `["El usuario no está asociado a un empleado."]` si el usuario no tiene un empleado asociado (por ejemplo, el
  administrador). Muestra el mensaje y no lo trates como error de red.
- **Búsquedas sensibles a mayúsculas:** `Seccion/buscar?texto=` distingue mayúsculas y minúsculas. Los códigos están en
  mayúsculas, así que conviene enviar el texto en mayúsculas. `Equipo/listar` ya convierte a mayúsculas en la API.
- **Catálogos vacíos:** algunos catálogos de `Aviso/gestionar/parametros` (causas, mecanismos, impactos) pueden venir
  vacíos. La pantalla no debe romperse.
- **Notificar OT:** `POST api/OrdenTrabajo/notificar` cambia el estado y registra el avance de las tareas enviadas
  (`tareas: [{ id, ejecutado }]`), los adjuntos y el comentario. Con cierre técnico, total o anulación, libera el
  equipo o la ubicación en el plan de mantenimiento.

---

## 4. Checklist de pruebas

- [ ] Login con un usuario de AG Chavín y token en las cabeceras.
- [ ] Avisos: listar, buscar, crear, actualizar y gestionar.
- [ ] Adjuntos: subir temporales, asociarlos a un aviso y a una OT, listarlos y eliminarlos.
- [ ] OT: listar, gestionar/listar, buscar (sin `codigoExterno`), guardar y editar.
- [ ] Notificar OT con tareas ejecutadas y comentario → al volver a buscar se ven el estado y el avance.
- [ ] Notificaciones de tiempo (iniciar, detener, en ejecución) con un usuario **que sí tenga empleado**.
- [ ] Notificaciones de empleados, materiales, contadores, puntos de medida y aspectos.
- [ ] Secciones: buscar y cargar tareas.
- [ ] Descargar el PDF de una OT → se abre el reporte de AG Chavín.
- [ ] No queda ningún acceso al Kanban.
