#!/usr/bin/env bash
# Ejecuta un script de k6 dentro de Docker, con un env-file local.
#
# Uso:
#   ENV_FILE=./.env RUTA=normal VUS=100 DURACION=5m \
#     ./run.sh navegacion.js
#
# El archivo de resultados queda en resultados/.

set -euo pipefail

AQUI="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${ENV_FILE:-$AQUI/../.env}"
SCRIPT="${1:-navegacion.js}"
shift || true

RUTA="${RUTA:-normal}"
VUS="${VUS:-100}"
DURACION="${DURACION:-5m}"
NOMBRE="${NOMBRE:-$(basename "$SCRIPT" .js)-${RUTA}-$(date +%Y%m%d-%H%M%S)}"
IMAGEN="${K6_IMAGEN:-grafana/k6:latest}"
RESULTADOS="$AQUI/../resultados"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "No existe el env-file: $ENV_FILE" >&2
  echo "Copia ejemplo/signbb-test.env.example a .env, completa las credenciales y usa chmod 600." >&2
  exit 2
fi

mkdir -p "$AQUI/resultados"

echo "Ejecutando $SCRIPT con RUTA=$RUTA, VUS=$VUS, DURACION=$DURACION"
echo "Resultados: $RESULTADOS/$NOMBRE-summary.json"

mkdir -p "$RESULTADOS"

docker run --rm -i \
  --ulimit nofile=65536:65536 \
  --env-file "$ENV_FILE" \
  -e RUTA="$RUTA" \
  -e VUS="$VUS" \
  -e DURACION="$DURACION" \
  -e HOME=/tmp \
  -e K6_NO_USAGE_REPORT=true \
  -v "$AQUI/k6:/scripts:ro" \
  -v "$RESULTADOS:/resultados" \
  -u "$(id -u):$(id -g)" \
  "$IMAGEN" run \
  --summary-export="/resultados/$NOMBRE-summary.json" \
  "/scripts/$SCRIPT" \
  2>&1 | tee "$RESULTADOS/$NOMBRE.log"
