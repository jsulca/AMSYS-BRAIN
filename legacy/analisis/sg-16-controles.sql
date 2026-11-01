-- ============================================================================================
-- SG-16 - Alta de los primeros controles por rol
--
-- "elemento" y "rolelemento" existian en la base desde el principio y no los leia ni los escribia
-- nadie: la columna CONTROLES del editor de roles estaba siempre vacia y ninguna vista los miraba.
-- SG-16 completa el ciclo (decision DS-06 b) y empieza por los botones destructivos y de dinero.
--
-- Como se comporta mientras no se ejecute esto:
--   Una clave que NO esta registrada no la puede tener nadie, asi que ExigeElemento la deja pasar y
--   lo anota en el log. Es decir: hasta que des de alta el control, todo sigue como hoy. En cuanto
--   lo des de alta, la accion SOLO la podran hacer los roles a los que se lo concedas.
--
-- Uso:
--   1) Ejecutar el bloque CONTROLES.
--   2) Conceder cada uno a los roles que deban poder hacerlo (bloque PERMISOS).
--   3) Los usuarios con sesion abierta lo notan en su siguiente peticion (SG-12).
--
-- Tambien se pueden dar de alta desde la aplicacion: Seguridad > Paginas > editar la pagina.
-- ============================================================================================

-- ---------------------------------------------------------------------------- CONTROLES
-- Cada control cuelga de la PAGINA donde esta el boton. Si la pagina no esta registrada, registrala
-- antes (Seguridad > Paginas), o este INSERT no insertara nada.

INSERT INTO elemento (paginaid, clave, nombre)
SELECT p.id, v.clave, v.nombre
FROM (VALUES
    ('Logistica', 'NotaSalida',     'Index',  'anular-nota-salida',     'Anular nota de salida'),
    ('Logistica', 'NotaEntrada',    'Index',  'anular-nota-entrada',    'Anular nota de entrada'),
    ('Logistica', 'HojaAceptacion', 'Index',  'anular-hoja-aceptacion', 'Anular hoja de aceptacion'),
    ('Seguridad', 'Empresa',        'Editar', 'renovar-licencia',       'Renovar licencia')
) AS v(area, controlador, accion, clave, nombre)
JOIN pagina p ON p.area = v.area AND p.controlador = v.controlador AND p.accion = v.accion
WHERE NOT EXISTS (SELECT 1 FROM elemento e WHERE e.paginaid = p.id AND e.clave = v.clave);

-- Se insertaron? Si falta alguno, es que su pagina no esta registrada.
SELECT e.id, e.clave, e.nombre, p.area, p.controlador, p.accion
FROM elemento e JOIN pagina p ON p.id = e.paginaid
ORDER BY p.area, p.controlador, e.clave;

-- ---------------------------------------------------------------------------- PERMISOS
-- Concede cada control a los roles que corresponda. Ejemplo con el rol de instalacion:
-- INSERT INTO rolelemento (rolid, elementoid)
-- SELECT r.id, e.id FROM rol r CROSS JOIN elemento e
-- WHERE r.nombre = 'SUPERADMINISTRADOR'
--   AND e.clave IN ('anular-nota-salida', 'anular-nota-entrada', 'anular-hoja-aceptacion', 'renovar-licencia')
--   AND NOT EXISTS (SELECT 1 FROM rolelemento re WHERE re.rolid = r.id AND re.elementoid = e.id);

-- ---------------------------------------------------------------------------- COMPROBACION
-- Quien puede anular que, hoy.
SELECT e.nombre AS control,
       r.nombre AS rol,
       (SELECT count(*) FROM usuario u WHERE u.rolid = r.id AND u.activo) AS usuarios_activos
FROM rolelemento re
JOIN elemento e ON e.id = re.elementoid
JOIN rol r ON r.id = re.rolid
ORDER BY e.nombre, r.nombre;

-- Controles registrados que NO tiene ningun rol: hoy nadie puede usar esa accion.
SELECT e.clave, e.nombre
FROM elemento e
WHERE NOT EXISTS (SELECT 1 FROM rolelemento re WHERE re.elementoid = e.id);
