# Hoja de ruta

Se construye por módulos; cada cliente migra cuando la plataforma cubre lo que usa. El legacy sigue en
producción hasta el corte de cada cliente.

| Etapa | Contenido | Hito | Estado |
|-------|-----------|------|--------|
| **NP-0 Fundaciones** | Solución, CI, auth JWT, tenant + query filters, configuración multicliente (módulos, campos, etiquetas, branding), layout Blazor | Login + menú filtrado por permisos y módulos | 🟡 En curso (pasos 1–4 de 5 hechos) |
| **NP-1 Maestros** | Seguridad (usuarios, roles, permisos), catálogos de Administración | CRUD genérico reutilizable | ⚪ |
| **NP-2 Activos** | Equipos, Ubicaciones, árbol jerárquico, contadores, puntos de medida, datos técnicos | Primer uso de campos personalizados | ⚪ |
| **NP-3 Correctivo** | Avisos → OT, notificación, Kanban, costos | **MVP** → migrar ares, energiaycombustion, itc | ⚪ |
| **NP-4 Preventivo** | Hoja de ruta, secciones, planes, previsualización y generación a demanda | Portar cálculo de posiciones **con tests primero** | ⚪ |
| **NP-5 Logística** | Almacenes, notas, kardex, hojas de aceptación | | ⚪ |
| **NP-6 Reportes y módulos** | Indicadores, PDF de OT, exportaciones, módulos de cliente | Migrar el resto de clientes | ⚪ |

## Orden de migración de clientes

| Ola | Clientes | Motivo |
|-----|----------|--------|
| 1 | ares, energiaycombustion, itc, pyme | Poca divergencia (branding, dashboard, plantillas) |
| 2 | eulen, caja_arequipa | Comparten módulo `SOLICITUDES` |
| 3 | agchavin, rentanor | Comparten indicadores y reportes de plan |
| 4 | oterra | Base 2023, mayor lógica propia |

Cada migración: ETL `tools/clientes/<x>/` desde su BD legacy → ensayo en copia del backup → cuadre de
conteos y totales → aceptación en staging → corte.

## Módulos candidatos (de las ramas legacy)

`SOLICITUDES` (eulen, caja) · `ELIMINACION_LOGICA` (core) · `INDICADORES_CONFIABILIDAD` (oterra, rentanor,
agchavin) · `REPORTE_PDF_OT` · `CONFORMIDAD_AVISO` (oterra) · `CALIFICACION_OT` (caja) · `AREAS_IMPACTO`
(oterra) · `TURNOS_PROGRAMACION` (oterra) · `FERIADOS` (caja) · `COSTOS_OT_AVANZADO` (pyme).
Detalle en `PLAN-MULTICLIENTE.md` §4 del legacy.
