# Secuencia de bloqueo AS-06

Entorno: https://consulta.canguritos.tech
Fecha: 2026-11-09T03:09:10-05:00

| Cuenta | Intento | Esperado | Obtenido | Retry-After | Estado |
|---|---|---|---|---|---|
| seg.bloqueo.20261109030910-1432993@signbb.test | fallo 1 | 401 | 401 |  | OK |
| seg.bloqueo.20261109030910-1432993@signbb.test | fallo 2 | 401 | 401 |  | OK |
| seg.bloqueo.20261109030910-1432993@signbb.test | fallo 3 | 401 | 401 |  | OK |
| seg.bloqueo.20261109030910-1432993@signbb.test | fallo 4 | 401 | 401 |  | OK |
| seg.bloqueo.20261109030910-1432993@signbb.test | fallo 5 | 401 | 401 |  | OK |
| seg.bloqueo.20261109030910-1432993@signbb.test | correcta tras 5 fallos | 429 | 429 | 899 | OK |
| seg.reset.20261109030910-1432993@signbb.test | fallo previo 1 | 401 | 401 |  | OK |
| seg.reset.20261109030910-1432993@signbb.test | fallo previo 2 | 401 | 401 |  | OK |
| seg.reset.20261109030910-1432993@signbb.test | fallo previo 3 | 401 | 401 |  | OK |
| seg.reset.20261109030910-1432993@signbb.test | fallo previo 4 | 401 | 401 |  | OK |
| seg.reset.20261109030910-1432993@signbb.test | ingreso que reinicia | 200 | 200 |  | OK |
| seg.reset.20261109030910-1432993@signbb.test | fallo posterior 1 | 401 | 401 |  | OK |
| seg.reset.20261109030910-1432993@signbb.test | fallo posterior 2 | 401 | 401 |  | OK |
| seg.reset.20261109030910-1432993@signbb.test | fallo posterior 3 | 401 | 401 |  | OK |
| seg.reset.20261109030910-1432993@signbb.test | fallo posterior 4 | 401 | 401 |  | OK |
| seg.reset.20261109030910-1432993@signbb.test | quinto fallo posterior | 401 | 401 |  | OK |
| seg.reset.20261109030910-1432993@signbb.test | sexto fallo posterior | 429 | 429 | 899 | OK |

Total: 17; fallos: 0

Cuenta bloqueada para la verificación de recuperación: seg.bloqueo.20261109030910-1432993@signbb.test
Espera 15 minutos y ejecuta MODO=verificar con el mismo env-file.
# Verificación de recuperación AS-06

Cuenta: seg.bloqueo.20261109030910-1432993@signbb.test
Fecha: 2026-11-09T03:28:50-05:00

| Cuenta | Intento | Esperado | Obtenido | Retry-After | Estado |
|---|---|---|---|---|---|
| seg.bloqueo.20261109030910-1432993@signbb.test | recuperación | 200 | 200 |  | OK |

Total: 1; fallos: 0
