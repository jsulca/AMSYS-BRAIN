-- ============================================================================================
-- SC-02 · Limpieza en amsys_v3_oterra: empresa de pruebas y usuarios duplicados
--
-- Plan: legacy/planes/PLAN-SEGURIDAD-CENTRAL.md (fase S-2). Diagnóstico: legacy/analisis/sc-00/amsys_v3_oterra.md
-- Decisión del propietario (2026-11-19): borrar la empresa 2 TEST-OTERRA (con su usuario 47) y los usuarios
-- duplicados 45 y 46 de OTERRA (sin datos propios). Se conserva la empresa 1.
-- Versión de eulen-SC02-limpieza-empresas.sql con un parámetro más: usuarios sueltos a borrar de empresas que
-- se conservan. Usuario destino NULL = abortar si alguno tuviera autoría que reasignar.
--
-- Cómo funciona (genérico, sirve para otras BD cambiando los parámetros):
--   1. Marca las filas de las empresas a borrar (toda tabla con empresaid) y, siguiendo las FK, todo lo que
--      cuelga de ellas (tareas de OT, logs, detalle de notas…), aunque no tenga empresaid.
--      Las FK hacia usuario sólo se siguen en tablas "personales" (alertas, organizaciones del usuario,
--      suscripciones de notificación); en el resto se REASIGNA al usuario destino.
--   2. Aborta si la marca alcanzó alguna fila de una empresa que se conserva.
--   3. Reasigna la autoría que queda en filas que se conservan.
--   4. Borra lo marcado (FK desactivadas sólo durante el borrado) y verifica que no queda NINGUNA fila
--      huérfana en ninguna FK y que la empresa que se conserva tiene las mismas filas que antes.
--   Todo en una transacción. Con -v commit=0 termina en ROLLBACK (ensayo); con -v commit=1, COMMIT.
--
-- Uso:  psql -h <servidor> -U postgres -d amsys_v3_oterra -v commit=0 -f oterra-SC02-limpieza-empresas.sql
-- Requisitos: respaldo pg_dump previo; usuario con permiso para session_replication_role (superusuario).
-- Nota: los archivos físicos de los adjuntos borrados (si están en disco) no se tocan.
-- ============================================================================================
\set ON_ERROR_STOP on

BEGIN;

CREATE TEMP TABLE sc_param (empresas_borrar int[], usuarios_borrar int[], usuario_destino int) ON COMMIT DROP;
INSERT INTO sc_param VALUES ('{2}', '{45,46}', NULL);

CREATE TEMP TABLE sc_marca   (tbl oid, rid tid, PRIMARY KEY (tbl, rid)) ON COMMIT DROP;
CREATE TEMP TABLE sc_resumen (orden serial, paso text, tabla text, filas bigint) ON COMMIT DROP;

DO $$
DECLARE
    emp       int[];
    usu       int[];
    sueltos   bigint;
    destino   int;
    personal  text[] := ARRAY['alerta','usuarioorganizacion','notificacionaviso','notificacioncontador',
                              'notificacionequipoaspecto','notificacionpuntomedida','notificacionubicacionaspecto'];
    usuario_oid oid := 'public.usuario'::regclass;
    r record; n bigint; total bigint; antes bigint := 0; despues bigint := 0; huerfanas bigint := 0;
    cond text; nn text;
BEGIN
    SELECT empresas_borrar, usuarios_borrar, usuario_destino INTO emp, usu, destino FROM sc_param;
    -- usuarios sueltos que pertenecen a empresas que se conservan (restan de la cuenta final)
    SELECT count(*) INTO sueltos FROM usuario WHERE id = ANY(usu) AND NOT (empresaid = ANY(emp));
    IF sueltos <> coalesce(array_length(usu, 1), 0) - (SELECT count(*) FROM usuario WHERE id = ANY(usu) AND empresaid = ANY(emp)) THEN
        RAISE EXCEPTION 'Algún usuario de la lista no existe';
    END IF;
    IF destino = ANY(usu) THEN RAISE EXCEPTION 'El usuario destino está en la lista de borrado'; END IF;

    IF destino IS NOT NULL AND NOT EXISTS (SELECT 1 FROM usuario WHERE id = destino AND NOT (empresaid = ANY(emp))) THEN
        RAISE EXCEPTION 'El usuario destino % no es de una empresa que se conserva', destino;
    END IF;

    -- Filas de la empresa que se conserva, antes
    FOR r IN SELECT c.table_name FROM information_schema.columns c
             JOIN information_schema.tables t ON t.table_schema = c.table_schema AND t.table_name = c.table_name
             WHERE c.table_schema = 'public' AND c.column_name = 'empresaid' AND t.table_type = 'BASE TABLE' LOOP
        EXECUTE format('SELECT count(*) FROM public.%I WHERE empresaid IS NOT NULL AND NOT (empresaid = ANY($1))', r.table_name) INTO n USING emp;
        antes := antes + n;
    END LOOP;

    -- 1. Semillas: empresa, sus 1:1 (configuracion, limitacion: PK = id de empresa) y toda tabla con empresaid
    INSERT INTO sc_marca SELECT 'public.empresa'::regclass, ctid FROM empresa WHERE id = ANY(emp);
    INSERT INTO sc_marca SELECT 'public.usuario'::regclass, ctid FROM usuario WHERE id = ANY(usu) ON CONFLICT DO NOTHING;
    FOR r IN SELECT c.table_name FROM information_schema.columns c
             JOIN information_schema.tables t ON t.table_schema = c.table_schema AND t.table_name = c.table_name
             WHERE c.table_schema = 'public' AND c.column_name = 'empresaid' AND t.table_type = 'BASE TABLE' LOOP
        EXECUTE format('INSERT INTO sc_marca SELECT %s, ctid FROM public.%I WHERE empresaid = ANY($1) ON CONFLICT DO NOTHING',
                       to_regclass(format('public.%I', r.table_name))::oid, r.table_name) USING emp;
    END LOOP;

    -- 1b. Cierre por FK: hijos de filas marcadas
    LOOP
        total := 0;
        FOR r IN SELECT c.conrelid, c.confrelid, c.conkey, c.confkey, cl.relname AS hijo
                 FROM pg_constraint c JOIN pg_class cl ON cl.oid = c.conrelid
                 WHERE c.contype = 'f' AND c.connamespace = 'public'::regnamespace LOOP
            CONTINUE WHEN r.confrelid = usuario_oid AND NOT (r.hijo = ANY(personal));
            SELECT string_agg(format('h.%I = p.%I', ah.attname, ap.attname), ' AND ') INTO cond
            FROM unnest(r.conkey, r.confkey) AS k(hc, pc)
            JOIN pg_attribute ah ON ah.attrelid = r.conrelid  AND ah.attnum = k.hc
            JOIN pg_attribute ap ON ap.attrelid = r.confrelid AND ap.attnum = k.pc;
            EXECUTE format('INSERT INTO sc_marca SELECT %s, h.ctid FROM %s h JOIN %s p ON %s
                            JOIN sc_marca m ON m.tbl = %s AND m.rid = p.ctid ON CONFLICT DO NOTHING',
                           r.conrelid, r.conrelid::regclass, r.confrelid::regclass, cond, r.confrelid);
            GET DIAGNOSTICS n = ROW_COUNT;
            total := total + n;
        END LOOP;
        EXIT WHEN total = 0;
    END LOOP;

    -- 2. Seguridad: la marca no puede alcanzar filas de empresas que no se borran
    FOR r IN SELECT DISTINCT m.tbl, cl.relname FROM sc_marca m JOIN pg_class cl ON cl.oid = m.tbl
             WHERE EXISTS (SELECT 1 FROM information_schema.columns c
                           WHERE c.table_schema = 'public' AND c.table_name = cl.relname AND c.column_name = 'empresaid') LOOP
        EXECUTE format('SELECT count(*) FROM %s t JOIN sc_marca m ON m.tbl = %s AND m.rid = t.ctid
                        WHERE t.empresaid IS NOT NULL AND NOT (t.empresaid = ANY($1)) %s', r.tbl::regclass, r.tbl,
                        CASE WHEN r.tbl = usuario_oid THEN 'AND NOT (t.id = ANY($2))' ELSE '' END)
            INTO n USING emp, usu;
        IF n > 0 THEN
            RAISE EXCEPTION 'La marca alcanzó % filas de otra empresa en %', n, r.relname;
        END IF;
    END LOOP;

    -- 3. Reasignar autoría en filas que se conservan
    FOR r IN SELECT c.conrelid, cl.relname AS hijo, ah.attname AS col
             FROM pg_constraint c JOIN pg_class cl ON cl.oid = c.conrelid
             JOIN pg_attribute ah ON ah.attrelid = c.conrelid AND ah.attnum = c.conkey[1]
             WHERE c.contype = 'f' AND c.confrelid = usuario_oid AND NOT (cl.relname = ANY(personal)) LOOP
        IF destino IS NULL THEN
            EXECUTE format('SELECT count(*) FROM %s h WHERE h.%I IN (SELECT id FROM usuario WHERE empresaid = ANY($1) OR id = ANY($3))
                              AND NOT EXISTS (SELECT 1 FROM sc_marca m WHERE m.tbl = %s AND m.rid = h.ctid)',
                           r.conrelid::regclass, r.col, r.conrelid) INTO n USING emp, NULL::int, usu;
            IF n > 0 THEN RAISE EXCEPTION 'Hay % filas en %.% de usuarios a borrar que se conservan: falta usuario destino', n, r.hijo, r.col; END IF;
            CONTINUE;
        END IF;
        EXECUTE format('UPDATE %s h SET %I = $1
                        WHERE h.%I IN (SELECT id FROM usuario WHERE empresaid = ANY($2) OR id = ANY($3))
                          AND NOT EXISTS (SELECT 1 FROM sc_marca m WHERE m.tbl = %s AND m.rid = h.ctid)',
                       r.conrelid::regclass, r.col, r.col, r.conrelid) USING destino, emp, usu;
        GET DIAGNOSTICS n = ROW_COUNT;
        IF n > 0 THEN INSERT INTO sc_resumen (paso, tabla, filas) VALUES ('reasignado a usuario ' || destino, r.hijo || '.' || r.col, n); END IF;
    END LOOP;

    -- 4. Borrar lo marcado (sin disparar FK; la verificación de abajo garantiza la integridad)
    SET LOCAL session_replication_role = replica;
    FOR r IN SELECT m.tbl, cl.relname, count(*) AS filas FROM sc_marca m JOIN pg_class cl ON cl.oid = m.tbl
             GROUP BY m.tbl, cl.relname LOOP
        EXECUTE format('DELETE FROM %s t WHERE EXISTS (SELECT 1 FROM sc_marca m WHERE m.tbl = %s AND m.rid = t.ctid)',
                       r.tbl::regclass, r.tbl);
        GET DIAGNOSTICS n = ROW_COUNT;
        IF n <> r.filas THEN RAISE EXCEPTION 'En % se esperaban % filas y se borraron %', r.relname, r.filas, n; END IF;
        INSERT INTO sc_resumen (paso, tabla, filas) VALUES ('borrado', r.relname, n);
    END LOOP;
    SET LOCAL session_replication_role = origin;

    -- 5a. Verificar: ninguna fila huérfana en ninguna FK del esquema
    FOR r IN SELECT c.conname, c.conrelid, c.confrelid, c.conkey, c.confkey
             FROM pg_constraint c WHERE c.contype = 'f' AND c.connamespace = 'public'::regnamespace LOOP
        SELECT string_agg(format('h.%I = p.%I', ah.attname, ap.attname), ' AND '),
               string_agg(format('h.%I IS NOT NULL', ah.attname), ' AND ')
          INTO cond, nn
        FROM unnest(r.conkey, r.confkey) AS k(hc, pc)
        JOIN pg_attribute ah ON ah.attrelid = r.conrelid  AND ah.attnum = k.hc
        JOIN pg_attribute ap ON ap.attrelid = r.confrelid AND ap.attnum = k.pc;
        EXECUTE format('SELECT count(*) FROM %s h WHERE %s AND NOT EXISTS (SELECT 1 FROM %s p WHERE %s)',
                       r.conrelid::regclass, nn, r.confrelid::regclass, cond) INTO n;
        IF n > 0 THEN
            huerfanas := huerfanas + n;
            RAISE WARNING 'FK %: % filas huérfanas', r.conname, n;
        END IF;
    END LOOP;
    IF huerfanas > 0 THEN RAISE EXCEPTION 'Quedarían % filas huérfanas: no se aplica nada', huerfanas; END IF;

    -- 5b. Verificar: la empresa que se conserva tiene las mismas filas
    FOR r IN SELECT c.table_name FROM information_schema.columns c
             JOIN information_schema.tables t ON t.table_schema = c.table_schema AND t.table_name = c.table_name
             WHERE c.table_schema = 'public' AND c.column_name = 'empresaid' AND t.table_type = 'BASE TABLE' LOOP
        EXECUTE format('SELECT count(*) FROM public.%I WHERE empresaid IS NOT NULL AND NOT (empresaid = ANY($1))', r.table_name) INTO n USING emp;
        despues := despues + n;
    END LOOP;
    IF despues <> antes - sueltos THEN RAISE EXCEPTION 'Las empresas conservadas tenían % filas (menos % usuarios sueltos) y quedarían %', antes, sueltos, despues; END IF;

    INSERT INTO sc_resumen (paso, tabla, filas) VALUES ('verificado: filas de las empresas conservadas', 'antes - usuarios sueltos = después', despues);
    INSERT INTO sc_resumen (paso, tabla, filas) VALUES ('verificado: filas huérfanas en todas las FK', '-', 0);
END $$;

SELECT paso, tabla, filas FROM sc_resumen ORDER BY orden;
SELECT id, nombre FROM empresa ORDER BY id;

\if :commit
COMMIT;
\echo '>>> COMMIT aplicado'
\else
ROLLBACK;
\echo '>>> ENSAYO: ROLLBACK, no se cambió nada'
\endif
