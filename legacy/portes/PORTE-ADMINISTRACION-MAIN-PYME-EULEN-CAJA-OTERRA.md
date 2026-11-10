# Porte del módulo de Administración de `main` a pyme, eulen, caja_arequipa y oterra

> Plan: `legacy/planes/PLAN-ADMINISTRACION-UNIFICADA-Y-BD-CATALOGOS.md` (§2.3, filas 3–6). Antes: `PORTE-ADMINISTRACION-MAIN-AGCHAVIN-AKDRILLING.md`
> Fecha: 2026-11-10 · Base: `main` `4a89abe` · Estado: **commits locales, sin push; migraciones sin aplicar en servidor**

Resultado: `git diff main <rama> -- <6 carpetas del módulo>` vacío en las **7 ramas**.

## Común a las cuatro
- `git checkout main -- <módulo>` + borrar los archivos propios de la rama con otro nombre (sus versiones de los catálogos).
- Desde `main`: `ArchivoTemporal`, `UsoCatalogoDTO`, `AdjuntoUsoDTO`, `MaterialRelacionDTO`, `RespuestaValidacion`, `BaseEntity`, `EquipoDatoTecnicoRepositorio` (la versión de la rama era subconjunto).
- `MoverAsync` (AD-04): 13–15 llamadas por rama → `if (await …MoverAsync(adjunto, carpeta, id)) lista.Add(adjunto)`. Todas las API ya generaban temporales `{empresa}_{guid}`.
- `PlanMantenimiento.Controller`: unidad de servicio buscada con la empresa (AD-01).
- Contexto y `Program.cs`: catálogos con configuración estática + `IUsoCatalogoServicio`.
- Selectores (`_Seleccionar`): mismo `callBack(items)` y mismas claves; el de Material añade `precio`. Compatibles.

## Por rama

| Rama | Commits | Específico | Migración (`Administracion_DesdeMain`) | Pruebas (copia local) |
|---|---|---|---|---|
| pyme | `48f3715`, `821b629` | Nada más | `material.precio` + Fase 0 | Sin BD local: sólo compilación y selectores |
| eulen | `0b67420`, `7f3d139` | Sus Cliente/CategoriaAviso/TipoSolicitudAviso = los de main (mismas tablas). **`AreaPorEspacioDeNombres`** en `Program.cs`: eulen declara `[Area]` en sus 80 controladores y main en ninguno; sin la convención los de Administración daban 404 | campos de Prioridad, `material.precio` sin precisión fija, `adjunto.token` admite nulos, 4 tablas | `amsys_v3_eulen_prueba_admin`: 79/80 (Calificación sin página registrada: datos de permisos de antes). Búsqueda por token comprobada (el archivo está en el disco del servidor) |
| caja_arequipa | `0c35995`, `0c80a69` | Sus 4 catálogos = los de main. **Fecha necesaria del aviso** (web, API, DemonApp): prioridad buscada en la empresa, feriados sólo de la empresa, sin plazo → sin fecha, `DespuesDelDia` vacío = no | Prioridad admite nulos (datos intactos), `material.marca`, `adjunto.token`, índice y FK de `feriado`, 3 tablas | `amsys_v3_caja_arequipa_prueba_admin` (licencia extendida **sólo en la copia**): 63/64; fecha necesaria: 3 h → 03:00; 47,9 h hábiles desde 24/12 → lun 28/12 23:54; prioridad de otra empresa → sin fecha |
| oterra | `29611e2`, `48a44ab` | Area/Conformidad/ImpactoProceso = los de main. Relaciones sin colección inversa (mismas FK): Aviso→ImpactoProceso, OrdenTrabajoConformidad→Conformidad, NotaEntrada→SocioNegocio; `Empresa` sin Areas/Conformidades/ImpactosProceso y con Calificaciones. `EquipoSistema`/`EquipoDatoTecnico` al namespace de main (+ `using` en 25 archivos). Sistema/Parte con config estática. Panel de relaciones de Material ahora viene de main (DU-04) | código en 4 catálogos de falla, `material.precio`, `area.codigo` admite nulos, Fase 0, tablas `calificacion` y 4 opcionales. No toca FK ni recrea tablas | `amsys_v3_oterra_prueba_admin`: 75/80 (Sistema, Parte, Calificación: 403, el rol no las tiene). Datos intactos: 10 áreas, 32 usuarios con área, 1 792 avisos con impacto |

## DU-04 en main (`4a89abe`) y en todas las ramas
Ventana «Relación del material» del pedido P4 de oterra llevada a `main`: equipos, secciones y las 100 OT más recientes,
dentro de la empresa; se abre con un botón por fila o desde la cifra de «En uso». La lista de materiales arranca en
Activo = SI. El estado de la OT sale del enum de cada instalación (caja renombra estados). Sincronizada a agchavin
`018b7d3`, akdrilling `ec3685d`, pyme, eulen y caja (commits de arriba).
Diferencia con lo que tenía oterra: tras **crear** un material la lista vuelve a la página 1 (donde aparece el nuevo,
resaltado); tras editar se mantiene la página, como pedía P5.

## Scripts para el servidor (idempotentes, sólo la migración nueva)
`legacy/portes/sql/{pyme,eulen,caja_arequipa,oterra}-Administracion_DesdeMain.sql`. Aplicarlos es decisión del propietario;
antes, respaldo `pg_dump -Fc` como en los portes de Seguridad.

## Pendiente
- Recorrido en navegador en cada rama (adjuntos en aviso/OT/equipo/sección; catálogos propios; relación de Material).
- eulen y caja tienen activadas las páginas de sus catálogos; nada que activar. pyme no usa catálogos opcionales.
- Bases de prueba locales creadas hoy (borrables): `amsys_v3_{demo,agchavin,eulen,caja_arequipa,oterra}_prueba_admin`.
