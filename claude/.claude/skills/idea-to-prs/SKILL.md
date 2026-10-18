---
name: idea-to-prs
description: Runs a loose idea through research, decisions, plan, tickets and reviewed stacked PRs, across one or more repos. Chains wayfinder, to-tickets, horde and create-pr with the gates that proved necessary.
disable-model-invocation: true
argument-hint: "<idea> [reference repos or paths]"
effort: high
---

# Idea to PRs

You orchestrate one pipeline. Each stage ends on a **gate**: do not start the next stage until the gate holds.
Stage tools: `wayfinder`, `to-tickets`, `horde`, `create-pr`. This skill adds what sits between them.

Read [references/lessons.md](references/lessons.md) before stage 5 and whenever a review round fails. Read [references/review-prompts.md](references/review-prompts.md) when dispatching a reviewer.

## 1. Chart

- Call `grilling` and `domain-modeling`. Ask each round's whole frontier at once, each question with a recommended answer.
- Name the destination first: a spec with every decision closed, not the built feature.
- Read the reference repos and the backend yourself; a fact in the environment is your job, never the user's.
- Create the map, the tickets and their native blocking edges; launch every `research` ticket as a parallel subagent on a throwaway `research/<name>` branch (pushed, no PR).

Gate: map and tickets exist; each research ticket is closed with a link to its branch.

## 2. Resolve

- One decision ticket per session; research tickets run in parallel.
- Verify the premise in code before asking about it. A flag, a status or an endpoint the user names exists only once you have read where it is set.
- Close each ticket with a resolution comment, then add one line to the map's Decisions so far.
- Create `GLOSSARY.md` when the first term resolves; add each term as it resolves.

Gate: no open ticket and an empty Not yet specified section.

## 3. Plan

- Write the plan as vertical slices, each starting with its test and each runnable with mocks.
- Keep the plan outside the PRs (`.scratch/horde/plan.md`); the PRs carry code and `GLOSSARY.md` only.
- Give a change in another repo its own ticket and a deploy gate on the slice that depends on it.

Gate: every slice names its test, its blockers and its deploy gate, if any.

## 4. Tickets

- Run `to-tickets` on the plan. Publish the other repo's ticket first and wire blocking edges, cross-repo ones included.
- Show the breakdown and wait for approval.

Gate: user approved; each ticket is `ready-for-agent` with native blockers.

## 5. Build

Run `horde` with these additions:

- Preflight: clean tree, `.scratch/` and `.claude/worktrees/` excluded through `.git/info/exclude`, base resolved from `origin/<default>`, `herdr worktree create --cwd <repo>` for any repo that is not the current one.
- Logic-heavy tickets get frozen checks approved by the user; UI tickets are covered by the ticket's e2e criteria.
- Stack the UI tickets: each branch starts from the previous one.
- Verify every builder yourself (typecheck, lint, tests, diff free of the plan), then dispatch fresh reviewers with the prompts in `references/review-prompts.md`.
- A surviving mutant is a finding; a reviewer's mutation proof is the pass criterion.
- Rounds: three. Extend a round only with concrete findings, and log the extension.

Gate: a ticket passes when checks are green, frozen files are intact, and the reviewers report 0 blockers and 0 issues.

## 6. Ship

- Push the branch and open the PR ready for review with `create-pr`, the base set to the previous branch in the stack.
- Put in each body: what to verify by hand, the dependency on the other repo, and any deploy gate.
- Report the merge order and the cleanup commands.

Gate: every ticket has a PR; the hand-back lists unverified assumptions.
