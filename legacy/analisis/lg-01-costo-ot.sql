-- ============================================================================================
-- LG-01 · Costo de materiales de la orden de trabajo (decisión DL-03: recalcular todas)
--
-- En la nota de salida, "precio" es el IMPORTE de la línea (el unitario es precio / cantidad).
-- El cálculo anterior sumaba cantidad * precio, así que el costo de material de cada OT con notas
-- de salida quedó inflado.
--
-- Uso:
--   1) Ejecutar el INFORME y guardar el resultado (es el respaldo de lo que va a cambiar).
--   2) Revisar el total de la diferencia con el propietario.
--   3) Ejecutar la CORRECCIÓN dentro de una transacción, con la aplicación detenida o en una
--      ventana sin registro de notas de salida.
--
-- La corrección reproduce la fórmula de OrdenTrabajoCostoLogica.CalcularAsync para el material
-- (DL-01, opción c: se mantienen las dos fuentes):
--     costomaterial = notas de salida no anuladas (importe)
--                   + materiales notificados en la OT (cantidad * precio)
--                   + materiales externos notificados (cantidad * precio)
-- No toca costoservicio ni costoempleado.
-- ============================================================================================

-- ------------------------------------------------------------------ INFORME (sólo lectura)
WITH salida AS (
    SELECT ns.ordentrabajoid,
           SUM(nsm.precio)               AS importe_correcto,
           SUM(nsm.cantidad * nsm.precio) AS importe_anterior
    FROM notasalidamaterial nsm
    JOIN notasalida ns ON ns.id = nsm.notasalidaid
    WHERE ns.ordentrabajoid IS NOT NULL
      AND ns.anulado = false
    GROUP BY ns.ordentrabajoid
),
notificado AS (
    SELECT ordentrabajoid, SUM(cantidad * precio) AS importe
    FROM notificacionmaterial
    GROUP BY ordentrabajoid
),
externo AS (
    SELECT ordentrabajoid, SUM(cantidad * precio) AS importe
    FROM notificacionmaterialexterno
    GROUP BY ordentrabajoid
)
SELECT ot.id                                              AS orden_trabajo_id,
       ot.codigo                                          AS orden_trabajo,
       ot.empresaid,
       otc.costomaterial                                  AS costo_material_actual,
       COALESCE(s.importe_correcto, 0)
           + COALESCE(n.importe, 0)
           + COALESCE(e.importe, 0)                       AS costo_material_corregido,
       otc.costomaterial
           - (COALESCE(s.importe_correcto, 0)
              + COALESCE(n.importe, 0)
              + COALESCE(e.importe, 0))                   AS diferencia,
       COALESCE(s.importe_anterior, 0)                    AS salidas_calculo_anterior,
       COALESCE(s.importe_correcto, 0)                    AS salidas_calculo_corregido
FROM ordentrabajocosto otc
JOIN ordentrabajo ot ON ot.id = otc.id
LEFT JOIN salida s     ON s.ordentrabajoid = otc.id
LEFT JOIN notificado n ON n.ordentrabajoid = otc.id
LEFT JOIN externo e    ON e.ordentrabajoid = otc.id
WHERE otc.costomaterial IS DISTINCT FROM (COALESCE(s.importe_correcto, 0) + COALESCE(n.importe, 0) + COALESCE(e.importe, 0))
ORDER BY ABS(otc.costomaterial - (COALESCE(s.importe_correcto, 0) + COALESCE(n.importe, 0) + COALESCE(e.importe, 0))) DESC;

-- Resumen por empresa (para la conversación con el propietario)
-- WITH ... (mismas CTE) SELECT ot.empresaid, COUNT(*) AS ordenes, SUM(diferencia) ...

-- ------------------------------------------------------------------ CORRECCIÓN (escribe)
-- BEGIN;
--
-- WITH salida AS (
--     SELECT ns.ordentrabajoid, SUM(nsm.precio) AS importe
--     FROM notasalidamaterial nsm
--     JOIN notasalida ns ON ns.id = nsm.notasalidaid
--     WHERE ns.ordentrabajoid IS NOT NULL AND ns.anulado = false
--     GROUP BY ns.ordentrabajoid
-- ),
-- notificado AS (
--     SELECT ordentrabajoid, SUM(cantidad * precio) AS importe FROM notificacionmaterial GROUP BY ordentrabajoid
-- ),
-- externo AS (
--     SELECT ordentrabajoid, SUM(cantidad * precio) AS importe FROM notificacionmaterialexterno GROUP BY ordentrabajoid
-- )
-- UPDATE ordentrabajocosto otc
-- SET costomaterial = COALESCE(s.importe, 0) + COALESCE(n.importe, 0) + COALESCE(e.importe, 0)
-- FROM ordentrabajocosto base
-- LEFT JOIN salida s     ON s.ordentrabajoid = base.id
-- LEFT JOIN notificado n ON n.ordentrabajoid = base.id
-- LEFT JOIN externo e    ON e.ordentrabajoid = base.id
-- WHERE otc.id = base.id
--   AND otc.costomaterial IS DISTINCT FROM (COALESCE(s.importe, 0) + COALESCE(n.importe, 0) + COALESCE(e.importe, 0));
--
-- -- Comprobar que el INFORME ya no devuelve filas antes de confirmar:
-- -- COMMIT;   (o ROLLBACK; si algo no cuadra)
