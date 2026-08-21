---
name: session-retro
description: "Review this chat for where the agent struggled (repeated failures, user corrections, wrong assumptions, missing context) and propose fixes to the config that would have prevented it. Use when the user says session retro, retro this chat, what did you struggle with, what should we fix in the config, or invokes /session-retro."
argument-hint: "[optional: focus area]"
---

# Session Retro

Turn friction in this chat into a durable fix. Analyze, get approval, then edit. Never edit first.

## Phase 1: Analyze

Review this conversation from the start, or the `$ARGUMENTS` focus area.

### Struggle signals

- A tool call failed, then was retried differently.
- The user corrected a claim, an assumption, or a diff.
- The agent asked something a doc or a skill should already have answered.
- Backtracking after the wrong file, API, command, or convention.
- The same class of lint, test, or build failure more than once.
- A skill's steps did not fit the situation.

Ignore routine scoping, decisions, and approvals. Only real friction counts.

### Root cause and target

| Root cause | Target |
|------------|--------|
| A repo convention was undocumented or wrong | that repo's `AGENTS.md` |
| A skill's steps were wrong, missing, or out of order | that `SKILL.md` |
| A cross-project habit of mine was wrong | `~/.claude/CLAUDE.md` |
| A durable fact about me or this project | a memory file |
| A recurring workflow has no skill | flag it; do not build one inline |
| The cause is in the tool itself, or outside any config | drop it, say so |

Prefer the narrowest target that prevents recurrence. A repo-specific fact does not belong in
global config; a cross-project habit does not belong in one repo.

`~/.claude/CLAUDE.md` loads on every request in every project. A line earns its place there only
if it would change behavior in most sessions.

### Draft the fix

- The smallest edit that prevents the finding.
- Prefer merging into or generalizing an existing line over appending a new one. Net lines flat
  or shrinking.
- Follow `doc-write` conventions.

## Phase 2: Present

````
## Session Retro Findings

1. `[path]`
   - Struggle: [<=12 words]
   - Fix: [<=12 words]
   - Diff: `- old` -> `+ new`
````

- One-line diff where possible; otherwise a fence of <=20 lines. Beyond that, summarize the hunks.
- No findings: say so and stop.
- Ask which to apply. Use AskUserQuestion with one option per finding plus "none" when available.
- Revise on feedback, drop findings the user rejects, re-ask until settled.

## Phase 3: Apply

Only after the user selects.

1. Apply each Phase 1 diff, not the Phase 2 summary.
2. If the target is in a repo with a PR workflow, follow that repo's `AGENTS.md` for branch and
   commit. If it is `~/.claude/`, edit in the dotfiles repo so the change is versioned, not in
   `~/.claude/` directly: those are symlinks.
3. Report each file changed.
