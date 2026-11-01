# Comportamiento del plan de mantenimiento por cliente

> **Unificado el 2026-10-31**: todas las ramas calculan como `main` (decisión del propietario: "el comportamiento de
> main para todos"). Commits **locales, sin push**: main `8bc50b6` + `5d228c9`; agchavin `5b9825d`, akdrilling `2b4cef5`,
> ares `2fb1ee1`, caja_arequipa `d17a18c`, energiaycombustion `ddee110`, eulen `8bb1462`, itc `cf5a77b`, oterra `70d395b`,
> pyme `729aaa4` (itc y rentanor: ramas borradas el 2026-10-31, commits en el bundle de `clientes/ex/`). Lo de abajo describe el estado **anterior** (para saber qué cambió en cada cliente).
>
> Mejoras sobre `main`, aplicadas a todos:
> - La decisión por objeto vive en funciones puras (`AvanzarPorCalendario`, `AvanzarPorContador`, `SumarIntervalo`,
>   `PuedeProgramarse`). Comprobado contra la lógica anterior de main con un arnés de ~580.000 casos aleatorios
>   (0 diferencias; detecta la variante `!=` de rentanor si se introduce).
> - Un plan sin intervalo/unidad/posiciones, un equipo por calendario sin inicio o uno por contador sin lecturas ya no
>   lanzan una excepción que paraba la generación **de todos**: se salta ese objeto (~8 % de los casos aleatorios).
> - Fallo de main corregido: al notificar o cambiar el estado de la última OT de un plan **por ubicación**, la última
>   ejecución tomaba la fecha anterior de la OT y luego la pisaba con la notificada (o la vaciaba). Ahora, como equipos.
> - El cierre al notificar es el de main en todas (desbloquea, ajusta contador con el valor de ejecución, toma la fecha
>   de ejecución notificada). **Excepción itc**: no tiene `FechaEjecucion`/`FechaLanzamiento` en la OT (falta la migración
>   `OrdenTrabajo_AgregarFechaPlan`), así que conserva la fecha programada; completar al migrar itc.
> - Sin tocar: `ProgramarAsync` (estado PROGRAMADO) en las ramas que aún lo tienen; `ActualizarAsync` ya era igual en todas.
>
> Efecto en datos existentes al desplegar: ninguno inmediato (no hay migración). En las ramas C/D/E, equipos cuya posición
> ya se adelantó con el factor no relanzan: el plan sigue cuando la lectura supera esa posición.

Revisado el 2026-10-31 sobre `origin/<rama>` (sin trabajo local). Se compararon los métodos que deciden el ciclo:
`PlanMantenimientoLogica.GenerarMantenimientoEquipos` / `GenerarMantenimientoUbicaciones` (+ `CalcularPosicion`,
`ActualizarLanzamiento`) y el desbloqueo del ciclo en `OrdenTrabajoLogica`. La comparación es de código, no se ejecutó.

## Lo que es igual en todas las ramas

- **Generación a demanda** (D-05): sólo desde `Gestion/OrdenTrabajo` ("Generar órdenes"). Donde el demonio
  (`AMSYS.DemonApp`) la menciona, está comentada.
- Mismas operaciones públicas del plan; mismas entidades `PlanMantenimiento`, `PlanMantenimientoEquipo` (salvo
  una línea en caja_arequipa y eulen en `PlanMantenimientoSeccion`).
- **Cierre/anulación de una OT de plan flotante**: desbloquea el objeto técnico, recoloca `ContadorActual` en
  `PosicionActual × Intervalo` y pone `UltimaEjecucion` = fecha del cierre. Igual en todas salvo itc (abajo).
  caja_arequipa sólo cambia el nombre del estado (`CIERRE_PARCIAL` por `CIERRE_TECNICO`).
- Los feriados de caja_arequipa **no** intervienen en el cálculo del plan.

## Variantes

| Variante | Ramas | Qué cambia en el comportamiento |
|---|---|---|
| **A — `main`** | main, akdrilling, ares, caja_arequipa, eulen, pyme (equipos) | Referencia (ver abajo) |
| **B — `!=` en contador** | rentanor | Por contador lanza si la posición calculada es **distinta** de la actual (no sólo mayor): un contador reiniciado o cambiado vuelve a lanzar |
| **C — factor siempre + posición absoluta** | agchavin, energiaycombustion | Por contador **siempre suma el factor de planificación** (adelanta el lanzamiento) y usa `!=`. Por calendario la posición crece sin reiniciarse (misma sección elegida). Sin la validación de índice de main (`ContainsKey`) |
| **D — C + última sección no vacía** | oterra | Como C; si el contador saltó varios intervalos lanza la **última posición con tareas** (A/B/C toman la última posición aunque esté vacía y entonces no lanzan) |
| **E — D + calendario desde "hoy"** | itc | Como D, y por calendario `UltimaEjecucion` = **fecha en que se generó** la orden (no la programada): si se genera tarde, todo el calendario se corre. Al notificar, `UltimaEjecucion` = `FinEjecutado`. En ubicaciones el factor del primer lanzamiento **se ignora** (`fechaLanzamiento.AddDays(...)` sin asignar: fallo) |

**Ubicaciones**: `main` sólo genera para ubicaciones **mantenibles** (EU-22, decisión DE-04); **todas las demás ramas**
generan para cualquier ubicación activa.

### Referencia (`main`)

- Calendario: lanza cuando `(UltimaEjecucion ?? Inicio) − factor` + intervalo ≤ hoy; la siguiente
  `UltimaEjecucion` es la **programada** (anterior + intervalo), no la de hoy; la posición se reinicia con módulo.
- Contador: posición = ⌊lectura / intervalo⌋; si no alcanza, prueba con ⌊(lectura + factor) / intervalo⌋. Sólo
  lanza si la posición **sube** (`<`).
- Flotante: el objeto queda `Bloqueado` hasta cerrar o anular la OT.

## Para unificar (decisiones del propietario)

1. ¿Factor de planificación en contador: sólo como segundo intento (main) o siempre (agchavin, oterra, itc, e&c)?
2. ¿Relanzar si el contador baja (`!=`) o sólo si sube (`<`)? Relevante al cambiar un horómetro.
3. Contador que salta varios intervalos: ¿última posición o última con tareas (oterra, itc)?
4. itc calendario desde "hoy": casi seguro no deseado; confirmar con el cliente antes de migrarlo.
5. Ubicaciones no mantenibles: llevar `Mantenible` (EU-22) a todos.
