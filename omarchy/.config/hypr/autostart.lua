-- RGB al color del tema actual.
-- Ruta absoluta: hl.exec_cmd no garantiza expansión de `~`.
o.exec_on_start((os.getenv("HOME") or "") .. "/.config/omarchy/hooks/theme-set.d/openrgb")

-- Bitwarden al iniciar sesión. Se desactiva el inicio propio de la app (ver docs/omarchy.md §8).
o.launch_on_start("bitwarden-desktop")
