Vendored from https://github.com/anthropics/claude-code-playground (claude-code/mods/replay-theater)
at commit 569c528 (Anthropic sample mod, shared as-is; see LICENSE). Only `hooks/` copied;
`.claude-plugin/plugin.json` written here. Reviewed: it only reads files (`$.fs.read`/`exists`)
to capture the text before an edit, registers `/replay`, and always calls `next(e)`; no network,
processes, env or model calls. Repeat that check before updating.
