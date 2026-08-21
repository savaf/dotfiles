# Review Output Format

Shared by the reviewer agents in `~/.claude/agents/`. A project may override this: if the repo
defines its own review output format, follow the repo.

## Gates

Every finding passes all four. Drop it on any fail.

1. **Changed line.** Only flag code this branch changed.
2. **Requires action.** Drop it if the code is already correct.
3. **Within intent.** The caller states the intent of the change. Out-of-intent findings drop
   unless they introduce a bug.
4. **Verifiable.** Say so when the diff alone cannot confirm it. Never present a guess as a
   confirmed issue.

## Empty result

`No <your domain> issues found.`

## Findings table

Sort by severity, blockers first.

| # | Severity | File | Line | Issue |
|---|----------|------|------|-------|
| 1 | blocker | src/cart/Cart.tsx | 42 | `dangerouslySetInnerHTML` fed from `product.description` (user-controllable). |

One to two sentences per finding. Append a fenced `suggestion` block right after the row when
the fix is concrete.

## Severity

| Level | Meaning |
|-------|---------|
| `blocker` | Must fix before merge |
| `issue` | Should fix: a bug or a violated project convention |
| `nit` | Minor, optional |
| `question` | Needs clarification |
| `thought` | Observation or alternative |

## Skip

Style, naming, and formatting a linter or formatter owns. TODOs. Preferences the project has not
written down.
