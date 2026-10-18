# Lessons

Each line came from a failure in a real run (a seven-ticket dashboard across two repos).

## Tests that discriminate

- A reviewer proves a test by mutating a **copy** of the worktree and watching it go red. A surviving mutant is a finding.
- A test of a failure waits for the failure signal before asserting. A test that passed 3 of 8 runs without the fix proves nothing; run `--repeat-each=8` with the fix removed and expect 8 failures.
- Anchor regexes in frozen checks to what they mean. `/IS NULL/` matched `ris.deleted_at IS NULL`, and `OR` matched `ORDER BY`.
- Measure overflow with `document.body.scrollWidth` and each control's `boundingBox` at 320 and 375 px. `documentElement.scrollWidth` cannot fail when `body` has `overflow-x: clip`.
- Check every touch target (44 px) on mobile as well as desktop.
- Pin the browser timezone in a date test. Fixtures give each date field a different day in each zone, so reading the wrong field fails.
- Make a tie-break test put the correct item in the middle of the tied group, with the highest id elsewhere.
- Give each list item a unique id in fixtures; shared ids hide key bugs.

## Behaviour that reviewers found

- An empty search applies instantly, also in the debounced value; otherwise retyping revives the old term.
- Every term change, clearing included, returns to page 1.
- `keepPreviousData` spans the whole query key. Keep the old list across pages only; show nothing stale across terms or lists.
- The page error state shows only when there is no data. A failed background refetch keeps the list.
- The query key carries the list group so two lists never share a cache entry.
- A 401 keeps its existing flow (toast, cookie removed, redirect); a test fixes it, and a mutant that rejects instead of staying pending must fail.
- Resolve a status by (institution, code). Ids follow seeding order and differ by environment.
- `fueAprobado` style flags can exist but never be set; read where a flag is written before building on it.

## Process

- The user's "do everything recommended" accepts the recommended answers; record that in each resolution.
- A plan-only PR is noise. Keep the plan out of every PR and close a plan-only PR.
- `GLOSSARY.md` rides in the first implementation PR.
- Commit before mutating; restore a mutated file with `git checkout -- <file>` only when the tree has no uncommitted work.
- The e2e fixtures pin one port. Parallel worktrees collide on it; change the port in reviewers' copies.
- Leave no test server running when a builder stops.
- `gh` 2.46 has no `--parent`; use `gh api repos/<o>/<r>/issues/<n>/sub_issues`. Native `blocked_by` worked across repos.
- A hook may block a commit on a protected branch; create the branch in a separate command first.
- `herdr worktree create` needs `--cwd <repo>` for a repo other than the current one.
- A stale local `master` is not the base; branch from `origin/master`.
- Watch the plan usage shown in the builder status bar. Near the limit, verify and mutate yourself instead of dispatching another reviewer, and say so in the hand-back.
- Every round is a row in `.scratch/horde/results.tsv`, extensions included.
