-- ============================================================================================
-- SG-13 · Alta de la pantalla «Rastro de seguridad» en el catálogo
--
-- La pantalla es código (Areas/Seguridad/{Controllers,Views}/SeguridadLog), pero el permiso es
-- DATO. Con la autorización invertida de SG-01, una acción cuya ruta no esté en el catálogo de
-- páginas exige el Index de su propio controlador; aquí ese Index es justamente la pantalla, así
-- que sin esta fila NADIE puede abrirla (hoy sólo se registra en el log, porque
-- AutorizacionSoloRegistra sigue en true).
--
-- Uso:
--   1) Ejecutar el bloque PÁGINA.
--   2) Conceder la página a los roles que deban consultar el rastro (bloque PERMISO).
--   3) Opcional: añadir la entrada de menú (bloque MENÚ) para que se vea en la navegación.
--      Mientras SG-22 no permita reordenar el árbol, el "orden" se pone a mano.
-- ============================================================================================

-- ---------------------------------------------------------------------------- PÁGINA
INSERT INTO pagina (nombre, area, controlador, accion)
SELECT 'Rastro de seguridad', 'Seguridad', 'SeguridadLog', 'Index'
WHERE NOT EXISTS (
    SELECT 1 FROM pagina
    WHERE area = 'Seguridad' AND controlador = 'SeguridadLog' AND accion = 'Index'
);

-- ---------------------------------------------------------------------------- PERMISO
-- Al rol reservado de instalación (AppSettings.RolInstalacion). Revisa el nombre antes de correrlo.
INSERT INTO rolpagina (rolid, paginaid)
SELECT r.id, p.id
FROM rol r
CROSS JOIN pagina p
WHERE r.nombre = 'SUPERADMINISTRADOR'
  AND p.area = 'Seguridad' AND p.controlador = 'SeguridadLog' AND p.accion = 'Index'
  AND NOT EXISTS (SELECT 1 FROM rolpagina rp WHERE rp.rolid = r.id AND rp.paginaid = p.id);

-- Para que un administrador de empresa vea el rastro de SU empresa, concédele la misma página:
-- el controlador ya filtra por la empresa de la sesión salvo que el usuario sea de instalación.
-- INSERT INTO rolpagina (rolid, paginaid)
-- SELECT r.id, p.id FROM rol r CROSS JOIN pagina p
-- WHERE r.nombre = '<NOMBRE DEL ROL>'
--   AND p.area = 'Seguridad' AND p.controlador = 'SeguridadLog' AND p.accion = 'Index'
--   AND NOT EXISTS (SELECT 1 FROM rolpagina rp WHERE rp.rolid = r.id AND rp.paginaid = p.id);

-- ---------------------------------------------------------------------------- MENÚ
-- padreid: el nodo de Seguridad. Comprueba antes cuál es:
--   SELECT id, nombre, padreid, ruta, orden FROM menu ORDER BY padreid NULLS FIRST, orden;
-- tipo: 0 CABECERA, 1 COLAPSADO, 2 NORMAL
-- INSERT INTO menu (padreid, tipo, nombre, icono, ruta, orden)
-- VALUES (<PADREID>, 2, 'Rastro de seguridad', 'fa fa-history', '/Seguridad/SeguridadLog/Index', 99);
--
-- Y concédeselo al rol:
-- INSERT INTO rolmenu (rolid, menuid)
-- SELECT r.id, m.id FROM rol r CROSS JOIN menu m
-- WHERE r.nombre = 'SUPERADMINISTRADOR' AND m.ruta = '/Seguridad/SeguridadLog/Index'
--   AND NOT EXISTS (SELECT 1 FROM rolmenu rm WHERE rm.rolid = r.id AND rm.menuid = m.id);

-- ---------------------------------------------------------------------------- COMPROBACIÓN
-- ¿Quién puede abrirla?
-- SELECT r.nombre AS rol
-- FROM rolpagina rp
-- JOIN rol r ON r.id = rp.rolid
-- JOIN pagina p ON p.id = rp.paginaid
-- WHERE p.area = 'Seguridad' AND p.controlador = 'SeguridadLog';
