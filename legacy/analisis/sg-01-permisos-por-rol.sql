-- ============================================================================================
-- SG-01 · Inventario de permisos antes de aplicar la autorización por defecto (decisión DS-01)
--
-- Hasta ahora [FiltroAccion] se ponía acción por acción y faltaba en 276 de 488 rutas: todos los
-- POST del sistema se podían invocar sin permiso. Ahora toda acción nace protegida y las
-- excepciones se declaran con [SinAutorizacion] (11 rutas: login, perfil propio, errores y el
-- tablero de inicio).
--
-- Qué exige cada ruta (ai/analysis/sg-01-rutas.csv lo lista una por una):
--   · Si la ruta ESTÁ registrada como página  -> se exige esa misma página.
--   · Si NO está registrada (lista por AJAX, exportación, acción auxiliar)
--                                             -> se exige el Index de su propio controlador.
--
-- POR QUÉ ESE SEGUNDO CASO: un POST "Nuevo" comparte ruta con el formulario del que sale, así que
-- se autoriza solo con el permiso que ya existía. Las acciones auxiliares nunca se registraron, y
-- exigirles una página inexistente dejaría sin datos a todas las pantallas.
--
-- Uso:
--   1) Desplegar con AppSettings.AutorizacionSoloRegistra = true (ya viene así en appsettings.json).
--      En ese modo NO se bloquea nada: sólo se registra en el log lo que se habría denegado.
--   2) Dejarlo unos días de uso normal y revisar el log, buscando "Autorización (sólo registro)".
--      Cada línea dice el usuario, la ruta y el permiso que le faltaba.
--   3) Ejecutar estas consultas y contrastarlas con el log y con sg-01-rutas.csv.
--   4) Registrar las páginas que falten y concederlas a los roles que las necesiten.
--   5) Con el log limpio, poner AutorizacionSoloRegistra = false.
-- ============================================================================================

-- ------------------------------------------------------- 1) Qué tiene concedido cada rol
SELECT r.id            AS rolid,
       r.nombre        AS rol,
       r.perfil,
       r.activo,
       COUNT(rp.paginaid) AS paginas_concedidas,
       COUNT(DISTINCT p.area) AS areas
FROM rol r
LEFT JOIN rolpagina rp ON rp.rolid = r.id
LEFT JOIN pagina    p  ON p.id = rp.paginaid
GROUP BY r.id, r.nombre, r.perfil, r.activo
ORDER BY r.activo DESC, r.nombre;

-- Roles ACTIVOS CON USUARIOS y SIN ninguna página concedida: hoy entran al tablero y poco más;
-- tras SG-01 no podrán abrir nada. Son los primeros a revisar.
SELECT r.id AS rolid, r.nombre AS rol, COUNT(u.id) AS usuarios_activos
FROM rol r
JOIN usuario u ON u.rolid = r.id AND u.activo
WHERE r.activo
  AND NOT EXISTS (SELECT 1 FROM rolpagina rp WHERE rp.rolid = r.id)
GROUP BY r.id, r.nombre
ORDER BY COUNT(u.id) DESC;

-- ------------------------------------------------------- 2) Controladores sin su página Index
-- El Index es el permiso con el que se sirven las acciones auxiliares de su controlador. Un rol
-- que tenga, por ejemplo, /Gestion/Equipo/Editar pero NO /Gestion/Equipo/Index se quedará sin las
-- listas y los selectores de esa pantalla.
SELECT r.nombre AS rol,
       p.area,
       p.controlador,
       STRING_AGG(p.accion, ', ' ORDER BY p.accion) AS acciones_concedidas
FROM rolpagina rp
JOIN rol    r ON r.id = rp.rolid
JOIN pagina p ON p.id = rp.paginaid
WHERE r.activo
GROUP BY r.nombre, p.area, p.controlador
HAVING COUNT(*) FILTER (WHERE LOWER(p.accion) = 'index') = 0
ORDER BY r.nombre, p.area, p.controlador;

-- ------------------------------------------------------- 3) El catálogo de páginas, tal cual
-- Contrastar con ai/analysis/sg-01-rutas.csv: lo que esté en el CSV y no aquí se servirá con el
-- Index de su controlador; lo que esté aquí y no en el CSV es una página que ya no existe.
SELECT p.id, p.area, p.controlador, p.accion, p.nombre,
       '/' || p.area || '/' || p.controlador || '/' || p.accion AS ruta,
       COUNT(rp.rolid) AS roles_que_la_tienen
FROM pagina p
LEFT JOIN rolpagina rp ON rp.paginaid = p.id
GROUP BY p.id, p.area, p.controlador, p.accion, p.nombre
ORDER BY p.area, p.controlador, p.accion;

-- Páginas registradas que no tiene ningún rol: o sobran, o alguien se quedó sin ellas
SELECT p.area, p.controlador, p.accion, p.nombre
FROM pagina p
WHERE NOT EXISTS (SELECT 1 FROM rolpagina rp WHERE rp.paginaid = p.id)
ORDER BY p.area, p.controlador, p.accion;

-- ------------------------------------------------------- 4) A cuántos afecta cada rol
-- Para priorizar la revisión: los roles con más usuarios activos primero.
SELECT r.id AS rolid, r.nombre AS rol, r.perfil,
       COUNT(DISTINCT u.id)        AS usuarios_activos,
       COUNT(DISTINCT u.empresaid) AS empresas
FROM rol r
JOIN usuario u ON u.rolid = r.id AND u.activo
WHERE r.activo
GROUP BY r.id, r.nombre, r.perfil
ORDER BY COUNT(DISTINCT u.id) DESC;
