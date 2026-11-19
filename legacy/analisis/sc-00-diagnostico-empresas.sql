-- ============================================================================================
-- SC-00 · Diagnóstico de empresas, usuarios y roles de UNA base de datos (sólo lectura)
--
-- Plan: legacy/planes/PLAN-SEGURIDAD-CENTRAL.md (fase S-0).
--
-- Para qué: decidir, BD por BD, qué empresa es la que sirve y cuáles se limpian. No escribe nada,
-- no crea objetos: sólo SELECT. Sirve en todas las ramas, aunque el esquema sea distinto, porque
-- las tablas con "empresaid" se descubren solas (information_schema + query_to_xml).
--
-- Uso: ejecutar cada bloque en la BD del cliente (DBeaver o psql) y guardar los resultados en
-- legacy/analisis/sc-00/<bd>.md o .csv. Repetir en cada BD de la tabla del plan (§2).
-- ============================================================================================


-- ------------------------------------------------------------------ 1. Empresas y licencia
SELECT e.id,
       e.nombre,
       e.tipoplan,
       e.registro::date        AS registro,
       e.vencimiento::date     AS vencimiento,
       l.cantidadusuario       AS limite_usuarios,
       (SELECT count(*) FROM usuario u WHERE u.empresaid = e.id)                 AS usuarios,
       (SELECT count(*) FROM usuario u WHERE u.empresaid = e.id AND u.activo)    AS usuarios_activos
FROM empresa e
LEFT JOIN limitacion l ON l.id = e.id
ORDER BY e.id;


-- ------------------------------------------------------------------ 2. Datos por empresa (resumen)
-- Cuántas filas tiene cada empresa en todas las tablas con "empresaid". Una empresa con casi
-- nada es candidata a limpiar; la que concentra OT, avisos y equipos es la que sirve.
WITH tablas AS (
    SELECT c.table_name
    FROM information_schema.columns c
    JOIN information_schema.tables t
      ON t.table_schema = c.table_schema AND t.table_name = c.table_name AND t.table_type = 'BASE TABLE'
    WHERE c.table_schema = 'public' AND c.column_name = 'empresaid'
),
conteo AS (
    SELECT tb.table_name, x.empresaid, x.filas
    FROM tablas tb,
         XMLTABLE('/table/row'
                  PASSING query_to_xml(format('SELECT empresaid, count(*) AS filas FROM public.%I GROUP BY empresaid',
                                              tb.table_name), false, false, '')
                  COLUMNS empresaid int PATH 'empresaid', filas bigint PATH 'filas') x
)
SELECT e.id,
       e.nombre,
       coalesce(sum(c.filas), 0)                                           AS filas_total,
       count(c.table_name)                                                 AS tablas_con_datos,
       coalesce(max(c.filas) FILTER (WHERE c.table_name = 'ordentrabajo'), 0) AS ot,
       coalesce(max(c.filas) FILTER (WHERE c.table_name = 'aviso'), 0)        AS avisos,
       coalesce(max(c.filas) FILTER (WHERE c.table_name = 'equipo'), 0)       AS equipos,
       coalesce(max(c.filas) FILTER (WHERE c.table_name = 'ubicacion'), 0)    AS ubicaciones,
       coalesce(max(c.filas) FILTER (WHERE c.table_name = 'planmantenimiento'), 0) AS planes
FROM empresa e
LEFT JOIN conteo c ON c.empresaid = e.id
GROUP BY e.id, e.nombre
ORDER BY filas_total DESC;


-- ------------------------------------------------------------------ 3. Datos por empresa (detalle por tabla)
-- Sólo las tablas con filas. Filas con empresaid sin empresa = huérfanas (también se limpian).
WITH tablas AS (
    SELECT c.table_name
    FROM information_schema.columns c
    JOIN information_schema.tables t
      ON t.table_schema = c.table_schema AND t.table_name = c.table_name AND t.table_type = 'BASE TABLE'
    WHERE c.table_schema = 'public' AND c.column_name = 'empresaid'
),
conteo AS (
    SELECT tb.table_name, x.empresaid, x.filas
    FROM tablas tb,
         XMLTABLE('/table/row'
                  PASSING query_to_xml(format('SELECT empresaid, count(*) AS filas FROM public.%I GROUP BY empresaid',
                                              tb.table_name), false, false, '')
                  COLUMNS empresaid int PATH 'empresaid', filas bigint PATH 'filas') x
)
SELECT c.empresaid,
       coalesce(e.nombre, '<<SIN EMPRESA: huérfanas>>') AS empresa,
       c.table_name,
       c.filas
FROM conteo c
LEFT JOIN empresa e ON e.id = c.empresaid
ORDER BY c.empresaid NULLS FIRST, c.filas DESC;


-- ------------------------------------------------------------------ 4. Última actividad por empresa
-- Fecha más reciente de "registro" en las tablas que tienen empresaid y registro (OT, avisos…).
WITH tablas AS (
    SELECT c.table_name
    FROM information_schema.columns c
    JOIN information_schema.tables t
      ON t.table_schema = c.table_schema AND t.table_name = c.table_name AND t.table_type = 'BASE TABLE'
    WHERE c.table_schema = 'public' AND c.column_name = 'empresaid'
      AND EXISTS (SELECT 1 FROM information_schema.columns r
                  WHERE r.table_schema = 'public' AND r.table_name = c.table_name AND r.column_name = 'registro')
),
ultima AS (
    SELECT tb.table_name, x.empresaid, x.ultima
    FROM tablas tb,
         XMLTABLE('/table/row'
                  PASSING query_to_xml(format('SELECT empresaid, max(registro)::date AS ultima FROM public.%I GROUP BY empresaid',
                                              tb.table_name), false, false, '')
                  COLUMNS empresaid int PATH 'empresaid', ultima date PATH 'ultima') x
)
SELECT e.id, e.nombre, max(u.ultima) AS ultima_actividad
FROM empresa e
LEFT JOIN ultima u ON u.empresaid = e.id
GROUP BY e.id, e.nombre
ORDER BY ultima_actividad DESC NULLS LAST;


-- ------------------------------------------------------------------ 5. Usuarios
SELECT u.id, u.empresaid, e.nombre AS empresa, u.nombre, u.correo, r.nombre AS rol, u.activo
FROM usuario u
LEFT JOIN empresa e ON e.id = u.empresaid
LEFT JOIN rol r     ON r.id = u.rolid
ORDER BY u.empresaid, u.activo DESC, u.nombre;


-- ------------------------------------------------------------------ 6. Correos repetidos dentro de la BD
SELECT lower(trim(u.correo)) AS correo,
       count(*)              AS veces,
       string_agg(u.id || ' (empresa ' || u.empresaid || ', ' || CASE WHEN u.activo THEN 'activo' ELSE 'inactivo' END || ')',
                  ', ' ORDER BY u.id) AS usuarios
FROM usuario u
GROUP BY lower(trim(u.correo))
HAVING count(*) > 1
ORDER BY veces DESC;


-- ------------------------------------------------------------------ 7. Roles (son globales a la BD: no tienen empresaid)
SELECT r.id, r.nombre, r.activo,
       count(u.id)                                                    AS usuarios,
       string_agg(DISTINCT u.empresaid::text, ', ')                   AS empresas_que_lo_usan,
       (SELECT count(*) FROM rolpagina rp WHERE rp.rolid = r.id)      AS paginas,
       (SELECT count(*) FROM rolmenu   rm WHERE rm.rolid = r.id)      AS menus
FROM rol r
LEFT JOIN usuario u ON u.rolid = r.id
GROUP BY r.id, r.nombre, r.activo
ORDER BY r.id;


-- ------------------------------------------------------------------ 8. Permisos huérfanos
SELECT 'rolpagina → página inexistente' AS caso, count(*) FROM rolpagina rp WHERE NOT EXISTS (SELECT 1 FROM pagina p WHERE p.id = rp.paginaid)
UNION ALL
SELECT 'rolmenu → menú inexistente',             count(*) FROM rolmenu rm   WHERE NOT EXISTS (SELECT 1 FROM menu m   WHERE m.id = rm.menuid)
UNION ALL
SELECT 'usuarioorganizacion → org. inexistente', count(*) FROM usuarioorganizacion uo WHERE NOT EXISTS (SELECT 1 FROM organizacion o WHERE o.id = uo.organizacionid)
UNION ALL
SELECT 'usuarioorganizacion → org. de otra empresa', count(*)
FROM usuarioorganizacion uo
JOIN usuario u      ON u.id = uo.usuarioid
JOIN organizacion o ON o.id = uo.organizacionid
WHERE o.empresaid <> u.empresaid;


-- ------------------------------------------------------------------ 9. Ids máximos (para elegir los rangos de S-4)
SELECT 'empresa' AS tabla, max(id) FROM empresa
UNION ALL SELECT 'usuario', max(id) FROM usuario
UNION ALL SELECT 'rol', max(id) FROM rol
UNION ALL SELECT 'organizacion', max(id) FROM organizacion;
