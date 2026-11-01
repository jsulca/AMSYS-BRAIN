-- ============================================================================================
-- SG-15 · Estados concedidos a los roles existentes
--
-- Hasta ahora la pestaña "Estados" del editor de roles estaba OCULTA y el alta mandaba TODAS las
-- casillas marcadas. Resultado: casi todos los roles pueden mover una orden de trabajo y un aviso a
-- CUALQUIER estado —anular incluido— sin que nadie lo haya decidido ni haya podido verlo.
--
-- SG-15 muestra la pestaña y hace que un rol nuevo nazca SIN NADA concedido (decisión DS-07 a).
-- Lo que NO hace, y hay que hacer a mano, es recortar lo que los roles ya tienen.
--
-- Uso:
--   1) Ejecutar el INFORME y entregárselo al propietario.
--   2) Decidir rol por rol qué estados corresponden de verdad.
--   3) Quitar los que sobren, desde la pantalla de roles (ahora ya se ven) o con el bloque final.
-- ============================================================================================

-- ---------------------------------------------------------------------------- INFORME
-- Qué estados tiene concedidos cada rol, y a cuánta gente afecta.
-- Estados de OT:    0 EMITIDO · 2 CIERRE TÉCNICO · 3 CIERRE TOTAL · 4 ANULADO
-- Estados de aviso: 0 EMITIDO · 1 APROBADO · 2 ATENDIDO · 3 FINALIZADO · 4 RECHAZADO
SELECT r.id,
       r.nombre                                                      AS rol,
       r.perfil,
       r.activo,
       (SELECT count(*) FROM usuario u WHERE u.rolid = r.id AND u.activo) AS usuarios_activos,
       (SELECT count(DISTINCT u.empresaid) FROM usuario u WHERE u.rolid = r.id) AS empresas,
       (SELECT string_agg(ot.estado::text, ', ' ORDER BY ot.estado)
          FROM rolestadoordentrabajo ot WHERE ot.rolid = r.id)       AS estados_ot,
       (SELECT string_agg(av.estado::text, ', ' ORDER BY av.estado)
          FROM rolestadoaviso av WHERE av.rolid = r.id)              AS estados_aviso
FROM rol r
ORDER BY usuarios_activos DESC, r.nombre;

-- ---------------------------------------------------------------------------- LOS SOSPECHOSOS
-- Roles con TODOS los estados concedidos: casi con seguridad no lo decidió nadie, es el valor
-- por defecto que ponía el alta. Son los primeros que hay que revisar.
SELECT r.id, r.nombre, r.perfil,
       (SELECT count(*) FROM usuario u WHERE u.rolid = r.id AND u.activo) AS usuarios_activos
FROM rol r
-- 4 estados de OT (0, 2, 3, 4) y 5 de aviso (0..4), según los enumerados del código
WHERE (SELECT count(*) FROM rolestadoordentrabajo ot WHERE ot.rolid = r.id) >= 4
  AND (SELECT count(*) FROM rolestadoaviso av WHERE av.rolid = r.id) >= 5
ORDER BY usuarios_activos DESC;

-- ---------------------------------------------------------------------------- QUIÉN PUEDE ANULAR
-- Lo más caro de conceder por descuido: anular una OT (estado 4) y rechazar un aviso (estado 4).
SELECT r.nombre AS rol,
       (SELECT count(*) FROM usuario u WHERE u.rolid = r.id AND u.activo) AS usuarios_activos,
       EXISTS (SELECT 1 FROM rolestadoordentrabajo ot WHERE ot.rolid = r.id AND ot.estado = 4) AS puede_anular_ot,
       EXISTS (SELECT 1 FROM rolestadoaviso av WHERE av.rolid = r.id AND av.estado = 4)        AS puede_rechazar_aviso
FROM rol r
WHERE r.activo
ORDER BY usuarios_activos DESC;

-- ---------------------------------------------------------------------------- CORRECCIÓN
-- Sólo con los valores acordados. Ejemplo: quitarle a un rol la capacidad de anular órdenes.
-- OJO: guardar el rol desde la pantalla REESCRIBE todos sus estados, así que si alguien lo guarda
-- después sin tocar la pestaña, quedará lo que muestre la pantalla, no lo que diga este script.
--
-- DELETE FROM rolestadoordentrabajo
-- WHERE rolid = (SELECT id FROM rol WHERE nombre = '<NOMBRE DEL ROL>') AND estado = 4;
--
-- DELETE FROM rolestadoaviso
-- WHERE rolid = (SELECT id FROM rol WHERE nombre = '<NOMBRE DEL ROL>') AND estado = 4;
