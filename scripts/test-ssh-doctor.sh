#!/usr/bin/env bash
set -euo pipefail

# Tests de scripts/ssh-doctor.sh y de link_host_conf (scripts/modules/stow.sh) por
# comportamiento externo. Todo en un HOME temporal con un ssh-agent efímero y una clave
# desechable: nunca toca el HOME, el agente ni la red reales. Sin frameworks.
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO="${ROOT_DIR}"
DOCTOR="${REPO}/scripts/ssh-doctor.sh"
TMP="$(mktemp -d)"
AGENT_PIDS=()
cleanup() {
  for p in ${AGENT_PIDS[@]+"${AGENT_PIDS[@]}"}; do kill "${p}" 2>/dev/null || true; done
  rm -rf "${TMP}"
}
trap cleanup EXIT

fail() { echo "FAIL: $*"; exit 1; }

HOST="testhost"
EMAIL="test@example.invalid"

start_agent() { # $1 socket; deja el pid en AGENT_PIDS
  local out
  out="$(ssh-agent -a "$1" -s)"
  LAST_PID="$(sed -n 's/^SSH_AGENT_PID=\([0-9]*\);.*/\1/p' <<<"${out}")"
  AGENT_PIDS+=("${LAST_PID}")
}

# Entorno nuevo: HOME falso con la clave de este host, allowed_signers y un agente que la
# tiene cargada en el socket que ssh-doctor espera ($HOME/.bitwarden-ssh-agent.sock).
N=0
setup() {
  N=$((N + 1))
  H="${TMP}/h${N}"
  mkdir -p "${H}/.ssh"
  ssh-keygen -q -t ed25519 -N '' -C "${HOST}" -f "${H}/key"
  mv "${H}/key.pub" "${H}/.ssh/${HOST}.pub"
  echo "${EMAIL} namespaces=\"git\" $(cut -d' ' -f1,2 "${H}/.ssh/${HOST}.pub")" >"${H}/.ssh/allowed_signers"
  printf '[user]\n\tsigningkey = ~/.ssh/%s.pub\n' "${HOST}" >"${H}/.gitconfig"
  SOCK="${H}/.bitwarden-ssh-agent.sock"
  start_agent "${SOCK}"
  SSH_AUTH_SOCK="${SOCK}" ssh-add -q "${H}/key"
  AUTH_SOCK="${SOCK}"
}

doctor() { # args extra; deja salida en OUT y código en RC
  RC=0
  OUT="$(HOME="${H}" SSH_AUTH_SOCK="${AUTH_SOCK}" SSH_DOCTOR_HOST="${HOST}" \
    SSH_DOCTOR_EMAIL="${DOCTOR_EMAIL-${EMAIL}}" GIT_CONFIG_GLOBAL="${H}/.gitconfig" PATH="${STUBS:+${STUBS}:}${PATH}" bash "${DOCTOR}" "$@" 2>&1)" || RC=$?
}

expect() { # $1 descripción  $2 código esperado  $3 fragmento esperado en la salida
  [[ "${RC}" -eq "$2" ]] || fail "$1: código ${RC}, esperado $2:
${OUT}"
  [[ "${OUT}" == *"$3"* ]] || fail "$1: falta '$3' en:
${OUT}"
}

STUBS=""

# --- ssh-doctor ---------------------------------------------------------------------
setup
doctor
expect "todo bien" 0 "✓"
[[ "${OUT}" != *"✗"* ]] || fail "todo bien: hay ✗:
${OUT}"

setup; AUTH_SOCK="${TMP}/otro.sock"
doctor
expect "SSH_AUTH_SOCK incorrecto" 1 "✗ SSH_AUTH_SOCK"

setup; SSH_AUTH_SOCK="${SOCK}" ssh-add -q -D
doctor
expect "clave fuera del agente" 1 "✗ La clave de ${HOST} no está en el agente"

setup; rm "${H}/.ssh/${HOST}.pub"
doctor
expect ".pub ausente" 1 "✗ ${H}/.ssh/${HOST}.pub"

setup
ssh-keygen -q -t ed25519 -N '' -f "${H}/otra"
echo "${EMAIL} namespaces=\"git\" $(cut -d' ' -f1,2 "${H}/otra.pub")" >"${H}/.ssh/allowed_signers"
doctor
expect "allowed_signers sin la clave" 1 "✗ Firma de prueba"

setup; kill "${LAST_PID}"; sleep 0.2; rm -f "${SOCK}"
doctor
expect "sin agente" 1 "✗ Socket de Bitwarden"
[[ "${OUT}" == *"→"* ]] || fail "sin agente: no sugiere arreglo:
${OUT}"

# Socket presente pero muerto (ssh-add sale 2): agente matado con -9 deja el archivo.
setup; kill -9 "${LAST_PID}"; sleep 0.2
doctor
expect "socket que no responde" 1 "✗ Socket de Bitwarden"
[[ "${OUT}" == *"no responde"* ]] || fail "socket muerto: mensaje distinto de 'no responde':
${OUT}"

setup; printf '[user]\n\tsigningkey = ~/.ssh/otro.pub\n' >"${H}/.gitconfig"
doctor
expect "signingkey de otro host" 1 "✗ user.signingkey"
[[ "${OUT}" == *"reejecuta el bootstrap"* ]] || fail "signingkey: sin sugerencia:
${OUT}"

setup; : >"${H}/.gitconfig"
doctor
expect "sin signingkey" 1 "✗ user.signingkey"

setup; DOCTOR_EMAIL="" doctor
expect "user.email vacío" 1 "✗ Firma de prueba omitida"

# --network: ssh stub (nunca la red real). GitHub responde con código 1 al autenticar.
STUBS="${TMP}/stubs"; mkdir -p "${STUBS}"
cat >"${STUBS}/ssh" <<STUB
#!/usr/bin/env bash
echo called >>"${TMP}/ssh-called"
echo "Hi test! You've successfully authenticated, but GitHub does not provide shell access." >&2
exit 1
STUB
chmod +x "${STUBS}/ssh"

setup; doctor
[[ ! -e "${TMP}/ssh-called" ]] || fail "sin --network no debe invocar ssh"
setup; doctor --network
expect "--network ok" 0 "✓ ssh -T git@github.com"
[[ -e "${TMP}/ssh-called" ]] || fail "--network no invocó ssh"
printf '#!/usr/bin/env bash\necho "Permission denied (publickey)." >&2\nexit 255\n' >"${STUBS}/ssh"
setup; doctor --network
expect "--network falla" 1 "✗ ssh -T git@github.com"
STUBS=""
echo "OK: ssh-doctor"

# --- link_host_conf: git elige la llave por host sin symlink github.pub ---------------
H="${TMP}/hb"; R="${TMP}/repo"
mkdir -p "${H}/.ssh" "${R}/ssh/.ssh"
ln -s ancient.pub "${H}/.ssh/github.pub"   # residuo de la versión anterior
host="$(hostname -s)"
TILDE="~"   # git guarda la ruta con "~" literal (no se expande); por eso no es $HOME
log() { :; }
HOME="${H}" ROOT_DIR="${R}"
# shellcheck source=modules/stow.sh
source "${REPO}/scripts/modules/stow.sh"

mkdir -p "${H}/.config/git"; echo stale >"${H}/.config/git/host.conf"   # host.conf viejo
link_host_conf
[[ ! -e "${H}/.config/git/host.conf" ]] || fail "host.conf sin .pub en el repo (o viejo sin borrar)"

touch "${R}/ssh/.ssh/${host}.pub"
link_host_conf; link_host_conf   # idempotente
[[ "$(git config --file "${H}/.config/git/host.conf" user.signingkey)" == "${TILDE}/.ssh/${host}.pub" ]] \
  || fail "host.conf sin signingkey de ${host}"
[[ ! -L "${H}/.ssh/github.pub" ]] || fail "github.pub residual no se limpió"

# El .gitconfig versionado incluye host.conf y de él sale la llave efectiva.
GITCONFIG="${REPO}/git/.gitconfig"
[[ "$(git config --file "${GITCONFIG}" --get-all include.path)" == "${TILDE}/.config/git/host.conf" ]] \
  || fail "git/.gitconfig no incluye ~/.config/git/host.conf"
! git config --file "${GITCONFIG}" --get user.signingkey >/dev/null \
  || fail "git/.gitconfig aún fija user.signingkey"
[[ "$(HOME="${H}" GIT_CONFIG_GLOBAL="${GITCONFIG}" git config --global --includes user.signingkey)" == "${TILDE}/.ssh/${host}.pub" ]] \
  || fail "signingkey efectiva no sale de host.conf"
echo "OK: link_host_conf"
