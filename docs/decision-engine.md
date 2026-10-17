# Decision engine (Clef-Flash in shadow mode)

Claude Code hands closed-ended decisions to a cheap local model instead of spending them on the
big model. Vocabulary in [`GLOSSARY.md`](../GLOSSARY.md): Decision, Decision engine, Fallback,
Fail open, Shadow mode.

- **Engine**: [Clef-Flash](https://huggingface.co/Cloudflare/clef-flash) (Cloudflare, 9B,
  Apache-2.0), `Q4_K_M` GGUF served by llama.cpp's `llama-server` on `/v1/systemone`.
- **Fallback**: Haiku 5.5 via `claude -p`, only when the engine's confidence is below `0.6`.
- **Shadow mode**: every Decision is made and logged; none is applied yet.
- Identifiers in code and logs stay in Spanish (`respaldo` = fallback, `ninguna` = none).

## What gets decided

| Decision | When | Options |
|---|---|---|
| `modelo-hilo` (main-thread model) | Every user prompt | haiku / sonnet / opus / ninguna |
| `skill` | Every user prompt | 13 curated skills / ninguna |
| `modelo-skill` (skill model) | When `skill` ≠ ninguna | haiku / sonnet / opus / ninguna |
| `modelo-subagente` (subagent model) | Every `PreToolUse` on `Agent` | haiku / sonnet / opus / ninguna |
| `agent` | Every user prompt | researcher / builder / test-runner / docs-reviewer / pr-reviewer / none |

`agent` is the one Decision with English identifiers (`agent`, `none`); the others keep Spanish.

- Questions and criteria: [`claude/.claude/hooks/decisiones.json`](../claude/.claude/hooks/decisiones.json).
- Input: only the prompt text (or the agent's `description` + `prompt`), cut to 6,000 characters.
- Prompts starting with `<` (notifications, internal commands) are skipped.

## Agents and the frontmatter suggestion

The engine decides the model of a subagent; the `model:` in the agent's frontmatter only
suggests one.

- On `PreToolUse(Agent)` the hook finds the agent by `subagent_type` in `agentsDir`
  (`~/.claude/agents`) and prepends `[agent suggests model: <m>]` to the question. The log keeps
  it as `suggested`, next to `final`; `decisiones-report` prints how often the engine differed.
- While in shadow mode nothing is applied, so the frontmatter `model:` is what runs. It is also
  the fallback when the engine fails open or answers `ninguna`.
- When `modelo-subagente` starts acting (`updatedInput.model`), its answer wins over the
  frontmatter. The acting requirements below still apply first.
- `agent` only picks the subagent. It does not pick the model; `modelo-subagente` does, once the
  agent is launched.

## Pieces

| Piece | What it does |
|---|---|
| `claude/.claude/hooks/decision-shadow.mjs` | `UserPromptSubmit` and `PreToolUse(Agent)` hook; spawns a background worker and exits in ~30 ms |
| `clef/.config/systemd/user/clef.socket` | Listens on `127.0.0.1:8770`; the first connection starts the engine |
| `clef/.config/systemd/user/clef.service` | `systemd-socket-proxyd --exit-idle-time=300s` to `127.0.0.1:8771` |
| `clef/.config/systemd/user/clef-server.service` | `llama-server`; `StopWhenUnneeded`, waits for `/health` 200 |
| `clef/.local/bin/clef-server` | Wrapper: CUDA `LD_LIBRARY_PATH` and the `llama-server` flags |
| `clef/.local/bin/decisiones-report` | Per-Decision summary of the log |
| `scripts/modules/llama.sh` | `ensure_clef()`: pinned llama.cpp, API key, enables the socket |
| `scripts/download-clef-model.sh` | Downloads the GGUF (~6.5 GB) to `~/.local/share/clef/` |

## Lifecycle

- Nothing runs at boot: only `clef.socket` listens.
- First Decision: cold start in ~4.6 s (measured through the socket on WSL2 with the RTX 3080).
- Warm: ~90 ms (model) and ~170 ms (skill).
- 2 min idle: `--sleep-idle-seconds 120` unloads the model (VRAM 6.6 → ~0.8 GB); wakes in ~2 s.
- 5 min without connections: the proxy exits and `clef-server` stops; all VRAM is freed.
- Every Claude Code session shares the same server.

## Install

`scripts/bootstrap.sh` calls `ensure_clef` after linking the packages. It installs only if
`nvidia-smi -L` answers:

1. Downloads the `llama` and `cudart-llama` tarballs of release `LLAMA_CPP_VERSION` (CUDA 12.8),
   checks their sha256, and moves them to `~/.local/share/llama.cpp/<version>` with `current`
   pointing there.
2. Creates `~/.config/clef/api-key` (mode 600).
3. Enables `clef.socket` with `systemctl --user`; if that fails, deletes the key.

The model is separate because of its size:

```sh
scripts/download-clef-model.sh   # resumes if interrupted; HF_TOKEN speeds it up
```

- To upgrade llama.cpp: change `LLAMA_CPP_VERSION` and both `LLAMA_CPP_SHA256` in `scripts/modules/llama.sh`, then re-run the bootstrap.
- The tarballs and the GGUF (pinned HF revision) are checked by sha256; on mismatch nothing is installed.
- Clef needs llama.cpp ≥ b11622 (PR ggml-org/llama.cpp#29831).
- Without the `cudart` tarball libs on `LD_LIBRARY_PATH`, `llama-server` silently runs on CPU.

## Platforms

| Setup | Status |
|---|---|
| Ubuntu/WSL2 with NVIDIA | Installed and tested end to end |
| Arch/Omarchy, Bazzite with NVIDIA | Same tarball and units; untested |
| macOS, Linux without NVIDIA | Nothing installed; fail open |

- On CPU Clef-Flash is just as accurate but takes ~9 s per Decision, so it is not installed without a GPU.
- Metal (Apple Silicon) and Vulkan are unmeasured.

## Fail open and fallback

- The hook never prints anything or blocks: Claude Code carries on as if the engine did not exist.
- Without `~/.config/clef/api-key` (engine not installed), the worker exits without logging.
- If the engine fails or takes more than 15 s: `error` is logged and the fallback is **not** called.
- If the engine answers with confidence < `0.6`: Haiku 5.5 decides, with no tools, MCP, user settings or saved session.
- The log is `0600` (it holds prompt text); fallback errors never include the prompt.
- `DECISIONES_OFF=1` turns the hook off; `DECISIONES_WORKER=1` marks the worker so it never decides in a loop.

## Log

One JSON line per Decision in `~/.local/state/decisiones/YYYY-MM.jsonl`:

```json
{"ts":"…","session_id":"…","transcript_path":"…","decision":"skill","input":"…",
 "motor":{"choice":"code-review","confidence":0.93,"ms":322},"respaldo":null,
 "final":"code-review","applied":false,"error":null}
```

```sh
decisiones-report   # per Decision: volume, engine/fallback/error, chosen options
```

## From shadow to acting

Per Decision, not global. Requirements:

- ≥ 200 real log lines for that Decision.
- ≥ 95 % accuracy of `final` on a hand-labelled sample of 50.
- `modelo-hilo` never waits for the fallback when acting: below the threshold it fails open.

Acting is not implemented. Each Decision needs its own hook point (see
[`docs/claude-code.md`](claude-code.md)): `updatedInput.model` in `PreToolUse(Agent)`,
`additionalContext` in `UserPromptSubmit` for the skill, and a mod with `turn.step` for the thread.

## Measurement

84 own cases (44 model, 40 skill) on the RTX 3080; label sample reviewed on 2026-10-14:

| | model | skill | latency |
|---|---|---|---|
| Clef-Flash Q4 | 89 % (97 % at conf ≥ 0.6, covers 82 %) | 98 % (100 % at conf ≥ 0.6, covers 85 %) | ~90 / ~170 ms |
| Clef-Flash Q8 | same as Q4, 9.7 GB VRAM | same as Q4 | ~80 / ~160 ms |
| Haiku 5.5 | 98 % | 100 % | ~3.5 s |
