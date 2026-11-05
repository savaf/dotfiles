#!/usr/bin/env bash
# Dice si cada variable esta present / empty / missing, sin imprimir nunca el valor.
# Mira el entorno y, si existe, el .env del directorio actual.
# Uso: env-check.sh KEY [KEY...]
set -euo pipefail

[ $# -gt 0 ] || { echo "uso: env-check.sh KEY [KEY...]" >&2; exit 2; }

for key in "$@"; do
  [[ "$key" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || { echo "$key: nombre invalido" >&2; exit 2; }
  if [ -n "${!key+x}" ]; then
    value="${!key}"
  elif [ -f .env ] && line="$(grep -E "^[[:space:]]*(export[[:space:]]+)?${key}=" .env | tail -n1)"; then
    value="${line#*=}"
    value="${value%\"}"; value="${value#\"}"; value="${value%\'}"; value="${value#\'}"
  else
    echo "$key: missing"
    continue
  fi
  if [ -n "$value" ]; then echo "$key: present"; else echo "$key: empty"; fi
done
