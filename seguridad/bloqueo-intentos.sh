#!/usr/bin/env bash
# Bloqueo por intentos fallidos (AS-06).
#
# Uso:
#   ENV_FILE=./.env MODO=bloquear ./bloqueo-intentos.sh
#   # esperar 15 minutos
#   ENV_FILE=./.env MODO=verificar ./bloqueo-intentos.sh
#
# Las cuentas son desechables (@signbb.test). No se usan las cuentas del seed.

set -uo pipefail

AQUI="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${ENV_FILE:-$AQUI/../.env}"
RESULTADOS="$AQUI/../resultados"
CUENTA_FILE="$RESULTADOS/bloqueo-cuenta.txt"
mkdir -p "$RESULTADOS"

if [[ -f "$ENV_FILE" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +a
fi

BASE_URL="${BASE_URL:-https://consulta.canguritos.tech}"
BASE_URL="${BASE_URL%/}"
MODO="${MODO:-bloquear}"
SEG_CONTRASENA="${SEG_CONTRASENA:-PruebaBloqueo123}"
SEG_CORREO="${SEG_CORREO:-}"
SEG_CORREO2="${SEG_CORREO2:-}"

RESP_FILE="$(mktemp)"
HDR_FILE="$(mktemp)"
trap 'rm -f "$RESP_FILE" "$HDR_FILE"' EXIT

TOTAL=0
FALLOS=0

registro() {
  local nombre="$1" correo="$2" cuerpo codigo
  cuerpo="$(jq -nc --arg n "$nombre" --arg c "$correo" --arg p "$SEG_CONTRASENA" \
    '{nombre:$n,correo:$c,contrasena:$p}')"
  codigo="$(curl -sS --max-time 20 -o "$RESP_FILE" -w '%{http_code}' -X POST \
    "$BASE_URL/api/auth/registro" -H 'Content-Type: application/json' -d "$cuerpo")"
  if [[ "$codigo" != "201" ]]; then
    echo "No se pudo registrar $correo: HTTP $codigo" >&2
    head -c 240 "$RESP_FILE" >&2
    echo >&2
    return 1
  fi
}

login_con_headers() {
  local correo="$1" contrasena="$2" cuerpo
  cuerpo="$(jq -nc --arg c "$correo" --arg p "$contrasena" '{correo:$c,contrasena:$p}')"
  curl -sS --max-time 20 -D "$HDR_FILE" -o "$RESP_FILE" -w '%{http_code}' -X POST \
    "$BASE_URL/api/auth/login" -H 'Content-Type: application/json' -d "$cuerpo"
}

retry_after() {
  grep -i '^Retry-After:' "$HDR_FILE" 2>/dev/null | tr -d '\r' | awk '{print $2}' | head -1
}

mensaje() {
  jq -r '.mensaje // empty' "$RESP_FILE" 2>/dev/null
}

check_fila() {
  local cuenta="$1" intento="$2" esperado="$3" obtenido="$4" retry="${5:-}" detalle="${6:-}"
  local estado="FALLO"
  TOTAL=$((TOTAL + 1))
  if [[ "$obtenido" == "$esperado" ]]; then
    estado="OK"
  else
    FALLOS=$((FALLOS + 1))
  fi
  printf '| %s | %s | %s | %s | %s | %s |\n' \
    "$cuenta" "$intento" "$esperado" "$obtenido" "$retry" "$estado"
  if [[ "$estado" == "FALLO" ]]; then
    printf '  detalle %s/%s: %s\n' "$cuenta" "$intento" "$detalle" >&2
  fi
}

verificar() {
  local correo codigo retry
  correo="${SEG_CORREO:-}"
  if [[ -z "$correo" && -f "$CUENTA_FILE" ]]; then
    correo="$(head -n 1 "$CUENTA_FILE")"
  fi
  if [[ -z "$correo" ]]; then
    echo "Falta SEG_CORREO o $CUENTA_FILE para verificar la recuperación." >&2
    exit 2
  fi

  echo "# Verificación de recuperación AS-06"
  echo
  echo "Cuenta: $correo"
  echo "Fecha: $(date -Is)"
  echo
  echo "| Cuenta | Intento | Esperado | Obtenido | Retry-After | Estado |"
  echo "|---|---|---|---|---|---|"

  codigo="$(login_con_headers "$correo" "$SEG_CONTRASENA")"
  retry="$(retry_after)"
  check_fila "$correo" "recuperación" "200" "$codigo" "$retry" "$(mensaje)"
  echo
  echo "Total: $TOTAL; fallos: $FALLOS"
  if [[ "$FALLOS" -gt 0 ]]; then
    exit 1
  fi
}

bloquear() {
  local codigo retry mensaje_error i

  SEG_CORREO="${SEG_CORREO:-seg.bloqueo.$(date +%Y%m%d%H%M%S)-$$@signbb.test}"
  SEG_CORREO2="${SEG_CORREO2:-seg.reset.$(date +%Y%m%d%H%M%S)-$$@signbb.test}"

  echo "# Secuencia de bloqueo AS-06"
  echo
  echo "Entorno: $BASE_URL"
  echo "Fecha: $(date -Is)"
  echo
  echo "| Cuenta | Intento | Esperado | Obtenido | Retry-After | Estado |"
  echo "|---|---|---|---|---|---|"

  registro "Bloqueo AS-06" "$SEG_CORREO" || exit 1
  printf '%s\n' "$SEG_CORREO" > "$CUENTA_FILE"

  for i in 1 2 3 4 5; do
    codigo="$(login_con_headers "$SEG_CORREO" "ClaveIncorrecta${i}")"
    check_fila "$SEG_CORREO" "fallo $i" "401" "$codigo" "" "$(mensaje)"
  done

  codigo="$(login_con_headers "$SEG_CORREO" "$SEG_CONTRASENA")"
  retry="$(retry_after)"
  mensaje_error="$(mensaje)"
  check_fila "$SEG_CORREO" "correcta tras 5 fallos" "429" "$codigo" "$retry" "$mensaje_error"
  if [[ -z "$retry" || ! "$retry" =~ ^[0-9]+$ || "$retry" -lt 1 ]]; then
    echo "  la cabecera Retry-After no llegó o no es un entero positivo." >&2
    FALLOS=$((FALLOS + 1))
  fi
  if [[ "$mensaje_error" != *"Demasiados intentos"* ]]; then
    echo "  el mensaje de bloqueo no tiene el texto genérico esperado." >&2
    FALLOS=$((FALLOS + 1))
  fi

  # Segunda cuenta: comprobar que un ingreso correcto reinicia el contador.
  registro "Reinicio AS-06" "$SEG_CORREO2" || exit 1
  for i in 1 2 3 4; do
    codigo="$(login_con_headers "$SEG_CORREO2" "ClaveIncorrecta${i}")"
    check_fila "$SEG_CORREO2" "fallo previo $i" "401" "$codigo" "" "$(mensaje)"
  done
  codigo="$(login_con_headers "$SEG_CORREO2" "$SEG_CONTRASENA")"
  check_fila "$SEG_CORREO2" "ingreso que reinicia" "200" "$codigo" "" "$(mensaje)"

  for i in 1 2 3 4; do
    codigo="$(login_con_headers "$SEG_CORREO2" "OtraClave${i}")"
    check_fila "$SEG_CORREO2" "fallo posterior $i" "401" "$codigo" "" "$(mensaje)"
  done
  codigo="$(login_con_headers "$SEG_CORREO2" "OtraClave5")"
  check_fila "$SEG_CORREO2" "quinto fallo posterior" "401" "$codigo" "" "$(mensaje)"
  codigo="$(login_con_headers "$SEG_CORREO2" "OtraClave6")"
  retry="$(retry_after)"
  check_fila "$SEG_CORREO2" "sexto fallo posterior" "429" "$codigo" "$retry" "$(mensaje)"

  echo
  echo "Total: $TOTAL; fallos: $FALLOS"
  echo
  echo "Cuenta bloqueada para la verificación de recuperación: $SEG_CORREO"
  echo "Espera 15 minutos y ejecuta MODO=verificar con el mismo env-file."
  if [[ "$FALLOS" -gt 0 ]]; then
    exit 1
  fi
}

case "$MODO" in
  bloquear) bloquear ;;
  verificar) verificar ;;
  *)
    echo "MODO debe ser bloquear o verificar." >&2
    exit 2
    ;;
esac
