---
name: horde
description: "Implement tickets with builder agents, in any tracker setup. Batch mode: parallel builders, one worktree per ticket, via herdr. Solo mode: one ticket, end to end, autonomous, notes kept local. Use when the user says build the tickets, unleash the horde, orchestrate agents on this project, work this ticket on its own, or invokes /horde."
argument-hint: "[ticket ids, path or text] [--base <branch>] [--solo] [max parallel builders]"
effort: medium
---

# Horde

You orchestrate. Builders write the code. The user merges. Never push, never touch a protected branch.

Rule: one ticket = one builder session.

- **Batch**: several tickets, one worktree each, parallel builders via herdr.
- **Solo**: one ticket, no map, no tracker writes, notes stay local.

Solo when `--solo` is passed, or `$ARGUMENTS` names exactly one ticket, or the overlap check (section 2) says so.

## 1. Preflight

Stop and tell the user what is missing; do not fix it silently.

```bash
git branch --show-current
git status --short
```

- Working tree clean. Builders branch from the base.
- Base = `--base <branch>`, else the current branch. A base that is protected, or equals the default branch: stop and ask for a feature branch.
- Read `AGENTS.md` and `docs/agents/issue-tracker.md` to learn where tickets live. Every tracker the repo configured is valid; use its operations below.
- Batch only: `herdr status` must show herdr running.
- GitHub tracker only: `gh auth status` must pass.
- Missing `.claude/settings.json`: run `ai-project-init`. It must set `AI_GUARD_PROTECT_BRANCHES` to the default branch and allow the repo's test, lint, build commands. A missing permission blocks a builder and interrupts the user.

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
- Show the chosen list and wait for a yes before launching. Solo with one named ticket: no wait.

## 3. Conventions

Read once, paste into every builder prompt:

- Commit format, from `AGENTS.md`, `CLAUDE.md`, `CLAUDE.local.md`, else `git log`.
- Test, lint, build commands.
- Amend and push stay off unless the user asked.

## 4. Launch builders

### Batch

```bash
herdr worktree create --branch feat/<id>-<slug> --label "<id>"
herdr agent start b-<id> --kind claude --pane <pane-id> -- --model sonnet
herdr agent prompt b-<id> "<prompt>" --wait --until idle --until blocked --until done
```

- `worktree create` branches from the checked-out base; read workspace and pane ids from its output.
- The pane must sit at a shell prompt. If `agent start` times out, report it; do not retry in a loop.
- Builder state `blocked`: read it with `herdr agent read b-<id>`, then tell the user what it needs. Do not answer permission prompts for them.
- Each finished ticket branch merges into the base locally by you, one at a time, tests green after each. No push.

### Solo

- One builder on the base in place: no worktree, no new branch.
- Run it in this session with `tdd`, or in a herdr pane as above when herdr is running.
- Notes go to `.scratch/<slug>/notes.md` (plan, decisions, test results). `.scratch/` stays untracked.
- Never create, comment on, or transition a ticket in the external tracker.

### Prompt

The ticket body verbatim, then:

- Use the `tdd` skill. Red, green, refactor.
- The conventions from section 3.
- The repo's test command passes before you stop.
- Commit on this branch. Do not push.
- Stay inside the ticket's scope.

## 5. Review gate

When a builder reports `done`:

1. Run the repo's test and lint commands in that checkout yourself. A claim is not evidence.
2. Run `git diff <base>...HEAD` and dispatch `architecture-reviewer`. Add `security-reviewer` when the diff touches auth, secrets, input parsing, network, or privileged calls.
3. Gate: 0 `blocker` and 0 `issue` findings (see `~/.claude/docs/review-output.md`).
4. Gate fails: send the findings to the same builder. Max **3** rounds.
5. Round 3 still failing: stop and report. Do not loosen the gate.

## 6. Hand back

Per ticket, one line: ticket, branch, path, test result, review rounds, gate pass or fail.

- Open a PR only if the user asks (`create-pr` skill). A base that already has a PR needs none.
- Batch cleanup after the user merges: `herdr worktree remove --workspace <id>`, then `git branch -d <branch>`.

## Never

- `--dangerously-skip-permissions` outside a container or VM.
- Pushing, force-pushing, amending, or committing `.scratch/`.
- Writing to the user's external tracker.
- Running real network or privileged tests (VPN, root, system services) unattended. Those are the user's.
- Starting more builders than the user approved.
