# Claude Code

## Profiles (multiple accounts)

Claude Code has no native profile switch: `CLAUDE_CONFIG_DIR` (default `~/.claude`) relocates
*all* of its state, and the credential store is namespaced per config dir, so two accounts can
run side by side without touching each other.

| Profile | Config dir | How to launch |
|---|---|---|
| personal (default) | `~/.claude` | `claude` |
| work | `~/.claude-work` | `ccw`, `claude-profile work` |

`claude-profile <name>` (in `zsh/.config/zsh/functions.zsh`) just runs `claude` with
`CLAUDE_CONFIG_DIR=~/.claude-<name>`. `ccw` / `claude-work` are aliases for the work profile;
plain `claude` stays on the default dir.

**Per profile** (never shared): `.credentials.json`, `.claude.json` (MCP servers, per-project
trust, history), `sessions/`, `projects/` (transcripts + auto-memory), `plans/`, `plugins/`.

**Shared** across profiles: `settings.json`, `CLAUDE.md`, `agents/` — symlinked from this repo —
plus `skills/`. Stow only links into `~/.claude`; `link_claude_profiles()` in
`scripts/bootstrap.sh` replicates the same symlinks into every extra profile listed in
`CLAUDE_PROFILES`. The real skills live in `~/.claude/skills` (that's where `npx skills add -g`
writes them); extra profiles get a symlink to it.

MCP servers can't be symlinked — they live inside each profile's `.claude.json` — so
`scripts/install-claude-skills.sh` registers `context7` once per profile.

To add a profile: append it to `CLAUDE_PROFILES` in both
`scripts/modules/claude-profiles.sh` and `scripts/install-claude-skills.sh`, re-run the
bootstrap, add an alias in
`zsh/.config/zsh/aliases.zsh`, then `claude-profile <name>` → `/login`.

`/status` shows which account the current session is on — worth checking when several panes are
open.

## Versioned config

Versioned pieces (stow package `claude/`, linked into `~/.claude/` and into each extra profile):

- `claude/.claude/settings.json` — user settings (model, theme). Local/runtime state
  (sessions, cache, plugins, the profile's `.claude.json`) is NOT versioned; stow links per file
  (`--no-folding`), so it stays untouched.

  `"theme": "custom:omarchy"` hace que Claude Code siga al tema de Omarchy: el archivo de
  colores (`~/.claude/themes/omarchy.json`) lo regenera `omarchy-theme-set-claude` en cada
  cambio de tema, y Claude Code lo recarga en caliente. En Ubuntu/WSL y macOS ese archivo no
  existe y Claude Code cae a su tema por defecto — es el precio de compartir un único
  `settings.json`.

  > **No ejecutes `omarchy-theme-set-claude --activate`.** Ese flag escribe el `theme` con un
  > `mv` sobre `settings.json`, lo que reemplazaría el symlink de stow por un archivo real y
  > desconectaría el perfil del repo. La activación ya está versionada aquí.
- `claude/.claude/CLAUDE.md` — global memory loaded in every session. Keep it tiny:
  every line costs tokens in every conversation.
- `claude/.claude/agents/*.md` — subagent definitions. User-level agents override the
  built-ins with the same `name`. See "Project-agnostic AI layer" below.
- `claude/.claude/hooks/` — guardrails and session-start context, wired from `settings.json`.
- `claude/.claude/skills/` — skills written here rather than installed from a repo.
- `claude/.claude/docs/` — contracts the agents share, e.g. the review output format.

Extra profiles get `settings.json`, `CLAUDE.md`, and each `agents/*.md` symlinked by
`link_claude_profiles()`. They need no copy of `hooks/` or `docs/`: `settings.json` points at
`$HOME/.claude/hooks/` and the agents at `~/.claude/docs/`, both absolute, and `skills/` is
already a symlink to the default profile's.

## Project-agnostic AI layer

Every project gets the same baseline, even one with no AI config of its own. Ported and
generalized from a large private frontend repo, with the project-specific parts (issue tracker,
CMS, framework) stripped out.

Three pieces, all versioned in `claude/.claude/` and linked by stow.

### Hooks

`claude/.claude/hooks/`, wired in `settings.json`. They run in every project, on every profile.

| Hook | Event | What it does |
|---|---|---|
| `git-guardrails.mjs` | `PreToolUse` on `Bash` | Denies irreversible commands before they run |
| `guard-protected-branch.mjs` | `PreToolUse` on `Write`/`Edit` | Blocks edits to repo files on a protected branch |
| `load-agents-md.sh` | `SessionStart` | Injects the project's `AGENTS.md` when Claude Code would not load it |
| `decision-shadow.mjs` | `UserPromptSubmit`, `PreToolUse` on `Agent` | Logs Decisions from the local engine in shadow mode; applies nothing (see `docs/decision-engine.md`) |

`git-guardrails.mjs` splits its rules in two:

- **SAFETY**, always on. Recursive force-delete, hard reset, force-clean, force-push to
  `main`/`master`, force-push without a lease, force-delete of a branch, reflog expiry, and the
  whole-tree forms of `checkout`/`restore`. Each one destroys work with no recovery.
- **POLICY**, opt-in. Staging every file at once, skipping commit hooks, amending. These are team
  conventions, not universal safety, so they stay off unless a project asks for them.

Rules are evaluated **per shell segment** (split on newlines, `&&`, `||`, `;`, `|`), not over the
whole command string. Evaluating the whole string produces false positives: a recursive delete on
the last line of a compound command combines with a `[ -f ... ]` test inside a heredoc body and
reads as a force-delete.

The hooks also speak Cursor (`beforeShellExecution`) and Gemini (`BeforeTool`) response shapes via
`--runtime=`, so the same file can back a project's `.cursor/hooks.json`.

**Known false positive.** The hook matches text, not intent, so a heredoc that *documents* a
dangerous command is blocked the same as running one. Writing this very section through `cat`
tripped it. Use the `Write` tool for that content. A safety hook should over-block rather than
under-block, so this is not worth loosening.

Tests: `node claude/.claude/hooks/git-guardrails.test.mjs`. Run it after touching a rule.

### Per-project switches

Environment variables, set in a project's `.claude/settings.json` under `env`:

| Variable | Effect |
|---|---|
| `AI_GUARD_PROTECT_BRANCHES` | Comma list of branches where commits and repo edits are blocked. Empty (default) = off |
| `AI_GUARD_ENABLE` | Comma list of POLICY rule ids to turn on. `all` enables every one |
| `AI_GUARD_DISABLE` | Comma list of SAFETY rule ids to turn off |

The default is permissive on workflow, strict on data loss. A solo repo where committing to the
default branch is normal (this one) needs no config. A shared repo with a PR workflow sets
`"AI_GUARD_PROTECT_BRANCHES": "main"`.

### Agents

`claude/.claude/agents/`. The first three route models per subagent type; the rest are review
lenses and a compressor, dispatchable by name.

| Agent | Model | Effort | Why |
|---|---|---|---|
| `Explore` | haiku | medium | mechanical searching; cheapest model does it fine |
| `Plan` | opus | high | deep reasoning is worth it for architecture |
| `general-purpose` | sonnet | medium | implementation workhorse; haiku falls short on non-trivial code |
| `architecture-reviewer` | opus | high | boundaries, contracts, state, error paths, test gaps |
| `security-reviewer` | opus | xhigh | injection, secrets, auth, data leakage |
| `performance-reviewer` | sonnet | high | algorithmic cost, N+1 queries, bundle weight |
| `contrarian` | opus | high | counterarguments only pay off with depth |
| `feedback-resolver` | sonnet | medium | turns critiques into fixes; no deep reasoning needed |
| `summarizer` | haiku | low | compresses logs and command output out of the main thread |
| `researcher` | sonnet | medium | primary-source research into a Markdown note; reads and synthesises, no design calls |
| `builder` | sonnet | medium | one ticket end to end in its worktree; `/horde` starts builders with `--agent builder` |
| `test-runner` | sonnet | low | runs the tests, reports only failures and probable cause |
| `docs-reviewer` | sonnet | medium | mechanical check that README/docs/CLAUDE.md still match the diff |
| `pr-reviewer` | opus | high | PR review for a team (paste-ready comments) or for another agent (ticket and frozen checks); never posts |

The reviewers (`architecture`, `security`, `performance`, `docs`) share an output contract in
`claude/.claude/docs/review-output.md`: gates a
finding must pass, the findings table, and the severity scale. A project that defines its own
review format overrides it. `pr-reviewer` uses it too.

`researcher`, `builder`, `test-runner`, `docs-reviewer` and `pr-reviewer` are project-agnostic: none reads a tracker or depends on a third-party skill.
`researcher` and `pr-reviewer` draft in `.scratch/` (or outside the repo) and publish to GitHub
only when the caller says so; `pr-reviewer` never writes into tracked files. Wayfinder is wired by
one line in the global `CLAUDE.md` ("Research (including `wayfinder:research` tickets): `researcher`"), not by editing the skill.

`model:` in an agent's frontmatter is a suggestion for the decision engine, not a rule: see
"Agents and the frontmatter suggestion" in `docs/decision-engine.md`.

Do NOT set `CLAUDE_CODE_SUBAGENT_MODEL` in `settings.json`: that env var takes precedence over
per-agent `model:` frontmatter and would force a single model for every subagent.

### Main-thread model

The table above routes subagents. The main thread is the expensive one — it carries the whole
conversation and re-sends it on every tool call — so it gets its own default.

`settings.json` sets `"model": "sonnet"` as the floor. Opus is an opt-in escalation.

| Work | Model | Why |
|---|---|---|
| Editing code, features, refactors | sonnet | The workhorse, same call as `general-purpose` |
| Config, dotfiles, docs | sonnet | Editing JSON and shell is not Opus work |
| Architecture and design | opus | Trade-offs before implementation pay for it |
| Hard debugging, security | opus | Escalate per session, not by default |

Escalate mid-session with `/model opus`; start there with `cco` (alias in `aliases.zsh`).
`/model` beats `settings.json`, so the floor never blocks anything.

The `statusLine` exists for this: without the active model on screen, sessions stay on whatever
they opened with. Before it was added, 100% of sampled requests in `~/.claude/projects/` were
Opus 5.

`claude/.claude/hooks/statusline.sh` also surfaces, straight from the statusLine JSON (no
transcript parsing needed):
- context window usage as a color-coded bar, so `/context` is rarely needed mid-session
- git branch, dirty file count, and ahead/behind vs. upstream
- session cost and lines added/removed
- output style, when it isn't `default`, and the effort level
- plan limits, on plans that expose them: 5-hour usage with its reset time, and weekly usage
- failover proxy: active account (`⇄ personal` / `⇄ ccw`) with its 5h/7d quota read from the proxy, `directo` when the session doesn't go through it, `proxy off` if it's down
- context color: yellow from 50% (where the model degrades), red from 75%

Relies on `jq`, which every platform manifest in `packages/*.txt` installs as a base package.

### Effort

Effort is independent of the model. Each agent and skill sets `effort:` in its frontmatter.

Scale: `low` → `medium` → `high` → `xhigh` → `max`. `max` is not used here.

| Level | Use |
|---|---|
| `low` | summaries, mechanical skills |
| `medium` | search (`Explore` on Haiku 5.5, whose default it is), standard implementation, drafting |
| `high` | design, review, analysis |
| `xhigh` | security, critical architecture |

Skills (`claude/.claude/skills/`, all inline):

| Skill | Effort |
|---|---|
| `git-commit` | low |
| `create-pr` | low |
| `doc-write` | medium |
| `ai-project-init` | medium |
| `session-retro` | high |
| `horde` | medium |
| `idea-to-prs` | high |

Rules:
- An inline skill's `effort:` replaces the session's for that turn only.
- The `Skill` tool takes no effort parameter; only the skill's frontmatter sets it.
- The `Agent` tool takes `effort` per spawn; it beats the agent's frontmatter for that spawn.
- Main-thread dispatch rule lives in `claude/.claude/CLAUDE.md`.
- `Explore` and `summarizer` run on haiku. Haiku 5.5 honors `effort`; older Haiku models ignore it
  without an error, so `low` is documentation only there.

Precedence, highest first:
1. `CLAUDE_CODE_EFFORT_LEVEL`
2. `--effort`
3. `effort:` in agent or skill frontmatter
4. Session level (`effortLevel` or `/effort`)
5. Model default

`maxEffortLevel` caps every source, frontmatter included.

Do NOT set `CLAUDE_CODE_EFFORT_LEVEL`: it beats every `effort:` frontmatter and would force one
level on all agents and skills, like `CLAUDE_CODE_SUBAGENT_MODEL` does for models.

`/effort` saves its level per model in `modelSettings`, which beats top-level `effortLevel`.
After one `/effort` call, the `settings.json` default stops applying to that model.

### Skills

`claude/.claude/skills/`, versioned here rather than installed by `npx skills add`. Stow links
each file (`SKILL.md`, `pr-template.md`, `references/`, `scripts/`) into `~/.claude/skills/<name>/`, alongside the third-party ones, so both kinds
coexist. Unprefixed on purpose: a project skill of the same name shadows the global one.

| Skill | What it is for |
|---|---|
| `ai-project-init` | Scaffold `AGENTS.md` + `.claude/settings.json` in a repo that has none, or refresh one that drifted |
| `session-retro` | Turn friction in a chat into a fix in the narrowest config that would have prevented it |
| `doc-write` | House style for persistent markdown: rules first, one idea per line, no filler. Bundles `scripts/check-skill.py`, which validates a `SKILL.md` against the best-practices limits |
| `git-commit` | Commit using the convention inferred from `git log`, not an imposed one |
| `create-pr` | Open a PR with title, template, labels and base inferred from recent merged PRs; draft approved before creating. Its `pr-template.md` is only a fallback: the repo's template wins |
| `horde` | Implement open tickets with builder agents: one worktree per ticket via herdr, frozen checks approved before the build, background `herdr agent wait` per builder, parallel reviewer gate (0 blocker/issue, max 3 rounds), fresh builder on a repeated failure, every round in `.scratch/horde/results.tsv`. Never pushes. Herdr launch details live in `references/batch.md`, loaded only in batch mode |
| `idea-to-prs` | Run a loose idea through wayfinder research, decisions, plan, `to-tickets`, `horde` builds and reviewed stacked PRs across repos. User-invoked orchestrator; each stage ends on a gate. Lessons from real runs live in `references/lessons.md`, reviewer prompts in `references/review-prompts.md` |

### Workflow and agents

The third-party skills (`ponytail`, `mattpocock/skills`) are wired in by name, not copied: the
global `CLAUDE.md` carries a five-line "Workflow" map, and each agent body points at the skill
that fits its job. Bodies load only when an agent runs, so this costs no per-request tokens.

| Situation | Skill |
|---|---|
| Any coding task | `ponytail` (reuse, stdlib, native, one line) |
| Feature or fix with tests | `tdd` |
| Hard bug, perf regression | `diagnosing-bugs` |
| Fuzzy plan or design | `grilling`, then `domain-modeling` |
| Pre-merge review | `code-review`; over-engineering only: `ponytail-review` |

| Agent | Wired to |
|---|---|
| `Plan` | `ponytail` ladder, repo `CONTEXT.md`/ADRs, `codebase-design` |
| `general-purpose` | `ponytail` ladder, `tdd`, `diagnosing-bugs` |
| `architecture-reviewer` | over-engineering bullet reading `ponytail-review` and `codebase-design` |
| `contrarian` | `ponytail` ladder as the "build nothing" baseline |

`security-reviewer` and `performance-reviewer` stay unwired on purpose: minimalism is not a
lens for security. Reviewers have no `Skill` tool, so they `Read` the `SKILL.md` by path.

### AGENTS.md over CLAUDE.md

`AGENTS.md` is the cross-tool standard (Claude Code, Codex, Cursor, Gemini). Claude Code only
auto-loads `CLAUDE.md`, so `load-agents-md.sh` injects `AGENTS.md` at session start when the repo
has one and no `CLAUDE.md`. It stays quiet when the project defines its own `SessionStart` hook,
which is how a project that ships its own loader avoids doing it twice.

Write project conventions in `AGENTS.md`. Every tool reads it.

### Cost

Skill and agent descriptions land in the system prompt of every request. Measured here:

| Addition | Tokens per request |
|---|---:|
| 6 own skills | ~310 |
| 4 agents | ~215 |
| **total** | **~525** |

The hooks cost nothing in tokens: they are shell, not prompt. `guard-protected-branch.mjs` exits
before spawning git when no branch is protected, and `git-guardrails.mjs` only shells out to git
for a commit in a repo that set `AI_GUARD_PROTECT_BRANCHES`.

## Skills and MCP servers

`packages/claude-skills.txt` lists GitHub repos installed user-level
(`~/.claude/skills/`) by `scripts/install-claude-skills.sh` (run by the bootstrap) via
`npx skills@<pinned version> add <repo> -g -a claude-code -s <names> -y`; a manifest line may add a comma-separated skill list, the default is every skill in the repo. The CLI version is pinned in the script. The same script registers the
`context7` MCP server (library docs) at user scope with `claude mcp add`, once per profile; that
lands in each profile's `.claude.json`, which is runtime state and can't be stowed.

Security note: third-party skills are instructions injected into the agent. Before adding a
repo to the manifest:

1. Read every file in it, scripts and `references/` included.
2. Run `python3 -I ~/.claude/skills/doc-write/scripts/check-skill.py --audit` after installing and
   read each warning (network calls, scripts, secrets, manipulation phrases).
3. Pin what you accepted; a later update is a new review, not a free upgrade.

`~/.claude/skills/` now holds two kinds: the ones this script installs, and the ones versioned
in `claude/.claude/skills/` and linked by stow. They sit side by side; `npx skills add` leaves the
symlinked directories alone unless a repo ships a skill with the same name.

Token note: every installed skill puts its `name` + `description` in the system prompt of
**every** request (the body loads on demand, so size on disk is irrelevant). Count and cost: `check-skill.py --all` (below).
`marketingskills` was 47 skills (~8,000 tokens) and is commented out of the manifest — its
directories sit in `~/.claude/skills-disabled/`, as do `transitions-dev`, `transitions-polish` and
the 13 skills from `Leonxlnx/taste-skill` (UI-only, off by default here).

Plugins de terceros: el marketplace `better-claude` (`midudev/better-claude`, con `autoUpdate`) está en
`extraKnownMarketplaces` de `settings.json` y se activan `image-preview` y `quick-peek` en
`enabledPlugins`. En una máquina nueva, Claude Code los instala solo al aceptar el marketplace; cada uno
trae una opción sin definir: `/plugin configure <plugin>@better-claude`.

`mattpocock/skills` is installed through the manifest, **not** as the
`mattpocock-skills@claude-plugins-official` plugin: enabling both lists every skill twice
(`tdd` and `mattpocock-skills:tdd`). Per repo, run `/setup-matt-pocock-skills` once (issue
tracker, triage labels, `docs/agents/`); `code-review` and `triage` need it.
Solo se instalan `ponytail`, `mattpocock/skills` (lista explícita en el manifiesto; sin `grill-me`,
`grill-with-docs`, `retro`, `pr`, que duplican `grilling`, `session-retro` y `create-pr`) y las
skills propias. Los plugins de la cuenta (`design`, `engineering`, `productivity`, `figma`,
`humanizer`, `brightdata-plugin`) y `cloudflare` están a `false` en `enabledPlugins`.
Re-enable a single one with `mv ~/.claude/skills-disabled/<skill> ~/.claude/skills/`.

To validate and re-measure after adding or removing skills:

```sh
python3 -I ~/.claude/skills/doc-write/scripts/check-skill.py --all
```

## Auditing token usage

- `/usage` — session cost broken down by model, subagents, skills, MCP.
- `/context` — what's occupying the context window.
- `/mcp` — disable connectors you're not using (each one adds tool schemas).
- `/compact [focus]` — manually summarize a long conversation; `/clear` between
  unrelated tasks.

## Where the tokens actually go

Measured across 19 local sessions (1,884 requests, from `~/.claude/projects/**/*.jsonl`):

| component | share of cost |
|---|---:|
| `cache_read` (conversation re-sent every request) | 47.6% |
| `cache_creation` | 31.2% |
| `output` | 19.3% |
| uncached `input` | 1.9% |

Input-to-output ratio is **128:1**. The cost is not what Claude writes — it's re-sending the
conversation on every tool call. Context per request: median 105k, p90 292k. ~99 requests per
session on average.

So the levers that matter, in order:

1. **`/clear` between unrelated tasks.** At p90, staying in a finished session makes every
   subsequent tool call re-read ~292k tokens.
2. **Short, single-goal sessions.** Cost grows with turns × context-per-turn, so it compounds.
3. **Trim the fixed prompt overhead** (skills above, `/mcp` connectors).
4. **Model per task** — Sonnet 5 ($3/$15, intro $2/$10 through 2026-08-31) is 0.6× Opus 5
   ($5/$25), 0.4× while the intro price lasts. `settings.json` makes `sonnet` the floor; see
   "Main-thread model" for when to escalate. Opus's 1M context carries **no long-context
   premium**; `[1m]` costs nothing extra by itself.

`CLAUDE.md` is *not* on this list: at ~100 tokens it's 0.04% of consumption. Keep it short for
signal-to-noise, not for savings.

## Failover personal → ccw (teamclaude)

`cfo` (= `teamclaude run`) lanza Claude Code a través de un proxy local
([`@karpeleslab/teamclaude`](https://www.npmjs.com/package/@karpeleslab/teamclaude), fijado a
**1.1.24**) que usa la cuenta personal y salta a ccw cuando recibe el 429 de cuota. `claude` y
`ccw` siguen yendo directos. Auditoría y pruebas: `.scratch/claude-failover-proxy/research/`.

Reglas de seguridad (de la auditoría):

- Instalar solo el paquete con scope, sin scripts: `npm i -g --ignore-scripts @karpeleslab/teamclaude@1.1.24`.
  `teamclaude` sin scope es otro proyecto.
- `TEAMCLAUDE_DISABLE_AUTOUPDATE=1` (en `exports.zsh`) y `"autoUpdate": false` en la config.
- Nunca `teamclaude callback login` (sube todos los tokens) ni `teamclaude alias --install`
  (reescribe `~/.zshrc` y rompe el symlink de Stow).
- `~/.config/teamclaude.json` guarda los tokens: **no se versiona** ni se enlaza con Stow.
- Login con `teamclaude login --name <cuenta>` por cuenta (no `import`: compartiría el refresh
  token con Claude Code y se invalidarían entre sí).
- Config: `priority` 0 la personal, 1 ccw, y `switchThreshold: 1` para cambiar solo al agotarse.

### Replicar en otra máquina

1. `scripts/bootstrap.sh`: `packages/global-node-packages.txt` instala `@karpeleslab/teamclaude@1.1.24`,
   stow enlaza la función `claude` y el alias `cfo`, y `settings.json` (compartido) declara el
   marketplace local `claude-mods/` (`~/dotfiles/claude-mods`, el plugin `teamclaude-status` de la
   barra de estado) y lo activa en todos los perfiles.
2. `scripts/setup-teamclaude.sh` (a mano, es interactivo): logins de `personal` y `ccw`, cada uno en una
   sesión de navegador **distinta** (`scripts/teamclaude-browser.sh` hace de `xdg-open`/`open` solo durante el
   login) para que la segunda cuenta no herede la sesión de claude.ai de la primera. Prefiere **Brave**, un
   perfil por cuenta con sus extensiones (Bitwarden/passkeys): `personal` usa el perfil `Default` y `ccw`
   el `Profile 1` (Brave lo crea vacío la primera vez: instala Bitwarden ahí una vez; cámbialos con
   `TC_BRAVE_PROFILE_PERSONAL` / `TC_BRAVE_PROFILE_CCW`). Sin Brave, Chrome/Edge con un perfil limpio. Cierra
   cada ventana al terminar. Luego fija prioridades, `switchThreshold: 1`, modo `base-url`, sin auto-update e instalación del servicio
   de usuario. Para que siga vivo sin sesión abierta: `loginctl enable-linger $USER` (Linux).
3. Abre una terminal nueva: `claude` pasa por el proxy `:3456` si está arriba, o va directo.

La función `claude` usa `curl`, y el servicio `systemd --user` (o launchd en macOS) lo registra
`teamclaude service install`. La segunda instancia inversa para `ccw` (`:3457`) aún no está
scriptada.

### Failover inverso para `ccw` (segunda instancia)

`claude` va por el proxy `:3456` (personal → ccw). `ccw` / `claude-profile work` va por un
segundo proxy en `:3457` con prioridades invertidas (ccw → personal), si está arriba; si no,
directo. Un solo proxy no basta: `TC_ACCT` fija una cuenta pero nunca hace failover.

- Config propia: `TEAMCLAUDE_CONFIG=~/.config/teamclaude-work.json`, con **logins propios**
  (no copiar tokens del otro config: dos procesos refrescando el mismo refresh token se
  invalidan). Mismas reglas de seguridad que arriba.
- Contrapartida: cuando ccw se agota, el código y prompts de trabajo van a la cuenta personal,
  con otras condiciones de retención.

## Mods (`claude-mods/`)

Marketplace local `dotfiles-mods` (declarado en `settings.json`, ruta `~/dotfiles/claude-mods`), activo en todos los perfiles. Se leen desde la carpeta: edita y `/reload-plugins`.

| Mod | Qué hace |
|---|---|
| `teamclaude-status` | Toast cuando el proxy cambia de cuenta (los prompts pasan a otra org). La barra de estado con cuenta y cuota la dibuja `statusline.sh`; un mod no puede lanzar avisos desde ahí |
| `replay-theater` | `/replay`: recorre uno a uno los diffs de los archivos que Claude editó en el último turno. Vendorizado del mod de ejemplo de [anthropics/claude-code-playground](https://github.com/anthropics/claude-code-playground) (commit `569c528`); solo lee archivos |

Regla para mods ajenos: se **copian** al repo y se revisan (qué `$.*` llaman; `claude plugin
validate` lo lista), nunca se instalan desde el repo upstream, para que una actualización no
cambie lo que corre.

Descartados: `blast-radius` (ya cubierto por `git-guardrails.mjs`, `guard-protected-branch.mjs` y el bloqueo de `rm -rf`), `token-weather` (el contexto ya está en `statusline.sh`) y `am-context-bar` (casi todo cabe en `statusline.sh`; solo aportaba el desglose por categoría y el contador de compactaciones, y `/context` los cubre).
