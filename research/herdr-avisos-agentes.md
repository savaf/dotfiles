# herdr: avisos de estado de agentes en el escritorio (Omarchy)

Fecha: 2026-11-01. herdr instalado: 0.9.1 (cliente y servidor, protocolo 22). Última estable: 0.9.5.
Las docs web (`llms.txt`) apuntan a v0.9.5; donde importa se indica si se verificó en el binario 0.9.1.

## Resumen

- herdr **ya calcula** el estado de cada agente (`idle`, `working`, `blocked`, `done`, `unknown`) sin ayuda del hook de Claude. El hook v10 solo envía el id de sesión; el estado sale de leer la terminal.
- Lo más barato: activar `[ui.toast] delivery = "system"` (y opcionalmente `delay_seconds`). Eso hace que herdr llame a `notify-send` y Omarchy lo muestra con su propio demonio de notificaciones. **Funciona con el hook actual, sin cambios en Claude Code.**
- Para algo que herdr no hace solo (urgencia de ventana, indicador en la barra), la pieza correcta es un proceso que se suscriba a `pane.agent_status_changed` por el socket, o un plugin de herdr con `[[events]]`. Tampoco requiere hooks de Claude.
- Un hook `Notification`/`Stop` de Claude Code solo hace falta si se quiere texto propio del evento (por ejemplo, el mensaje exacto de la pregunta de Claude), no para saber *que* hay que avisar.

## 1. Cómo expone herdr el estado

Verificado con `herdr agent list` (0.9.1) y la API de socket.

- Cada agente tiene `agent_status` (`working`, `idle`, ...), `pane_id`, `workspace_id`, `tab_id`, `state_change_seq`, `revision`, `terminal_title`, `agent_session`. Ejemplo real: 5 paneles de Claude, uno `working` y cuatro `idle`.
- Significado (`herdr --skill`): `idle` y `done` = listo para recibir input; `done` es "idle y aún no visto". `blocked` = herdr reconoció una UI de aprobación o pregunta. `unknown` = hay agente pero no se puede clasificar; no implica terminado.
- El estado de Claude lo detecta herdr por la pantalla de la terminal. Confirma `docs/herdr.md` ("herdr reads idle/working/blocked/done from the terminal itself") y el hook v10, que sale con `exit 0` salvo en `SessionStart`.
- Superficies de consumo:
  - Poll: `herdr agent list` / `herdr agent get <t>` (JSON).
  - Espera puntual: `herdr agent wait <target> [--until idle|working|blocked|done|unknown]... [--timeout MS]`. Sin `--until` espera `idle`, `done` o `blocked`; devuelve de inmediato si ya coincide.
  - Stream: método de socket `events.subscribe` con evento `pane.agent_status_changed` y filtros opcionales `pane_id` y `agent_status`. Presente en `herdr api schema --json` de 0.9.1 (`events.subscribe`, `events.wait`, `agent.wait`, `pane.agent_status_changed`). Sin replay; un suscriptor lento recibe `events_lost` y se cierra la conexión: hay que resuscribir y leer `session.snapshot`.

Fuentes: `herdr --skill`, `herdr agent --help`, `herdr api schema`, https://herdr.dev/docs/socket-api/, https://herdr.dev/docs/cli-reference/ (equivalente en v0.9.5).

## 2. Notificaciones propias de herdr

### 2.1 Toasts (`[ui.toast]`)

Config por defecto (`herdr --default-config`): `delivery = "off"`. Es decir, **hoy no hay ningún popup**: `herdr/.config/herdr/config.toml` no define `[ui.toast]`.

| `delivery` | Efecto |
|---|---|
| `off` | sin popups (actual) |
| `herdr` | toast dentro de la TUI (`[ui.toast.herdr] position`, por defecto `bottom-right`) |
| `terminal` | pide a la terminal exterior una notificación de escritorio (útil por SSH) |
| `system` | pide al servicio de notificaciones del SO directamente |

- Se avisa cuando un agente en segundo plano **termina** o **necesita input** (`blocked`); no se avisa de la pestaña activa.
- `delay_seconds` (0 a 3600, por defecto 1): herdr avisa solo si el panel sigue en el mismo estado al vencer el retraso. Sirve para filtrar parpadeos `working`/`idle`.
- **Linux, `system`**: la doc no lo cubre (solo detalla macOS y Windows). Se verificó en el binario 0.9.1: contiene la cadena `notify-send` junto a `--app-name` y `Herdr`. Conclusión: en Linux `system` ejecuta `notify-send --app-name Herdr ...`. `notify-send` está en `/usr/bin/notify-send`. Falta confirmar de forma empírica con un cambio de estado real; esta investigación no tocó la config ni el servidor.
- `herdr notification show <TITLE> [--body T] [--position ...] [--sound none|done|request]` usa el mismo `delivery` configurado. Sirve para probar el canal sin esperar a un agente (`--sound` por defecto `none`). Con `delivery = "off"` no muestra nada.
- `keys.open_notification_target` (por defecto `prefix+o`): enfoca el destino de la notificación visible. Las notificaciones de sistema en Linux no tienen click-to-focus documentado (la doc lo describe para macOS y Windows).

### 2.2 Sonido (`[ui.sound]`)

- `enabled = true` por defecto: ya suena al cambiar el estado de agentes en workspaces en segundo plano. El sonido lo reproduce el cliente local; el binario referencia `paplay`, `pw-play`, `ffplay`, `mpg123` y `mpv`. `HERDR_DISABLE_SOUND` lo apaga.
- Se puede personalizar con mp3 (`path`, `done_path`, `request_path`) y por agente (`[ui.sound.agents] claude = "on"|"off"`).
- El sonido es independiente de `ui.toast.delivery`. Con `herdr notification show --sound done|request` solo suena si la notificación se muestra.

### 2.3 Indicadores visibles dentro de herdr

- Barra lateral: ya muestra un punto de color por agente (`status_indicators = "dots"`). Opciones: `status_indicators = "symbols"` (formas distintas por estado), `agent_panel_sort = "priority"` (cola de atención en lugar de agrupar por workspace; la doc no detalla el criterio) y plantillas `[ui.sidebar.agents] rows = [[...]]` con `state_icon`, `state_text`, etc.
- Barra de pestañas: `tab_bar_right` solo admite `zoom`, `hostname`, `datetime`, `text` y `command`. No hay un indicador de estado de agentes nativo. Un `command` (corre en el servidor) podría imprimir un resumen con `herdr agent list | jq`; no se probó y la frecuencia de refresco no está documentada.
- `window_title` ya está en la config (`{hostname}: {workspace}`). Admite `{tab}`, `{pane}`, `{terminal_title}`, pero no un token de estado de agente. No sirve para señalar estado.

## 3. Lado Omarchy / Hyprland

Hallazgos de la máquina (solo lectura):

- **No hay mako ni waybar.** Omarchy actual usa su propia shell en Quickshell: `makoctl`, `mako` y `waybar` no existen, y `~/.config/mako` no existe. El demonio de notificaciones es el plugin `omarchy.notifications` (`/usr/share/omarchy/shell/plugins/notifications/`), basado en `Quickshell.Services.Notifications`: implementa la interfaz estándar de freedesktop, así que `notify-send` funciona. Tiene DND e historial (`~/.local/state/omarchy/notifications/`). Los toasts aparecen siempre arriba a la derecha.
- La barra es `omarchy.bar`, configurada en `~/.config/omarchy/shell.json` (enlazado a `omarchy/.config/omarchy/shell.json` en este repo). Widgets: `omarchy.workspaces`, `omarchy.indicators`, `omarchy.agents`, etc.
- El widget `omarchy.agents` ya está en la barra, pero **no sirve para esto**: muestra límites de uso y tokens de Claude/Codex, no el estado de herdr.
- `omarchy.workspaces` e `omarchy.indicators`: no se encontró nada sobre urgencia de ventanas (`grep urgent` sin resultados en los widgets). No hay indicador de urgencia hecho.
- Hyprland expone el evento `urgent>>ADDRESS` por su socket2; la urgencia de ventana la dispara el cliente (xdg-activation o un `BEL` según la terminal). Esto es conocimiento general de Hyprland, **no verificado aquí**: no se probó si herdr reenvía `BEL` a la terminal exterior al cambiar de estado, ni cómo reacciona la terminal usada (hay config de alacritty, foot, kitty y ghostty; kitty tiene `enable_audio_bell no`). Tratar como hipótesis.
- Omarchy ofrece ganchos de usuario (`~/.config/omarchy/hooks/*.d`), pero son para eventos de Omarchy (tema, fuente, batería), no de agentes.

## 4. Qué funciona con el hook actual (v10) y qué necesita algo extra

| Opción | Esfuerzo | ¿Con el hook v10 tal cual? | Qué hace falta |
|---|---|---|---|
| A. Toast de escritorio vía herdr (`delivery = "system"`) | 2 líneas en `config.toml` | Sí | Nada más. `prefix q` recarga la config. Verificar que sale por Omarchy |
| B. Toast dentro de herdr (`delivery = "herdr"`) | 1 línea | Sí | Solo se ve si herdr está visible en pantalla |
| C. Sonido | ya activo | Sí | Ajustar `[ui.sound]`; comprobar que hay `paplay` o `pw-play` |
| D. Sidebar más legible (`symbols`, `priority`) | 2 líneas | Sí | Nada |
| E. Watcher propio (script suscrito a `pane.agent_status_changed` con `agent_status = blocked`/`done`) que llame a `notify-send -u critical` o a `hyprctl` | Medio: un script y arranque en `autostart.lua` | Sí (usa el estado de herdr, no de Claude) | Cliente de socket (python3, como el hook) o bucle con `herdr agent wait`; manejar `events_lost` y reconexión |
| F. Plugin de herdr con `[[events]] on = "pane.agent_status_changed"` | Medio | Probablemente sí | La doc de plugins no lista los nombres de evento (solo muestra `worktree.created` y `startup`); probar en 0.9.1. Los hooks reciben `HERDR_PLUGIN_EVENT_JSON` |
| G. `herdr agent wait` en un script de un solo disparo | Bajo | Sí | Solo cubre el siguiente cambio de un agente concreto; útil dentro de `horde`, no como aviso global |
| H. Urgencia de ventana en Hyprland | Alto o incierto | No determinado | Depende de que la terminal marque urgencia con `BEL`; hay que comprobar si herdr lo propaga. Alternativa: el watcher (E) y `hyprctl` |
| I. Indicador en la barra de Omarchy (clon de widget) | Alto | Sí (si se alimenta de E) | Clonar un widget con `omarchy plugin clone` y leer un archivo de estado que escriba el watcher |
| J. Hooks `Notification`/`Stop` de Claude Code | Medio | No: requiere registrar hooks nuevos en `~/.claude/settings.json` | Solo si se quiere el texto exacto del aviso (p. ej. "Claude necesita permiso para X"). Duplicaría el aviso de herdr; `docs/herdr.md` pide no tocar `settings.json` con `herdr integration install` |

Detalles:

- Con A, el aviso lo emite herdr con título propio (no documentado); no incluye el cuerpo del mensaje de Claude.
- `herdr agent wait` y `events.subscribe` no necesitan hook: leen el estado ya calculado.
- El hook v10 sirve solo para guardar el id de sesión y permitir `resume_agents_on_restore`. Subirlo a una versión con más eventos no es necesario para avisar.

## 5. Recomendación

1. Primero A: añadir a `herdr/.config/herdr/config.toml` un bloque `[ui.toast]` con `delivery = "system"` y `delay_seconds` de 2 a 5 para evitar avisos de ráfagas cortas. Probar con `herdr notification show "prueba" --body "ok"` desde un panel de herdr. Si el popup sale arriba a la derecha en Omarchy, el canal está verificado.
2. Si el aviso llega pero se pierde (herdr en otro workspace de Hyprland), considerar D y, si hace falta más, E.
3. Dejar J fuera salvo que se necesite el texto de la pregunta de Claude.

## 6. Incertidumbres

- La ruta `system` en Linux se infirió de cadenas del binario (`notify-send`), no de documentación ni de una ejecución real.
- herdr "suprime popups para la pestaña activa", pero no sabe qué workspace de Hyprland está visible; no está documentado cómo se comporta si herdr está en un workspace de Hyprland oculto.
- La lista oficial de eventos para `[[events]]` de plugins no se pudo confirmar; los nombres de evento sí están documentados para el socket.
- No se comprobó propagación de `BEL` ni urgencia de ventana.
- Notas de versión 0.9.2 a 0.9.5: ninguna cambia `ui.toast`. v0.9.2 evita falsos avisos de "done" al arrancar o restaurar sesiones; v0.9.5 hace que las preguntas de Claude en sesiones con nombre cuenten como `blocked` (relevante para `horde`). Actualizar de 0.9.1 a 0.9.5 aporta esas dos mejoras.

## Fuentes

- `herdr --help`, `herdr agent --help`, `herdr agent wait --help`, `herdr notification show --help`, `herdr --skill`, `herdr --default-config`, `herdr api schema --json`, `herdr plugin list`, `herdr agent list` (todo 0.9.1, lectura).
- https://herdr.dev/llms.txt y las páginas que enlaza (v0.9.5): configuration, cli-reference, plugins; https://herdr.dev/docs/socket-api/; https://herdr.dev/docs/config-reference/.
- Notas de versión v0.9.2 a v0.9.5 de `herdrdev/herdr` (`gh release view`).
- `docs/herdr.md`, `herdr/.config/herdr/config.toml`, `claude/.claude/hooks/herdr-agent-state.sh` (rama `main`).
- Omarchy: `/usr/share/omarchy/shell/plugins/notifications/`, `/usr/share/omarchy/shell/plugins/agents/README.md`, `/usr/share/omarchy/shell/plugins/bar/README.md`, `~/.config/omarchy/shell.json`.
