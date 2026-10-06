---
name: horde
description: "Implement a repo's open GitHub tickets with parallel builder agents, one worktree per ticket, via herdr. Use when the user says build the tickets, unleash the horde, orchestrate agents on this project, or invokes /horde."
argument-hint: "[optional: issue numbers, or max parallel builders]"
effort: medium
---

# Horde

You orchestrate. Builders write the code. The user merges. Never merge, never push to a protected branch.

Rule: one ticket = one worktree = one builder session.

## 1. Preflight

Stop and tell the user what is missing; do not fix it silently.

```bash
herdr status
gh auth status
git branch --show-current
git status --short
```

- herdr must be running. `gh` must be authenticated with PR rights.
- The working tree must be clean. Builders branch from the current HEAD.
- Read `AGENTS.md` and `docs/agents/issue-tracker.md` to learn where tickets live. If the tracker is not GitHub Issues, stop and say so.
- Missing `.claude/settings.json`: run `ai-project-init`. It must set `AI_GUARD_PROTECT_BRANCHES` to the default branch and allow the repo's test, lint, build commands. A missing permission blocks a builder and interrupts the user.

## 2. Pick tickets

```bash
gh issue list --label ready-for-agent --state open --json number,title,body
```

- Use the label from `docs/agents/triage-labels.md` if it differs.
- Skip a ticket whose body or sub-issue links name an open blocker (`Blocked by #N`).
- User named issues in `$ARGUMENTS`: use those, still skipping blocked ones.
- Default to **1** builder. Go to 2-3 only if the user asked or the first one finished clean. Cost scales with agents × turns × context.
- Two tickets that touch the same files do not run in parallel.
- Show the chosen list and wait for a yes before launching.

## 3. Launch one builder per ticket

```bash
herdr worktree create --branch feat/<N>-<slug> --label "#<N>"
herdr agent start b-<N> --kind claude --pane <pane-id> -- --model sonnet
herdr agent prompt b-<N> "<prompt>" --wait --until idle --until blocked --until done
```

- `worktree create` prints the workspace and pane ids; read them from its output.
- The pane must sit at a shell prompt. If `agent start` times out, report it; do not retry in a loop.
- Prompt = the issue body verbatim, then:
  - Use the `tdd` skill. Red, green, refactor.
  - The repo's test command must pass before you stop.
  - Commit on this branch with the repo's convention. Do not push.
  - Do not touch files outside the ticket's scope.
- Builder state `blocked`: read it with `herdr agent read b-<N>`, then tell the user what it needs. Do not answer permission prompts for them.

## 4. Review gate

When a builder reports `done`:

1. Run the repo's test and lint commands in that worktree yourself. A claim is not evidence.
2. Run `git diff <base>...HEAD` and dispatch `architecture-reviewer`. Add `security-reviewer` when the diff touches auth, secrets, input parsing, network, or privileged calls.
3. Gate: 0 `blocker` and 0 `issue` findings (see `~/.claude/docs/review-output.md`).
4. Gate fails: send the findings to the same builder with `herdr agent prompt`. Max **3** rounds.
5. Round 3 still failing: stop and report. Do not loosen the gate.

## 5. Hand back

Per ticket, one line: issue, branch, worktree path, test result, review rounds, gate pass or fail.

- Open a PR only if the user asks (`create-pr` skill).
- Cleanup after the user merges: `herdr worktree remove --workspace <id>`, then `git branch -d <branch>`.

## Never

- `--dangerously-skip-permissions` outside a container or VM.
- Merging, force-pushing, or editing the main checkout from an orchestration turn.
- Running real network or privileged tests (VPN, root, system services) unattended. Those are the user's.
- Starting more builders than the user approved.
