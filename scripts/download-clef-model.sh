#!/usr/bin/env bash
# Descarga el GGUF de Clef-Flash (Q4_K_M, ~6,5 GB) que usa clef-server.
# Va aparte del bootstrap por su tamaño. Reanuda si se corta; HF_TOKEN acelera.
set -euo pipefail

DIR="${XDG_DATA_HOME:-$HOME/.local/share}/clef"
FILE="Clef-Flash-Q4_K_M.gguf"
URL="https://huggingface.co/ggml-org/Clef-Flash-GGUF/resolve/main/${FILE}"

mkdir -p "${DIR}"
[[ -f "${DIR}/${FILE}" ]] && { echo "Ya está: ${DIR}/${FILE}"; exit 0; }
auth=()
[[ -n "${HF_TOKEN:-}" ]] && auth=(-H "Authorization: Bearer ${HF_TOKEN}")
curl -fL -C - "${auth[@]}" -o "${DIR}/${FILE}.part" "${URL}"
mv "${DIR}/${FILE}.part" "${DIR}/${FILE}"
echo "Listo: ${DIR}/${FILE}"
