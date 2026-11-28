# Desktop app launch

Replaces `batch.md` when `HC_TERMINAL_ID` is set. The orchestration rules stay in `SKILL.md`. Do not mix with the TUI `herdr` commands.

Create the ticket's worktree at `~/.herdr/worktrees/<repo>/<slug>` (slug: branch lowercased, `/` → `-`) with `git -C <repo> worktree add -b <branch> <path> <base>`, then open its space:

```bash
herdr-app do space.new --name <repo>-<slug> --folder <worktree> --argv '["claude-9r"]' --task "$(cat .scratch/horde/<id>/prompt.md)" --focus false
```

- Read `.terminal` (for example `t8`) from the JSON and keep it per ticket. Never guess it.
- `.claude/settings.json` untracked: `cp` it into the worktree first.
- Same prompt, checks and frozen set as the TUI flow; only the launch and monitor commands differ.

| Step | Command |
|---|---|
| Monitor | `hc wait <t>` in the background (`run_in_background`); `timeout` is a check-in, wait again |
| Read result | `hc read --lines 100 <t>` |
| Next round | `hc send <t> "<text>"` |
| Overview | `herdr-app ls`, `hc ls` |
| Close after merge | `herdr-app do space.close` for the ticket's space (check `herdr-app commands` for its arguments); keep the worktree and branch |

A permission or trust dialog is the user's to answer; tell them, never answer it. Round metrics (`batch.md`) read the transcript the same way; if the session id is unknown, leave those fields empty.
