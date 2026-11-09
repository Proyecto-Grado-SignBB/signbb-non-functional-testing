#!/usr/bin/env bash
# Consulta la fila de limite_intentos de una cuenta de prueba en el VPS.
#
# Uso:
#   ./consultar-limite.sh seg.bloqueo.20261109@signbb.test
#   # o, si no se pasa correo, usa SEG_CORREO o resultados/bloqueo-cuenta.txt
#
# La clave que guarda la aplicación es SHA-256 del correo normalizado.

set -euo pipefail

AQUI="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${ENV_FILE:-$AQUI/../.env}"
RESULTADOS="$AQUI/../resultados"

if [[ -f "$ENV_FILE" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +a
fi

CORREO="${1:-${SEG_CORREO:-}}"
if [[ -z "$CORREO" && -f "$RESULTADOS/bloqueo-cuenta.txt" ]]; then
  CORREO="$(head -n 1 "$RESULTADOS/bloqueo-cuenta.txt")"
fi
if [[ -z "$CORREO" ]]; then
  echo "Indica el correo o define SEG_CORREO." >&2
  exit 2
fi

NORMALIZADO="$(printf '%s' "$CORREO" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' | tr '[:upper:]' '[:lower:]')"
CLAVE="$(printf '%s' "$NORMALIZADO" | sha256sum | awk '{print $1}')"

VPS_HOST="${VPS_HOST:-signbb@2.25.152.145}"
VPS_KEY="${VPS_KEY:-$HOME/.ssh/signbb_vps_ed25519}"
VPS_DIR="${VPS_DIR:-/opt/signbb/signbb-frontend/deploy}"

echo "Cuenta: $CORREO"
echo "Clave SHA-256: $CLAVE"
echo
echo "tipo|contador|bloqueado_hasta|expira_en"

SALIDA="$(ssh -o BatchMode=yes -o ConnectTimeout=10 -i "$VPS_KEY" "$VPS_HOST" \
  "cd '$VPS_DIR' && docker compose -f compose.prod.yaml exec -T db psql -U admin -d signbb -tA -F '|'" <<SQL
select tipo, contador, bloqueado_hasta, expira_en
from limite_intentos
where clave = '$CLAVE';
SQL
)"

if [[ -z "$SALIDA" ]]; then
  echo "(sin fila: el contador no existe o ya se borró)"
else
  printf '%s\n' "$SALIDA"
fi
