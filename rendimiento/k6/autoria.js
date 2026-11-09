// Autoría: 20 VUs constantes creando, editando y borrando un borrador propio.
// Mide el camino de escritura de RD-02 sin tocar los subgrafos publicados del seed.

import http from 'k6/http';
import { check, sleep } from 'k6';
import { BASE_URL, authHeaders, login, think } from './comun.js';

const VUS = Number(__ENV.VUS || 20);
const DURACION = __ENV.DURACION || '5m';

export const options = {
  scenarios: {
    autoria: {
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
  const token = login(__ENV.MEDICO_CORREO, __ENV.MEDICO_CONTRASENA);
  const respuesta = http.get(`${BASE_URL}/api/autoria/categorias`, {
    headers: authHeaders(token),
    tags: { paso: 'categorias' },
  });
  if (respuesta.status !== 200) {
    throw new Error(`No se pudieron leer las categorías: HTTP ${respuesta.status}`);
  }
  const categorias = respuesta.json();
  if (!Array.isArray(categorias) || categorias.length === 0) {
    throw new Error('La lista de categorías está vacía.');
  }
  return { token, puenteId: categorias[0].puenteId };
}

export default function (data) {
  const sufijo = `${__VU}-${__ITER}-${Date.now()}`;
  const nombre = `Carga ${sufijo}`.slice(0, 100);
  const etiqueta = `Carga ${sufijo}`.slice(0, 60);
  let borradorId = null;

  try {
    let respuesta = http.post(
      `${BASE_URL}/api/autoria/subgrafos`,
      JSON.stringify({ nombre, puenteId: data.puenteId, etiquetaOpcion: etiqueta }),
      { headers: authHeaders(data.token), tags: { paso: 'crear_borrador' } },
    );
    if (!check(respuesta, { 'crear borrador 201': (r) => r.status === 201 })) {
      return;
    }
    const borrador = respuesta.json();
    borradorId = borrador.id;

    respuesta = http.post(
      `${BASE_URL}/api/autoria/subgrafos/${borradorId}/nodos`,
      JSON.stringify({
        tipo: 'PREGUNTA',
        texto: '¿Pregunta de prueba de carga?',
        variasRespuestas: false,
        respuestas: [
          { texto: 'Sí', gravedad: 'GRAVE' },
          { texto: 'No', gravedad: 'LEVE' },
        ],
      }),
      { headers: authHeaders(data.token), tags: { paso: 'crear_nodo' } },
    );
    if (!check(respuesta, { 'crear nodo 200': (r) => r.status === 200 })) {
      return;
    }
    const conNodo = respuesta.json();
    if (!conNodo.nodos || conNodo.nodos.length === 0) {
      check(conNodo, { 'borrador con nodo': () => false });
      return;
    }
    const nodo = conNodo.nodos[0];

    respuesta = http.put(
      `${BASE_URL}/api/autoria/subgrafos/${borradorId}/nodos/${nodo.id}`,
      JSON.stringify({
        tipo: 'PREGUNTA',
        texto: '¿Pregunta de prueba de carga editada?',
        variasRespuestas: false,
        respuestas: [
          { id: nodo.respuestas[0].id, texto: 'Sí', gravedad: 'GRAVE' },
          { id: nodo.respuestas[1].id, texto: 'No', gravedad: 'LEVE' },
        ],
      }),
      { headers: authHeaders(data.token), tags: { paso: 'editar_nodo' } },
    );
    if (!check(respuesta, { 'editar nodo 200': (r) => r.status === 200 })) {
      return;
    }

    respuesta = http.get(
      `${BASE_URL}/api/autoria/subgrafos/${borradorId}`,
      { headers: authHeaders(data.token), tags: { paso: 'leer_borrador' } },
    );
    check(respuesta, { 'leer borrador 200': (r) => r.status === 200 });

    respuesta = http.del(
      `${BASE_URL}/api/autoria/subgrafos/${borradorId}/nodos/${nodo.id}`,
      null,
      { headers: authHeaders(data.token), tags: { paso: 'borrar_nodo' } },
    );
    check(respuesta, { 'borrar nodo 200': (r) => r.status === 200 });

    sleep(think());
  } finally {
    if (borradorId) {
      const borrado = http.del(
        `${BASE_URL}/api/autoria/subgrafos/${borradorId}`,
        null,
        { headers: authHeaders(data.token), tags: { paso: 'borrar_borrador' } },
      );
      check(borrado, { 'borrar borrador 204': (r) => r.status === 204 });
    }
  }
}
