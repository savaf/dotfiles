#!/usr/bin/env bash
set -euo pipefail

# Prueba hypr/looknfeel.lua con stubs de `hl`/`o` (sin Hyprland): sintaxis, workspace 1 de cada
# bloque de monitor flotante, y ratio 1:1 solo cuando /etc/hostname es "andrea".
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FILE="${ROOT_DIR}/omarchy/.config/hypr/looknfeel.lua"

luac -p "${FILE}"

run() { # $1 hostname → imprime "modes=<ids> ratio=<r>"
  lua - "${FILE}" "$1" <<'LUA'
local file, host = arg[1], arg[2]
local modes, ratio = {}, "none"
o = {
  window = function() end,
  workspace_mode = function(spec) modes[#modes + 1] = spec.workspace .. ":" .. spec.mode end,
}
hl = { config = function(t)
  local r = t.layout and t.layout.single_window_aspect_ratio
  if r then ratio = r[1] .. ":" .. r[2] end
end }
package.loaded["default.hypr.workspace-modes"] = {}
local real_open = io.open
io.open = function(path, mode)
  if path == "/etc/hostname" then
    return { read = function() return host end, close = function() end }
  end
  return real_open(path, mode)
end
dofile(file)
print("modes=" .. table.concat(modes, ",") .. " ratio=" .. ratio)
LUA
}

fail=0
check() { # $1 hostname, $2 esperado
  local got
  got="$(run "$1")"
  if [[ "${got}" == "$2" ]]; then echo "ok  $1 → ${got}"; else echo "FAIL $1: got '${got}', want '$2'"; fail=1; fi
}

check andrea "modes=1:floating,11:floating,21:floating ratio=1:1"
check ANDREA "modes=1:floating,11:floating,21:floating ratio=1:1"
check songbird "modes=1:floating,11:floating,21:floating ratio=none"
exit "${fail}"
