// Capacidad de ingreso: 50 VUs constantes durante 1 minuto.
// Este escenario mide BCrypt y el endpoint de login; no es RD-01 ni se mezcla
// con la navegación. Las cuentas se crean en setup y se eliminan al final.

import http from 'k6/http';
import { check, sleep } from 'k6';
import { BASE_URL, JSON_HEADERS } from './comun.js';

const VUS = Number(__ENV.VUS || 50);
const DURACION = __ENV.DURACION || '1m';
const USUARIOS = Number(__ENV.LOGIN_USUARIOS || VUS);

export const options = {
  scenarios: {
    login: {
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
  setupTimeout: '5m',
};

export function setup() {
  const contrasena = __ENV.LOGIN_CONTRASENA;
  if (!contrasena) {
    throw new Error('Falta LOGIN_CONTRASENA en el entorno.');
  }
  const marca = Date.now();
  const usuarios = [];
  for (let i = 0; i < USUARIOS; i += 1) {
    const correo = `perf.login.${marca}.${i}@signbb.test`;
    const respuesta = http.post(
      `${BASE_URL}/api/auth/registro`,
      JSON.stringify({
        nombre: `Carga login ${i}`,
        correo,
        contrasena,
      }),
      { headers: JSON_HEADERS, tags: { paso: 'registro_setup' } },
    );
    if (respuesta.status !== 201) {
      throw new Error(`No se pudo crear la cuenta de login ${i}: HTTP ${respuesta.status}`);
    }
    usuarios.push({ correo, contrasena });
  }
  return { usuarios };
}

export default function (data) {
  const usuario = data.usuarios[(__VU - 1) % data.usuarios.length];
  const respuesta = http.post(
    `${BASE_URL}/api/auth/login`,
    JSON.stringify({ correo: usuario.correo, contrasena: usuario.contrasena }),
    { headers: JSON_HEADERS, tags: { paso: 'login' } },
  );
  check(respuesta, {
    'login 200': (r) => r.status === 200,
    'login con token': (r) => {
      try {
        return !!r.json('token');
      } catch (e) {
        return false;
      }
    },
  });
  sleep(Number(__ENV.LOGIN_PAUSA || 1));
}
