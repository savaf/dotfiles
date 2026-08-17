-- Solo los deltas contra los bindings por defecto de Omarchy.
-- Ver los actuales con: omarchy menu keybindings --print

-- Typora en vez de Omawrite, que es lo que Omarchy pone en SUPER+SHIFT+W.
hl.unbind("SUPER + SHIFT + W")
o.bind("SUPER + SHIFT + W", "Typora", { launch = "typora --enable-wayland-ime" })

-- Alterna el layout (US <-> LATAM) del teclado que estás usando ahora mismo.
-- El auto-switch por dispositivo vive en input.lua; esto es el override manual.
-- SUPER+ALT+K es "Tmux keybindings" en Omarchy, hay que liberarlo primero.
hl.unbind("SUPER + ALT + K")
o.bind("SUPER + ALT + K", "Toggle keyboard layout", "hyprctl switchxkblayout current next")
