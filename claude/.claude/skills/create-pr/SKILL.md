---
name: create-pr
description: "Open a pull request using the conventions the repo actually uses: title, template, labels, base branch. Use when the user says create PR, open PR, push and make a PR, or invokes /create-pr."
argument-hint: "[optional: base branch, or 'draft']"
---

# Create PR

Match the repo. Never impose a convention it does not use. Never create the PR before the user approves the draft.

## 1. Preflight

```bash
git branch --show-current
git status --short
gh pr view --json url,state 2>/dev/null
```

- On the default branch: stop, ask for a feature branch.
- Dirty tree: say so and ask. Do not commit on the user's behalf; that is `git-commit`.
- A PR already exists for the branch: return its URL, do not create another.
- No `gh`, or not authenticated: give the user the push command and the draft body, stop.

## 2. Resolve the base

Ask `gh` first, fall back to the default branch. Fetch it before diffing, a stale base widens the diff.

```bash
BASE=${ARG:-$(gh repo view --json defaultBranchRef --jq .defaultBranchRef.name)}
git fetch origin "$BASE"
git log "origin/$BASE"..HEAD --oneline
git diff "origin/$BASE"...HEAD --stat
```

Confirm the base when the branch already tracks a `release/*` or other non-default base. Read changed files one by one; do not dump the whole diff.

## 3. Infer the conventions

```bash
gh pr list --state merged --limit 10 --json title,labels,milestone,body
```

Determine from the sample, do not assume:

- **Title shape**: ticket-prefixed (`ABC-123 - x`), Conventional Commits, or bare imperative. Copy separator, case, and language exactly.
- **Ticket**: taken from the branch name when the sample uses it. Fetch the real title if a tool is available. Never invent one.
- **Labels and milestone**: use only those the sample shows on most PRs. Look each up with `gh label list` / `gh api repos/{owner}/{repo}/milestones`. Ask when a required one is ambiguous.
- **Squash merges**: when the sample shows the PR title becoming the commit, the title carries the weight. Make it stand alone.

Under 5 merged PRs or an inconsistent sample: ask instead of guessing.

## 4. Draft the body

Structure, in order of precedence. The first that exists wins, never merge two:

1. The repo's template: `.github/PULL_REQUEST_TEMPLATE.md`, `.github/pull_request_template.md`, or a file in `.github/PULL_REQUEST_TEMPLATE/`.
2. The section layout of the sampled PR bodies, when they share one.
3. The fallback `pr-template.md` next to this file.

Section names in the fallback are English; use the language of the sampled PRs.

- Fill every section from the diff, then delete sections that do not apply. Remove `<!-- -->` comments and placeholder bullets. Never leave a section blank.
- **Summary**: 1-3 bullets, what changed and why. The why is not in the diff.
- **Testing**: only what someone verifies by hand. Classify the change first.

| Change | Testing scope |
|---|---|
| Feature | Behavior of the new thing, including its error states |
| Bug fix | The fix, plus the adjacent behavior that could regress |
| Refactor | One smoke check per user flow through the moved code, not per branch |

Bullets describe behavior, not files or implementation. Skip what CI already covers: unit tests, lint, types, build. When the change removes something, verify its absence.

- Link the ticket, issue, or spec when one exists. Add `Closes #N` only when the branch or commits name that issue.
- Scan the diff for secrets and stray debug output. Stop and say so if found.

Show title, labels, base, and body. Wait for approval.

## 5. Push and create

Ask: draft or ready for review? (Skip the question when the argument said `draft`.)

```bash
git push -u origin HEAD
gh pr create [--draft] --base "$BASE" --title "..." --body-file <file> --assignee "@me" --label "a,b" --milestone "x"
```

- Pass every resolved label and the milestone on create. Some CI keys label and milestone checks at creation, and `gh pr edit` afterwards does not retrigger them.
- Use `--body-file` for the body, never inline, so backticks and quotes survive.
- Never `--force` push, never `--no-verify`. A failing hook is a finding: diagnose it.

## 6. Verify and report

```bash
gh pr checks
```

Report failures about metadata (label, milestone, title) and fix them. If CI does not rerun on `gh pr edit`, say so and ask before pushing an empty commit. Return the PR URL.
