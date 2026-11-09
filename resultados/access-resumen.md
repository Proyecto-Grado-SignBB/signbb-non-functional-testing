Archivo: pruebas/resultados/access.log
Peticiones API contabilizadas: 31432; ignoradas: 0
4xx: 22; 5xx: 0

| Método | Endpoint | n | 4xx | 5xx | p50 (ms) | p95 (ms) | p99 (ms) | máx (ms) |
|---|---|---:|---:|---:|---:|---:|---:|---:|
| POST | /api/recorridos/{id}/respuestas | 16146 | 1 | 0 | 9.7 | 21.7 | 49.6 | 227.1 |
| POST | /api/recorridos | 3625 | 0 | 0 | 4.0 | 33.1 | 274.5 | 467.2 |
| DELETE | /api/autoria/subgrafos/{id} | 1657 | 0 | 0 | 3.9 | 8.5 | 19.2 | 89.0 |
| DELETE | /api/autoria/subgrafos/{id}/nodos/{nodo} | 1657 | 0 | 0 | 4.9 | 13.3 | 28.4 | 51.9 |
| GET | /api/autoria/subgrafos/{id} | 1657 | 0 | 0 | 3.8 | 9.7 | 29.9 | 46.4 |
| POST | /api/autoria/subgrafos | 1657 | 0 | 0 | 6.9 | 18.8 | 235.6 | 316.3 |
| POST | /api/autoria/subgrafos/{id}/nodos | 1657 | 0 | 0 | 5.2 | 15.0 | 103.7 | 238.0 |
| PUT | /api/autoria/subgrafos/{id}/nodos/{nodo} | 1657 | 0 | 0 | 5.3 | 14.6 | 78.1 | 159.0 |
| POST | /api/auth/login | 1635 | 1 | 0 | 724.6 | 1126.4 | 1534.3 | 2285.0 |
| POST | /api/auth/registro | 52 | 0 | 0 | 74.3 | 98.2 | 161.9 | 161.9 |
| GET | /api/consulta/disponibilidad | 6 | 4 | 0 | 2.9 | 14.8 | 14.8 | 14.8 |
| GET | /api/auth/yo | 4 | 1 | 0 | 3.1 | 9.3 | 9.3 | 9.3 |
| GET | /api/autoria/subgrafos | 4 | 2 | 0 | 3.6 | 28.7 | 28.7 | 28.7 |
| GET | /api/recorridos | 4 | 3 | 0 | 2.9 | 193.8 | 193.8 | 193.8 |
| GET | /api/usuarios | 4 | 3 | 0 | 2.8 | 26.5 | 26.5 | 26.5 |
| GET | /api/autoria/revisiones | 3 | 2 | 0 | 3.6 | 12.6 | 12.6 | 12.6 |
| GET | /api/recorridos/{id} | 3 | 2 | 0 | 4.5 | 4.8 | 4.8 | 4.8 |
| POST | /api/autoria/subgrafos/{id}/aprobar | 2 | 2 | 0 | 3.1 | 7.4 | 7.4 | 7.4 |
| GET | /api/autoria/categorias | 1 | 0 | 0 | 100.5 | 100.5 | 100.5 | 100.5 |
| POST | /api/usuarios | 1 | 1 | 0 | 2.8 | 2.8 | 2.8 | 2.8 |

Resumen JSON: pruebas/resultados/access-resumen.json
