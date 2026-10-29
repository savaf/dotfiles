# Batch launch

Herdr mechanics for batch mode. The orchestration rules live in `SKILL.md`.

```bash
herdr worktree create --branch feat/<id>-<slug> --base <base> --label "<id>" --no-focus
```

- Read the workspace id, root pane id, and worktree path from the JSON response. Never guess them.
- `.claude/settings.json` untracked (section 1): `cp` it into the same path in the worktree.
- Write the checks (section 4) in the worktree, then:

```bash
herdr agent start b-<id> --kind claude --pane <pane-id> --timeout 60000 -- --agent builder
herdr agent prompt b-<id> "$(cat .scratch/horde/<id>/prompt.md)"
herdr agent wait b-<id> --until working --until blocked --timeout 15000
```

- Constants: `--timeout 60000` gives the pane a minute to reach a shell prompt; `--until working
  --until blocked --timeout 15000` waits just long enough to see the first state change, so a
  dead start surfaces fast; `--agent builder` loads the builder agent, whose model and effort live in
  `agents/builder.md`.
- Agent names must match `[a-z][a-z0-9_-]{0,31}`: lowercase the ticket id.
- Write each prompt to `.scratch/horde/<id>/prompt.md` in the base checkout first. It keeps quoting out of the shell and leaves a record.
- The pane must sit at a shell prompt. `agent start` fails or returns `agent_not_ready`: run `herdr agent read b-<id> --source recent-unwrapped --lines 60`. A folder-trust or permission dialog is the user's to answer; tell them, never answer it. Do not retry in a loop.
- `agent_prompt_stalled` or a timeout does not prove the prompt was lost. Read the pane before sending anything again.

**Monitor.** After every builder is working, start one background wait per builder (Bash with `run_in_background`, so the harness wakes you when it settles):

```bash
herdr agent wait b-<id> --timeout 5400000
```

Then `herdr agent get b-<id>` to see which state it settled in:

| State | Meaning | Do |
|---|---|---|
| `idle` / `done` | Turn finished | Review gate (section 6) |
| `blocked` | Approval or question dialog | `agent read`, tell the user what it needs. Never answer for them |
| `unknown` | Cannot classify | `agent read`; does not prove completion |
| wait timed out | Still working after 90 min | `agent read`, report progress, start a new wait |

While a builder works, leave its pane alone. `herdr agent list` is the cheap overview when the user asks for status.

Merge each passed ticket branch into the base yourself, one at a time, tests green after each. No push.

## Plateau restart

Same `failure` as the previous round: the builder is stuck in a habit and its context carries it.
Split a fresh pane in the worktree and start `b-<id>-r<round>` there:

```bash
herdr pane split --pane <pane-id> --direction down --cwd <worktree> --no-focus
```

Prompt it with the ticket, the frozen set, `git log <CHECKS_SHA>..HEAD`, and a three-line summary
of what failed and what was already tried. Leave the old pane open while the ticket is in review; it closes with the rest (below).

## Close panes

Once a ticket passed the review gate and its branch is merged into the base with tests green, close every pane of that ticket (original and any `-r<round>` restarts):

```bash
herdr pane close <pane-id>
```

Only the pane: keep the worktree and branch; cleanup stays in the hand-back. Ignore a pane that no longer exists. Never close the panes of a ticket that failed round 3, hit CHECK-DISPUTE, or was stopped. Later changes (e.g. PR feedback) go to a fresh builder in a new round. Solo in a herdr pane: same; without a pane there is nothing to close.
