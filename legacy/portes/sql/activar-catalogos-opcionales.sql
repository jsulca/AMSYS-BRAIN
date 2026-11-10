-- =============================================================================================
-- Activa catálogos opcionales de Administración en UNA instalación (decisión DU-02, opción a).
-- Plan: legacy/planes/PLAN-ADMINISTRACION-UNIFICADA-Y-BD-CATALOGOS.md (UA-02…UA-04)
--
-- Los catálogos existen en todas las BD (migración Administracion_Superconjunto) pero nadie los ve
-- hasta que se registran sus páginas y se conceden a un rol. Este script:
--   1. registra las páginas Index / Nuevo / Editar de cada catálogo elegido (si no existen),
--   2. crea su opción de menú bajo el menú padre indicado (si no existe),
--   3. concede páginas y menú a los roles indicados.
-- Es idempotente: se puede ejecutar varias veces.
--
-- Uso: editar las tres variables de abajo y ejecutar en la BD del cliente. Revisar antes en una copia.
-- =============================================================================================
DO $$
DECLARE
    -- Catálogos a activar: Cliente, CategoriaAviso, TipoSolicitudAviso, Feriado, Area, Conformidad, ImpactoProceso
    catalogos  text[] := ARRAY['Cliente', 'CategoriaAviso', 'TipoSolicitudAviso'];
    -- Roles que los verán (id de la tabla rol)
    roles      int[]  := ARRAY[1];
    -- Menú padre (el grupo de catálogos de Administración; en la demo es "MetaDatos")
    menu_padre int    := (SELECT id FROM menu WHERE nombre = 'MetaDatos' AND tipo = 1 ORDER BY id LIMIT 1);

    c text; v_titulo text; v_nuevo text; v_editar text; v_menu int; v_pagina int; v_accion text; v_nombre text;
BEGIN
    IF menu_padre IS NULL THEN RAISE EXCEPTION 'No se encontró el menú padre: fijar menu_padre a mano'; END IF;

    FOREACH c IN ARRAY catalogos LOOP
        SELECT t.titulo, t.nuevo, t.editar INTO v_titulo, v_nuevo, v_editar FROM (VALUES
            ('Cliente',            'Clientes',                    'Nuevo cliente',               'Editar cliente'),
            ('CategoriaAviso',     'Categorías de aviso',         'Nueva categoría de aviso',    'Editar categoría de aviso'),
            ('TipoSolicitudAviso', 'Tipos de solicitud de aviso', 'Nuevo tipo de solicitud',     'Editar tipo de solicitud'),
            ('Feriado',            'Feriados',                    'Nuevo feriado',               'Editar feriado'),
            ('Area',               'Áreas',                       'Nueva área',                  'Editar área'),
            ('Conformidad',        'Conformidades',               'Nueva conformidad',           'Editar conformidad'),
            ('ImpactoProceso',     'Impactos en el proceso',      'Nuevo impacto en el proceso', 'Editar impacto en el proceso')
        ) AS t(controlador, titulo, nuevo, editar) WHERE t.controlador = c;
        IF v_titulo IS NULL THEN RAISE EXCEPTION 'Catálogo desconocido: %', c; END IF;

        -- 1. Páginas
        FOREACH v_accion IN ARRAY ARRAY['Index', 'Nuevo', 'Editar'] LOOP
            v_nombre := CASE v_accion WHEN 'Index' THEN 'Lista de ' || lower(v_titulo) WHEN 'Nuevo' THEN v_nuevo ELSE v_editar END;
            SELECT id INTO v_pagina FROM pagina WHERE area = 'Administracion' AND controlador = c AND accion = v_accion LIMIT 1;
            IF v_pagina IS NULL THEN
                INSERT INTO pagina (nombre, area, controlador, accion) VALUES (v_nombre, 'Administracion', c, v_accion) RETURNING id INTO v_pagina;
            END IF;
            INSERT INTO rolpagina (rolid, paginaid) SELECT r, v_pagina FROM unnest(roles) r
                WHERE NOT EXISTS (SELECT 1 FROM rolpagina x WHERE x.rolid = r AND x.paginaid = v_pagina);
            v_pagina := NULL;
        END LOOP;

        -- 2. Menú
        SELECT id INTO v_menu FROM menu WHERE ruta = '/Administracion/' || c || '/Index' LIMIT 1;
        IF v_menu IS NULL THEN
            INSERT INTO menu (padreid, tipo, nombre, icono, ruta, orden)
            VALUES (menu_padre, 2, v_titulo, NULL, '/Administracion/' || c || '/Index',
                    COALESCE((SELECT max(orden) FROM menu WHERE padreid = menu_padre), 0) + 1)
            RETURNING id INTO v_menu;
        END IF;

        -- 3. Menú para los roles
        INSERT INTO rolmenu (rolid, menuid) SELECT r, v_menu FROM unnest(roles) r
            WHERE NOT EXISTS (SELECT 1 FROM rolmenu x WHERE x.rolid = r AND x.menuid = v_menu);
        v_menu := NULL; v_titulo := NULL;
    END LOOP;
END $$;

-- Después: los usuarios deben volver a iniciar sesión (los permisos se cargan en la sesión) y, si la app
-- estaba corriendo, se puede reiniciar o guardar cualquier página en Seguridad > Páginas para refrescar el
-- catálogo de rutas en memoria.
