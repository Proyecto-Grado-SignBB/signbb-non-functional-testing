#!/usr/bin/env bash
# Matriz de control de acceso (AS-02) contra el despliegue del VPS.
#
# Uso:
#   ENV_FILE=./.env ./matriz-acceso.sh
#
# Requiere curl y jq. No imprime tokens ni contraseñas. Las cuentas de prueba
# creadas se registran en resultados/cuentas-acceso.txt para su limpieza.

set -uo pipefail

AQUI="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${ENV_FILE:-$AQUI/../.env}"
RESULTADOS="$AQUI/../resultados"
mkdir -p "$RESULTADOS"

if [[ -f "$ENV_FILE" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +a
fi

BASE_URL="${BASE_URL:-https://consulta.canguritos.tech}"
BASE_URL="${BASE_URL%/}"
TEST_USER_PASSWORD="${TEST_USER_PASSWORD:-PruebaCarga123}"
SUFIJO="$(date +%Y%m%d%H%M%S)-$$"
A_CORREO="perf.acceso.a.${SUFIJO}@signbb.test"
B_CORREO="perf.acceso.b.${SUFIJO}@signbb.test"

RESP_FILE="$(mktemp)"
HDR_FILE="$(mktemp)"
trap 'rm -f "$RESP_FILE" "$HDR_FILE"' EXIT

TOTAL=0
FALLOS=0

api() {
  local metodo="$1" token="$2" ruta="$3" cuerpo="${4:-}"
  local args=(-sS --max-time 20 -o "$RESP_FILE" -w '%{http_code}' -X "$metodo" "$BASE_URL$ruta")
  if [[ -n "$token" ]]; then
    args+=(-H "Authorization: Bearer $token")
  fi
  if [[ -n "$cuerpo" ]]; then
    args+=(-H 'Content-Type: application/json' -d "$cuerpo")
  fi
  curl "${args[@]}"
}

login() {
  local correo="$1" contrasena="$2" cuerpo codigo token
  if [[ -z "$correo" || -z "$contrasena" ]]; then
    echo "Faltan credenciales para $correo." >&2
    return 1
  fi
  cuerpo="$(jq -nc --arg c "$correo" --arg p "$contrasena" '{correo:$c,contrasena:$p}')"
  codigo="$(api POST "" "/api/auth/login" "$cuerpo")"
  if [[ "$codigo" != "200" ]]; then
    echo "El ingreso de $correo falló con HTTP $codigo." >&2
    return 1
  fi
  token="$(jq -r '.token // empty' "$RESP_FILE")"
  if [[ -z "$token" ]]; then
    echo "El ingreso de $correo no devolvió token." >&2
    return 1
  fi
  printf '%s' "$token"
}

registrar() {
  local nombre="$1" correo="$2" cuerpo codigo token
  cuerpo="$(jq -nc --arg n "$nombre" --arg c "$correo" --arg p "$TEST_USER_PASSWORD" \
    '{nombre:$n,correo:$c,contrasena:$p}')"
  codigo="$(api POST "" "/api/auth/registro" "$cuerpo")"
  if [[ "$codigo" != "201" ]]; then
    echo "No se pudo registrar $correo: HTTP $codigo." >&2
    return 1
  fi
  token="$(jq -r '.token // empty' "$RESP_FILE")"
  if [[ -z "$token" ]]; then
    echo "El registro de $correo no devolvió token." >&2
    return 1
  fi
  printf '%s' "$token"
}

check() {
  local caso="$1" rol="$2" metodo="$3" ruta="$4" esperado="$5" token="$6" cuerpo="${7:-}"
  local obtenido estado valido esperado_item

  TOTAL=$((TOTAL + 1))
  obtenido="$(api "$metodo" "$token" "$ruta" "$cuerpo")"
  estado="FALLO"
  valido=0
  for esperado_item in $esperado; do
    if [[ "$obtenido" == "$esperado_item" ]]; then
      valido=1
      break
    fi
  done
  if [[ "$valido" == "1" ]]; then
    estado="OK"
  else
    FALLOS=$((FALLOS + 1))
  fi
  printf '| %s | %s | %s | %s | %s | %s | %s |\n' \
    "$caso" "$rol" "$metodo" "$ruta" "$esperado" "$obtenido" "$estado"
  if [[ "$estado" == "FALLO" ]]; then
    printf '  detalle %s: %s\n' "$caso" "$(head -c 240 "$RESP_FILE" | tr '\n' ' ')" >&2
  fi
}

echo "# Matriz de acceso AS-02"
echo
echo "Entorno: $BASE_URL"
echo "Fecha: $(date -Is)"
echo
echo "| Caso | Rol | Método | Ruta | Esperado | Obtenido | Estado |"
echo "|---|---|---|---|---|---|---|"

PADRE_TOKEN="$(login "${PADRE_CORREO:-}" "${PADRE_CONTRASENA:-}")" || exit 1
MEDICO_TOKEN="$(login "${MEDICO_CORREO:-}" "${MEDICO_CONTRASENA:-}")" || exit 1
SUPERVISOR_TOKEN="$(login "${SUPERVISOR_CORREO:-}" "${SUPERVISOR_CONTRASENA:-}")" || exit 1

# Sin sesión
check "AC-007" "Anónimo" GET "/api/consulta/disponibilidad" "401" ""
check "AC-008" "Anónimo" GET "/api/recorridos" "401" ""
check "AC-009" "Anónimo" GET "/api/autoria/subgrafos" "401" ""
check "AC-010" "Anónimo" GET "/api/usuarios" "401" ""

# Padre
check "AC-011" "Padre" GET "/api/consulta/disponibilidad" "200" "$PADRE_TOKEN"
check "AC-012" "Padre" GET "/api/recorridos" "200" "$PADRE_TOKEN"
check "AC-013" "Padre" GET "/api/autoria/subgrafos" "403" "$PADRE_TOKEN"
check "AC-014" "Padre" GET "/api/autoria/revisiones" "403" "$PADRE_TOKEN"
check "AC-015" "Padre" GET "/api/usuarios" "403" "$PADRE_TOKEN"
check "AC-016" "Padre" GET "/api/auth/yo" "200" "$PADRE_TOKEN"

# Médico
check "AC-017" "Médico" GET "/api/consulta/disponibilidad" "403" "$MEDICO_TOKEN"
check "AC-018" "Médico" GET "/api/recorridos" "403" "$MEDICO_TOKEN"
check "AC-019" "Médico" GET "/api/autoria/subgrafos" "200" "$MEDICO_TOKEN"
check "AC-020" "Médico" GET "/api/autoria/revisiones" "403" "$MEDICO_TOKEN"
check "AC-021" "Médico" GET "/api/usuarios" "403" "$MEDICO_TOKEN"
check "AC-022" "Médico" GET "/api/auth/yo" "200" "$MEDICO_TOKEN"
check "AC-023" "Médico" POST "/api/autoria/subgrafos/999999/aprobar" "403" "$MEDICO_TOKEN"

CUERPO_USUARIO="$(jq -nc --arg c "no.crear.${SUFIJO}@signbb.test" --arg p "$TEST_USER_PASSWORD" \
  '{nombre:"No crear",correo:$c,contrasena:$p,rol:"MEDICO",institucion:"Prueba"}')"
check "AC-024" "Médico" POST "/api/usuarios" "403" "$MEDICO_TOKEN" "$CUERPO_USUARIO"

# Supervisor
check "AC-025" "Supervisor" GET "/api/consulta/disponibilidad" "403" "$SUPERVISOR_TOKEN"
check "AC-026" "Supervisor" GET "/api/recorridos" "403" "$SUPERVISOR_TOKEN"
check "AC-027" "Supervisor" GET "/api/autoria/subgrafos" "200" "$SUPERVISOR_TOKEN"
check "AC-028" "Supervisor" GET "/api/autoria/revisiones" "200" "$SUPERVISOR_TOKEN"
check "AC-029" "Supervisor" GET "/api/usuarios" "200" "$SUPERVISOR_TOKEN"
check "AC-030" "Supervisor" GET "/api/auth/yo" "200" "$SUPERVISOR_TOKEN"
check "AC-031" "Supervisor" POST "/api/autoria/subgrafos/999999/aprobar" "404 422" "$SUPERVISOR_TOKEN"

# Propiedad del recorrido: dos padres desechables y un recorrido de A.
A_TOKEN="$(registrar "Padre A acceso" "$A_CORREO")" || exit 1
B_TOKEN="$(registrar "Padre B acceso" "$B_CORREO")" || exit 1

check "AC-032" "Padre A" POST "/api/recorridos" "200" "$A_TOKEN"
A_RECORRIDO="$(jq -r '.recorridoId // empty' "$RESP_FILE")"
if [[ -n "$A_RECORRIDO" ]]; then
  check "AC-033" "Padre A" GET "/api/recorridos/$A_RECORRIDO" "200" "$A_TOKEN"
  check "AC-034" "Padre B" GET "/api/recorridos/$A_RECORRIDO" "404" "$B_TOKEN"
  check "AC-035" "Padre B" POST "/api/recorridos/$A_RECORRIDO/respuestas" "404" "$B_TOKEN" '{"respuesta":"x"}'
  check "AC-036" "Médico" GET "/api/recorridos/$A_RECORRIDO" "403" "$MEDICO_TOKEN"
else
  echo "  no se pudo crear el recorrido de A; se omiten AC-033 a AC-036" >&2
  FALLOS=$((FALLOS + 1))
fi

# Token alterado
TOKEN_ALTERADO="${PADRE_TOKEN%?}A"
if [[ "$TOKEN_ALTERADO" == "$PADRE_TOKEN" ]]; then
  TOKEN_ALTERADO="${PADRE_TOKEN%?}B"
fi
check "AC-037" "Padre" GET "/api/auth/yo" "401" "$TOKEN_ALTERADO"

# CORS: origen permitido (otro host de la configuración) y origen no permitido.
# Se usa el host de autoría porque un origen idéntico al de la petición no
# necesita cabecera Access-Control-Allow-Origin.
ORIGEN_PERMITIDO="${CORS_ORIGEN_PERMITIDO:-https://autoria.canguritos.tech}"
CORS_CODE="$(curl -sS --max-time 20 -D "$HDR_FILE" -o /dev/null -w '%{http_code}' \
  -H "Origin: $ORIGEN_PERMITIDO" \
  -H "Authorization: Bearer $PADRE_TOKEN" \
  "$BASE_URL/api/consulta/disponibilidad")"
CORS_ORIGEN="$(grep -i '^access-control-allow-origin:' "$HDR_FILE" | tr -d '\r' | awk '{print $2}' | head -1)"
TOTAL=$((TOTAL + 1))
if [[ "$CORS_CODE" == "200" && "$CORS_ORIGEN" == "$ORIGEN_PERMITIDO" ]]; then
  ESTADO_CORS="OK"
else
  ESTADO_CORS="FALLO"
  FALLOS=$((FALLOS + 1))
fi
printf '| AC-038 | Padre | GET | /api/consulta/disponibilidad (origen %s) | 200 + ACAO | %s / %s | %s |\n' \
  "$ORIGEN_PERMITIDO" "$CORS_CODE" "${CORS_ORIGEN:-sin cabecera}" "$ESTADO_CORS"

CORS_CODE2="$(curl -sS --max-time 20 -o /dev/null -w '%{http_code}' \
  -H "Origin: https://evil.example" \
  -H "Authorization: Bearer $PADRE_TOKEN" \
  "$BASE_URL/api/consulta/disponibilidad")"
TOTAL=$((TOTAL + 1))
if [[ "$CORS_CODE2" == "403" ]]; then
  ESTADO_CORS2="OK"
else
  ESTADO_CORS2="FALLO"
  FALLOS=$((FALLOS + 1))
fi
printf '| AC-039 | Padre | GET | /api/consulta/disponibilidad (origen no permitido) | 403 | %s | %s |\n' \
  "$CORS_CODE2" "$ESTADO_CORS2"

printf '%s\n%s\n' "$A_CORREO" "$B_CORREO" > "$RESULTADOS/cuentas-acceso.txt"

echo
echo "Total: $TOTAL; fallos: $FALLOS"
echo "Cuentas de prueba creadas: $A_CORREO, $B_CORREO"
echo "Se eliminan con seguridad/limpiar-datos.sh."

if [[ "$FALLOS" -gt 0 ]]; then
  exit 1
fi
