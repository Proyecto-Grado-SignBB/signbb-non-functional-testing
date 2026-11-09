// Navegación del cuidador con 100 VUs constantes.
//
// RUTA=normal  -> ruta determinista que termina en NORMAL y no activa reglas.
// RUTA=reglas  -> alterna por iteración entre URGENCIA y CONSULTAR_MEDICO,
//                 comprobando que la regla correspondiente queda en razones.
//
// La ruta se apoya en las etiquetas de las opciones del seed; los identificadores
// de pregunta se toman de la respuesta, porque el grafo compuesto los prefija.

import http from 'k6/http';
import { check, sleep, fail } from 'k6';
import { BASE_URL, authHeaders, login, think, comoJson } from './comun.js';

const RUTA = (__ENV.RUTA || 'normal').toLowerCase();
const VUS = Number(__ENV.VUS || 100);
const DURACION = __ENV.DURACION || '5m';

if (RUTA !== 'normal' && RUTA !== 'reglas') {
  throw new Error('RUTA debe ser normal o reglas.');
}

const RUTAS = {
  normal: ['Respiración', 'Revisar respiración y nariz', 'No', 'No', 'No'],
  urgencia: ['Respiración', 'Revisar respiración y nariz', 'Sí', 'Aleteo nasal'],
  consulta: ['Respiración', 'Revisar respiración y nariz', 'Sí', 'Respira diferente sin esfuerzo'],
};

const ESPERADOS = {
  normal: { nivel: 'NORMAL', regla: null },
  urgencia: { nivel: 'URGENCIA', regla: 'Urgencia Respiración' },
  consulta: { nivel: 'CONSULTAR_MEDICO', regla: 'Consultar Respiración' },
};

export const options = {
  scenarios: {
    navegacion: {
      executor: 'constant-vus',
      vus: VUS,
      duration: DURACION,
      gracefulStop: '30s',
    },
  },
  thresholds: {
    http_req_failed: ['rate<0.01'],
    checks: ['rate>0.99'],
  },
  summaryTrendStats: ['avg', 'min', 'med', 'p(90)', 'p(95)', 'p(99)', 'max'],
  setupTimeout: '2m',
};

export function setup() {
  const token = login(__ENV.PADRE_CORREO, __ENV.PADRE_CONTRASENA);
  return { token };
}

export default function (data) {
  const variante = RUTA === 'reglas'
    ? (__ITER % 2 === 0 ? 'urgencia' : 'consulta')
    : 'normal';
  const pasos = RUTAS[variante];
  const esperado = ESPERADOS[variante];

  let respuesta = http.post(
    `${BASE_URL}/api/recorridos`,
    null,
    { headers: authHeaders(data.token), tags: { ruta: variante, paso: 'iniciar' } },
  );

  const inicioOk = check(respuesta, {
    'inicio 200': (r) => r.status === 200,
    'inicio con recorrido': (r) => {
      const cuerpo = comoJson(r);
      return !!(cuerpo && cuerpo.recorridoId && cuerpo.estado === 'EN_CURSO' && cuerpo.pregunta);
    },
    'RD-04 inicio': (r) => r.body.length <= 15 * 1024,
  });
  if (!inicioOk) {
    return;
  }

  let recorrido = comoJson(respuesta);
  const recorridoId = recorrido.recorridoId;

  for (let i = 0; i < pasos.length; i += 1) {
    if (!recorrido || recorrido.estado !== 'EN_CURSO' || !recorrido.pregunta) {
      check(recorrido, { [`paso ${i} en curso`]: () => false });
      return;
    }

    const pregunta = recorrido.pregunta;
    const opcion = pasos[i];
    const disponibles = Array.isArray(pregunta.opciones) ? pregunta.opciones : [];
    const opcionOk = check(pregunta, {
      [`paso ${i} con opción esperada`]: (p) => disponibles.indexOf(opcion) >= 0,
      [`paso ${i} con identificador`]: (p) => !!p.id,
    });
    if (!opcionOk) {
      return;
    }

    sleep(think());

    respuesta = http.post(
      `${BASE_URL}/api/recorridos/${recorridoId}/respuestas`,
      JSON.stringify({
        idPregunta: pregunta.id,
        respuesta: opcion,
        tipo: pregunta.tipoInteraccion || null,
      }),
      { headers: authHeaders(data.token), tags: { ruta: variante, paso: `respuesta_${i}` } },
    );

    const respuestaOk = check(respuesta, {
      [`respuesta ${i} 200`]: (r) => r.status === 200,
      [`RD-04 respuesta ${i}`]: (r) => r.body.length <= 15 * 1024,
    });
    if (!respuestaOk) {
      return;
    }
    recorrido = comoJson(respuesta);
  }

  check(recorrido, {
    'recorrido finalizado': (r) => r.estado === 'FINALIZADO',
    'nivel esperado': (r) => !!(r.resultado && r.resultado.nivel === esperado.nivel),
    'regla esperada': (r) => {
      if (!r.resultado) {
        return false;
      }
      const razones = Array.isArray(r.resultado.razones) ? r.resultado.razones : [];
      if (esperado.regla) {
        return razones.indexOf(esperado.regla) >= 0;
      }
      return razones.length === 0;
    },
  });

  sleep(think());
}
