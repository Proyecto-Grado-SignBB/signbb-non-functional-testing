# Pruebas de desempeño y seguridad — despliegue VPS

Suite para el despliegue de pruebas de SignBB. El escenario de desempeño es
**100 VUs constantes**. La seguridad se concentra en **AS-02** (control de
acceso) y **AS-06** (bloqueo por intentos). AS-01 queda cubierto por las
pruebas locales y no se repite aquí.

## Estructura del repositorio

| Carpeta | Contenido |
|---|---|
| `ejemplo/` | Plantilla de configuración y explicación de las variables. No contiene credenciales reales. |
| `rendimiento/` | Escenarios de k6, analizador del access log, override de Docker y ejecutor. |
| `seguridad/` | Matriz de acceso, bloqueo por intentos, consulta del contador y limpieza. |
| `resultados/` | Evidencia de la ejecución: resúmenes de k6, access log, matrices, monitoreo y limpieza. |

## Requisitos

- Docker para ejecutar k6 (`grafana/k6`).
- `curl` y `jq` para las pruebas de seguridad.
- Acceso SSH al VPS para habilitar el access log, consultar la base y limpiar.
- Un archivo `.env` en la raíz del repositorio, creado a partir de
  `ejemplo/signbb-test.env.example`, con `chmod 600`. No guardes credenciales
  en el repositorio.

```bash
cp ejemplo/signbb-test.env.example ./.env
chmod 600 ./.env
# completar los valores reales
chmod +x rendimiento/run.sh seguridad/*.sh
```

## Glosario de métricas

| Término | Significado |
|---|---|
| **4xx** | Respuestas HTTP con código entre 400 y 499. Indican un error del lado del cliente o de la petición: falta de sesión, permisos insuficientes, recurso inexistente o demasiados intentos. En esta suite varias son esperadas: por ejemplo, 401 y 403 en la matriz de acceso y 429 en el bloqueo por intentos. No cuentan como fallo del servidor si el caso las espera. |
| **5xx** | Respuestas HTTP con código entre 500 y 599. Indican un error del servidor o de una dependencia. En las pruebas de desempeño deben ser cero o, como máximo, menos del 1 % de las peticiones. |
| **p50** | Percentil 50, también llamado mediana. Es el tiempo por debajo del cual quedó el 50 % de las peticiones. |
| **p95** | Percentil 95. Es el tiempo por debajo del cual quedó el 95 % de las peticiones; el 5 % restante fue más lento. Es el criterio principal de RD-01 y RD-02: por ejemplo, un p95 de 500 ms significa que 95 de cada 100 peticiones respondieron en 500 ms o menos. |
| **p99** | Percentil 99. Es el tiempo por debajo del cual quedó el 99 % de las peticiones; muestra la cola lenta y los casos atípicos. Siempre es mayor o igual que el p95. |
| **RTT** | *Round-trip time* o tiempo de ida y vuelta de la red entre el equipo que genera la carga y el servidor. Las métricas de k6 del lado del cliente incluyen el RTT; el access log de Tomcat no, porque mide solo el procesamiento del servidor. Por eso el p95 de servidor es el que se compara con RD-01 y RD-02. |

Los percentiles se calculan sobre los tiempos de respuesta de cada operación. El access log de Tomcat entrega el tiempo de procesamiento del servidor; k6 entrega el tiempo percibido por el cliente, que incluye la red.

## 1. Habilitar el access log de Tomcat

El access log se usa para medir el tiempo del servidor (`%D`, en
microsegundos en Tomcat 11; el analizador lo convierte a milisegundos), que es
el que exige RD-01/RD-02. Se habilita solo durante la ventana de prueba.

```bash
scp -i ~/.ssh/signbb_vps_ed25519 \
  rendimiento/compose.accesslog.yaml \
  signbb@2.25.152.145:/tmp/compose.accesslog.yaml

ssh -i ~/.ssh/signbb_vps_ed25519 signbb@2.25.152.145 \
  'cd /opt/signbb/signbb-frontend/deploy && \
   docker compose -f compose.prod.yaml -f /tmp/compose.accesslog.yaml \
     up -d --force-recreate backend'

# esperar a que el backend esté sano
curl -fsS https://consulta.canguritos.tech/actuator/health
```

Comprobar que el archivo se está escribiendo:

```bash
ssh -i ~/.ssh/signbb_vps_ed25519 signbb@2.25.152.145 \
  'cd /opt/signbb/signbb-frontend/deploy && \
   docker compose -f compose.prod.yaml exec -T backend \
     sh -c "ls -l /tmp/signbb-access.log; tail -n 3 /tmp/signbb-access.log"'
```

Al terminar las pruebas, **copiar el log antes de recrear el backend**:

```bash
ssh -i ~/.ssh/signbb_vps_ed25519 signbb@2.25.152.145 \
  'cd /opt/signbb/signbb-frontend/deploy && \
   docker compose -f compose.prod.yaml cp backend:/tmp/signbb-access.log /tmp/access.log'

scp -i ~/.ssh/signbb_vps_ed25519 \
  signbb@2.25.152.145:/tmp/access.log \
  resultados/access.log

ssh -i ~/.ssh/signbb_vps_ed25519 signbb@2.25.152.145 \
  'cd /opt/signbb/signbb-frontend/deploy && \
   docker compose -f compose.prod.yaml up -d --force-recreate backend'
```

## 2. Desempeño

Primero un humo de 1 VU para validar las rutas y el token:

```bash
ENV_FILE=./.env RUTA=normal VUS=1 DURACION=1m \
  rendimiento/run.sh navegacion.js
```

Ruta normal con 100 VUs constantes:

```bash
ENV_FILE=./.env RUTA=normal VUS=100 DURACION=5m \
  rendimiento/run.sh navegacion.js
```

Ruta con reglas con 100 VUs constantes (alterna urgencia y consulta por
iteración):

```bash
ENV_FILE=./.env RUTA=reglas VUS=100 DURACION=5m \
  rendimiento/run.sh navegacion.js
```

Autoría con 20 VUs:

```bash
ENV_FILE=./.env VUS=20 DURACION=5m \
  rendimiento/run.sh autoria.js
```

Login con 50 VUs durante 1 minuto (capacidad de BCrypt; no es RD-01):

```bash
ENV_FILE=./.env VUS=50 DURACION=1m \
  rendimiento/run.sh login.js
```

Los resultados quedan en `resultados/`. El resumen de k6
incluye el p95 de cliente, que incorpora el RTT; no se usa como criterio de
RD-01. El access log de Tomcat es la fuente de verdad del tiempo de servidor.

### Analizar el access log

```bash
python3 rendimiento/analizar-access-log.py \
  resultados/access.log \
  | tee resultados/access-resumen.md
```

El script normaliza las rutas con identificadores y calcula p50, p95, p99 y
máximo por endpoint, además de 4xx y 5xx. Filtra las peticiones de salud.

## 3. Seguridad

### AS-02 — matriz de acceso

```bash
ENV_FILE=./.env \
  seguridad/matriz-acceso.sh \
  | tee resultados/matriz-acceso.md
```

El script crea dos padres desechables para comprobar la propiedad del
recorrido, recorre la matriz de roles y prueba el token alterado y CORS. Las
cuentas creadas quedan en `resultados/cuentas-acceso.txt`.

### AS-06 — bloqueo por intentos

```bash
ENV_FILE=./.env MODO=bloquear \
  seguridad/bloqueo-intentos.sh \
  | tee resultados/bloqueo-intentos.md
```

La secuencia es: 5 fallos → 401; sexto intento con la contraseña correcta →
429 con `Retry-After`; después se comprueba el reinicio del contador con una
segunda cuenta. La cuenta bloqueada queda en
`resultados/bloqueo-cuenta.txt`.

Consultar la fila de la base:

```bash
ENV_FILE=./.env \
  seguridad/consultar-limite.sh \
  | tee resultados/bloqueo-db.txt
```

Esperar 15 minutos (se pueden ejecutar las pruebas de desempeño mientras
tanto) y verificar la recuperación:

```bash
ENV_FILE=./.env MODO=verificar \
  seguridad/bloqueo-intentos.sh \
  | tee -a resultados/bloqueo-intentos.md
```

## 4. Limpieza

Después de guardar las evidencias:

```bash
ENV_FILE=./.env \
  seguridad/limpiar-datos.sh
```

Borra usuarios `@signbb.test`, sus recorridos y observaciones, los recorridos
del padre del seed iniciados después del corte, los borradores de carga y las
filas de `limite_intentos` actualizadas después del corte. Es solo para el
entorno de pruebas.

## 5. Alcance y criterios

- **Desempeño**: 100 VUs constantes; p95 de servidor ≤ 500 ms; 5xx < 1 %;
  cuerpos de pregunta ≤ 15 KB (RD-04). Los grafos del seed son pequeños, como
  se espera por las validaciones con médicos; no se genera un grafo grande.
- **Seguridad**: AS-02 con matriz de roles y propiedad del recorrido; AS-06 con
  la secuencia de 5 fallos y el sexto intento bloqueado, persistencia en base y
  recuperación a los 15 minutos.
- **Fuera de alcance**: pruebas de estrés y verificación de hashes de AS-01
  (cubierta localmente). No se usa OWASP ZAP.
- **Informe**: `AGENTS/Informe_Pruebas_VPS.md`, en el repositorio principal de
  documentación, con las convenciones de los artefactos de documentación.
