# Global guidance

- For single-fact lookups (one known file, symbol, or value), use Grep/Glob/Read
  directly instead of spawning subagents; reserve subagents for broad multi-file sweeps.
- Don't re-read files already read in this conversation.
- Prefer CLI tools (`gh`, `git`, etc.) over MCP tools when both can do the job.
- Keep answers concise; don't duplicate file contents in summaries.
