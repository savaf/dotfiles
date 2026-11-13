# Puente del agente SSH de Bitwarden (Windows) hacia WSL. Solo en WSL; se carga
# desde zsh/bash. Requiere socat (apt) y npiperelay.exe (winget) en el PATH.
# Ver docs/git-and-ssh.md.
grep -qi microsoft /proc/version 2>/dev/null || return 0
command -v socat >/dev/null 2>&1 && command -v npiperelay.exe >/dev/null 2>&1 || return 0

export SSH_AUTH_SOCK="$HOME/.ssh/agent.sock"
# Si el socket no responde (primer shell o socat muerto), recréalo.
if ! ss -xl 2>/dev/null | grep -q "$SSH_AUTH_SOCK"; then
  rm -f "$SSH_AUTH_SOCK"
  (setsid socat "UNIX-LISTEN:$SSH_AUTH_SOCK,fork" \
    "EXEC:npiperelay.exe -ei -s //./pipe/openssh-ssh-agent,nofork" >/dev/null 2>&1 &)
fi
