#!/usr/bin/env bash
set -euo pipefail

# Alta de una máquina: exporta del agente SSH la llave `savaf@<hostname>` a
# ssh/.ssh/<hostname>.pub, la añade a ssh/.ssh/allowed_signers (sin duplicar) y, con
# --github, la registra en GitHub (authentication + signing) tras confirmar.
# Ver docs/git-and-ssh.md.
#
# Uso: scripts/ssh-add-host.sh [--dry-run] [--github] [hostname]

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SSH_DIR="${ROOT_DIR}/ssh/.ssh"
SIGNER_ID="10409334+savaf@users.noreply.github.com"

DRY=0
GITHUB=0
HOST=""
for arg in "$@"; do
  case "${arg}" in
    --dry-run) DRY=1 ;;
    --github) GITHUB=1 ;;
    -*) echo "Opción desconocida: ${arg}" >&2; exit 2 ;;
    *) HOST="${arg}" ;;
  esac
done
HOST="${HOST:-$(hostname -s)}"
# El hostname forma parte de una ruta y de la búsqueda en el agente: solo caracteres seguros.
[[ "${HOST}" =~ ^[A-Za-z0-9][A-Za-z0-9-]*$ ]] || { echo "Hostname inválido: ${HOST}" >&2; exit 2; }
PUB="${SSH_DIR}/${HOST}.pub"

# Línea completa "tipo base64 comentario" de la llave savaf@<host> en el agente.
# El comentario va por ENVIRON (awk -v interpretaría escapes).
lines="$(ssh-add -L 2>/dev/null | C="savaf@${HOST}" awk '$3 == ENVIRON["C"]')"
[[ -n "${lines}" ]] || { echo "No hay llave 'savaf@${HOST}' en el agente (ssh-add -L)." >&2; exit 1; }
[[ "${lines}" != *$'\n'* ]] || { echo "Hay varias llaves 'savaf@${HOST}' en el agente: deja solo una." >&2; exit 1; }
line="${lines}"
key="${line%% savaf@*}"

if [[ -f "${PUB}" && "$(cat "${PUB}")" != "${line}" ]]; then
  echo "${PUB} ya existe con otra llave: bórrala a mano si es una rotación." >&2
  exit 1
fi

signer="${SIGNER_ID} namespaces=\"git\" ${key}"
have_signer=0
grep -qxF "${signer}" "${SSH_DIR}/allowed_signers" 2>/dev/null && have_signer=1

if [[ ${DRY} -eq 1 ]]; then
  echo "[dry-run] escribiría ${PUB}"
  [[ ${have_signer} -eq 1 ]] && echo "[dry-run] allowed_signers ya la tiene" \
    || echo "[dry-run] añadiría la llave a ${SSH_DIR}/allowed_signers"
  [[ ${GITHUB} -eq 0 ]] || echo "[dry-run] gh ssh-key add ${PUB} --type authentication / --type signing (con confirmación)"
  exit 0
fi

echo "${line}" >"${PUB}"
if [[ ${have_signer} -eq 0 ]]; then
  signers="${SSH_DIR}/allowed_signers"
  # Si el archivo no termina en salto de línea, la entrada nueva se pegaría a la última.
  [[ ! -s "${signers}" || -z "$(tail -c1 "${signers}")" ]] || echo >>"${signers}"
  echo "${signer}" >>"${signers}"
fi
echo "Listo: ${PUB} y allowed_signers. Commitea ambos."

if [[ ${GITHUB} -eq 1 ]]; then
  ssh-keygen -lf "${PUB}"
  read -r -p "¿Registrar savaf@${HOST} en GitHub (authentication y signing)? [y/N] " ans || ans=""
  if [[ "${ans}" =~ ^[yY] ]]; then
    gh ssh-key add "${PUB}" --type authentication --title "${HOST}"
    gh ssh-key add "${PUB}" --type signing --title "${HOST}"
  else
    echo "GitHub: omitido."
  fi
fi
