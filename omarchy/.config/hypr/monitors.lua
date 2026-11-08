-- Ver https://wiki.hypr.land/Configuring/Basics/Monitors/
-- Lista de monitores y modos soportados: hyprctl monitors all
--
-- Mismo truco que el device{} de input.lua: Hyprland ignora las reglas de outputs que no
-- existen, así el mismo archivo sirve en la laptop y en el desktop.

hl.env("GDK_SCALE", "1")

-- Default: ThinkPad (eDP-1 1920x1200) y el monitor externo 1080p.
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })

-- Desktop ANDREA: Acer EI322QUR (2560x1440, 165 Hz). Su EDID marca 60 Hz como "preferred", así
-- que el modo va explícito. El desc tiene que ser completo (con el serial): con uno parcial
-- Hyprland perdió la salida y cayó a FALLBACK.
hl.monitor({ output = "desc:Acer Technologies EI322QUR TJBAA0033V01", mode = "2560x1440@165", position = "auto", scale = 1 })

-- Monitor secundario en vertical (transform: 1 = 90°, 3 = 270°).
-- hl.monitor({ output = "DP-2", mode = "preferred", position = "auto", scale = 1, transform = 1 })
