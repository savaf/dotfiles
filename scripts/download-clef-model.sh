#!/usr/bin/env bash
# Descarga el GGUF de Clef-Flash (Q4_K_M, ~6,5 GB) que usa clef-server.
# Va aparte del bootstrap por su tamaño. Reanuda si se corta; HF_TOKEN acelera.
set -euo pipefail

DIR="${XDG_DATA_HOME:-$HOME/.local/share}/clef"
FILE="Clef-Flash-Q4_K_M.gguf"
# Revisión fija del repo de HF y sha256 del archivo: un GGUF malicioso o
# corrupto es superficie de ataque para el parser de llama.cpp.
REV="6b4fe4c59098479652d94f0fe11a40facbebd1ec"
SHA256="3626116623ca8d89641952471fac9ce12af84fb3517520029a2ac6f5146868a2"
URL="https://huggingface.co/ggml-org/Clef-Flash-GGUF/resolve/${REV}/${FILE}"

mkdir -p "${DIR}"
[[ -f "${DIR}/${FILE}" ]] && { echo "Ya está: ${DIR}/${FILE}"; exit 0; }
# El token va por stdin (-K -), no en la línea de comandos visible en ps.
{ [[ -n "${HF_TOKEN:-}" ]] && printf 'header = "Authorization: Bearer %s"\n' "${HF_TOKEN}"; true; } \
  | curl -K - -fL -C - -o "${DIR}/${FILE}.part" "${URL}"
echo "${SHA256}  ${DIR}/${FILE}.part" | sha256sum -c --quiet \
  || { echo "sha256 no coincide; borra ${DIR}/${FILE}.part y reintenta." >&2; exit 1; }
mv "${DIR}/${FILE}.part" "${DIR}/${FILE}"
echo "Listo: ${DIR}/${FILE}"
