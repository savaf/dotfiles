-- Solo los deltas contra los bindings por defecto de Omarchy.
-- Ver los actuales con: omarchy menu keybindings --print

-- Typora en vez de Omawrite, que es lo que Omarchy pone en SUPER+SHIFT+W.
hl.unbind("SUPER + SHIFT + W")
o.bind("SUPER + SHIFT + W", "Typora", { launch = "typora --enable-wayland-ime" })

-- Alterna el layout (US <-> LATAM) del teclado que estás usando ahora mismo y avisa cuál quedó.
-- El auto-switch por dispositivo vive en input.lua; esto es el override manual.
-- SUPER+ALT+K es "Tmux keybindings" en Omarchy, hay que liberarlo primero.
-- El layout activo se lee del teclado `main` (el que Hyprland usa para resolver los binds).
hl.unbind("SUPER + ALT + K")
o.bind("SUPER + ALT + K", "Toggle keyboard layout", [[bash -c 'hyprctl switchxkblayout current next >/dev/null; omarchy-notification-send "Teclado: $(hyprctl devices -j | jq -r "first(.keyboards[] | select(.main)) | .active_keymap")"']])

-- Tmux keybindings, que dejó de tener atajo al reasignar SUPER+ALT+K.
o.bind("SUPER + ALT + SHIFT + K", "Tmux keybindings", "omarchy-menu-tmux-keybindings")

-- Modo térmico de los ventiladores: cicla auto → silencio → rendimiento → ultra (ver coolercontrol-mode).
o.bind("SUPER + ALT + T", "Fan mode cycle", "coolercontrol-mode cycle")
