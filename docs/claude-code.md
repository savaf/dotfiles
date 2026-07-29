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

Token note: every installed skill puts its `name` + `description` in the system prompt of
**every** request (the body loads on demand, so size on disk is irrelevant). Measured here:
71 skills = ~10,800 tokens per request. `marketingskills` was 47 of them (~8,000 tokens) and
is now commented out of the manifest — its directories sit in `~/.claude/skills-disabled/`.
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
