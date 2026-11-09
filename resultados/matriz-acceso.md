# Matriz de acceso AS-02

Entorno: https://consulta.canguritos.tech
Fecha: 2026-11-09T03:29:00-05:00

| Caso | Rol | Método | Ruta | Esperado | Obtenido | Estado |
|---|---|---|---|---|---|---|
| AC-007 | Anónimo | GET | /api/consulta/disponibilidad | 401 | 401 | OK |
| AC-008 | Anónimo | GET | /api/recorridos | 401 | 401 | OK |
| AC-009 | Anónimo | GET | /api/autoria/subgrafos | 401 | 401 | OK |
| AC-010 | Anónimo | GET | /api/usuarios | 401 | 401 | OK |
| AC-011 | Padre | GET | /api/consulta/disponibilidad | 200 | 200 | OK |
| AC-012 | Padre | GET | /api/recorridos | 200 | 200 | OK |
| AC-013 | Padre | GET | /api/autoria/subgrafos | 403 | 403 | OK |
| AC-014 | Padre | GET | /api/autoria/revisiones | 403 | 403 | OK |
| AC-015 | Padre | GET | /api/usuarios | 403 | 403 | OK |
| AC-016 | Padre | GET | /api/auth/yo | 200 | 200 | OK |
| AC-017 | Médico | GET | /api/consulta/disponibilidad | 403 | 403 | OK |
| AC-018 | Médico | GET | /api/recorridos | 403 | 403 | OK |
| AC-019 | Médico | GET | /api/autoria/subgrafos | 200 | 200 | OK |
| AC-020 | Médico | GET | /api/autoria/revisiones | 403 | 403 | OK |
| AC-021 | Médico | GET | /api/usuarios | 403 | 403 | OK |
| AC-022 | Médico | GET | /api/auth/yo | 200 | 200 | OK |
| AC-023 | Médico | POST | /api/autoria/subgrafos/999999/aprobar | 403 | 403 | OK |
| AC-024 | Médico | POST | /api/usuarios | 403 | 403 | OK |
| AC-025 | Supervisor | GET | /api/consulta/disponibilidad | 403 | 403 | OK |
| AC-026 | Supervisor | GET | /api/recorridos | 403 | 403 | OK |
| AC-027 | Supervisor | GET | /api/autoria/subgrafos | 200 | 200 | OK |
| AC-028 | Supervisor | GET | /api/autoria/revisiones | 200 | 200 | OK |
| AC-029 | Supervisor | GET | /api/usuarios | 200 | 200 | OK |
| AC-030 | Supervisor | GET | /api/auth/yo | 200 | 200 | OK |
| AC-031 | Supervisor | POST | /api/autoria/subgrafos/999999/aprobar | 404 422 | 404 | OK |
| AC-032 | Padre A | POST | /api/recorridos | 200 | 200 | OK |
| AC-033 | Padre A | GET | /api/recorridos/fb446a97-53fe-4b50-aa3a-cb7338f645e1 | 200 | 200 | OK |
| AC-034 | Padre B | GET | /api/recorridos/fb446a97-53fe-4b50-aa3a-cb7338f645e1 | 404 | 404 | OK |
| AC-035 | Padre B | POST | /api/recorridos/fb446a97-53fe-4b50-aa3a-cb7338f645e1/respuestas | 404 | 404 | OK |
| AC-036 | Médico | GET | /api/recorridos/fb446a97-53fe-4b50-aa3a-cb7338f645e1 | 403 | 403 | OK |
| AC-037 | Padre | GET | /api/auth/yo | 401 | 401 | OK |
| AC-038 | Padre | GET | /api/consulta/disponibilidad (origen https://autoria.canguritos.tech) | 200 + ACAO | 200 / https://autoria.canguritos.tech | OK |
| AC-039 | Padre | GET | /api/consulta/disponibilidad (origen no permitido) | 403 | 403 | OK |

Total: 33; fallos: 0
Cuentas de prueba creadas: perf.acceso.a.20261109032900-1449134@signbb.test, perf.acceso.b.20261109032900-1449134@signbb.test
Se eliminan con seguridad/limpiar-datos.sh.
