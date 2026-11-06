-- RGB al color del tema actual.
-- Ruta absoluta: hl.exec_cmd no garantiza expansión de `~`.
o.exec_on_start((os.getenv("HOME") or "") .. "/.config/omarchy/hooks/theme-set.d/openrgb")

-- Marca por hostname: enlaza el About de esta máquina (idempotente; ver docs/omarchy.md).
o.exec_on_start((os.getenv("HOME") or "") .. "/.local/bin/branding-select")

-- Bitwarden al iniciar sesión: su agente SSH crea $HOME/.bitwarden-ssh-agent.sock (ver uwsm/env).
-- Se desactiva el inicio propio de la app para no duplicarlo (ver docs/omarchy.md §8).
o.launch_on_start("bitwarden-desktop")
