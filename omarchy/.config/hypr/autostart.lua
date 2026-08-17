-- RGB al color del tema actual.
-- Ruta absoluta: hl.exec_cmd no garantiza expansión de `~`.
o.exec_on_start((os.getenv("HOME") or "") .. "/.config/omarchy/hooks/theme-set.d/openrgb")
