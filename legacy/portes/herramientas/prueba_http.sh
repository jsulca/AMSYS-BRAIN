#!/usr/bin/env bash
# Pruebas HTTP de la Fase 0 contra la copia local (amsys_v3_demo_prueba_admin). Uso: bash prueba_http.sh <cookiejar>
CJ="$1"; B=http://localhost:5199/Administracion
ok=0; mal=0
check() { # nombre, condición (0 = ok)
  if [ "$2" = "0" ]; then ok=$((ok+1)); echo "  OK   $1"; else mal=$((mal+1)); echo "  FALLA $1 :: $3"; fi
}
get()  { curl -s -b "$CJ" -H 'X-Requested-With: XMLHttpRequest' -w '\n%{http_code}' "$@"; }
post() { local url=$1; shift; curl -s -b "$CJ" -H 'X-Requested-With: XMLHttpRequest' -w '\n%{http_code}' -X POST "$url" "$@"; }
code() { tail -n1 <<<"$1"; }
body() { sed '$d' <<<"$1"; }
idde() { body "$1" | grep -oE '"id":[0-9]+' | head -1 | cut -d: -f2; }

simple() { # Catalogo campoEtiqueta tieneCodigo [campoExtra valorExtra]
  local C=$1 E=$2 COD=$3 X=$4 XV=$5
  echo "== $C"
  r=$(get "$B/$C/Nuevo?callBack=index.Guardado"); check "GET Nuevo" $([ "$(code "$r")" = 200 ] && echo 0 || echo 1) "$(code "$r")"
  r=$(post "$B/$C/Nuevo" --data-urlencode "$E=" --data-urlencode "activo=true"); check "POST Nuevo vacío -> 400 con errores" $([ "$(code "$r")" = 400 ] && body "$r" | grep -q '"errores"' && echo 0 || echo 1) "$(code "$r") $(body "$r" | head -c 200)"
  extra=(); [ -n "$X" ] && extra=(--data-urlencode "$X=$XV")
  cod=(); [ "$COD" = 1 ] && cod=(--data-urlencode "codigo=PRB-01")
  r=$(post "$B/$C/Nuevo" --data-urlencode "$E=Prueba $C" --data-urlencode "activo=true" "${cod[@]}" "${extra[@]}"); id=$(idde "$r")
  check "POST Nuevo -> id" $([ "$(code "$r")" = 200 ] && [ -n "$id" ] && echo 0 || echo 1) "$(code "$r") $(body "$r" | head -c 200)"
  r=$(get "$B/$C/Listar?pageIndex=1&pageSize=15&filtro.Activo=true"); check "Listar contiene el registro" $(body "$r" | grep -q "Prueba $C" && echo 0 || echo 1) "$(body "$r" | head -c 200)"
  [ -n "$X" ] && check "Listar devuelve $X" $(body "$r" | grep -qi "\"$X\":\"$XV\"" && echo 0 || echo 1) "$(body "$r" | head -c 300)"
  r=$(get "$B/$C/Editar?id=$id&callBack=index.Guardado"); check "GET Editar" $([ "$(code "$r")" = 200 ] && body "$r" | grep -q "Prueba $C" && echo 0 || echo 1) "$(code "$r")"
  r=$(get "$B/$C/Editar?id=999999&callBack=index.Guardado"); check "GET Editar id inexistente -> 400" $([ "$(code "$r")" = 400 ] && echo 0 || echo 1) "$(code "$r")"
  r=$(post "$B/$C/Editar" --data-urlencode "id=$id" --data-urlencode "$E=Prueba $C editada" --data-urlencode "activo=false" "${cod[@]}" "${extra[@]}")
  check "POST Editar" $([ "$(code "$r")" = 200 ] && echo 0 || echo 1) "$(code "$r") $(body "$r" | head -c 200)"
  r=$(post "$B/$C/Editar" --data-urlencode "id=999999" --data-urlencode "$E=X" --data-urlencode "activo=true"); check "POST Editar id inexistente -> rechazado" $([ "$(code "$r")" != 200 ] && echo 0 || echo 1) "$(code "$r")"
  r=$(get "$B/$C/Listar?pageIndex=1&pageSize=15&filtro.Activo=false"); check "Edición guardada (inactivo, nombre nuevo)" $(body "$r" | grep -q "Prueba $C editada" && echo 0 || echo 1) "$(body "$r" | head -c 200)"
  r=$(get "$B/$C/Listar?pageIndex=1&pageSize=15&filtro.$E=noexiste-zzz"); check "Filtro por $E" $(body "$r" | grep -q '"total":0' && echo 0 || echo 1) "$(body "$r" | head -c 200)"
  if [ "$COD" = 1 ]; then
    r=$(get "$B/$C/BuscarCodigo?codigo=PRB-01"); check "BuscarCodigo encuentra el código" $(body "$r" | grep -q "\"id\":$id" && echo 0 || echo 1) "$(body "$r" | head -c 200)"
    r=$(get "$B/$C/BuscarCodigo?codigo=PRB-01&excluirId=$id"); check "BuscarCodigo excluye el propio" $([ "$(body "$r")" = "[]" ] && echo 0 || echo 1) "$(body "$r" | head -c 200)"
  fi
}

simple Cliente nombre 0 correos "a@x.com;b@x.com"
simple CategoriaAviso descripcion 1
simple TipoSolicitudAviso descripcion 1
simple Area descripcion 1
simple Conformidad descripcion 0
simple ImpactoProceso descripcion 0

echo "== Feriado"
r=$(post "$B/Feriado/Nuevo" --data-urlencode "fecha=" --data-urlencode "concepto="); check "POST Nuevo vacío -> 400" $([ "$(code "$r")" = 400 ] && echo 0 || echo 1) "$(code "$r")"
r=$(post "$B/Feriado/Nuevo" --data-urlencode "fecha=2026-12-25" --data-urlencode "concepto=Navidad"); fid=$(idde "$r"); check "POST Nuevo" $([ -n "$fid" ] && echo 0 || echo 1) "$(code "$r") $(body "$r" | head -c 200)"
r=$(get "$B/Feriado/Listar?pageIndex=1&pageSize=15&filtro.Anio=2026"); check "Listar por año (anio calculado)" $(body "$r" | grep -q '"anio":2026' && body "$r" | grep -q 'Navidad' && echo 0 || echo 1) "$(body "$r" | head -c 300)"
r=$(get "$B/Feriado/Editar?id=$fid&callBack=index.Guardado"); check "GET Editar con fecha" $(body "$r" | grep -q 'value="2026-12-25"' && echo 0 || echo 1) "$(code "$r")"
r=$(post "$B/Feriado/Editar" --data-urlencode "id=$fid" --data-urlencode "fecha=2027-01-01" --data-urlencode "concepto=Año nuevo"); check "POST Editar cambia de año" $([ "$(code "$r")" = 200 ] && echo 0 || echo 1) "$(code "$r") $(body "$r" | head -c 200)"
r=$(get "$B/Feriado/Listar?pageIndex=1&pageSize=15&filtro.Anio=2027"); check "Año recalculado al editar" $(body "$r" | grep -q 'Año nuevo' && echo 0 || echo 1) "$(body "$r" | head -c 300)"

echo "== Prioridad (campos opcionales)"
r=$(post "$B/Prioridad/Nuevo" --data-urlencode "descripcion=Prueba SLA" --data-urlencode "activo=true" --data-urlencode "horasAtencion=4.5" --data-urlencode "despuesDelDia=true"); pid=$(idde "$r"); check "POST Nuevo con plazo" $([ -n "$pid" ] && echo 0 || echo 1) "$(code "$r") $(body "$r" | head -c 200)"
r=$(post "$B/Prioridad/Nuevo" --data-urlencode "descripcion=Prueba sin SLA" --data-urlencode "activo=true" --data-urlencode "horasAtencion=" --data-urlencode "despuesDelDia=false"); check "POST Nuevo sin plazo" $([ -n "$(idde "$r")" ] && echo 0 || echo 1) "$(code "$r") $(body "$r" | head -c 200)"
r=$(get "$B/Prioridad/Editar?id=$pid&callBack=index.Guardado"); check "GET Editar muestra plazo y casilla" $(body "$r" | grep -q 'id="DespuesDelDia" checked' && body "$r" | grep -qE 'name="HorasAtencion"[^>]*value="4[.,]5' && echo 0 || echo 1) "$(body "$r" | grep -E 'HorasAtencion|DespuesDelDia' | head -3)"

echo "== Material (Marca y Precio en el alta)"
um=$(get "$B/UnidadMedida/Listar?pageIndex=1&pageSize=1" | sed '$d' | grep -oE '"id":[0-9]+' | head -1 | cut -d: -f2)
r=$(post "$B/Material/Nuevo" --data-urlencode "descripcion=Prueba material" --data-urlencode "unidadMedidaId=$um" --data-urlencode "activo=true" --data-urlencode "precio=12.5" --data-urlencode "marca=ACME"); check "POST Nuevo" $([ -n "$(idde "$r")" ] && echo 0 || echo 1) "$(code "$r") $(body "$r" | head -c 200)"
r=$(get "$B/Material/Listar?pageIndex=1&pageSize=15&filtro.Descripcion=Prueba%20material"); check "Precio y Marca guardados en el alta" $(body "$r" | grep -q '"precio":12.5' && body "$r" | grep -q '"marca":"ACME"' && echo 0 || echo 1) "$(body "$r" | head -c 300)"

echo
echo "RESULTADO: $ok OK, $mal FALLAS"
