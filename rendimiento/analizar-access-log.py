#!/usr/bin/env python3
"""Resume el access log de Tomcat por endpoint y calcula percentiles.

El log debe tener el patrón:
    %t %a "%r" %s %b %D
donde %D es el tiempo de procesamiento del servidor en microsegundos
(Tomcat 11). El script lo convierte a milisegundos.

Uso:
    python3 analizar-access-log.py access.log
    python3 analizar-access-log.py access.log --json resumen.json
"""

from __future__ import annotations

import argparse
import json
import math
import re
import sys
from collections import defaultdict
from pathlib import Path

LINEA = re.compile(r'^\S+ \S+ \S+ "([A-Z]+) (\S+) [^"]*" (\d{3}) (\S+) (\d+)\s*$')


def normalizar_ruta(ruta: str) -> str:
    ruta = ruta.split("?", 1)[0]
    ruta = re.sub(r"/api/autoria/subgrafos/\d+/nodos/[^/]+",
                  "/api/autoria/subgrafos/{id}/nodos/{nodo}", ruta)
    ruta = re.sub(r"/api/autoria/subgrafos/\d+/respuestas/[^/]+/destino",
                  "/api/autoria/subgrafos/{id}/respuestas/{respuesta}/destino", ruta)
    ruta = re.sub(r"/api/autoria/subgrafos/\d+", "/api/autoria/subgrafos/{id}", ruta)
    ruta = re.sub(r"/api/usuarios/\d+", "/api/usuarios/{id}", ruta)
    ruta = re.sub(r"/api/recorridos/[0-9a-fA-F-]{8,}", "/api/recorridos/{id}", ruta)
    return ruta


def percentil(valores: list[float], p: float) -> float:
    if not valores:
        return 0
    ordenados = sorted(valores)
    indice = max(0, min(len(ordenados) - 1, math.ceil(p / 100 * len(ordenados)) - 1))
    return ordenados[indice]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("archivo", type=Path)
    parser.add_argument("--json", type=Path, help="Escribe el resumen también como JSON")
    parser.add_argument("--min-count", type=int, default=1)
    args = parser.parse_args()

    if not args.archivo.is_file():
        print(f"No existe el archivo: {args.archivo}", file=sys.stderr)
        return 2

    grupos: dict[tuple[str, str], dict[str, object]] = defaultdict(
        lambda: {"durations": [], "4xx": 0, "5xx": 0}
    )
    total = 0
    total_4xx = 0
    total_5xx = 0
    ignoradas = 0

    with args.archivo.open("r", encoding="utf-8", errors="replace") as entrada:
        for linea in entrada:
            coincidencia = LINEA.match(linea.rstrip("\n"))
            if not coincidencia:
                ignoradas += 1
                continue
            metodo, ruta, estado, _bytes, duracion = coincidencia.groups()
            if metodo == "OPTIONS" or not ruta.startswith("/api/"):
                continue
            if ruta.startswith("/actuator/health"):
                continue
            estado_num = int(estado)
            # Tomcat 11 expresa %D en microsegundos; se pasa a milisegundos.
            duracion_num = int(duracion) / 1000.0
            clave = (metodo, normalizar_ruta(ruta))
            grupo = grupos[clave]
            grupo["durations"].append(duracion_num)
            if 400 <= estado_num < 500:
                grupo["4xx"] += 1
                total_4xx += 1
            elif estado_num >= 500:
                grupo["5xx"] += 1
                total_5xx += 1
            total += 1

    filas = []
    for (metodo, ruta), datos in grupos.items():
        duraciones = datos["durations"]
        if len(duraciones) < args.min_count:
            continue
        filas.append({
            "metodo": metodo,
            "ruta": ruta,
            "n": len(duraciones),
            "4xx": datos["4xx"],
            "5xx": datos["5xx"],
            "p50": percentil(duraciones, 50),
            "p95": percentil(duraciones, 95),
            "p99": percentil(duraciones, 99),
            "max": max(duraciones),
        })
    filas.sort(key=lambda fila: (-fila["n"], fila["metodo"], fila["ruta"]))

    print(f"Archivo: {args.archivo}")
    print(f"Peticiones API contabilizadas: {total}; ignoradas: {ignoradas}")
    print(f"4xx: {total_4xx}; 5xx: {total_5xx}")
    print()
    print("| Método | Endpoint | n | 4xx | 5xx | p50 (ms) | p95 (ms) | p99 (ms) | máx (ms) |")
    print("|---|---|---:|---:|---:|---:|---:|---:|---:|")
    for fila in filas:
        print(
            f"| {fila['metodo']} | {fila['ruta']} | {fila['n']} | {fila['4xx']} | "
            f"{fila['5xx']} | {fila['p50']:.1f} | {fila['p95']:.1f} | {fila['p99']:.1f} | {fila['max']:.1f} |"
        )

    if args.json:
        args.json.write_text(
            json.dumps(
                {
                    "archivo": str(args.archivo),
                    "total": total,
                    "4xx": total_4xx,
                    "5xx": total_5xx,
                    "endpoints": filas,
                },
                ensure_ascii=False,
                indent=2,
            )
            + "\n",
            encoding="utf-8",
        )
        print(f"\nResumen JSON: {args.json}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
