# Cliente: agchavin

> Esqueleto creado el 2026-10-31 a partir de `git log`, `legacy/planes/PLAN-MULTICLIENTE.md` y
> `migracion/PENDIENTES-MIGRACION.md`. Completar el detalle al tocar la rama.

| Campo | Valor |
|---|---|
| Rama legacy | `agchavin` |
| Último commit (revisado 2026-10-31) | `be90f45 2026-10-26` |
| Commits propios / atrasados respecto a `main` | 79 / 82 |
| Divergencia | 🔴 Muy alta (10 migraciones propias) |
| Ola de migración | 3 (con rentanor) |
| Base de datos legacy | `amsys_v3_agchavin` |
| Servidor / despliegue | Por documentar (sin claves) |
| Configuración en la plataforma | Pendiente (`D:\Documentos\Amsys\tools\clientes\`) |
| Estado de migración | Pendiente |

## Módulos y particularidades

`INDICADORES_CONFIABILIDAD` (incluye indicador mundial, `IndicadorGrupo`), `REPORTE_PDF_OT`, Home idéntico a rentanor, campo `Equipo.Orden`.

**Plan de mantenimiento**: igual que `main` desde el 2026-10-31 (commit `5b9825d`, publicado). Antes: variante C (factor siempre en contador, posición absoluta) — ver `legacy/analisis/plan-mantenimiento-por-cliente.md` (revisado 2026-10-31).

## Pendientes

Porte de la UI de `main` hecho el 2026-10-26 (`legacy/portes/PORTE-UI-MAIN-AGCHAVIN.md`). Migración `20261020022722_VistaLista_Crear_Almacen_AgregarActivo` aplicada en localhost el 2026-10-30; **falta en el servidor 10.2.1.2 / producción**. Al 2026-10-31 hay ~45 archivos modificados sin commit en la rama (programación de OT, notificación de tareas, migración `20261030152417_OrdenTrabajo_AgregarProgramacion`).

**Manual de usuario (2026-11-05)**: HTML estático en `AMSYS.WebAdmin/wwwroot/manual/` (portada + 6 capítulos: 1 ubicaciones y equipos con árbol jerárquico y parámetros, 2 hojas de ruta y secciones, 3 planes, 4 órdenes de trabajo, 5 avisos, 6 administración/metadatos; 36 capturas reales de localhost en `manual/img/`; índice lateral y anterior/siguiente generados desde los `<h2 id>`). Enlace "Manual de usuario" en el menú de usuario (`Views/Shared/_Header.cshtml`) y en el pie (`Views/Shared/_Footer.cshtml`). Se sirve sin sesión (archivos estáticos). Commit `4ea59bd` (publicado en origin, 2026-11-05).

Hallazgos al escribirlo:
- La sincronización Aviso→OT solo ocurre al cambiar el estado desde `OrdenTrabajo/Editar` (`OrdenTrabajo.Controller.cs` ~l. 341): cerrar desde Ejecutar (`Notificar`) no finaliza el aviso (= `MNT-007`, sigue vigente en agchavin). El manual indica finalizarlo a mano desde Gestionar.
- En la base local `amsys_v3_agchavin` no están registradas las páginas `ProgramacionEmpleado` (Mis Órdenes de Trabajo) ni `NotificacionTarea` (Monitoreo / Reporte de actividades): el Administrador recibe 403. Documentadas en el manual sin captura.

## Bitácora

| Fecha | Qué |
|---|---|
| 2026-10-31 | Ficha creada (esqueleto) |
| 2026-10-31 | Plan de mantenimiento unificado con main (`5b9825d`, publicado) |
| 2026-10-31 | Porte de Seguridad de `main` (SG-01…25), commit `d527ecd` (publicado en origin), probado en navegador, migración `20261101015429_Seguridad_PortarDesdeMain` aplicada en localhost (no en servidor); rol de instalación `SUPER ADMIN`: `legacy/portes/PORTE-SEGURIDAD-MAIN-AGCHAVIN.md` |
| 2026-11-05 | Manual de usuario estático en `wwwroot/manual/` + enlaces en cabecera y pie (sin commit) |
| 2026-11-05 | Manual: capítulos nuevos Ubicaciones y equipos (árbol jerárquico) y Administración (metadatos); renumeración (sin commit) |
