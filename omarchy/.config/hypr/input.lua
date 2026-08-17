-- Layouts de teclado por dispositivo. Ver https://wiki.hypr.land/Configuring/Basics/Variables/#input
--
-- Omarchy carga este archivo después de default/hypr/input.lua, así que lo de aquí gana.

-- Layout global: US primero. Aplica al Keychron EN-US, al teclado virtual de fcitx5
-- (que es el `main`, contra el que Hyprland resuelve los keybinds) y a cualquier máquina
-- sin teclado LATAM físico. El segundo layout es lo que hace posible el toggle manual.
--
-- Hardcodeado a propósito: el default de Omarchy saca kb_layout de XKBLAYOUT en
-- /etc/vconsole.conf, que el instalador deja en `latam` y varía por instalación.
hl.config({
  input = {
    kb_layout = "us,latam",
    kb_variant = "",
    kb_options = "compose:caps,shift:both_capslock_cancel",
  },
})

-- Teclado físico del ThinkPad (Español LatAm) -> LATAM.
-- El name es el que reporta `hyprctl devices` (minúsculas, espacios -> guiones).
-- En máquinas sin este teclado (p.ej. ANDREA, el desktop) la regla no matchea y todo
-- cae en el default US de arriba, así el mismo archivo sirve para ambas PCs.
hl.device({
  name = "at-translated-set-2-keyboard",
  kb_layout = "latam,us",
  kb_options = "compose:caps,shift:both_capslock_cancel",
})

-- repeat_rate/repeat_delay, numlock_by_default, clickfinger_behavior, scroll_factor y los
-- scroll_touchpad por terminal ya vienen con estos mismos valores en los defaults de Omarchy.
