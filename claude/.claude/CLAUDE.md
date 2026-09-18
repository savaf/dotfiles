# Global guidance

Each tool call is a request that re-sends the whole conversation, so fewer, fatter turns
cost less than many thin ones.

- Batch independent tool calls into a single message; don't serialize what has no dependency.
- Prefer one composed shell command over several round trips when the steps are known upfront.
- For single-fact lookups (one known file, symbol, or value), use Grep/Glob/Read directly.
- Delegate broad searching to a subagent: it starts on clean context and returns the conclusion.
- The longer the conversation, the cheaper that trade gets. Judge by context size, not file count.
- Don't re-read files already read in this conversation.
- Prefer CLI tools (`gh`, `git`, etc.) over MCP tools when both can do the job.
- Keep answers concise; don't duplicate file contents in summaries.

## Workflow

- Coding: climb the `ponytail` ladder first (exists in repo → stdlib → native → one line).
  Deletion over addition.
- Feature or fix with tests: `tdd`. Hard bug or perf regression: `diagnosing-bugs`.
- Fuzzy plan or design: `grilling`; record terms and decisions with `domain-modeling`.
- Before merging: `code-review`; over-engineering only: `ponytail-review`.
- Delegate: Explore finds, Plan designs, reviewers read the diff, contrarian then
  feedback-resolver weigh options.
