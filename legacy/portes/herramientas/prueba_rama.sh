#!/usr/bin/env bash
# Pruebas del módulo de Administración sobre los datos reales de una rama (copia local).
# Uso: bash prueba_rama.sh <correo> <clave>
S="${TMPDIR:-/tmp}"
CJ="$S/cj_rama.txt"; rm -f "$CJ"; H=http://localhost:5199; B=$H/Administracion
ok=0; mal=0
check() { if [ "$2" = "0" ]; then ok=$((ok+1)); else mal=$((mal+1)); echo "  FALLA $1 :: $3"; fi; }

curl -s -c "$CJ" --retry 60 --retry-connrefused --retry-delay 2 $H/Account/Login > "$S/login.html"
T=$(grep -oE '__RequestVerificationToken[^>]*value="[^"]+"' "$S/login.html" | sed 's/.*value="//;s/"$//')
r=$(curl -s -b "$CJ" -c "$CJ" -o /dev/null -w "%{http_code}" --data-urlencode "Correo=$1" --data-urlencode "Clave=$2" --data-urlencode "__RequestVerificationToken=$T" $H/Account/Login)
check "login" $([ "$r" = 302 ] && echo 0 || echo 1) "$r"

CATALOGOS="${EXTRA:-} Aspecto Calificacion CausaFalla CentroCosto ClaseEquipo Criticidad CuentaContable Empleado Especialidad Impacto Material MecanismoFalla MetodoDeteccion ModoFalla Parte Prioridad Servicio Sistema SocioNegocio TallerResponsable TipoMantenimiento TipoTarea UnidadMedida UnidadMedidaServicio Adjunto"
for c in $CATALOGOS; do
  r=$(curl -s -b "$CJ" -o /dev/null -w '%{http_code}' $B/$c/Index); check "$c Index" $([ "$r" = 200 ] && echo 0 || echo 1) "$r"
  r=$(curl -s -b "$CJ" -H 'X-Requested-With: XMLHttpRequest' -w '\n%{http_code}' "$B/$c/Listar?pageIndex=1&pageSize=15&conUso=true")
  cod=$(tail -n1 <<<"$r"); cuerpo=$(sed '$d' <<<"$r")
  check "$c Listar (conUso)" $([ "$cod" = 200 ] && grep -q '"total"' <<<"$cuerpo" && echo 0 || echo 1) "$cod $(head -c 200 <<<"$cuerpo")"
  id=$(grep -oE '"id":[0-9]+' <<<"$cuerpo" | head -1 | cut -d: -f2)
  total=$(grep -oE '"total":[0-9]+' <<<"$cuerpo" | head -1 | cut -d: -f2)
  usos=$(grep -oE '"total":[0-9]+' <<<"$cuerpo" | sed -n '2,$p' | cut -d: -f2 | awk '{s+=$1} END {print s+0}')
  echo "  $c: $total registros; usos en la página: $usos"
  if [ -n "$id" ] && [ "$c" != "Adjunto" ]; then
    accion=Editar; [ "$c" = "ClaseEquipo" ] && accion=Editar
    r=$(curl -s -b "$CJ" -H 'X-Requested-With: XMLHttpRequest' -o /dev/null -w '%{http_code}' "$B/$c/$accion?id=$id&callBack=index.Guardado")
    check "$c Editar id=$id" $([ "$r" = 200 ] && echo 0 || echo 1) "$r"
  fi
done
echo "RESULTADO: $ok OK, $mal FALLAS"
