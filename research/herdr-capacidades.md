# herdr 0.9.x: qué ofrece y no usamos

Fecha: 2026-11-01. Base: `main` (450692f). Binario instalado: **0.9.1** en `~/.local/bin/herdr`
(instalado por el script oficial, así que `herdr update` funciona). Canal: `stable`.

## Resumen

- Estable actual: **0.9.5** (14-oct-2026). Estamos 4 versiones atrás (0.9.2, 0.9.3, 0.9.4, 0.9.5).
- Canal `preview`: el último build (`preview-2026-10-14-fbd2ae23927f`) va **por detrás** de `v0.9.5`
  (la API de GitHub da `status: behind, ahead_by: 0, behind_by: 2`). Hoy preview no aporta nada que
  stable no tenga.
- Lo más prometedor sin usar: `agent prompt --wait` y `agent explain` en horde, `notification show`
  junto con `[ui.toast] delivery` para avisar de builders bloqueados, `[worktrees] directory`,
  `[[keys.command]]` tipo popup (lazygit) y `workspace report-metadata` para mostrar progreso en la
  barra lateral. Detalle y veredicto por destino más abajo.
- Nada de esto se probó ejecutándolo: solo se leyó `--help`, `--default-config`, `--skill` y la
  documentación. No se tocó la config ni el servidor.

Leyenda de aplicabilidad: **Sí** = encaja claramente; **Quizá** = depende de una decisión tuya;
**No** = no aplica hoy. Destinos: (a) `herdr/.config/herdr/config.toml`, (b) `hw` en
`zsh/.config/zsh/functions.zsh`, (c) `scripts/modules/herdr.sh`, (d) skills `horde` e `idea-to-prs`.

## Estado actual en `main` (lo que ya usamos)

- (a) Config: `[theme]` terminal, `[terminal] new_cwd = "follow"`, `[keys]` completo con prefijo
  `ctrl+space`, `[ui]` con `accent`, `pane_gaps`, `pane_outer_borders`, `pane_scrollbars`,
  `confirm_close`, `prompt_new_tab_name`, `mouse_capture`, `tab_bar_right`, `window_title`.
  `onboarding = false`.
- (b) `hw`: `workspace list/create/focus`, `tab create/rename`, `pane run`. Un workspace por
  proyecto, una tab por repo, `claude` en cada panel.
- (c) `herdr.sh`: solo instala si falta (`exists herdr && return 0`) con `curl ... install.sh | sh`.
- (d) `horde` (en `main` tiene modo batch y modo solo): `worktree create`/`remove`, `agent start`,
  `agent prompt`, `agent wait`, `agent get`, `agent list`, `agent read`, `pane split`, `pane close`,
  `status`. `idea-to-prs` solo menciona `herdr worktree create --cwd <repo>` y la exclusión de
  `.claude/worktrees/`.
- Hook de Claude en integración v10, `herdr integration status` dice `claude: current`.

## Changelog reciente (0.9.0 a 0.9.5)

Fuente: notas de release en GitHub (`herdrdev/herdr`) y `https://herdr.dev/latest.json`.

| Versión | Fecha | Cambios que nos tocan |
|---|---|---|
| 0.9.0 | 2026-09-07 | Máquinas SSH guardadas en una misma ventana (`herdr machine`). Varios clientes ven workspaces/tabs distintos. `ui.pane_borders = "always"`. Temas con overrides claro/oscuro. `workspace close --group` obligatorio para cerrar un workspace primario con worktrees abiertos. `--trust-repository` en comandos de worktree. `agent prompt --wait` exige actividad observada (`agent_prompt_stalled` a los 5 s). Estado de Claude Code: bloqueado en preguntas MCP y aprobaciones Bash. |
| 0.9.1 | 2026-09-16 | `herdr --machine <label>` reenvía comandos de API a una máquina guardada. Edición de texto con cursor en inputs. Reglas `hide = true` en tokens de la barra lateral. |
| 0.9.2 | 2026-09-29 | Agentes pueden reportar su propio comando de reanudación. **`prefix` acepta lista** (`["ctrl+space", "ctrl+s"]`). Go To lista agentes y terminales. **`keys.clear_pane`**. `machine status` / `machine reconnect`. `machine add` detecta sesiones. `[session] startup_per_agent_delay_ms` (agentes restaurados de uno en uno, 100 ms). |
| 0.9.3 | 2026-09-29 | Hotfix de 0.9.2. |
| 0.9.4 | 2026-10-13 | `herdr plugin update`. En Linux/macOS el servidor **ignora SIGHUP** (cerrar el shell que lo lanzó ya no lo para; usar `herdr server stop`). Guardado de sesión antes de apagar (en Linux con systemd-logind). Sesión guardada con escritura atómica. Primer turno de un agente cuenta como `done` aunque arrancara con prompt. Nuevos paneles ponen `TERM_PROGRAM=herdr` y no heredan marcadores de sesión de Claude Code. `worktree open` ya no se apodera del workspace del repo. Tras `herdr update` lista los servidores aún en la versión vieja. |
| 0.9.5 | 2026-10-14 | Hotfix: atajos con prefijo funcionan con IME/Ghostty `text:`. **Preguntas de Claude Code se ven como `blocked` en sesiones con nombre.** Codex deja de instalar hooks de turno. |

Pendiente por actualizar: con 0.9.1 instalado no tenemos `prefix` en lista, `clear_pane`, el
espaciado de restauración ni los arreglos de 0.9.4 (SIGHUP, guardado al apagar, TERM_PROGRAM).
`herdr update` es la acción; ver sección de `update --handoff`.

## Opciones de `config.toml`

Fuente: `herdr --default-config` del binario instalado (0.9.1) y la lista de claves del 0.9.5
(`config-reference.json`, mismo repo). Solo se listan las que no usamos y tienen algún efecto
posible. Todas las demás ya están en la config o son valores por defecto aceptables.

### `[ui.toast]` y `[ui.sound]`: notificaciones (aplica a a y d)

- `ui.toast.delivery`: `off` (por defecto), `herdr`, `terminal` o `system`. Con `off` **no hay
  ningún aviso** cuando un agente de otro workspace termina o se bloquea. `system` usa el servicio
  de notificaciones del SO; en Omarchy sería el daemon de escritorio. `delay_seconds`,
  `[ui.toast.herdr] position`, `[ui.toast.clipboard]`.
- `ui.sound.enabled`, `path`, `done_path`, `request_path`, `[ui.sound.agents]`.
- Veredicto (a): **Sí**. Es la pieza que falta para que `notification show` y los agentes en
  segundo plano de `horde` avisen sin mirar la pantalla. Decisión tuya: `herdr` (toast dentro de la
  app) o `system` (escritorio).

### `[worktrees] directory` (aplica a a y d)

- Por defecto `~/.herdr/worktrees` y el checkout va en `<directory>/<repo>/<branch-slug>`.
- `idea-to-prs` excluye `.claude/worktrees/` en `.git/info/exclude`, pero los worktrees de herdr no
  caen ahí. Esa exclusión cubre los worktrees propios de Claude Code, no los de herdr. Conviene
  confirmar por qué está en el skill antes de quitarla.
- Veredicto (a): **Quizá**. Dejar el valor por defecto es seguro; cambiarlo solo si quieres los
  checkouts bajo `~/Projects` o similar.

### `[[keys.command]]`: atajos que ejecutan comandos (aplica a a)

- `type = "popup"` abre una terminal modal con `width`/`height` (ejemplo de la propia config por
  defecto: lazygit en `prefix+alt+g`, 80 %). También `type = "pane"` y `type = "shell"`.
- Tenemos `docs/lazygit.md`. Veredicto (a): **Sí** si usas lazygit dentro de herdr.

### Atajos de agentes y navegación sin configurar (aplica a a)

- `next_agent`, `previous_agent`, `focus_agent = "prefix+alt+1..9"`, `goto` (`prefix+g`),
  `workspace_picker` (`prefix+w`), `open_notification_target` (`prefix+o`), `edit_scrollback`
  (`prefix+e`), `toggle_sidebar` (`prefix+b`), `clear_pane` (solo >= 0.9.2), `new_worktree`
  (`prefix+shift+g`), `open_worktree`, `remove_worktree`. Los de `prefix+...` ya están activos por
  defecto salvo los que tu config sobreescribe. Tu config reasigna varios (`prefix+k` es `close_tab`, `prefix+q` es `reload_config`).
- Veredicto (a): **Quizá**. `next_agent`/`previous_agent` o `focus_agent` ayudan a saltar entre
  builders de `horde`. `clear_pane` requiere 0.9.5.

### `[ui.sidebar.agents]` y `[ui.sidebar.spaces]`: filas de la barra lateral (aplica a a y d)

- `rows`, `rows_by_agent`, `row_gap`. Tokens integrados: `state_icon`, `state_text`, `machine`,
  `workspace`, `tab`, `pane`, `agent`, `terminal_title`, `terminal_title_stripped`; en spaces
  también `branch`, `git_status`. Tokens propios con `$nombre` (se rellenan con
  `report-metadata`, ver más abajo). Estilo por token (`fg`, `bold`, `dim`, `hide`).
- Veredicto (a): **Quizá**; necesario solo si quieres mostrar metadatos propios.

### `[ui]` varias (aplica a a)

- `status_indicators = "symbols"` (glifos distintos en lugar de puntos de color), `agent_panel_sort
  = "priority"` (cola de atención en lugar de agrupar por workspace),
  `show_agent_labels_on_pane_borders`, `hide_tab_bar_when_single_tab`, `tab_bar_position`,
  `sidebar_start_collapsed`, `sidebar_collapsed_mode`, `copy_on_select`, `host_cursor`
  (en WSL dibuja el cursor propio), `redraw_on_focus_gained`, `mouse_scroll_lines`,
  `right_click_passthrough_modifier`, `pane_borders` (`auto`/`always`/`off`).
- Veredicto (a): **Quizá**. `agent_panel_sort = "priority"` es el que más encaja con varios
  builders en paralelo. `hide_tab_bar_when_single_tab` aplica a `dotfiles` y `SlipStream`
  (una sola tab), no a `CNC`.

### `[session]` y `[experimental]` (aplica a a)

- `session.resume_agents_on_restore` (por defecto `true`) y, desde 0.9.2,
  `session.startup_per_agent_delay_ms`. Con el hook v10 de Claude ya se reanuda la conversación
  tras reiniciar el servidor (requisito: integración >= v6 para Claude Code). Nada que cambiar.
- `experimental.pane_history = false`: guarda el contenido reciente de pantalla entre reinicios
  completos. Puede guardar secretos; dejar apagado.
- `experimental.allow_nested`: permite lanzar herdr dentro de un panel. No hace falta.
- Veredicto: **No** (el valor por defecto de `resume_agents_on_restore` ya hace lo que queremos).

### `[update]`, `[server]`, `[remote]`, `[advanced]` (aplica a a y c)

- `update.channel` (`stable`/`preview`), `version_check`, `manifest_check`. Mismo efecto que
  `herdr channel set`.
- `server.headless_cols/rows`: tamaño del terminal virtual sin cliente. Podría importar si los
  builders imprimen líneas largas mientras no hay cliente adjunto.
- `remote.manage_ssh_config`: solo con `--remote`.
- `advanced.scrollback_limit_bytes`: 10 MB por panel por defecto.
- Veredicto: **No** salvo que adoptes `preview` o máquinas remotas.

### `[theme]` (aplica a a)

- `auto_switch`, `dark_name`, `light_name` y `[theme.custom.light|dark]`: seguir el modo
  claro/oscuro del terminal. Veredicto (a): **No** mientras uses `name = "terminal"`, que ya hereda
  la paleta.

## `herdr worktree`

`list`, `create`, `open`, `remove` (`herdr worktree create [--workspace ID | --cwd PATH] [--branch]
[--base] [--path] [--label] [--focus|--no-focus] [--trust-repository]`). Un worktree es un
workspace normal con procedencia Git, agrupado bajo el workspace del repo padre. Si `--branch` ya
existe se hace checkout; si no, se crea desde `--base` o `HEAD`. `workspace close` solo cierra el
estado de herdr; `worktree remove` ejecuta `git worktree remove` y nunca borra la rama.

- (a) Quizá: `[worktrees] directory`, `new_worktree`/`open_worktree`/`remove_worktree`.
- (b) No: `hw` no usa worktrees.
- (c) No.
- (d) `create` y `remove` ya se usan en `horde` (batch). **Sí** para estas tres:
  1. `worktree open --branch <rama>` para la reanudación por feedback de PR que `batch.md` hoy
     resuelve con "un builder nuevo en una ronda nueva": abre el checkout existente en vez de
     recrearlo.
  2. `worktree list --workspace <id>` para recuperar ids de workspace/panel tras perder contexto.
  3. `workspace close <id> --group` es necesario para cerrar un workspace primario con worktrees
     abiertos; `horde` hoy solo cierra paneles, no choca con esto.
  En `idea-to-prs`, `--cwd <repo>` ya está documentado.

## `herdr agent wait`, `read`, `explain` (y `prompt --wait`, `start`, `attach`)

- `agent wait <target> [--until STATUS]... [--timeout MS]`: espera a `idle`/`done`/`blocked` por
  defecto; sin `--timeout` espera indefinidamente.
- `agent read <target> [--source visible|recent|recent-unwrapped|detection] [--lines N]
  [--format text|ansi]`. Para un agente inactivo y reconocido, leer más líneas que las visibles
  usa el scroll del propio agente (Claude Code pinta su transcripción en pantalla alterna) y
  devuelve `agent_not_idle` si está trabajando, bloqueado o desconocido.
- `agent explain <target> [--json|--verbose]` (o `--file PATH --agent LABEL` para un fixture):
  explica por qué herdr clasificó un agente en un estado (regla, manifiesto, evidencia). Requiere
  un servidor actualizado para el modo en vivo.
- `agent prompt <target> <text> --wait [--until] [--timeout]`: envía el prompt y espera al primer
  estado asentado. Si el agente está `blocked` devuelve `agent_blocked` sin enviar nada; si no hay
  actividad observada en 5 s devuelve `agent_prompt_stalled`.
- Respuestas pueden traer `completion_seq` (identifica la transición a idle como trabajo
  terminado, independiente de quién la haya visto).

Aplicabilidad:

- (a) No.
- (b) No.
- (c) No.
- (d) `horde` **Sí**, en tres puntos concretos de `references/batch.md`:
  1. Lanzamiento: hoy son tres pasos (`agent prompt`, `agent wait --until working --until blocked
     --timeout 15000`, luego una espera larga). `agent prompt ... --wait --timeout 5400000`
     lanzado en segundo plano (`run_in_background`) hace lo mismo: el chequeo de 5 s de
     `agent_prompt_stalled` ya detecta el arranque muerto y `agent_blocked` el diálogo previo. Se
     puede quitar el paso de 15 s. Riesgo a verificar al implementarlo: cómo reporta el fallo un
     comando en segundo plano que termina rápido.
  2. Fila `unknown` de la tabla de estados: añadir `agent explain <target>` además de `agent read`
     para decidir si es un fallo de detección o un agente realmente atascado.
  3. Distinguir `idle` de `done` con `completion_seq` en lugar de depender solo del texto del
     estado. Útil si la espera termina por un cambio de sesión y no por trabajo real.
  `idea-to-prs`: No directamente (delega en `horde`).

## `herdr pane wait-output`

`pane wait-output <pane_id> (--match TEXT | --regex PATTERN) [--source visible|recent|
recent-unwrapped] [--lines N] [--timeout MS]`: comprueba la captura actual de inmediato (puede
coincidir con salida ya existente) y luego sondea. `--match` es subcadena literal y `--regex` es
Rust regex, ambos por línea; por defecto mira las últimas 80 filas. Para procesos normales; para
agentes, `agent wait`. Complementa `pane run`, que envía comando y Enter de forma atómica (ya lo
usa `hw`).

- (a) No. (c) No.
- (b) Quizá: `hw` lanza `claude` con `pane run` y sigue sin comprobar que arrancó. Un
  `pane wait-output "$pane" --regex '...' --timeout 30000` solo ayuda si hay un prompt estable que
  reconocer; es frágil con `claude-profile`. Mejor `agent start` (ver más abajo) o dejarlo.
- (d) Quizá: para el comando de pruebas del repo dentro de un panel de builder. Hoy `horde` corre
  los tests él mismo, no vía panel. Sin necesidad clara.

## `workspace report-metadata` (y `pane report-metadata`)

- `workspace report-metadata <workspace_id> --source ID [--token NAME=VALUE]... [--clear-token NAME]
  [--seq N] [--ttl-ms N]`: publica valores solo para mostrar. Los tokens de workspace aparecen como
  `$nombre` en `[ui.sidebar.spaces] rows`. `--ttl-ms` (1 a 86 400 000) los caduca solos.
- `pane report-metadata <pane_id> --source ID [--title] [--display-agent] [--state-label
  STATUS=TEXTO] [--token]...`: lo mismo por panel (tokens `$nombre` en
  `[ui.sidebar.agents]`) sin tomar el control del estado semántico.
- Límites: texto de 80 caracteres, `source` solo `[A-Za-z0-9:._-]` hasta 80, como máximo 32 fuentes
  distintas con `--seq` por panel o workspace.

Aplicabilidad:

- (a) Necesario si se quiere usar: añadir `$horde` (o el nombre) a las `rows` de la barra lateral.
- (b) No.
- (c) No.
- (d) `horde` Quizá: publicar `ticket 3/5, ronda 2` en el workspace del ticket y `--ttl-ms`
  para que desaparezca si el orquestador muere. Es un extra de visibilidad, sin efecto en la
  lógica. Coste: más llamadas por ronda. Sugerencia: probar solo si usas batch con varios
  builders.

## `herdr notification show`

`notification show <title> [--body TEXT] [--position top-left|top-right|bottom-left|bottom-right]
[--sound none|done|request]`. Usa el `delivery` configurado en `[ui.toast]` (con `off` no se
muestra nada). `--position` solo afecta a los toasts dentro de herdr. `--sound` por defecto `none`;
`done` y `request` reutilizan los sonidos de terminado y de "necesita atención".

- (a) Requiere `[ui.toast] delivery` distinto de `off`.
- (b) No.
- (c) No.
- (d) `horde` **Sí**: en `blocked` (hoy solo se avisa en el chat), en CHECK-DISPUTE, y al final
  del hand-back, un `herdr notification show "horde: <id> bloqueado" --sound request` evita
  tener que mirar el terminal. Solo corre dentro de herdr (batch ya lo exige). `idea-to-prs`
  podría usarlo en cada gate que espera tu aprobación (tickets, PR).

## Sesiones con nombre

`herdr --session <nombre>`, `herdr session list|attach|stop|delete [--json]`. Cada sesión tiene
su propio servidor, paneles, tabs, workspaces, sockets y estado; comparte el mismo `config.toml`.
Los ids de workspace/panel/agente son por servidor. 0.9.5 arregla el estado `blocked` de Claude
Code en sesiones con nombre.

- (a) No (la config es global y compartida).
- (b) Quizá: una sesión por contexto de trabajo (`urbn`, `cnc`, `dotfiles`) en vez de tres
  workspaces en una. `docs/herdr.md` documenta "una sola sesión `default`" y `hw` lo asume; cambiar
  eso rompería la idempotencia por label, el `herdr workspace focus` final y el `$HERDR_ENV` de
  `horde`. No hay un problema que lo pida hoy.
- (c) No.
- (d) No: `horde` necesita un solo servidor con ids estables.

## `herdr machine` y `--remote` / `--machine`

- `herdr machine list|add|rename|remove|enable|disable|status|reconnect`; `machine add` prepara el
  servidor remoto y guarda el perfil (etiqueta, destino SSH, sesión remota). `herdr machine list`
  hoy: "No saved SSH machines".
- `herdr --remote <destino-ssh> [--session N] [--remote-keybindings local|server]`: adjunta por SSH
  con la UI local y atajos locales. `--handoff` opcional.
- `herdr --machine <label-o-id> <comando>`: reenvía comandos de API (`workspace`, `worktree`, `tab`,
  `pane`, `notification`, `agent` salvo `attach`, `status server`) a una máquina guardada sin
  necesidad de ventana abierta. No reenvía instalación, sesiones ni terminal interactivo; nunca
  cae a Local si falla; las rutas de worktree remoto deben ser absolutas o `~`.
- Aplicabilidad (a) No, (b) Quizá si hay otra máquina que quieras abrir con `hw`, (c) No,
  (d) No: `horde` asume paneles locales y el `--current` no vale para paneles remotos.
- Condición: no hay máquinas guardadas, así que no aplica hoy. `remote.manage_ssh_config` es
  irrelevante sin `--remote`.

## `herdr update --handoff`

- `herdr update` descarga e instala desde el canal configurado. Solo para instalaciones del propio
  instalador (en Homebrew, mise o Nix se actualiza con el gestor, `update` queda deshabilitado).
- Con la política actual de generación de endpoint 1, un update normal **mantiene vivos** los
  servidores compatibles y sus agentes. Después imprime qué servidores siguen en la versión vieja
  y cómo reiniciarlos.
- `--handoff` (experimental) pasa los paneles vivos del servidor viejo al nuevo sin parar los
  procesos. Solo hace falta si el servidor viejo es anterior a la generación 1 o si quieres
  reemplazarlo sin perder procesos. Interrumpe esperas y suscripciones en curso (`agent wait`
  puede fallar y hay que repetirlo). Un servidor antiguo limita el handoff a 64 paneles.
- (a) No. (b) No. (c) **Quizá**: `ensure_herdr` solo instala. No hay paso de actualización. Añadir
  `herdr update` al bootstrap cambiaría la idempotencia ("si existe, no hacer nada") y puede
  interrumpir builders en curso; mejor un comando manual documentado en `docs/herdr.md`. (d) No.
- Para este setup el orden recomendado: `herdr update` sin `--handoff` con el servidor de
  `default` parado o sin builders corriendo; usar `--handoff` solo si hay agentes vivos que no
  quieras perder.

## Canales (`stable` / `preview`)

- `herdr channel show|set <stable|preview>` y `[update] channel`. Preview son builds de
  prueba con fecha (por ejemplo `preview-2026-10-14-fbd2ae23927f`) y documentación
  propia (`https://herdr.dev/llms-preview.txt`). Los instalados con el script oficial empiezan en
  `stable`; los Windows preview siguen en preview hasta cambiarlos.
- Hoy el build de preview más reciente está **2 commits detrás de v0.9.5**. No hay motivo para
  cambiar de canal.
- (a) Quizá (`[update] channel`), (c) Quizá (solo si algún día se pide preview), (b) No, (d) No.

## Otras capacidades útiles que no estaban en la lista

- `herdr agent start <nombre> --kind claude --pane <id> [-- args]`: arranca un agente en un
  panel con un shell libre y vuelve cuando el agente está listo. `horde` ya lo usa para builders.
  Para `hw` **Quizá**: daría nombres estables (`herdr agent prompt dotfiles ...`), pero `--kind
  claude` ejecuta el binario canónico `claude`, no la función `claude-profile work` (que fija
  `CLAUDE_CONFIG_DIR` y el proxy `:3457`). Habría que pasar el entorno con `--env` en
  `workspace create` / `tab create` y se pierde la lógica del proxy. No compensa hoy.
- `workspace create --env KEY=VALUE` y `tab create --env`: variables en el shell raíz. Aplica a `hw`
  para `SlipStream` (Quizá, ver arriba).
- `herdr completion zsh`: completado de todos los subcomandos. (b) **Sí**: no hay referencia en
  `zsh/` ni se genera `_herdr`. Cambio mínimo: `source <(herdr completion zsh)` en
  `integrations.zsh` o un archivo en `fpath`.
- `herdr integration status`: `pi` y `opencode` salen desactualizados; no los usamos en este
  repo. Tras actualizar a 0.9.5, Codex deja de instalar hooks de turno (`herdr integration install
  codex` los actualiza; hacerlo fuera de nuestro `settings.json`, ver aviso de `docs/herdr.md`).
- `herdr api schema [--json]`: esquema del protocolo del binario instalado, útil si algún día se
  escribe un cliente.
- `herdr server agent-manifests` y `update-agent-manifests`: manifiestos de detección de estado
  (esto es lo que explica `agent explain`). `update.manifest_check = true` ya los actualiza solo.
- `herdr plugin update` y el marketplace (0.9.4): plugins locales con acciones, hooks y paneles.
  No hay caso de uso identificado.

## Qué cambiaría en cada destino (resumen accionable)

(a) `herdr/.config/herdr/config.toml`

- Sí: `[ui.toast] delivery` (elige `herdr` o `system`) para que los avisos de agentes funcionen.
- Sí si usas lazygit en herdr: `[[keys.command]]` popup.
- Quizá: `agent_panel_sort = "priority"`, `next_agent`/`previous_agent`, `focus_agent`,
  `[worktrees] directory`, `[ui.sidebar.spaces] rows` con `$horde`.
- Requiere 0.9.2 o superior: `prefix` en lista, `clear_pane`.

(b) `hw` en `functions.zsh`

- Sí: `herdr completion zsh` (en la integración de zsh, no dentro de `hw`).
- Quizá: sesión con nombre, `agent start`, `--env`. Ninguno resuelve un problema actual.
- Mantener `hw` idempotente por label y `pane run` (no hay motivo para cambiarlo).

(c) `scripts/modules/herdr.sh`

- Sin cambios claros. Opcional: documentar `herdr update` (y cuándo `--handoff`) en `docs/herdr.md`
  en lugar de automatizarlo, porque actualizar puede interrumpir builders. `docs/herdr.md` dice
  "Do not run `herdr integration install claude` by hand"; esa regla sigue valiendo.

(d) Skills `horde` e `idea-to-prs`

- `horde`: `agent prompt --wait`, `agent explain` para `unknown`, `notification show` en bloqueos
  y hand-back, `worktree open` para reanudar tras feedback de PR. Opcional: metadatos de workspace.
- `idea-to-prs`: `notification show` en los gates que esperan aprobación. Revisar si la exclusión
  de `.claude/worktrees/` sigue siendo necesaria con worktrees de herdr (por defecto viven en
  `~/.herdr/worktrees`).
- Nota de contexto: el `horde` de `main` tiene modo batch y modo solo. Existe un commit (#34, "sin
  modo solo, siempre un worktree por ticket en herdr") que no está en `main` y que cambia el
  texto de `SKILL.md` y `references/batch.md`. Los puntos de arriba valen para las dos versiones
  porque solo tocan los comandos de herdr de batch.

## Verificación pendiente (no comprobado)

- `herdr agent prompt ... --wait` en segundo plano: no se ejecutó; falta ver cómo se reporta un
  fallo a los 5 s.
- Efecto exacto de `[ui.toast] delivery = "system"` en Omarchy (qué daemon de notificaciones).
- Qué claves de 0.9.5 rechaza o ignora el binario 0.9.1 si se añaden a la config antes de
  actualizar. Actualizar primero.
- Los `--help` de segundo nivel (`herdr worktree create --help`, etc.) imprimen la ayuda raíz en
  0.9.1; los argumentos salen de la documentación del CLI de 0.9.5, no del binario instalado.

## Fuentes

- `herdr --help`, `herdr --default-config`, `herdr --skill`, `herdr integration status`,
  `herdr channel show`, `herdr session list`, `herdr machine list` (0.9.1, instalado).
- `https://herdr.dev/llms.txt` (índice estable 0.9.5), `https://herdr.dev/agent-guide.md`,
  `https://herdr.dev/llms-preview.txt`, `https://herdr.dev/latest.json`.
- Docs en `github.com/herdrdev/herdr` etiqueta `v0.9.5`, `docs/next/website/src/content/docs/`:
  `cli-reference.mdx`, `agent-automation.mdx`, `persistence-remote.mdx`, `session-state.mdx`,
  `connecting-machines.mdx`, `install.mdx`; y `src/data/config-reference.json`.
- Releases y comparación de commits: `gh api repos/herdrdev/herdr/releases` y
  `.../compare/v0.9.5...fbd2ae23927fe4923752bdb2db29661917fb05d7`.
- Archivos del repo leídos en `main`: `herdr/.config/herdr/config.toml`, `zsh/.config/zsh/functions.zsh`,
  `scripts/modules/herdr.sh`, `docs/herdr.md`, `claude/.claude/skills/horde/SKILL.md`,
  `claude/.claude/skills/horde/references/batch.md`, `claude/.claude/skills/idea-to-prs/SKILL.md`.
