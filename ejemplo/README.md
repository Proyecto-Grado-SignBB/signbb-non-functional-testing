# Ejemplo de configuración

Este directorio no contiene credenciales reales. La plantilla se copia a la
raíz del repositorio como `.env`, se completa con los valores del entorno de
pruebas y se protege con `chmod 600`.

```bash
cp ejemplo/signbb-test.env.example .env
chmod 600 .env
# editar .env con las credenciales reales
```

`.env` está ignorado por Git. No lo agregues al repositorio ni subas tokens,
contraseñas o claves privadas.

## Variables

| Variable | Uso |
|---|---|
| `BASE_URL` | Dirección del despliegue que se va a probar. |
| `PADRE_CORREO` y `PADRE_CONTRASENA` | Cuenta de cuidador para las rutas de navegación. |
| `MEDICO_CORREO` y `MEDICO_CONTRASENA` | Cuenta clínica para las pruebas de autoría. |
| `SUPERVISOR_CORREO` y `SUPERVISOR_CONTRASENA` | Cuenta de médico supervisor para la matriz de acceso y la administración. |
| `VUS` y `DURACION` | Carga y duración por defecto de los escenarios de k6. |
| `LOGIN_USUARIOS`, `LOGIN_CONTRASENA` y `LOGIN_PAUSA` | Cuentas desechables y pausa del escenario de ingreso. |
| `TEST_USER_PASSWORD` | Contraseña de las cuentas temporales de la matriz de acceso. |
| `SEG_CONTRASENA` | Contraseña de las cuentas temporales de la secuencia de bloqueo. |
| `VPS_HOST`, `VPS_KEY` y `VPS_DIR` | Acceso SSH para habilitar el access log, consultar la base y limpiar. |

Las cuentas de prueba se crean y se eliminan durante la ejecución. No uses las
cuentas del seed para las pruebas de bloqueo ni para las pruebas que desactivan
sesiones.
