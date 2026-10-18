# Review prompts

Dispatch `architecture-reviewer` always and `security-reviewer` when the diff touches input, SQL, auth, cookies or links. Give each the diff and the ticket, never the builder's transcript.

## Architecture reviewer

Fill the angle brackets.

```text
Review ticket <n> of <repo>. Worktree: <path> (branch <branch>, stacked on <base>).
Diff: `git -C <worktree> diff <base>...HEAD`. Ticket: `gh issue view <n> --json title,body --jq .body`.
Origin decisions: the resolution comments of the map tickets <list>.
Previous findings this round should have fixed: <list, or "none: first review">.

Verify each acceptance criterion, then prove the tests by mutation in a copy only:
<copy path>, port <free port> changed in the playwright config and in the fixtures of the copy.
Mutate: <one line per behaviour the ticket promises, e.g. drop the parameter, drop the aria attribute,
shrink a control below 44 px, keep the stale list>.
Every mutation must turn a test red; separate real assertion failures from incidental timeouts.
Measure overflow at 320 and 375 px with body.scrollWidth and boundingBox.
Confirm the diff holds no plan files and nothing outside the ticket.

Read-only on the real worktree. Classify each finding blocker, issue or nit.
```

## Security reviewer

```text
Review ticket <n> of <repo> adversarially. Worktree: <path>. Diff and ticket as above.
Focus: <the new request and its parameters, links built from API data, rendered API data,
raw SQL (everything parameterised, the owner filter first and parenthesised), session handling>.
Run the real code path without a database where possible and read the final SQL and parameters.
Read-only. Classify each finding blocker, issue or nit.
```

## Pass criterion

0 blockers, 0 issues, each mutation red, frozen files intact (`git diff <CHECKS_SHA> HEAD -- <frozen set>` empty).
