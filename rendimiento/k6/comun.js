// Utilidades compartidas por los escenarios de k6.
// No se imprimen tokens ni contraseñas.

import http from 'k6/http';
import { fail } from 'k6';

export const BASE_URL = (__ENV.BASE_URL || 'https://consulta.canguritos.tech').replace(/\/+$/, '');

export const JSON_HEADERS = {
  'Content-Type': 'application/json',
  Accept: 'application/json',
};

/** Cabeceras con el token de la sesión. */
export function authHeaders(token) {
  return {
    Authorization: `Bearer ${token}`,
    'Content-Type': 'application/json',
    Accept: 'application/json',
  };
}

/** Abre una sesión y devuelve el token. Aborta la prueba si el ingreso falla. */
export function login(correo, contrasena, dispositivoSeguro = false) {
  if (!correo || !contrasena) {
    fail('Faltan PADRE_CORREO/PADRE_CONTRASENA o las credenciales del rol en el entorno.');
  }
  const respuesta = http.post(
    `${BASE_URL}/api/auth/login`,
    JSON.stringify({ correo, contrasena, dispositivoSeguro }),
    { headers: JSON_HEADERS, tags: { paso: 'login' } },
  );
  if (respuesta.status !== 200) {
    console.error(`El ingreso falló con HTTP ${respuesta.status}.`);
    fail('No se pudo iniciar sesión; revisa las credenciales y el estado del backend.');
  }
  let cuerpo;
  try {
    cuerpo = respuesta.json();
  } catch (e) {
    fail('El ingreso no devolvió JSON.');
  }
  if (!cuerpo || !cuerpo.token) {
    fail('El ingreso no devolvió token.');
  }
  return cuerpo.token;
}

/** Pausa de lectura entre pasos, en segundos. */
export function think(minimo = 2, maximo = 4) {
  const bajo = Number(minimo);
  const alto = Number(maximo);
  return bajo + Math.random() * Math.max(0, alto - bajo);
}

/** Comprueba que una respuesta trae JSON y devuelve el objeto, o null. */
export function comoJson(respuesta) {
  try {
    return respuesta.json();
  } catch (e) {
    return null;
  }
}
