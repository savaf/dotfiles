#!/usr/bin/env bash
# Diagnostica la firma de commits y la auth SSH de esta máquina (agente de Bitwarden).
# Solo lectura: imprime ✓/✗ por chequeo, sugiere el arreglo (→) y sale ≠0 si algo falla.
#   ssh-doctor [--network]   --network añade `ssh -T git@github.com` (usa la red).
# Variables (para tests): SSH_DOCTOR_HOST (def. hostname -s), SSH_DOCTOR_EMAIL (def. user.email).
# Ver docs/git-and-ssh.md.
set -uo pipefail

network=0
case "${1:-}" in
  "") ;;
  --network) network=1 ;;
  *) echo "uso: ssh-doctor [--network]" >&2; exit 2 ;;
esac

host="${SSH_DOCTOR_HOST:-$(hostname -s)}"
email="${SSH_DOCTOR_EMAIL:-$(git config user.email 2>/dev/null)}"
bw_sock="${HOME}/.bitwarden-ssh-agent.sock"
pub="${HOME}/.ssh/${host}.pub"
signers="${HOME}/.ssh/allowed_signers"
failed=0

ok() { echo "✓ $1"; }
bad() { echo "✗ $1"; echo "  → $2"; failed=1; }

# 1. Socket de Bitwarden: existe y responde (ssh-add -l: 0 con llaves, 1 sin ellas, 2 error).
if [[ ! -S "${bw_sock}" ]]; then
  bad "Socket de Bitwarden (${bw_sock}) no existe" \
    "abre y desbloquea Bitwarden Desktop con el agente SSH activado (Settings → SSH agent)"
else
  SSH_AUTH_SOCK="${bw_sock}" ssh-add -l >/dev/null 2>&1
  if [[ $? -eq 2 ]]; then
    bad "Socket de Bitwarden (${bw_sock}) no responde" \
      "desbloquea el vault de Bitwarden; si persiste, reinicia bitwarden-desktop"
  else
    ok "Socket de Bitwarden responde"
  fi
fi

# 2. SSH_AUTH_SOCK apunta a ese socket.
if [[ "${SSH_AUTH_SOCK:-}" == "${bw_sock}" ]]; then
  ok "SSH_AUTH_SOCK correcto"
else
  bad "SSH_AUTH_SOCK es '${SSH_AUTH_SOCK:-}' (esperado ${bw_sock})" \
    "se define solo en ~/.config/uwsm/env: reejecuta el bootstrap y reinicia sesión; no lo redefinas en .zshrc"
fi

# 3. El .pub de este host existe.
if [[ -f "${pub}" ]]; then
  ok "${pub} existe"
else
  bad "${pub} no existe" \
    "exporta la llave pública de Bitwarden a ssh/.ssh/${host}.pub en el repo y reejecuta el bootstrap"
fi

# 4. Esa llave está cargada en el agente actual.
if [[ -f "${pub}" ]]; then
  blob="$(cut -d' ' -f1,2 "${pub}")"
  if ssh-add -L 2>/dev/null | cut -d' ' -f1,2 | grep -Fxq -- "${blob}"; then
    ok "La clave de ${host} está en el agente"
  else
    bad "La clave de ${host} está en el agente: no aparece en ssh-add -L" \
      "desbloquea Bitwarden y comprueba que la llave de ${host} existe en el vault y tiene el agente habilitado"
  fi
fi

# 5. Firma de prueba contra allowed_signers (en Bitwarden pide aprobación).
if [[ -f "${pub}" && -f "${signers}" && -n "${email}" ]]; then
  sig="$(mktemp)"
  trap 'rm -f "${sig}"' EXIT
  if printf 'ssh-doctor' | ssh-keygen -Y sign -f "${pub}" -n git >"${sig}" 2>/dev/null \
    && printf 'ssh-doctor' | ssh-keygen -Y verify -f "${signers}" -I "${email}" -n git -s "${sig}" >/dev/null 2>&1; then
    ok "Firma de prueba verificada con allowed_signers"
  else
    bad "Firma de prueba (sign/verify con allowed_signers) falló" \
      "aprueba la solicitud en Bitwarden y comprueba que ${signers} tiene la llave de ${host} con ${email}"
  fi
else
  bad "Firma de prueba omitida: falta ${pub##*/}, allowed_signers o user.email" \
    "arregla los chequeos anteriores; allowed_signers está en ssh/.ssh/ del repo"
fi

# 6. Auth real contra GitHub (red): solo con --network. GitHub responde con código 1.
if [[ ${network} -eq 1 ]]; then
  gh_out="$(ssh -T git@github.com 2>&1)"
  if [[ "${gh_out}" == *"successfully authenticated"* ]]; then
    ok "ssh -T git@github.com autentica"
  else
    bad "ssh -T git@github.com no autentica" \
      "registra la llave de ${host} en GitHub → Settings → SSH keys (Authentication) y revisa ssh/.ssh/config"
  fi
fi

exit "${failed}"
