#!/usr/bin/env bash
# Limpia los datos creados por las pruebas en el VPS.
#
# Solo para el entorno de pruebas. Borra:
#   - usuarios @signbb.test y sus recorridos/observaciones;
#   - recorridos del padre del seed iniciados después del corte;
#   - borradores de carga del médico del seed;
#   - filas de limite_intentos actualizadas después del corte.
#
# Uso:
#   ENV_FILE=./.env ./limpiar-datos.sh
#   CORTE='2026-11-09T06:00:00Z' ./limpiar-datos.sh
#
# Por defecto usa las últimas 2 horas.

set -euo pipefail

AQUI="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${ENV_FILE:-$AQUI/../.env}"

if [[ -f "$ENV_FILE" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +a
fi

CORTE="${CORTE:-$(date -u -d '2 hours ago' '+%Y-%m-%dT%H:%M:%SZ')}"
VPS_HOST="${VPS_HOST:-signbb@2.25.152.145}"
VPS_KEY="${VPS_KEY:-$HOME/.ssh/signbb_vps_ed25519}"
VPS_DIR="${VPS_DIR:-/opt/signbb/signbb-frontend/deploy}"

echo "Limpieza de datos de prueba en $VPS_HOST"
echo "Corte: $CORTE"
echo "Solo debe usarse en el despliegue de pruebas."
echo

ssh -o BatchMode=yes -o ConnectTimeout=10 -i "$VPS_KEY" "$VPS_HOST" \
  "cd '$VPS_DIR' && docker compose -f compose.prod.yaml exec -T db psql -U admin -d signbb -v ON_ERROR_STOP=1 -v corte='$CORTE'" <<'SQL'
begin;

create temp table tmp_usuarios as
    select id from usuario where correo like '%@signbb.test';

create temp table tmp_recorridos as
    select id from recorrido
    where iniciado_en >= :'corte'::timestamptz
      and usuario_id = (select id from usuario where correo = 'padre.ejemplo@signbb.local');

create temp table tmp_obs as
    select id from observacion_entity
    where usuario_id in (select id from tmp_usuarios)
       or recorrido_id in (select id from tmp_recorridos);

select 'usuarios de prueba' as concepto, count(*) as filas from tmp_usuarios
union all
select 'recorridos del seed desde el corte', count(*) from tmp_recorridos
union all
select 'observaciones asociadas', count(*) from tmp_obs;

delete from observacion_opciones
where observacion_id in (select id from tmp_obs);

delete from observacion_entity
where id in (select id from tmp_obs);

delete from recorrido
where usuario_id in (select id from tmp_usuarios)
   or id in (select id from tmp_recorridos);

delete from borrador_subgrafo_entity
where nombre like 'Carga %'
  and creado_en >= :'corte'::timestamptz
  and autor_id = (select id from usuario where correo = 'medico.ejemplo@signbb.local');

delete from usuario
where id in (select id from tmp_usuarios);

delete from limite_intentos
where actualizado_en >= :'corte'::timestamptz;

commit;
SQL

echo
echo "Limpieza terminada. Verifica que el backend sigue sano y que el seed permanece."
