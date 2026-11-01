# MNT-008b

## Título
Resolver el salto de posiciones en los planes por CONTADOR

## Tipo
BUSINESS_RULE

## Prioridad
HIGH

> [!NOTE]
> Tarea creada el 2026-08-29 como consecuencia de la decisión `D-05`. Al confirmar el propietario que
> la generación es **bajo demanda para controlar el backlog**, quedó al descubierto que los planes
> por contador se comportan de forma **opuesta** a los planes por calendario.

## Problema
Los dos tipos de plan tratan el atraso de manera incompatible:

| Tipo de plan | Al detectar atraso de N ciclos | Órdenes generadas |
|--------------|-------------------------------|-------------------|
| **CALENDARIO** | avanza **una** posición por ejecución | 1 (hay que volver a lanzar para las siguientes) |
| **CONTADOR** | salta **directamente** a la posición final | 1 — las posiciones intermedias **se pierden** |

En calendario, el trabajo pendiente se conserva y el planificador lo va liberando: eso es lo que
`D-05` busca. En contador, el trabajo pendiente **desaparece sin dejar rastro**: si un equipo acumuló
3 000 horas sin lanzar y el intervalo es de 250, el sistema salta de la posición 4 a la 16 y genera
**una sola** orden — las secciones de las 11 posiciones intermedias nunca se ejecutan y nadie se
entera.

## Objetivo
Que el tratamiento del atraso sea coherente y explícito en ambos tipos de plan.

## Comportamiento actual

`AMSYS.Logicas/Gestion/PlanMantenimiento.Logica.cs:270-295` (`ActualizarLanzamiento`):
```csharp
int posicionLanzamiento = equipo.PosicionActual;
for (int i = equipo.PosicionActual; i < nuevaPosicion; i++)
    posicionLanzamiento = i % cantidadPosiciones;      // el bucle solo conserva la ULTIMA

posicionLanzamiento %= cantidadPosiciones;

if (comportamientoConSeccion[posicionLanzamiento].Length > 0)
{
    equipo.Bloqueado = equipo.TipoProgramacion == TipoProgramacion.FLOTANTE;
    equipo.ContadorActual = nuevaPosicion * intervalo;
    lanzamientos.Add(equipo.Id, comportamientoConSeccion[posicionLanzamiento]);
}

equipo.PosicionActual = nuevaPosicion;                 // salta directamente
```

Observaciones:
- El bucle `for` **recorre** las posiciones intermedias pero sólo se queda con la última: es un bucle
  cuyo cuerpo entero podría sustituirse por una asignación. Sugiere que en su día se pretendía
  acumular algo y quedó a medias.
- `PosicionActual = nuevaPosicion` sin módulo: el valor crece sin límite (relacionado con `MNT-029`).
- `ContadorActual = nuevaPosicion * intervalo` descarta el excedente de contador acumulado.

En cambio, la rama de calendario (`:186-240`) es un `if` sin bucle: avanza una sola posición y deja
el resto para el siguiente lanzamiento.

## Comportamiento esperado
**DECISIÓN PENDIENTE `D-05b`.** Opciones a plantear al propietario:

- **Opción A — Alinear con calendario (coherente con `D-05`)**: avanzar **una** posición por
  ejecución también en contador. El planificador lanza tantas veces como necesite y controla el
  backlog igual que en calendario. Es la opción coherente con la decisión ya tomada.
- **Opción B — Mantener el salto, pero avisar**: conservar el comportamiento y **mostrar
  explícitamente** en la previsualización *"se omitirán N posiciones intermedias"*, para que sea una
  decisión consciente y no una pérdida silenciosa.
- **Opción C — Generar todas las posiciones pendientes**: una orden por posición intermedia.
  **Contradice directamente `D-05`**: es exactamente la explosión de backlog que el propietario
  quiere evitar. Se documenta para descartarla explícitamente.

**Recomendación técnica: Opción A**, por coherencia con `D-05`; con la Opción B como paso previo de
bajo riesgo si se prefiere observar antes de cambiar.

## Reglas de negocio involucradas
- `BR-GE-005` (calendario avanza una posición) — `CONFIRMED`, validada por `D-05`
- `BR-GE-006` (contador salta a la posición final) — `CONFIRMED` en comportamiento, **`UNKNOWN` en
  intención**
- `BR-GE-003` (condición de lanzamiento por contador) — `CONFIRMED`
- `BR-GE-010` (las lecturas sólo avanzan asignaciones no bloqueadas) — `CONFIRMED`

## Archivos potencialmente afectados
- `AMSYS.Logicas/Gestion/PlanMantenimiento.Logica.cs` (`ActualizarLanzamiento`, `CalcularPosicion`)
- `AMSYS.WebAdmin/Areas/Gestion/Views/OrdenTrabajo/Previsualizar.cshtml` (Opción B)

## Entidades involucradas
`PlanMantenimiento`, `PlanMantenimientoEquipo`, `Contador`, `OrdenTrabajo`

## Riesgos
- **ALTO**: la Opción A cambia cuántas órdenes se generan en cada lanzamiento para todos los planes
  por contador. Un equipo muy atrasado pasaría a exigir varios lanzamientos consecutivos.
- Cambiar `ContadorActual = nuevaPosicion * intervalo` afecta al cálculo del siguiente ciclo y a la
  reconciliación que hace `OrdenTrabajoLogica` al cerrar la orden (`:693-710`). Es el punto más
  delicado del cambio.
- Puede haber equipos con `PosicionActual` muy por encima de `CantidadPosiciones` por este mismo
  comportamiento: coordinar con `MNT-029` y `D-12`.

## Propuesta de solución
1. **Diagnóstico** (sin cambios): para cada `PlanMantenimientoEquipo` de un plan por contador,
   calcular cuántas posiciones se saltaron históricamente
   (`PosicionActual` frente a las órdenes realmente generadas). Cuantificar el mantenimiento perdido.
2. Presentar el diagnóstico y obtener `D-05b`.
3. Implementar de inmediato la parte no polémica: **hacer visible el salto** en la previsualización
   (Opción B), reutilizando el panel de `MNT-040`.
4. Implementar la opción elegida.
5. Sustituir el bucle `for` inerte por código que exprese la intención real, sea cual sea la decisión.

## Tests requeridos
- Equipo con contador atrasado 3 ciclos: comportamiento conforme a `D-05b`.
- Equipo sin atraso: comportamiento idéntico al actual.
- `ContadorActual` tras el lanzamiento es coherente con la posición resultante.
- Cerrar la orden reconcilia `ContadorActual` correctamente (`OrdenTrabajo.Logica.cs:693`).
- Planes por calendario: **sin ningún cambio**.
- Ciclo FLOTANTE completo (generar → bloquear → cerrar → desbloquear) sigue funcionando.

## Criterios de aceptación
- [ ] Diagnóstico del mantenimiento saltado entregado y cuantificado.
- [ ] Decisión `D-05b` registrada en `CURRENT-STATE.md`.
- [ ] El salto de posiciones es visible para el planificador antes de generar.
- [ ] El tratamiento del atraso es coherente entre calendario y contador, o la diferencia está
      documentada como intencional.
- [ ] Los planes por calendario no cambian de comportamiento.

## Fuera de alcance
- Automatizar la generación (descartado por `D-05`).
- Normalizar `PosicionActual` de las ubicaciones (`MNT-029`, `D-12`).
- Implementar contadores para ubicaciones (`MNT-009`).

## Dependencias
- Requiere la decisión `D-05b`.
- Se beneficia de `MNT-019` (tests del algoritmo): sin ellos, tocar `ActualizarLanzamiento` es
  arriesgado.
- El paso 3 se integra con `MNT-040`.

## Notas para Claude Code
- **No implementes la Opción C.** Generar una orden por posición intermedia es justo lo que `D-05`
  descarta. Está documentada sólo para dejar constancia de que se evaluó y se rechazó.
- El bucle `for` de `ActualizarLanzamiento` no acumula nada: su cuerpo se reduce a
  `posicionLanzamiento = (nuevaPosicion - 1) % cantidadPosiciones`. Verifica esa equivalencia con
  tests **antes** de simplificarlo; es la clase de "limpieza obvia" que introduce bugs sutiles.
- `ContadorActual` participa en tres lugares distintos (generación, lecturas de contador, cierre de
  OT). Revísalos los tres antes de tocar su cálculo.

## Estado
PENDING
