# Claude Code

## Profiles (multiple accounts)

Claude Code has no native profile switch: `CLAUDE_CONFIG_DIR` (default `~/.claude`) relocates
*all* of its state, and the credential store is namespaced per config dir, so two accounts can
run side by side without touching each other.

| Profile | Config dir | How to launch |
|---|---|---|
| personal (default) | `~/.claude` | `claude` |
| work | `~/.claude-work` | `ccw`, `claude-profile work`, `nic -p work` |

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

To add a profile: append it to `CLAUDE_PROFILES` in both `scripts/bootstrap.sh` and
`scripts/install-claude-skills.sh`, re-run the bootstrap, add an alias in
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

| Agent | Model | Why |
|---|---|---|
| `Explore` | haiku | mechanical searching; cheapest model does it fine |
| `Plan` | opus | deep reasoning is worth it for architecture |
| `general-purpose` | sonnet | implementation workhorse; haiku falls short on non-trivial code |
| `architecture-reviewer` | opus | boundaries, contracts, state, error paths, test gaps |
| `security-reviewer` | opus | injection, secrets, auth, data leakage |
| `performance-reviewer` | sonnet | algorithmic cost, N+1 queries, bundle weight |
| `summarizer` | haiku | compresses logs and command output out of the main thread |

The three reviewers share an output contract in `claude/.claude/docs/review-output.md`: gates a
finding must pass, the findings table, and the severity scale. A project that defines its own
review format overrides it.

Do NOT set `CLAUDE_CODE_SUBAGENT_MODEL` in `settings.json`: that env var takes precedence over
per-agent `model:` frontmatter and would force a single model for every subagent.

### Skills

`claude/.claude/skills/`, versioned here rather than installed by `npx skills add`. Stow links
each `SKILL.md` into `~/.claude/skills/<name>/`, alongside the third-party ones, so both kinds
coexist. Unprefixed on purpose: a project skill of the same name shadows the global one.

| Skill | What it is for |
|---|---|
| `ai-project-init` | Scaffold `AGENTS.md` + `.claude/settings.json` in a repo that has none, or refresh one that drifted |
| `session-retro` | Turn friction in a chat into a fix in the narrowest config that would have prevented it |
| `doc-write` | House style for persistent markdown: rules first, one idea per line, no filler |
| `git-commit` | Commit using the convention inferred from `git log`, not an imposed one |

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
| 4 skills | ~250 |
| 4 agents | ~215 |
| **total** | **~465** |

The hooks cost nothing in tokens: they are shell, not prompt. `guard-protected-branch.mjs` exits
before spawning git when no branch is protected, and `git-guardrails.mjs` only shells out to git
for a commit in a repo that set `AI_GUARD_PROTECT_BRANCHES`.

## Skills and MCP servers

`packages/claude-skills.txt` lists GitHub repos installed user-level
(`~/.claude/skills/`) by `scripts/install-claude-skills.sh` (run by the bootstrap) via
`npx skills add <repo> -g -a claude-code -s '*' -y`. The same script registers the
`context7` MCP server (library docs) at user scope with `claude mcp add`, once per profile; that
lands in each profile's `.claude.json`, which is runtime state and can't be stowed.

Security note: third-party skills are instructions injected into the agent — review a
repo before adding it to the manifest.

`~/.claude/skills/` now holds two kinds: the ones this script installs, and the ones versioned
in `claude/.claude/skills/` and linked by stow. They sit side by side; `npx skills add` leaves the
symlinked directories alone unless a repo ships a skill with the same name.

Token note: every installed skill puts its `name` + `description` in the system prompt of
**every** request (the body loads on demand, so size on disk is irrelevant). Currently 27 skills
= ~2,860 tokens per request, down from 71 skills = ~10,800 tokens. `marketingskills` was 47 of
them (~8,000 tokens) and is now commented out of the manifest — its directories sit in
`~/.claude/skills-disabled/`.
Re-enable a single one with `mv ~/.claude/skills-disabled/<skill> ~/.claude/skills/`.

To re-measure after adding or removing skills:

```sh
python3 -c "
import glob,re,os
t=0
for f in glob.glob(os.path.expanduser('~/.claude/skills/*/SKILL.md')):
    m=re.match(r'^---\n(.*?)\n---\n', open(f,errors='replace').read(), re.S)
    if not m: continue
    d=re.search(r'^description:\s*(.*?)(?=\n[a-zA-Z_-]+:|\Z)', m.group(1), re.S|re.M)
    t+=len(d.group(1).strip()) if d else 0
print(f'{t} chars ~ {t//4} tokens por request')"
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
4. **Model per task** — Sonnet 5 ($3/$15, intro $2/$10 through 2026-08-31) vs Opus 5 ($5/$25) for
   mechanical work. Note Opus's 1M context carries **no long-context premium**; `[1m]` costs
   nothing extra by itself.

`CLAUDE.md` is *not* on this list: at ~100 tokens it's 0.04% of consumption. Keep it short for
signal-to-noise, not for savings.
