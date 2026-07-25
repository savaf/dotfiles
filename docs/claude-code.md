# Claude Code

Versioned pieces (stow package `claude/`, linked into `~/.claude/`):

- `claude/.claude/settings.json` — user settings (model, theme). Local/runtime state
  (sessions, cache, plugins, `~/.claude.json`) is NOT versioned; stow links per file
  (`--no-folding`), so it stays untouched.
- `claude/.claude/CLAUDE.md` — global memory loaded in every session. Keep it tiny:
  every line costs tokens in every conversation.
- `claude/.claude/agents/*.md` — model routing per subagent type. User-level agents
  override the built-ins with the same `name`:

  | Agent | Model | Why |
  |---|---|---|
  | `Explore` | haiku | mechanical searching; cheapest model does it fine |
  | `Plan` | opus | deep reasoning is worth it for architecture |
  | `general-purpose` | sonnet | implementation workhorse; haiku falls short on non-trivial code |

  Do NOT set `CLAUDE_CODE_SUBAGENT_MODEL` in `settings.json`: that env var takes
  precedence over per-agent `model:` frontmatter and would force a single model for
  every subagent.

## Skills and MCP servers

`packages/claude-skills.txt` lists GitHub repos installed user-level
(`~/.claude/skills/`) by `scripts/install-claude-skills.sh` (run by the bootstrap) via
`npx skills add <repo> -g -a claude-code -s '*' -y`. The same script registers the
`context7` MCP server (library docs) at user scope with `claude mcp add`; that lands in
`~/.claude.json`, which is runtime state and can't be stowed.

Security note: third-party skills are instructions injected into the agent — review a
repo before adding it to the manifest.

Token note: every installed skill adds its description line to each session's context
(marketingskills alone ships 60+). If `/context` shows too much overhead, delete unused
ones from `~/.claude/skills/`; the manifest lets you reinstall.

## Auditing token usage

- `/usage` — session cost broken down by model, subagents, skills, MCP.
- `/context` — what's occupying the context window.
- `/mcp` — disable connectors you're not using (each one adds tool schemas).
- `/compact [focus]` — manually summarize a long conversation; `/clear` between
  unrelated tasks.
