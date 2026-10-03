# /ai – Contexto del proyecto Amsys (nueva plataforma)

Esta carpeta es la **fuente de contexto** del proyecto para cualquier agente de IA (Claude Code) o
persona nueva. Se actualiza **en cada avance**.

## Qué es Amsys

Sucesor del sistema **AMSYS legacy** (CMMS/EAM de mantenimiento industrial, ASP.NET Core MVC + jQuery,
repo `D:\Documentos\Alphamanufacturas\AMSYS\AMSYS`, GitHub `jsulca/AMSYS`).

El legacy mantiene **una rama git por cliente** (agchavin, ares, caja_arequipa, energiaycombustion,
eulen, itc, oterra, pyme, rentanor), cada una con su BD y migraciones divergentes. Amsys reemplaza eso
con **un solo producto configurable por cliente**: módulos activables, campos personalizados, etiquetas
de estado, branding y plantillas de reportes.

## Archivos

| Archivo | Contenido |
|---------|-----------|
| `README.md` | Este índice y las reglas para agentes |
| `CURRENT-STATE.md` | **Leer primero.** Etapa actual, avances, pendientes y siguiente paso |
| `ARCHITECTURE.md` | Estructura de la solución, dependencias, stack y convenciones |
| `DECISIONS.md` | Registro de decisiones (tomadas y pendientes) |
| `ROADMAP.md` | Etapas NP-0 … NP-6 y orden de migración de clientes |
| `PENDIENTES-MIGRACION.md` | **Qué falta migrar del legacy** (rutas de ambos proyectos, funcionalidades pendientes, orden recomendado, mejora de UI) |

## Documentación del legacy (referencia, no copiar)

En `D:\Documentos\Alphamanufacturas\AMSYS\AMSYS\ai\`:

| Archivo | Para qué sirve aquí |
|---------|---------------------|
| `PLAN-MULTICLIENTE.md` | Análisis de las ramas por cliente y qué cambia entre ellas (categorías A–F, módulos) |
| `PLAN-NUEVA-PLATAFORMA.md` | Propuesta original de esta plataforma |
| `BUSINESS-RULES.md` | **Reglas de negocio** a portar (con nivel de confianza) |
| `DOMAIN-MODEL.md` | Modelo de dominio real del legacy |
| `analysis/workflow.md` | Estados y transiciones de Aviso y OT |
| `analysis/orders.md` §9 | Flujos críticos → casos de test |

## Reglas para agentes

1. **Al empezar**: leer `CURRENT-STATE.md`.
2. **Al terminar un avance**: actualizar `CURRENT-STATE.md` (sección *Bitácora* + *Siguiente paso*) y,
   si se tomó una decisión, `DECISIONS.md`.
3. **Decisiones vinculantes heredadas del legacy** (no reabrir):
   - `D-05` La generación de órdenes desde planes es **a demanda**, nunca automática.
   - `D-02` No se puede anular una OT en `CIERRE_TECNICO`.
   - `D-03` Los códigos **no** son únicos: se alerta, no se bloquea.
4. **No ejecutar migraciones** contra bases de clientes. Generarlas y detenerse; aplicarlas es decisión
   del propietario (`Amsys.Migrator`).
5. **Nada de `if (EmpresaId == X)`**: lo específico de un cliente es configuración o módulo.
6. **Versiones de paquetes sólo en `Directory.Packages.props`**; en `.csproj` `<PackageReference Include="X" />`.
7. **No commitear secretos** (el legacy tiene tokens en `appsettings.json` de ramas de cliente).
8. Responder y documentar en **español**.
