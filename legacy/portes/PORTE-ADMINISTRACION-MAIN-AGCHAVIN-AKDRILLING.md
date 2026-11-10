# Porte del módulo de Administración de `main` a akdrilling y agchavin

> Plan: `legacy/planes/PLAN-ADMINISTRACION-UNIFICADA-Y-BD-CATALOGOS.md` (§2.3, filas 1 y 2)
> Fecha: 2026-11-10 · Base: `main` `634f165` (Fase 0) · Estado: **commits locales, sin push; migraciones sin aplicar en servidor**

## akdrilling — `f70a89a`

- akdrilling era `main` (antes de la Fase 0) salvo `DemonApp` y `appsettings`, con la **misma cadena de
  migraciones**. Se aplicó el commit de la Fase 0 con `git cherry-pick -x 634f165`: misma migración
  `20261110145523_Administracion_Superconjunto`.
- Diff del módulo contra `main`: vacío. Compila.
- Sin BD local de akdrilling: no se probó con sus datos (el código es el mismo que se probó en `main`).
- Script para el servidor: `legacy/portes/sql/main-akdrilling-Administracion_Superconjunto.sql` (idempotente).

## agchavin — `3b801b9`

Tenía la UI de `main` pero el backend antiguo. Se trajo el módulo entero (`git checkout main -- <6 carpetas>`).
Ningún archivo del módulo era exclusivo de agchavin.

Fuera del módulo (lo mínimo para compilar):

| Qué | Por qué |
|---|---|
| `AMSYS.Utilitarios/ArchivoTemporal.cs`, `Entidades/DTOs/UsoCatalogoDTO.cs`, `AdjuntoUsoDTO.cs`, `Entidades/BaseEntity.cs` | Nuevos en `main` (AD-04, AD-10, AD-17, Fase 0) |
| `Repositorios/Gestion/EquipoDatoTecnico.Repositorio.cs` = `main` | La versión de agchavin era un subconjunto; faltaba `ContarValoresPorDatoTecnicoAsync` (AD-14) |
| `EquipoSistema` → `namespace AMSYS.Entidades.Gestion` (+ `using` en `EquipoSistema.Controller`) | Único tipo que agchavin tenía en otro espacio de nombres que `main` |
| 13 llamadas a `MoverAsync` (API Aviso/OT, Gestion Aviso/Equipo/OT/Sección) | AD-04: `MoverAsync(adjunto, carpeta, id)` devuelve `bool`; sólo se asocia el adjunto si el temporal es válido y existe (antes podía asociarse uno con `Id = 0`). El API de agchavin ya generaba los temporales como `{empresa}_{guid}`: compatible |
| `PlanMantenimiento.Controller`: `BuscarPorIdAsync(id, usuario.EmpresaId)` (2) | AD-01 |
| Contexto y `Program.cs`: 7 catálogos + `IUsoCatalogoServicio` | Registro |

Migración `20261110151627_Administracion_DesdeMain`: `codigo` en causafalla, impacto, mecanismofalla y
metododeteccion; `prioridad.horasatencion/despuesdeldia`, `material.marca`, `adjunto.token`; 7 tablas con índice.
Script para el servidor: `legacy/portes/sql/agchavin-Administracion_DesdeMain.sql` (idempotente, sólo esta migración).

### Pruebas (2026-11-10)
Copia local `amsys_v3_agchavin_prueba_admin` (de `amsys_v3_agchavin`, que no se tocó); clave de prueba al
usuario 5 sólo en la copia. Migración aplicada sin error. 65/65: Index, Listar con «En uso» y Editar de los 25
catálogos sobre los datos reales (p. ej. Especialidad 40 331 usos, Prioridad 13 778, Material 1 137 registros).

### No portado / pendiente
- `EliminarTemporalesService` sigue comentado en `Program.cs` de agchavin (limpieza de temporales de 24 h, AD-04):
  decidir si se activa.
- Ningún catálogo opcional activado (agchavin no los usa).
- Falta: recorrido en navegador (subir un adjunto a un aviso/OT/equipo para probar el nuevo `MoverAsync`),
  aplicar el script en 10.2.1.2 y desplegar.

### Checklist en navegador
- [ ] Catálogos: crear, editar, desactivar uno en uso (aviso), código repetido (Causa de falla)
- [ ] Adjuntos: subir en Aviso, OT, Equipo y Sección; descargar; biblioteca de adjuntos
- [ ] Plan de mantenimiento: crear/editar con unidad de servicio
- [ ] App móvil: aviso y OT con adjuntos
