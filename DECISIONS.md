# Decisiones

## Tomadas

| ID | Fecha | Decisión | Motivo |
|----|-------|----------|--------|
| `D-NP-00` | 2026-10-02 | Nueva plataforma (Opción 3: un producto configurable); el repo actual pasa a legacy | Ramas por cliente no escalan: correcciones N veces, migraciones incompatibles |
| `D-NP-01` | 2026-10-02 | Front en **Blazor Server** (`InteractiveServer`). Se eliminó `Amsys.Web.Client` | Decisión del propietario. Sin descarga inicial, depuración simple. **Mitigar**: reconexión de circuito y, si hay varias réplicas (k8s), afinidad de sesión (sticky sessions) |
| `D-NP-01b` | 2026-10-02 | Aunque sea Server, el front **consume `Amsys.Api` por HTTP** (sólo referencia `Contracts`), no `Application` directamente | Una sola fuente de lógica y autorización, la misma que usa la app móvil. Revisable si la latencia lo exige |
| `D-NP-02` | 2026-10-02 | Repo **`amsys`**; el legacy se renombra a `AMSYS-legacy`. Namespaces `Amsys.*`, carpeta `D:\Documentos\Amsys`; se mantiene la marca AMSYS | Clientes conocen la marca; distinguir código nuevo del legacy |
| `D-NP-03` | 2026-10-02 | **Minimal APIs** agrupadas por módulo con `MapGroup` | Decisión del propietario |
| `D-NP-04` | 2026-10-02 | **Nueva versión de la app móvil** contra `/api/v1`; la API legacy sigue viva hasta el corte de cada cliente | Decisión del propietario |
| `D-NP-06` | 2026-10-02 | API separada (`Amsys.Api`) como único backend para web y móvil | Una sola fuente de lógica y autorización |
| `D-NP-08` | 2026-10-02 | `NombreUsuario` **único en toda la BD** (índice único parcial, los eliminados liberan el nombre) | El login ocurre antes de saber la empresa |
| `D-NP-09` | 2026-10-02 | Claves primarias `int` identity | Igual que el legacy: simplifica el ETL de migración de clientes |
| `D-NP-10` | 2026-10-02 | Sin empresa actual, las consultas de entidades por empresa devuelven vacío (seguro por defecto). Procesos del sistema (semillas, ETL) escriben con `EmpresaId` explícito | Imposible filtrar datos por olvido |
| `D-NP-11` | 2026-10-02 | Reloj = `TimeProvider` de .NET (no interfaz propia `IReloj`) | Estándar del framework, testeable |
| `D-NP-07` | 2026-10-02 | .NET 10, `.slnx`, Central Package Management, xunit.v3 + Microsoft.Testing.Platform | Estándar actual; versiones centralizadas |

### Heredadas del legacy (vinculantes)

| ID | Decisión |
|----|----------|
| `D-05` | Generación de OT desde planes **a demanda**, nunca automática |
| `D-02` | No se puede anular una OT en `CIERRE_TECNICO` |
| `D-03` | Códigos no únicos: alerta, no bloqueo |

## Pendientes

| ID | Pregunta | Recomendación |
|----|----------|---------------|
| `D-NP-05` | ¿Qué se sigue haciendo en el legacy? | Sólo hotfix y seguridad crítica |
| `D-MC-01` | ¿Instancia + BD por cliente o multi-tenant único? | Por cliente al inicio (mismo artefacto); multi-tenant después |
| `D-MC-02` | Campos personalizados en JSONB o columnas | JSONB |
| `D-MC-03` | ¿Estados renombrados de caja_arequipa equivalen a los canónicos? | Confirmar con el cliente |
| `D-MC-04` | Módulos de oterra (Área, Impacto, Conformidad, Turnos): ¿producto o exclusivos? | Producto |
| `D-MC-05` | Soft delete para todos | Sí — **ya implementado así en `Entidad`**; confirmar |
| `D-MC-06` | Versión base de MTBF/MTTR/Disponibilidad | La de oterra, revisada con cada cliente |
