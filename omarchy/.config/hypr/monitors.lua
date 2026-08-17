-- Ver https://wiki.hypr.land/Configuring/Basics/Monitors/
-- Lista de monitores y modos soportados: hyprctl monitors all
--
-- Mismo truco que el device{} de input.lua: Hyprland ignora las reglas de outputs que no
-- existen, así el mismo archivo sirve en la laptop y en el desktop.

hl.env("GDK_SCALE", "1")

-- Default: ThinkPad (eDP-1 1920x1200) y el monitor externo 1080p.
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1.25 })

-- Desktop ANDREA: ultrawide Samsung C49RG9x (3840x1080) a 1x. Rellenar el output con lo que
-- reporte `hyprctl monitors all` en esa máquina (nombre de puerto o "desc:<description>").
-- hl.monitor({ output = "desc:...", mode = "preferred", position = "auto", scale = 1 })

-- Monitor secundario en vertical (transform: 1 = 90°, 3 = 270°).
-- hl.monitor({ output = "DP-2", mode = "preferred", position = "auto", scale = 1, transform = 1 })
