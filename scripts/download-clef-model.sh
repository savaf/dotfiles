#!/usr/bin/env bash
# Downloads the Clef-Flash GGUF (Q4_K_M, ~6.5 GB) used by clef-server.
# Kept out of the bootstrap because of its size. Resumes if cut; HF_TOKEN speeds it up.
set -euo pipefail

DIR="${XDG_DATA_HOME:-$HOME/.local/share}/clef"
FILE="Clef-Flash-Q4_K_M.gguf"
# Pinned HF repo revision and file sha256: a malicious or corrupt GGUF is
# attack surface for llama.cpp's parser.
REV="6b4fe4c59098479652d94f0fe11a40facbebd1ec"
SHA256="3626116623ca8d89641952471fac9ce12af84fb3517520029a2ac6f5146868a2"
URL="https://huggingface.co/ggml-org/Clef-Flash-GGUF/resolve/${REV}/${FILE}"

mkdir -p "${DIR}"
[[ -f "${DIR}/${FILE}" ]] && { echo "Ya está: ${DIR}/${FILE}"; exit 0; }
# The token goes through stdin (-K -), not on the command line visible in ps.
{ [[ -n "${HF_TOKEN:-}" ]] && printf 'header = "Authorization: Bearer %s"\n' "${HF_TOKEN}"; true; } \
  | curl -K - -fL -C - -o "${DIR}/${FILE}.part" "${URL}"
echo "${SHA256}  ${DIR}/${FILE}.part" | sha256sum -c --quiet \
  || { echo "sha256 no coincide; borra ${DIR}/${FILE}.part y reintenta." >&2; exit 1; }
mv "${DIR}/${FILE}.part" "${DIR}/${FILE}"
echo "Listo: ${DIR}/${FILE}"
