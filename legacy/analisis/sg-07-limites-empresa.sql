-- ============================================================================================
-- SG-07 · Límites por perfil de la empresa
--
-- El formulario de la ficha de empresa sólo enviaba "cantidadusuario" y "cantidadalmacenamiento",
-- y EmpresaLogica.ActualizarAsync escribía los cuatro límites por perfil como "?? 0". Resultado:
-- cada vez que alguien guardaba una empresa, sus límites de administradores, mantenimiento,
-- operadores y clientes volvían a 0. El alta tampoco los pedía, así que toda empresa creada desde
-- la aplicación nace con los cuatro en 0.
--
-- Mientras el límite se comprobaba con perfil nulo (el defecto de PuedeAgregarUsuario), esos ceros
-- no bloqueaban nada. En cuanto SG-06 compruebe el límite del perfil que corresponde, una empresa
-- con ceros NO PODRÁ DAR DE ALTA A NADIE.
--
-- Uso:
--   1) Ejecutar el INFORME y guardarlo: es la foto de lo que hay que restaurar.
--   2) Acordar con el propietario el límite que corresponde a cada empresa según su contrato.
--   3) Ejecutar la CORRECCIÓN sólo con esos valores acordados. La plantilla de abajo NO inventa
--      los límites contratados: parte de lo que cada empresa ya consume, que es el mínimo para no
--      dejar a nadie fuera, y hay que revisarla empresa por empresa.
--
-- Ejecutar antes de desplegar SG-06.
-- ============================================================================================

-- ------------------------------------------------------------------ INFORME (sólo lectura)
-- Por empresa: el límite guardado de cada perfil y los usuarios activos que ya lo consumen.
-- Perfil: 0 ADMINISTRADOR · 1 MANTENIMIENTO · 2 OPERADOR · 3 CLIENTE · NULL sin perfil asignado
WITH consumo AS (
    SELECT u.empresaid,
           COUNT(*) FILTER (WHERE r.perfil = 0)    AS usa_administrador,
           COUNT(*) FILTER (WHERE r.perfil = 1)    AS usa_mantenimiento,
           COUNT(*) FILTER (WHERE r.perfil = 2)    AS usa_operador,
           COUNT(*) FILTER (WHERE r.perfil = 3)    AS usa_cliente,
           COUNT(*) FILTER (WHERE r.perfil IS NULL) AS usa_sin_perfil,
           COUNT(*)                                 AS usa_total
    FROM usuario u
    JOIN rol r ON r.id = u.rolid
    WHERE u.activo
    GROUP BY u.empresaid
)
SELECT e.id,
       e.nombre,
       e.tipoplan,
       e.vencimiento,
       l.cantidadusuario        AS lim_total,
       l.cantidadadministrador  AS lim_administrador,
       l.cantidadmantenimiento  AS lim_mantenimiento,
       l.cantidadoperador       AS lim_operador,
       l.cantidadcliente        AS lim_cliente,
       COALESCE(c.usa_total, 0)          AS usa_total,
       COALESCE(c.usa_administrador, 0)  AS usa_administrador,
       COALESCE(c.usa_mantenimiento, 0)  AS usa_mantenimiento,
       COALESCE(c.usa_operador, 0)       AS usa_operador,
       COALESCE(c.usa_cliente, 0)        AS usa_cliente,
       COALESCE(c.usa_sin_perfil, 0)     AS usa_sin_perfil,
       -- Qué pasaría hoy si el límite se comprobara por perfil
       CASE
           WHEN l.id IS NULL THEN 'SIN FILA DE LIMITES'
           WHEN COALESCE(c.usa_administrador, 0) > l.cantidadadministrador
             OR COALESCE(c.usa_mantenimiento, 0) > l.cantidadmantenimiento
             OR COALESCE(c.usa_operador, 0)      > l.cantidadoperador
             OR COALESCE(c.usa_cliente, 0)       > l.cantidadcliente  THEN 'LIMITE POR DEBAJO DE LO QUE YA USA'
           WHEN l.cantidadadministrador = 0 AND l.cantidadmantenimiento = 0
            AND l.cantidadoperador = 0 AND l.cantidadcliente = 0       THEN 'TODOS LOS PERFILES EN 0'
           ELSE 'OK'
       END AS situacion
FROM empresa e
LEFT JOIN limitacion l ON l.id = e.id
LEFT JOIN consumo    c ON c.empresaid = e.id
ORDER BY e.id;

-- Empresas sin fila en "limitacion": hoy hacen reventar PuedeAgregarUsuario con
-- NullReferenceException (Empresa.Logica.cs, GetOne(...)!). SG-06 las trata como límite cero.
SELECT e.id, e.nombre
FROM empresa e
LEFT JOIN limitacion l ON l.id = e.id
WHERE l.id IS NULL
ORDER BY e.id;

-- Usuarios activos cuyo rol no tiene perfil: no cuentan contra ningún límite por perfil.
-- Conviene asignarles perfil antes de SG-06, o quedarán fuera del control de límites.
SELECT u.empresaid, r.id AS rolid, r.nombre AS rol, COUNT(*) AS usuarios_activos
FROM usuario u
JOIN rol r ON r.id = u.rolid
WHERE u.activo AND r.perfil IS NULL
GROUP BY u.empresaid, r.id, r.nombre
ORDER BY u.empresaid, r.nombre;

-- ------------------------------------------------------------------ CORRECCIÓN (plantilla)
-- NO EJECUTAR TAL CUAL. Los límites son los que dice el contrato de cada empresa, y eso no está
-- en la base: esto sólo crea la fila que falta y deja cada límite en lo que la empresa YA consume,
-- para que nadie quede fuera. Revisar empresa por empresa con el informe de arriba antes de correr.
--
-- BEGIN;
--
-- -- 1) Crear la fila de límites de las empresas que no la tienen
-- INSERT INTO limitacion (id, cantidadusuario, cantidadalmacenamiento,
--                         cantidadadministrador, cantidadmantenimiento, cantidadoperador, cantidadcliente)
-- SELECT e.id, 0, 0, 0, 0, 0, 0
-- FROM empresa e
-- LEFT JOIN limitacion l ON l.id = e.id
-- WHERE l.id IS NULL;
--
-- -- 2) Subir cada límite al menos a lo que la empresa ya consume
-- WITH consumo AS (
--     SELECT u.empresaid,
--            COUNT(*) FILTER (WHERE r.perfil = 0) AS usa_administrador,
--            COUNT(*) FILTER (WHERE r.perfil = 1) AS usa_mantenimiento,
--            COUNT(*) FILTER (WHERE r.perfil = 2) AS usa_operador,
--            COUNT(*) FILTER (WHERE r.perfil = 3) AS usa_cliente,
--            COUNT(*)                             AS usa_total
--     FROM usuario u JOIN rol r ON r.id = u.rolid
--     WHERE u.activo
--     GROUP BY u.empresaid
-- )
-- UPDATE limitacion l
-- SET cantidadadministrador = GREATEST(l.cantidadadministrador, c.usa_administrador),
--     cantidadmantenimiento = GREATEST(l.cantidadmantenimiento, c.usa_mantenimiento),
--     cantidadoperador      = GREATEST(l.cantidadoperador,      c.usa_operador),
--     cantidadcliente       = GREATEST(l.cantidadcliente,       c.usa_cliente),
--     cantidadusuario       = GREATEST(l.cantidadusuario,       c.usa_total)
-- FROM consumo c
-- WHERE c.empresaid = l.id;
--
-- -- Volver a ejecutar el INFORME y comprobar que ninguna empresa queda en
-- -- 'LIMITE POR DEBAJO DE LO QUE YA USA' ni en 'SIN FILA DE LIMITES'.
-- COMMIT;
