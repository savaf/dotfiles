-- Los TUIs flotantes (btop, bluetui, impala, wiremix, lazydocker...) tienen tamaño fijo en
-- píxeles: 875x600 por defecto en Omarchy (default/hypr/apps/system.lua). Con la fuente a
-- 16px la rejilla encogía a ~65x19; subimos el tamaño para recuperar ~80x24.
o.window({ tag = "floating-window" }, { size = { 1080, 760 } })
