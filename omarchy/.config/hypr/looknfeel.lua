-- Los TUIs flotantes (btop, bluetui, impala, wiremix, lazydocker...) tienen tamaño fijo en
-- píxeles: 875x600 por defecto en Omarchy (default/hypr/apps/system.lua). Con la fuente a
-- 16px la rejilla encogía a ~65x19; subimos el tamaño para recuperar ~80x24.
o.window({ tag = "floating-window" }, { size = { 1080, 760 } })

-- Workspace 1 de cada monitor flotante (muestra el dock); el resto sigue tiled con dwindle.
-- Omarchy numera los workspaces en bloques de diez por monitor (default/hypr/monitor-workspaces.lua):
-- el primero de cada monitor es 1, 11, 21. Se declaran los tres para no depender del estado local
-- ~/.local/state/omarchy/workspace-layouts/*.lua, que se carga después y puede repetir un id sin
-- conflicto (mismo modo). o.workspace_mode lo define workspace-modes.lua, que Omarchy solo carga
-- tras este archivo, así que se requiere aquí (el módulo queda en caché).
require("default.hypr.workspace-modes")
for _, id in ipairs({ "1", "11", "21" }) do
  o.workspace_mode({ workspace = id, mode = "floating" })
end

-- Ventana única cuadrada y centrada, solo en el ultrawide de ANDREA; el ThinkPad no la usa.
local hostname_file = io.open("/etc/hostname", "r")
local hostname = hostname_file and hostname_file:read("*l") or ""
if hostname_file then hostname_file:close() end
if hostname:lower() == "andrea" then
  hl.config({ layout = { single_window_aspect_ratio = { 1, 1 } } })
end
