# Contexto del Sistema – AMSYS

## Qué hace el sistema

AMSYS es un **sistema de gestión de mantenimiento industrial (CMMS/EAM)** desarrollado en .NET (ASP.NET Core MVC + Web API). Gestiona el ciclo completo de mantenimiento de activos industriales: desde la planificación preventiva hasta la ejecución correctiva, incluyendo gestión de equipos, ubicaciones, materiales, personal y costos.

## Qué hace el módulo de Mantenimiento

El módulo de Mantenimiento es el **núcleo operativo** de AMSYS. Abarca:

### Mantenimiento Preventivo
- **Definición de plantillas de trabajo** (Hojas de Ruta → Secciones → Tareas)
- **Planificación cíclica** (Planes de Mantenimiento con intervalos basados en calendario o contador)
- **Generación automática de Órdenes de Trabajo** basada en posiciones y frecuencias
- **Previsualización** antes de lanzar órdenes

### Mantenimiento Correctivo
- **Avisos** de falla o solicitud de trabajo
- **Escalación** de Avisos a Órdenes de Trabajo
- **Gestión de fallas** (ModoFalla, MecanismoFalla, CausaFalla)

### Ejecución
- **Órdenes de Trabajo** con ciclo de vida (EMITIDO → CIERRE_TECNICO → CIERRE_TOTAL)
- **Notificación** de tareas ejecutadas, materiales consumidos, horas-hombre
- **Vista Kanban** para seguimiento visual
- **Costos** asociados a cada orden

## Usuarios Involucrados

| Rol | Función |
|-----|---------|
| **Planificador** | Crea Planes de Mantenimiento, Hojas de Ruta, Secciones, Tareas |
| **Supervisor** | Aprueba avisos, gestiona órdenes, genera lanzamientos |
| **Técnico/Ejecutor** | Ejecuta tareas, notifica avances (app móvil) |
| **Administrador** | Configura roles, permisos, estados permitidos |
| **Analista** | Consulta reportes, indicadores, exportaciones Excel |

## Procesos Relacionados

### Gestión de Equipos
- Equipos organizados jerárquicamente (Equipo → EquipoPadre)
- Equipos montados en Ubicaciones
- Contadores asociados a equipos (horómetros, kilómetros, etc.)
- Puntos de medida para monitoreo

### Gestión de Ubicaciones
- Ubicaciones funcionales donde se instalan equipos
- Centro de costo asociado
- Organización asociada

### Logística
- Materiales con unidades de medida
- Notas de salida de almacén vinculadas a órdenes
- Hojas de aceptación de servicios

### Alertas y Monitoreo
- Alertas por puntos de medida fuera de rango
- Niveles de alerta configurables

## Integraciones

| Integración | Descripción | Evidencia |
|-------------|-------------|-----------|
| **WhatsApp (Facebook Graph API)** | Notificación por WhatsApp al crear avisos | Hardcodeada en `Aviso.Controller.cs` vía `NotificarWspAsync` |
| **API REST (WebAPI)** | API para aplicación móvil y sistemas externos | `AMSYS.WebAPI` con autenticación por token |
| **Excel (ClosedXML)** | Exportación de planificaciones y previsualizaciones | En `PlanMantenimiento.Logica.cs` |

## Dependencias del Módulo

### Dependencias internas (otros módulos de AMSYS)
- **Administración**: TipoMantenimiento, TallerResponsable, Prioridad, Especialidad, CentroCosto, CuentaContable, UnidadMedidaServicio, Sistema, Parte
- **Seguridad**: Usuario, Rol, RolEstadoOrdenTrabajo, RolEstadoAviso, Empresa, Organizacion
- **Logística**: Material, NotaSalida, HojaAceptacion

### Dependencias externas (paquetes)
- **Entity Framework Core** (PostgreSQL)
- **ClosedXML** (generación de Excel)
- **jQuery + Bootstrap** (frontend)

## Contexto Funcional

El sistema opera bajo un modelo **multi-empresa** y **multi-organización**:
- Cada entidad pertenece a una `Empresa` (tenant)
- Las Órdenes de Trabajo se asocian a una `Organizacion` dentro de la empresa
- Los usuarios pueden tener acceso a múltiples organizaciones dentro de su empresa
- Los roles controlan qué estados de OT y Aviso puede gestionar cada usuario

### Modelo Multi-Tenant

```
Empresa (tenant)
    ├── Organizacion 1
    │       ├── Ubicaciones
    │       └── Equipos
    ├── Organizacion 2
    └── ...
```

El `EmpresaId` actúa como discriminador de tenant en prácticamente todas las entidades. Las consultas filtran por `EmpresaId` del usuario autenticado.
