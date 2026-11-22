# App móvil Oterra (Flutter): cambios de API respecto a main

> Rama de la API: `oterra` (commit `c9695fe`, 2026-11-21). Proyecto: `AMSYS.WebAdmin/Api`.
> Este documento es para el desarrollador de la app móvil Flutter.

## Contexto

La app móvil se hizo sobre la API de AMSYS (rama `main`). La versión de Oterra usa **la misma API**: las mismas rutas
(`api/[Controller]/...`), el mismo login (`POST api/Usuario`) y el mismo token JWT en las cabeceras.
Oterra solo **agrega campos** en **Avisos** y **Órdenes de Trabajo**, más **un endpoint nuevo** (cambiar conformidad del aviso).

Todo lo que no aparece en este documento funciona igual que en main.

### Convenciones del JSON (igual que en main)

| Tema | Regla |
|---|---|
| Nombres | camelCase (`impactoProcesoId`, `estaConforme`) |
| Fechas en respuestas | Texto con formato `dd/MM/yyyy HH:mm` |
| Nulos | **No se envían**: si un campo es `null`, no aparece en el JSON. En Dart, decláralo nullable (`int?`, `String?`) y lee con `json['x'] as int?` |
| Enums | Llegan como **número** |
| Errores de validación | HTTP 400 con un **arreglo de strings** (`["Es necesario seleccionar un impacto."]`). Muestra todos los mensajes |

---

## 1. Avisos

### 1.1 `GET api/Aviso/parametros`

Trae dos listas más:

```json
{
  "prioridades": [{ "id": 1, "descripcion": "ALTA" }],
  "metodosDeteccion": [{ "id": 1, "nombre": "..." }],
  "impactosProceso": [{ "id": 1, "descripcion": "..." }],
  "areas": [{ "id": 1, "codigo": "A01", "descripcion": "..." }]
}
```

### 1.2 `POST api/Aviso/guardar` y `POST api/Aviso/actualizar`

| Campo | Tipo | Regla |
|---|---|---|
| `prioridadId` | int | **OBLIGATORIO** |
| `impactoProcesoId` | int | **OBLIGATORIO** (nuevo). Va en un selector "Impacto en el proceso" con las opciones de `parametros.impactosProceso` |
| `areaId` | int? | Opcional (nuevo). Selector "Área" con las opciones de `parametros.areas` |
| `sistemaId`, `parteId` | int? | Opcionales (nuevos) |
| `avisoPadreId`, `ordenTrabajoId`, `puntoMedidaId` | int? | Opcionales, **solo en guardar**. No hace falta pedirlos en pantalla |
| `fechaEvento` | DateTime? | Ahora se guarda **para todos los tipos** de aviso, no solo para Solicitud de trabajo. Muéstrala siempre |

> Si falta `prioridadId` o `impactoProcesoId`, la API responde **400**. Valida ambos campos en el formulario antes de enviar.

### 1.3 `GET api/Aviso/listar`

Cada item trae además:

```json
{
  "impactoProceso": { "descripcion": "..." },
  "area": { "descripcion": "..." },
  "estaConforme": true,
  "puedoModificarConformidad": false
}
```

`impactoProceso`, `area` y `estaConforme` pueden no venir. Muestra impacto y área en la tarjeta cuando existan.

### 1.4 `GET api/Aviso/buscar?id=`

Campos nuevos:

| Campo | Tipo |
|---|---|
| `motivo` | String? |
| `impactoProcesoId`, `impactoProcesoDescripcion` | int?, String? |
| `areaId`, `areaDescripcion` | int?, String? |
| `avisoPadreId`, `avisoPadreCodigo` | int?, String? |
| `puntoMedidaId`, `ordenTrabajoId` | int? |
| `estaConforme` | bool? |
| `comentarioConformidad` | String? |
| `puedoModificar` | bool |
| `puedoModificarConformidad` | bool |

- **Detalle:** muestra Impacto, Área, Motivo y la conformidad (Conforme / No conforme + comentario).
- **Edición:** precarga `impactoProcesoId` y `areaId`.

### 1.5 NUEVO: `POST api/Aviso/cambiar-conformidad`

```json
{ "id": 123, "estaConforme": true, "comentario": "opcional" }
```

- Solo se permite si `puedoModificarConformidad == true`, es decir, si el aviso está **FINALIZADO** y aún no tiene conformidad.
- **UI:** en el detalle del aviso, agrega el botón **"Registrar conformidad"** con Conforme / No conforme y un comentario opcional.
  Después de guardar, recarga el aviso.
- Responde `200 { "id": 123 }`. Si el aviso no existe, responde 404. Si no admite el cambio, responde 400 con mensajes.

### 1.6 Gestionar aviso

**`GET api/Aviso/gestionar/parametros`** trae además:

```json
{
  "impactosProceso": [{ "id": 1, "descripcion": "..." }],
  "areas": [{ "id": 1, "codigo": "A01", "nombre": "..." }]
}
```

> ⚠️ Aquí el texto del área viene en **`nombre`**, no en `descripcion`.
>
> ⚠️ En `metodosDeteccion`, `mecanismosFalla`, `impactos` y `causasFalla` **ya no viene `codigo`**. Muestra solo `nombre`
> y declara `codigo` como `String?`. `modosFalla` sí sigue trayendo `codigo`.

**`POST api/Aviso/gestionar`** agrega `impactoProcesoId` (**obligatorio**) y `areaId` (opcional). `prioridadId` también es obligatorio.

**`GET api/Aviso/gestionar/listar`**: cada item trae además `impactoProceso: { descripcion }` y `area: { descripcion }`. Ambos pueden no venir.

---

## 2. Órdenes de trabajo

### 2.1 `GET api/OrdenTrabajo/parametros`

Trae además:

```json
{ "conformidades": [{ "id": 1, "descripcion": "..." }] }
```

### 2.2 `GET api/OrdenTrabajo/buscar?id=`

Campos nuevos:

| Campo | Tipo | Nota |
|---|---|---|
| `turno` | int? | `0` = MAÑANA, `1` = TARDE, `2` = NOCHE |
| `ejecutadoTercero` | bool | |
| `noConforme` | bool | |
| `conformidades` | lista | `[{ "id", "conformidadId", "conformidadDescripcion", "estaConforme": bool? }]` |

Campos que **cambian o se quitan**:
- `codigoExterno`: **ya no viene**. Quítalo de la UI.
- `materiales[].materialPrecio`: siempre llega vacío. No muestres el precio de los materiales.

### 2.3 `POST api/OrdenTrabajo/notificar`

Campos nuevos en el body:

```json
{
  "turno": 0,
  "ejecutadoTercero": false,
  "conformidades": [{ "id": 55, "estaConforme": true }]
}
```

- **turno:** selector Mañana / Tarde / Noche.
- **ejecutadoTercero:** check "Ejecutado por tercero".
- **conformidades:** el `id` es el **`id` de cada item de `buscar.conformidades`**, no el `conformidadId`. Muestra la lista con
  Conforme / No conforme por cada item.

### 2.4 `POST api/OrdenTrabajo/guardar` y `POST api/OrdenTrabajo/editar`

- Ya no se envía `codigoExterno`. Si se envía, la API lo ignora.
- `equipoId` es **opcional**: la OT puede ir solo con ubicación.
- Se validan las tareas y los materiales. Si algo falta, la API responde 400 con mensajes del tipo `"La tarea nro. 2, debe tener ..."`:
  - **Tarea:** `tipoTareaId`, `especialidadId`, `descripcion`, `cantidad > 0` y `duracion > 0`. Si tiene `parteId`, también necesita `sistemaId`.
  - **Material:** `materialId` y `cantidad > 0`.

### 2.5 Sin cambios

`GET api/OrdenTrabajo/listar` devuelve **el mismo formato que en main**: `{ lista, cantidadPaginas }`, con la entidad completa
(`puedoNotificar`, `ubicacionId`, `equipoId`, etc.).

---

## 3. Lo que NO cambia

- Login (`POST api/Usuario`) y token.
- Adjuntos temporales (`api/Adjunto/guardartemporales`, `eliminartemporal`). Se rechazan archivos ejecutables o que el navegador
  interpreta (`.exe`, `.js`, `.html`, `.svg`, …), igual que en main.
- Notificaciones: tareas, empleados, materiales, contadores, puntos de medida y aspecto de equipo.
- Equipos, ubicaciones, secciones, empleados, adjuntos de aviso y de OT.
- PDF de la OT (`GET api/OrdenTrabajo/pdf/{id}`): solo cambia el logo.
- **`api/WorkOrderKanban` no existe en Oterra.** Si la app lo referencia, quítalo.

---

## 4. Sugerencias para Flutter

- **Modelos:** agrega los campos nuevos como **nullable** en `fromJson`, porque los nulos no vienen en el JSON.
  Si usas `json_serializable`, pon `@JsonKey(includeIfNull: false)` en los `toJson` de los requests.
- **Turno:** crea un `enum Turno { manana, tarde, noche }` y envíalo como su `index` (0, 1, 2).
- **Errores 400:** si no existe ya, crea un helper común que lea el body como `List<dynamic>` y muestre los mensajes
  (SnackBar o diálogo).
- **Selectores:** reutiliza el mismo widget de lista desplegable que ya se usa para prioridad, en impacto y área.

## 5. Checklist de pruebas

- [ ] Crear aviso **sin** impacto → la app no deja enviar (o muestra el 400).
- [ ] Crear y actualizar aviso con prioridad, impacto y área → al buscarlo vienen los mismos valores.
- [ ] Listado de avisos muestra impacto y área.
- [ ] Aviso FINALIZADO → "Registrar conformidad" → se guarda y desaparece el botón (`puedoModificarConformidad = false`).
- [ ] Gestionar aviso con impacto obligatorio; la pantalla no se rompe aunque falte `codigo` en los catálogos.
- [ ] Buscar OT muestra turno, ejecutado por tercero y conformidades; ya no muestra código externo ni precio de material.
- [ ] Notificar OT con turno, ejecutado por tercero y conformidades → al volver a buscar se ven los valores.
- [ ] Guardar OT sin equipo (solo ubicación) funciona.
- [ ] Guardar OT con una tarea sin especialidad → se muestra el mensaje de la API.
- [ ] Listado de OT, notificaciones y adjuntos siguen funcionando como en main.
