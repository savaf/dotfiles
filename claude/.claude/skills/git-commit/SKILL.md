---
name: git-commit
description: "Commit staged work using the convention this repo actually uses, inferred from its history. Use when the user says commit, commit this, save changes, or invokes /git-commit."
argument-hint: "[optional: what the commit should say]"
---

# Git Commit

Match the repo. Never impose a convention it does not use.

## 1. Infer the convention

```bash
git log --oneline -20
git branch --show-current
```

Read the subjects, do not assume. Determine:

- **Shape**: Conventional Commits (`feat(scope): x`), ticket-prefixed (`ABC-123 - x`),
  scope-prefixed (`module: x`), or bare imperative.
- **Separator**: `: `, ` - `, or none. Copy it exactly.
- **Language**: some repos commit in a language other than English. Match the log.
- **Mood and case**: imperative vs past, capitalized vs lowercase.
- **Ticket**: if the branch name carries a ticket key and the log uses it, include it. Fetch the
  real ticket title when a tool is available. Never invent one.

Check for a `commit-msg` hook or `commitlint` config and let it constrain the shape.

If the history is inconsistent or under 5 commits, ask instead of guessing.

## 2. Review what is being committed

```bash
git status
git diff --staged
```

- Nothing staged: show the unstaged changes and ask what to include. Do not stage everything on
  the user's behalf unless they say so.
- Staged changes spanning unrelated concerns: propose splitting into separate commits.
- Scan the diff for secrets, keys, and stray debug output before writing the message. Stop and
  say so if you find any.

## 3. Write the message

- Subject under 72 chars, or under 100 where the repo's own log runs longer.
- Subject says what changed. The body, when it exists, says why.
- Add a body only when the why is not obvious from the diff.
- Do not list the files; the diff already does.

## 4. Commit

- Never `--no-verify`. A failing hook is a finding, not an obstacle: diagnose it.
- Never `--amend` unless the user asks. Add a new commit.
- Do not push. Pushing is a separate, explicit request.
- Report the resulting subject line.
