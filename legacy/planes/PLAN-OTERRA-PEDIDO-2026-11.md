# Plan: pedido de cambios de oterra (2026-11-05)

Rama legacy `oterra` (local en `70d395b`, 1 commit sin push sobre `origin/oterra` `c01cd75`). Ficha: `clientes/oterra.md`.
Análisis hecho sobre el código de la rama el 2026-11-05. **Ningún punto requiere migración EF.**

## Pedido del cliente

1. Agregar una hoja de repuestos a la exportación del Excel de los equipos.
2. Persistencia de página y filtros en la lista de todos los avisos y de mis avisos.
3. En la lista de equipos, por defecto mostrar solo los equipos activos.
4. En la lista de materiales, por defecto mostrar solo los activos, y visualizar la relación del material con
   equipos, secciones y órdenes de trabajo.
5. En la lista de materiales, tras crear o editar un material, mantener la página y los filtros.
6. Persistir el estado del árbol jerárquico tras una modificación.

## Diagnóstico (código de `oterra`)

| # | Situación actual | Archivo |
|---|---|---|
| 1 | `GenerarExcelAsync` llena solo la hoja 1 de la plantilla `wwwroot/reportes/formatoEquipoExportar.xlsx`. Los "repuestos" son `EquipoMaterial` (EquipoId, MaterialId, Cantidad) | `AMSYS.Logicas/Gestion/Equipo.Logica.cs:385` |
| 2 | Los botones Ver/Gestionar navegan a otra página (`/Gestion/Aviso/Ver/{id}`); al volver, `index.Listar(1)` arranca sin filtros y en la página 1. No hay ningún uso de `sessionStorage` en las vistas | `Areas/Gestion/Views/Aviso/Index.cshtml`, `MisAvisos.cshtml` |
| 3 | `#FActivo` arranca en "TODOS" | `Areas/Gestion/Views/Equipo/Index.cshtml` |
| 4 | `#FActivo` arranca en "TODOS". `Material` ya tiene `Equipos` (EquipoMaterial), `Secciones` (SeccionMaterial) y `OrdenTrabajoMateriales`: no hace falta modelo nuevo | `Areas/Administracion/Views/Material/Index.cshtml`, `AMSYS.Entidades/Administracion/Genericos/Material.cs` |
| 5 | Nuevo/Editar son modales (los filtros no se pierden), pero `index.Set` llama `index.Listar(1)` y vuelve a la página 1 | `Material/Index.cshtml` (`Set`) |
| 6 | Montar/Desmontar hacen `location.reload()`: el árbol se vuelve a colapsar | `Areas/Gestion/Views/ArbolJerarquico/Index.cshtml` |

### Qué ya existe en `main` (y qué no)

- **Punto 6**: `main` ya lo resolvió (rediseño del árbol: recarga por AJAX conservando los nodos expandidos, expande y
  resalta lo montado). Es la referencia para el porte, pero la vista de `main` depende del `helper.js` rediseñado
  (+541 líneas) y de un `_Generar` distinto: **portar solo la lógica**, no la vista completa.
- **Punto 4 (relación)**: `main` tiene `UsoCatalogoRepositorio` (AD-10), que solo **cuenta** usos de Material
  (equipos, secciones, OT). oterra pide **ver** la relación: se reutiliza la idea del conteo y se añade el detalle.
- **Puntos 2, 3, 5**: `main` tampoco los tiene (sus listas no persisten filtros y `FActivo` arranca en TODOS). Lo que
  se haga aquí es candidato a subir a `main` y a la nueva plataforma.

## Decisión de enfoque

Cambios **puntuales sobre `oterra`** (divergencia máxima, base 2023), sin portar el rediseño UX de `main`. Un commit
por punto (regla "una tarea = un cambio atómico").

## Pasos

### P1 — Hoja "Repuestos" en el Excel de equipos
- `EquipoMaterialFiltro`: agregar `int[]? EquipoIds`; en `EquipoMaterialRepositorio.QueryListar` filtrar por ellos e
  incluir `Material.UnidadMedida`.
- `EquipoLogica.GenerarExcelAsync`: con los Ids de `lista`, traer los `EquipoMaterial` en **una sola consulta** (no
  N+1) y escribir en `libro.AddWorksheet("Repuestos")` (o en una hoja 2 añadida a la plantilla, a elegir al
  implementar): N°, código y nombre del equipo, tipo, código y descripción del material, UM, cantidad, activo.
  Encabezado con el mismo estilo de la hoja 1 y bordes; ordenar por código de equipo.
- La hoja respeta el mismo filtro que la hoja de equipos.

### P2 — Persistencia de filtros y página en Avisos y Mis avisos
- `wwwroot/js/helper.js`: nuevo `helper.filtros` genérico:
  - `guardar(clave, tabla)`: guarda en `sessionStorage` los valores de los controles `[id^=F]` de la tabla/form de
    filtros y el `pageIndex`.
  - `restaurar(clave)`: repone los valores y devuelve la página guardada (o 1).
  - Clave por pantalla (`'filtros:' + location.pathname`), todo dentro de `try/catch`.
- `Aviso/Index.cshtml` y `MisAvisos.cshtml`: en `$(function)` llamar `restaurar` antes del primer `Listar(pagina)`;
  en `Listar` llamar `guardar` tras éxito. Considerar los selects dependientes y los rangos de fecha
  (`FRegistroDesde/Hasta`). Botón "Limpiar filtros" que borra la clave.
- Se usa `sessionStorage` (por pestaña, se borra al cerrar), no `localStorage`, para no dejar filtros "pegados"
  entre sesiones.

### P3 — Equipos: activos por defecto
- `Equipo/Index.cshtml`: `<option value="true" selected>` en `#FActivo`. El Excel usa el mismo filtro, así que
  exportará solo activos salvo que el usuario elija "TODOS" (avisar al cliente).
- Revisar si el modal `Equipo/_Seleccionar` debe hacer lo mismo (probablemente sí; confirmar con oterra).

### P4 — Materiales: activos por defecto + relación
- `Material/Index.cshtml`: `#FActivo` en "SI" por defecto.
- Relación:
  - Columna "Uso" en la lista con el conteo (equipos / secciones / OT) calculado en **una consulta por página**
    (proyección con `Count`, como `UsoCatalogoRepositorio` de `main`), no por fila.
  - Ícono por fila que abre un modal `Material/_Relaciones` (acción `Relaciones(id)`, filtrada por `EmpresaId`) con
    tres pestañas: Equipos (código, nombre, cantidad, activo), Secciones (hoja de ruta, código, descripción,
    cantidad), Órdenes de trabajo (código, estado, fecha, cantidad). Limitar OT a las últimas N o paginar.
- Opcional: mostrar el mismo aviso de uso en `_Editar` antes de desactivar un material en uso.

### P5 — Materiales: mantener página y filtros tras guardar
- `Material/Index.cshtml` → `index.Set`: `index.Listar($('#tblIndex').data('pageindex') || 1)` en lugar de
  `Listar(1)`. Los filtros ya se conservan porque Nuevo/Editar son modales.
- Aplicar también `helper.filtros` (P2) para que sobrevivan a una recarga.

### P6 — Árbol jerárquico: conservar estado tras montar/desmontar
- Tomando la lógica de `main` (`ArbolJerarquico/Index.cshtml`, `Expandidos()` y recarga con
  `opciones.expandir`): reemplazar `location.reload()` por una recarga AJAX de `/Gestion/ArbolJerarquico/Generar`
  que antes guarda los ids de los nodos `tr.expanded`, los re-expande después, expande el nodo destino y hace
  `scrollIntoView` del elemento montado.
- Guardar también los expandidos en `sessionStorage` para que sobrevivan a un F5.

## Orden sugerido

P3 → P5 → P4 (activos) → P2 (crea `helper.filtros`, reutilizado en P5) → P6 → P1 → P4 (relación).
Los primeros son cambios de una línea que se pueden entregar el mismo día.

## Checklist de pruebas (manual; el legacy no tiene tests)

- [ ] Excel de equipos: hoja Repuestos con los materiales de cada equipo filtrado; equipos sin repuestos no rompen; filtro "TODOS" incluye inactivos.
- [ ] Avisos y Mis avisos: filtrar + ir a página 3 → Ver → volver (botón y atrás del navegador) → mismos filtros y página. Nueva pestaña → sin filtros.
- [ ] Equipos y Materiales arrancan en Activo = SI; cambiar a TODOS sigue funcionando.
- [ ] Material: editar en página 4 con filtro → sigue en página 4 con filtro. Crear → igual.
- [ ] Relación del material: conteos correctos, modal con las tres listas, sin datos de otra empresa.
- [ ] Árbol: montar equipo / componente y desmontar conservan los nodos abiertos y muestran lo cambiado.
- [ ] Compilar sin errores; probar en `localhost` contra `amsys_v3_oterra`.

## Estado

| Fecha | Qué |
|---|---|
| 2026-11-05 | Plan creado. Nada implementado. |
