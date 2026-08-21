---
name: doc-write
description: "Write or edit persistent markdown: AGENTS.md, CLAUDE.md, README, docs/, SKILL.md, and agent config. Invoke before writing or editing any such file. Skip transient plan files and issue/PR templates."
argument-hint: "[file path and what to write]"
---

# Doc Writer

Applies to markdown that persists and gets re-read: `AGENTS.md`, `CLAUDE.md`, `README.md`,
`docs/**`, `SKILL.md`, and files under `.claude/`, `.agents/`, `.cursor/`, `.github/`.

Skip transient plan files and `.github/{PULL_REQUEST,ISSUE}_TEMPLATE/` (those have their own
format).

## Principles

- Rules first, examples after.
- One idea per line.
- Factual. No hedging, no softening.
- Plain. No marketing language.
- If a sentence can be a bullet, make it a bullet.
- Ground every claim in the repo. An unverified claim is worse than no line.

## Prohibited

- Filler: "Note that", "In order to", "Make sure to", "It's important", "Please note".
- Multi-sentence lines outside code blocks.
- Paragraphs where a list would do.
- Restating what the code or the file tree already shows.

## Steps

1. **Read the target file if it exists.** Match its structure exactly: heading depth, list
   marker, table shape, code-fence language tags. The house style beats this skill's style.
2. **Read two sibling files** in the same directory to calibrate voice before writing a new one.
3. **Draft**, applying the rules above line by line.
4. **Check before writing**: filler phrases, prose paragraphs, non-structural lines over 100
   chars, claims you did not verify.
5. **Write**, then re-read what landed.

## Scope

Keep the edit to the section you were asked to change. Do not reorder, do not fix unrelated
drift, do not rewrite adjacent sections. Raise them separately if they matter.
