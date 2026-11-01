# UI-01 · Tema base de MudBlazor y revisión visual de pantallas clave

- **Estado**: hecha (2026-10-03) — decisión `D-UI-01`, capturas en `plataforma/tareas/capturas/UI-01/`
- **Creada**: 2026-10-03
- **Proyecto**: `D:\Documentos\Amsys` (web en `src/Amsys.Web`). Legacy de referencia: `D:\Documentos\Alphamanufacturas\AMSYS\AMSYS`
- **Skills**: `frontend-design` (plugin `frontend-design@claude-plugins-official`, instalado) y `playwright-blazor`
  (plugin `dotnet-skills`, instalado) para capturas antes/después.

## Prompt para ejecutarla

> Usa frontend-design para proponer el tema base de MudBlazor de AMSYS (`D:\Documentos\Amsys\src\Amsys.Web`): paleta,
> tipografía, densidad y espaciado, sobre el cual se monte la marca de cada cliente (color primario y logo). Luego
> revisa la página de inicio y la ficha de la orden de trabajo.

## Contexto que hay que respetar

- El tema vive en `src/Amsys.Web/TemaAmsys.cs` (`TemaAmsys.Tema` y `Crear(colorPrimario, colorSecundario)`, con caché
  por combinación de colores) y se aplica en `Components/Layout/MainLayout.razor` y `ProveedoresMud.razor`.
- **Marca por cliente** (configuración multicliente, D-NP-1x): cada empresa define `NombreComercial`, `ColorPrimario`,
  `ColorSecundario` y logo (`wwwroot/clientes/<codigo>/`), aplicados con `Migrator --configurar
  tools/clientes/<codigo>/configuracion.json`. El tema base debe funcionar con **cualquier** color primario del cliente
  (contraste de texto sobre el primario, estados, modo claro).
- **Estados con color configurable** por empresa (`EtiquetaEstado`, componente `Components/Shared/EstadoChip.razor`): la
  paleta base no debe chocar con ellos.
- Uso real: Blazor Server con MudBlazor 9, pantallas densas de datos (listas, tablas editables, Kanban, matriz del plan),
  uso en oficina y en planta. Priorizar legibilidad y densidad sobre decoración.
- No cambiar comportamiento ni contratos: sólo presentación. Los tests (`dotnet test --solution Amsys.slnx`) deben seguir
  en verde y el build en Release sin advertencias.

## Pantallas a revisar (en este orden)

1. **Inicio** — `Components/Pages/Home.razor` (tarjetas `Shared/Indicador.razor`, gráficos, accesos).
2. **Ficha de la orden de trabajo** — `Components/Pages/Mantenimiento/FichaOrden.razor` y `NotificacionOrden.razor`.
3. Después, si hay tiempo: tablero Kanban (`Mantenimiento/TableroOrdenes.razor`), ficha del plan con su matriz
   (`Planificacion/FichaPlan.razor`), layout y menú (`Components/Layout/`).

## Pasos sugeridos

1. Capturas "antes" de las pantallas (Playwright, con la API y la web corriendo; usuario `admin`, empresa `demo`).
2. Proponer el tema: paleta neutra + acentos, tipografía (Google Fonts si aplica), tamaños, radios, sombras, densidad
   de tablas; cómo se combina con el `ColorPrimario` del cliente.
3. Implementarlo en `TemaAmsys.cs` (y CSS mínimo en `wwwroot/app.css` si hace falta).
4. Ajustar Inicio y Ficha de OT a la nueva jerarquía visual.
5. Capturas "después", probar con dos colores de cliente distintos (p. ej. cambiar `ColorPrimario` de `demo`).
6. Registrar la decisión de diseño en `plataforma/DECISIONS.md` y el avance en `plataforma/CURRENT-STATE.md` (bitácora).

## Criterios de aceptación

- [x] Tema base documentado (paleta, tipografía, densidad) y aplicado en `TemaAmsys.cs`.
- [x] Con dos colores primarios distintos de cliente, textos y botones siguen legibles (contraste AA).
- [x] Inicio y Ficha de OT revisadas, con capturas antes/después.
- [x] Sin cambios de comportamiento; tests en verde; Release sin advertencias.

## Resultado (2026-10-03)

- Tema en `TemaAmsys.cs` (paleta, tipografía Archivo, radios, colores semánticos, `Contraste` WCAG) y `wwwroot/app.css`
  (paneles con borde, cifras tabulares, franja de indicadores, "placa" de ficha, resumen de costos). Ver `D-UI-01`.
- **Inicio**: indicadores en una sola franja (sólo se colorea lo que pide atención: fallas, atrasadas, preventivo y
  reposición > 0), fecha del día, gráficos más bajos, accesos agrupados como el menú (antes: muro de botones).
- **Ficha de OT**: encabezado con código, estado, objeto técnico y origen (aviso/plan) y las acciones de estado;
  campos densos; tareas con "N de M hechas"; cifras a la derecha; notificación con resumen de costos en lugar de chips.
- `SelectorCatalogo` y `BuscadorActivo` aceptan `Margin` (por defecto el de antes: el resto de páginas no cambia).
- Probado con tres primarios: `#1E5AA8` (demo), `#F2C200` (amarillo: botones pasan a un ocre legible, barra con texto
  oscuro) y `#0F7B6C`. Tests `TemaAmsysTests` (13). 322/322 verdes, Release sin advertencias.
- Capturas tomadas con Playwright (Chrome) sobre una BD aparte `amsys_ui` con datos de muestra (no se tocó `amsys_dev`).

### Observado y no corregido (fuera del alcance: no es presentación)

- **Formato de números mezclado**: `Formato.Numero` muestra `28.5` / `3,850` (punto decimal) y los `MudNumericField`
  muestran `0,50` / `3850,0000` (coma decimal). Falta fijar una cultura única (p. ej. `es-PE`) para la web.
- El logo de `demo` (texto blanco) no se lee si el primario es claro: cada cliente debe entregar un logo para su barra.
- Los gráficos de MudChart usan su paleta propia y un eje fijo hasta 20; las barras quedan bajas con pocos datos.
- Pendiente de la tarea: Kanban, ficha del plan y menú no se revisaron (punto 3, "si hay tiempo").
