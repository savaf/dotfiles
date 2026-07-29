# Global guidance

Each tool call is a request that re-sends the whole conversation, so fewer, fatter turns
cost less than many thin ones.

- Batch independent tool calls into a single message; don't serialize what has no dependency.
- Prefer one composed shell command over several round trips when the steps are known upfront.
- For single-fact lookups (one known file, symbol, or value), use Grep/Glob/Read directly;
  reserve subagents for broad multi-file sweeps where you only need the conclusion.
- Don't re-read files already read in this conversation.
- Prefer CLI tools (`gh`, `git`, etc.) over MCP tools when both can do the job.
- Keep answers concise; don't duplicate file contents in summaries.
