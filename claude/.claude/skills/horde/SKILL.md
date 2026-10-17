---
name: horde
description: "Implements tickets with builder agents, in any tracker setup. Batch mode runs parallel builders, one worktree per ticket, via herdr; solo mode builds one ticket end to end, autonomously, with notes kept local. Use when the user asks to build tickets or unleash the horde."
argument-hint: "[ticket ids, path or text] [--base <branch>] [--solo] [--no-checks] [max parallel builders]"
effort: medium
---

# Horde

You orchestrate. Builders write the code. You merge ticket branches into the base; the user merges the base into the default branch. Never push, never touch a protected branch.

Rule: one ticket = one builder session at a time.

- **Batch**: several tickets, one worktree each, parallel builders via herdr.
- **Solo**: one ticket, no map, no tracker writes, notes stay local.

Solo when `--solo` is passed, or `$ARGUMENTS` names exactly one ticket, or the overlap check (section 2) says so.

Three anchors keep the loop honest. None of them is negotiable mid-run:

- **Checks**: tests written from the ticket's acceptance criteria *before* the builder starts, approved by the user, frozen. The builder may not edit them.
- **Fresh verifier**: you run the checks yourself, and reviewers get the diff and the ticket, never the builder's transcript.
- **Results log**: every round is a row in `.scratch/horde/results.tsv`. Repeated failures are read from it, not remembered.

## 1. Preflight

Stop and tell the user what is missing; do not fix it silently.

```bash
git branch --show-current
git status --short
git check-ignore -q .scratch/ && echo scratch-ignored
```

- Working tree clean. Builders branch from the base.
- Base = `--base <branch>`, else the current branch. A base that is protected, or equals the default branch: stop and ask for a feature branch.
- `.scratch/` must be git-ignored. Not ignored: ask before adding it to `.gitignore`.
- Read `AGENTS.md` and `docs/agents/issue-tracker.md` to learn where tickets live. Every tracker the repo configured is valid; use its operations below.
- Batch only: `test "${HERDR_ENV:-}" = 1` and `herdr status` shows the server running. Outside a herdr pane, batch is unavailable: offer solo.
- GitHub tracker only: `gh auth status` must pass.
- Missing `.claude/settings.json`: run `ai-project-init`. It must set `AI_GUARD_PROTECT_BRANCHES` to the default branch and allow the repo's test, lint, build commands. A missing permission blocks a builder and interrupts the user.
- Note whether `.claude/settings.json` is tracked (`git ls-files --error-unmatch .claude/settings.json`). A worktree only has the tracked copy; section 4 copies an untracked one in.

## 2. Pick tickets

Source follows the tracker doc:

| Tracker | List ready tickets |
|---|---|
| GitHub Issues | `gh issue list --label <ready label> --state open --json number,title,body` |
| Local markdown | `.scratch/*/issues/*.md` whose `Status:` line is the ready role |
| Other | the doc's own "fetch" and "list" operations |

- Ready label or role: `docs/agents/triage-labels.md`.
- Skip a ticket that names an open blocker (`Blocked by`).
- User named tickets in `$ARGUMENTS`: use those, still skipping blocked ones.
- A ticket the repo tracks outside the agent tracker (Jira key, pasted text, a plan file): solo only. Read it, never write back.
- Default to **1** builder. Go to 2-3 only if the user asked or the first one finished clean. Cost scales with agents × turns × context.
- Overlap check: list the files each ticket will touch. All tickets overlap: recommend `/tdd` on the base directly, then let the user pick. Some overlap: those tickets run in sequence, never in parallel.
- Independence check: run two tickets side by side only when neither reads the other's output. A ticket that needs another's code is a real dependency: sequence it.
- Show the chosen list and wait for a yes before launching. Solo with one named ticket: no wait.

## 3. Conventions

Read once, paste into every builder prompt:

- Commit format, from `AGENTS.md`, `CLAUDE.md`, `CLAUDE.local.md`, else `git log`.
- Test, lint, build commands.
- Amend and push stay off unless the user asked.

## 4. Checks

Skip with `--no-checks`; say in the hand-back that the ticket ran unchecked.

Per ticket, on its branch (batch: the worktree; solo: the base), before any builder runs:

1. Dispatch a fresh `general-purpose` agent with the ticket body and the conventions. It writes tests for the acceptance criteria only, in the repo's existing test layout, and runs them. They must fail for the right reason (missing behaviour, not a syntax or import error).
2. A criterion that no automated test can express: list it as **manual** instead of faking a test.
3. Show the user, per ticket: check files, what each asserts, the red output, and any manual criteria. Wait for a yes. Edits the user asks for go back to the same check writer.
4. Commit the approved checks alone (`test: checks for <id>`, in the repo's commit format). Record that commit as `CHECKS_SHA` and the file list as the frozen set.

The check writer never builds; the builder never writes checks. That split is the point.

## 5. Launch builders

### Batch

```bash
herdr worktree create --branch feat/<id>-<slug> --base <base> --label "<id>" --no-focus
```

- Read the workspace id, root pane id, and worktree path from the JSON response. Never guess them.
- `.claude/settings.json` untracked (section 1): `cp` it into the same path in the worktree.
- Write the checks (section 4) in the worktree, then:

```bash
herdr agent start b-<id> --kind claude --pane <pane-id> --timeout 60000 -- --model sonnet
herdr agent prompt b-<id> "$(cat .scratch/horde/<id>/prompt.md)"
herdr agent wait b-<id> --until working --until blocked --timeout 15000
```

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

### Solo

- One builder on the base in place: no worktree, no new branch.
- Run it in this session with `tdd`, or in a herdr pane as above when herdr is running.
- Notes go to `.scratch/<slug>/notes.md` (plan, decisions, test results). `.scratch/` stays untracked.
- Never create, comment on, or transition a ticket in the external tracker.

### Prompt

The ticket body verbatim, then:

- Use the `tdd` skill. The checks committed in `<CHECKS_SHA>` are the red tests: make them pass. Add more tests as you need them.
- Never edit, delete, rename, or skip a file in the frozen set: <list>. If you believe a check is wrong, stop and reply starting with `CHECK-DISPUTE:` and why. Do not work around it.
- The conventions from section 3.
- The repo's test command passes before you stop.
- Commit on this branch. Do not push.
- Stay inside the ticket's scope.

## 6. Review gate

When a builder settles in `idle` or `done`:

1. Reply starts with `CHECK-DISPUTE:`: stop that ticket and show the user. Only the user changes a frozen check, through the check writer, with a new `CHECKS_SHA`.
2. Frozen set untouched: `git diff --quiet <CHECKS_SHA> HEAD -- <frozen set>` and `git status --short -- <frozen set>` empty. A change fails the round as `checks-modified`; revert those files before the next round.
3. Run the repo's test and lint commands in that checkout yourself. A claim is not evidence.
4. Run `git diff <base>...HEAD` and dispatch the reviewers **in parallel, in one message**: `architecture-reviewer` always, `security-reviewer` when the diff touches auth, secrets, input parsing, network, or privileged calls. Each gets the diff and the ticket body, nothing from the builder's session.
5. Gate: checks green, frozen set intact, 0 `blocker` and 0 `issue` findings (see `~/.claude/docs/review-output.md`).
6. Log the round (section 7).
7. Gate fails, round < 3: pick the builder for the next round.
   - Same `failure` as the previous round: **plateau**. The builder is stuck in a habit and its context carries it. Split a fresh pane in the worktree (`herdr pane split --pane <pane-id> --direction down --cwd <worktree> --no-focus`), start `b-<id>-r<round>` there, and prompt it with the ticket, the frozen set, `git log <CHECKS_SHA>..HEAD`, and a three-line summary of what failed and what was already tried. Leave the old pane for the user to inspect.
   - Otherwise: send the findings to the same builder.
8. Round 3 still failing: stop and report. Do not loosen the gate, and do not weaken a check to pass it.

## 7. Results log

`.scratch/horde/results.tsv` in the base checkout, append-only, one row per round, across every run. Write it yourself; builders never touch it. Create it with this header row:

```text
ts	ticket	round	builder	checks	gate	findings	failure	action
```

| Column | Value |
|---|---|
| `ts` | `date -Is` |
| `ticket` | ticket id |
| `round` | 1, 2, 3 |
| `builder` | agent name, e.g. `b-07`, `b-07-r3` |
| `checks` | `pass`, `fail`, `none` (`--no-checks`) |
| `gate` | `pass`, `fail` |
| `findings` | `<blockers>/<issues>/<nits>`, e.g. `0/2/1` |
| `failure` | one stable key, empty on pass: `checks-modified`, `check-dispute`, `test:<test id>`, `lint:<rule>`, `review:<file>:<topic>` |
| `action` | `retry`, `restart`, `merged`, `stopped` |

Keep `failure` stable across rounds: the same cause must produce the same key, or the plateau rule never fires. Strip tabs and newlines from every field (`tr '\t\n' '  '`).

The log is evidence for the user, not a target for you. Never shape a fix to make a row look better.

## 8. Hand back

Per ticket, one line: ticket, branch, path, checks result, review rounds, gate pass or fail, and whether a plateau restart happened.

- Open a PR only if the user asks (`create-pr` skill). A base that already has a PR needs none.
- Several runs logged: point the user at `results.tsv` failures that repeat across tickets. They are candidates for the repo's `AGENTS.md`; propose the line, never add it yourself.
- Batch cleanup after the user merges: `herdr worktree remove --workspace <id>`, then `git branch -d <branch>`.

## Never

- `--dangerously-skip-permissions` outside a container or VM.
- Pushing, force-pushing, amending, or committing `.scratch/`.
- Writing to the user's external tracker.
- Running real network or privileged tests (VPN, root, system services) unattended. Those are the user's.
- Starting more builders than the user approved.
- Answering a builder's permission, trust, or question dialog.
- Editing a frozen check without the user's yes.
