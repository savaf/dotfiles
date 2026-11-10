#!/usr/bin/env bash
set -euo pipefail

# Tests de scripts/ssh-add-host.sh y de link_ssh_key (modo headless). Todo en directorios
# temporales: ssh-agent propio, `gh` y `hostname` simulados (stubs en PATH). Sin red, sin
# $HOME ni agente reales.
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
AGENT_PID=""
cleanup() {
  [[ -z "${AGENT_PID}" ]] || kill "${AGENT_PID}" 2>/dev/null || true
  rm -rf "${TMP}"
}
trap cleanup EXIT

fail() { echo "FAIL: $*"; exit 1; }

# Agente temporal con una llave savaf@testbox y otra ajena.
SSH_AUTH_SOCK="${TMP}/agent.sock"
export SSH_AUTH_SOCK
eval "$(ssh-agent -a "${SSH_AUTH_SOCK}" -s)" >/dev/null
AGENT_PID="${SSH_AGENT_PID}"
unset SSH_AGENT_PID
ssh-keygen -q -t ed25519 -N '' -C 'savaf@testbox' -f "${TMP}/k1"
ssh-keygen -q -t ed25519 -N '' -C 'otro@testbox' -f "${TMP}/k2"
ssh-add -q "${TMP}/k1" "${TMP}/k2"
KEY="$(cut -d' ' -f1,2 "${TMP}/k1.pub")"

# Stubs: gh registra sus argumentos; hostname responde "testbox".
mkdir -p "${TMP}/bin"
cat >"${TMP}/bin/gh" <<'STUB'
#!/usr/bin/env bash
echo "$*" >>"${GH_LOG}"
STUB
printf '#!/usr/bin/env bash\necho testbox\n' >"${TMP}/bin/hostname"
chmod +x "${TMP}/bin/gh" "${TMP}/bin/hostname"
export GH_LOG="${TMP}/gh.log"
export PATH="${TMP}/bin:${PATH}"

# Repo falso con una copia del script (resuelve ROOT_DIR desde su ubicación).
N=0
setup() {
  N=$((N + 1))
  R="${TMP}/r${N}"
  mkdir -p "${R}/scripts" "${R}/ssh/.ssh"
  cp "${ROOT_DIR}/scripts/ssh-add-host.sh" "${R}/scripts/"
  echo "existente@x namespaces=\"git\" ssh-ed25519 AAAAexistente" >"${R}/ssh/.ssh/allowed_signers"
  : >"${GH_LOG}"
}
run() { bash "${R}/scripts/ssh-add-host.sh" "$@"; }

# --dry-run: no escribe nada ni llama a gh.
setup
run --dry-run --github </dev/null >"${TMP}/out"
[[ ! -e "${R}/ssh/.ssh/testbox.pub" ]] || fail "dry-run creó el .pub"
[[ "$(wc -l <"${R}/ssh/.ssh/allowed_signers")" == 1 ]] || fail "dry-run tocó allowed_signers"
[[ ! -s "${GH_LOG}" ]] || fail "dry-run llamó a gh"
grep -q testbox.pub "${TMP}/out" || fail "dry-run no describe lo que haría"

# Alta: exporta solo la llave savaf@<hostname>, la añade a allowed_signers; sin gh.
setup
run >/dev/null
[[ "$(cat "${R}/ssh/.ssh/testbox.pub")" == "${KEY} savaf@testbox" ]] || fail ".pub: $(cat "${R}/ssh/.ssh/testbox.pub")"
grep -qx "10409334+savaf@users.noreply.github.com namespaces=\"git\" ${KEY}" "${R}/ssh/.ssh/allowed_signers" \
  || fail "falta la línea en allowed_signers"
[[ ! -s "${GH_LOG}" ]] || fail "llamó a gh sin --github"

# Idempotente: sin duplicados.
run >/dev/null
[[ "$(grep -c "${KEY#* }" "${R}/ssh/.ssh/allowed_signers")" == 1 ]] || fail "duplicó la línea en allowed_signers"

# --github con confirmación: registra authentication y signing.
setup
echo y | run --github >/dev/null
[[ "$(wc -l <"${GH_LOG}")" == 2 ]] || fail "gh llamado $(wc -l <"${GH_LOG}") veces"
grep -q 'ssh-key add .*--type authentication' "${GH_LOG}" || fail "falta authentication"
grep -q 'ssh-key add .*--type signing' "${GH_LOG}" || fail "falta signing"

# --github sin confirmar: no registra.
setup
echo n | run --github >/dev/null
[[ ! -s "${GH_LOG}" ]] || fail "registró sin confirmación"

# Sin llave en el agente: falla y no escribe.
setup
if run nohost >/dev/null 2>&1; then fail "aceptó un host sin llave en el agente"; fi
[[ ! -e "${R}/ssh/.ssh/nohost.pub" ]] || fail "creó .pub sin llave"

# .pub existente con otra llave: aborta sin tocar el .pub ni allowed_signers.
setup
echo "ssh-ed25519 AAAAotra savaf@testbox" >"${R}/ssh/.ssh/testbox.pub"
if run >/dev/null 2>&1; then fail "sobrescribió un .pub con otra llave"; fi
[[ "$(cat "${R}/ssh/.ssh/testbox.pub")" == "ssh-ed25519 AAAAotra savaf@testbox" ]] || fail "modificó el .pub existente"
[[ "$(wc -l <"${R}/ssh/.ssh/allowed_signers")" == 1 ]] || fail "tocó allowed_signers con .pub conflictivo"

# Hostname inválido (ruta o escapes de awk): exit 2 y nada escrito.
setup
for bad in .. 'a/b' '\x62'; do
  rc=0; run "${bad}" >/dev/null 2>&1 || rc=$?
  [[ ${rc} -ne 0 ]] || fail "aceptó el hostname inválido ${bad}"
done
rc=0; run '..' >/dev/null 2>&1 || rc=$?
[[ ${rc} -eq 2 ]] || fail "hostname '..' salió con ${rc}, no 2"
rc=0; run '\x62' >/dev/null 2>&1 || rc=$?
[[ ${rc} -eq 2 ]] || fail "hostname '\\x62' salió con ${rc}, no 2"
[[ ! -e "${R}/ssh/.pub" && ! -e "${R}/ssh/b.pub" ]] || fail "escribió con hostname inválido"

# Varias llaves con el mismo comentario: falla.
setup
ssh-keygen -q -t ed25519 -N '' -C 'savaf@testbox' -f "${TMP}/k3"
ssh-add -q "${TMP}/k3"
if run >/dev/null 2>&1; then fail "aceptó dos llaves savaf@testbox"; fi
[[ ! -e "${R}/ssh/.ssh/testbox.pub" ]] || fail "escribió con llaves duplicadas"
ssh-add -d "${TMP}/k3.pub" >/dev/null 2>&1

# allowed_signers sin salto de línea final: la entrada nueva no se pega a la anterior.
setup
printf 'otro@x namespaces="git" %s' "$(cut -d' ' -f1,2 "${TMP}/k2.pub")" >"${R}/ssh/.ssh/allowed_signers"
run >/dev/null
echo data >"${TMP}/data"
ssh-keygen -q -Y sign -f "${TMP}/k1" -n git "${TMP}/data"
principal="$(ssh-keygen -Y find-principals -s "${TMP}/data.sig" -f "${R}/ssh/.ssh/allowed_signers")"
[[ "${principal}" == "10409334+savaf@users.noreply.github.com" ]] || fail "find-principals: ${principal}"
[[ "$(wc -l <"${R}/ssh/.ssh/allowed_signers")" == 2 ]] || fail "allowed_signers sin 2 líneas"
rm -f "${TMP}/data" "${TMP}/data.sig"

# link_ssh_key: sin .pub solo avisa (nunca aborta el bootstrap, con o sin headless); con .pub enlaza.
link() { # corre link_ssh_key en un proceso aparte con HOME y ROOT_DIR falsos
  ROOT_DIR="${R}" HOME="${R}/home" REAL_ROOT="${REAL_ROOT}" bash -c '
    source "${REAL_ROOT}/scripts/lib/common.sh"
    source "${REAL_ROOT}/scripts/modules/stow.sh"
    link_ssh_key'
}
REAL_ROOT="${ROOT_DIR}"
setup
mkdir -p "${R}/home/.ssh"
link >/dev/null 2>&1 || fail "link_ssh_key falló sin .pub"
BOOTSTRAP_HEADLESS=1 link >/dev/null 2>&1 || fail "link_ssh_key falló en headless sin .pub"
[[ ! -e "${R}/home/.ssh/github.pub" && ! -L "${R}/home/.ssh/github.pub" ]] || fail "creó github.pub sin .pub"
echo "${KEY} savaf@testbox" >"${R}/ssh/.ssh/testbox.pub"
link >/dev/null
[[ "$(readlink "${R}/home/.ssh/github.pub")" == testbox.pub ]] || fail "no enlazó github.pub"

# Config versionada: Include de config.local primero, ejemplo VPS comentado, nunca ForwardAgent activo.
CONF="${REAL_ROOT}/ssh/.ssh/config"
[[ "$(grep -Eiv '^[[:space:]]*(#|$)' "${CONF}" | head -1)" == "Include ~/.ssh/config.local" ]] || fail "Include ~/.ssh/config.local no es la primera directiva"
grep -Eiq '^# *Host vps' "${CONF}" || fail "falta el ejemplo comentado del VPS"
if grep -Eiq '^[[:space:]]*ForwardAgent' "${CONF}"; then fail "ForwardAgent activo en config"; fi

echo "OK: ssh-add-host"
