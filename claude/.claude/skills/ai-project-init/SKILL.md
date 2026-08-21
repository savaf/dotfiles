---
name: ai-project-init
description: "Scaffold or refresh a repo's AI config: AGENTS.md, .claude/settings.json, and folder-level AGENTS.md. Use when a project has no AI configuration, when the user says set up AI config, init agents, add AGENTS.md, configure Claude for this repo, document this folder for agents, or invokes /ai-project-init."
argument-hint: "[optional: subfolder path to document, or --refresh]"
---

# AI Project Init

Give a repo the config it needs so any agent, in any tool, starts with the same grounding.

`AGENTS.md` is the cross-tool standard (Claude Code, Codex, Cursor, Gemini). Write conventions
there, not in `CLAUDE.md`. A `~/.claude/hooks/load-agents-md.sh` hook injects it at session
start when the repo has no `CLAUDE.md`.

## Modes

| Argument | Action |
|----------|--------|
| none | Full scaffold at the repo root |
| a folder path | Folder-level `AGENTS.md` for that folder only |
| `--refresh` | Audit the existing `AGENTS.md` against the code, fix what drifted |

## 1. Survey before writing

Never write from a template alone. Ground every claim in the repo.

- Manifests: `package.json`, `pyproject.toml`, `go.mod`, `Cargo.toml`, `composer.json`.
  Take the real script names, not the ones you expect.
- Run `git log --oneline -20` for the commit convention actually in use.
- Find the test, lint, build, and dev commands. Confirm each exists before documenting it.
- Find the layout: where source, tests, and config live. Name the non-obvious directories only.
- Read any existing `README.md`, `CONTRIBUTING.md`, `.cursor/rules/`, `.github/copilot-instructions.md`.
  Reuse what is already written; do not restate it.
- Detect the default branch: `git symbolic-ref refs/remotes/origin/HEAD` or `git branch --show-current`.

Report what you found and let the user correct it before writing.

## 2. Write AGENTS.md

Root `AGENTS.md`. Follow `doc-write` conventions. Keep it under ~120 lines: it loads into every
session in that repo.

```markdown
# <project name>

<one line: what it is, and the stack>

## Commands

| Command | What it does |
|---------|--------------|

## Layout

<only the non-obvious paths; skip what the tree makes clear>

## Conventions

<what a reviewer would flag. Ground each in code you read.>

## Gotchas

<the things that cost someone an hour. Nothing speculative.>

## Git

- Branch: <observed pattern>
- Commit: <observed convention, from git log>
```

Omit a section rather than filling it with guesses. An empty section costs tokens in every
request and teaches nothing.

## 3. Write .claude/settings.json

Only when the project needs something the global config does not give it.

```json
{
  "env": {
    "AI_GUARD_PROTECT_BRANCHES": "main",
    "AI_GUARD_ENABLE": "git-add-all,git-no-verify"
  },
  "permissions": {
    "allow": ["Bash(<the repo's own test/lint/build commands>)"]
  }
}
```

- `AI_GUARD_PROTECT_BRANCHES` turns on the branch guards in `~/.claude/hooks/`. Set it on shared
  repos with a PR workflow. Leave it out where committing straight to the default branch is normal.
- `AI_GUARD_ENABLE` opts into the workflow rules (`git-add-all`, `git-no-verify`, `git-amend`).
- Add only read-only or already-safe commands to `permissions.allow`.

Ask before committing `.claude/settings.json` to a shared repo: it changes behavior for every
contributor. `.claude/settings.local.json` is the personal, git-ignored alternative.

Check `.gitignore`. The usual split:

```
.claude/*
!.claude/settings.json
!.claude/hooks/
!.claude/skills/
```

## 4. Folder-level AGENTS.md

For a folder whose rules differ from the root, or that an agent gets wrong repeatedly.

- Trigger: the folder has its own invariants, its own test setup, or a pattern that must be
  matched exactly.
- Not a trigger: the folder is merely large, or merely important.
- Keep it to what is not visible from reading two files in that folder.
- Do not restate the root `AGENTS.md`. Point at it.

## 5. Verify

- Re-read what you wrote. Every command must run; every path must exist.
- `bash -n` or `node --check` anything executable you added.
- Report the files created and the one thing you were least sure about.
