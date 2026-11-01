# Comportamiento del plan de mantenimiento por cliente

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
