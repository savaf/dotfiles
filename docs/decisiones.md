# Motor de decisiones (Clef-Flash en Modo sombra)

Claude Code delega decisiones cerradas a un modelo local barato en vez de gastarlas en el modelo
grande. Vocabulario en [`GLOSSARY.md`](../GLOSSARY.md): Decisión, Motor de decisiones, Respaldo,
Fallo abierto, Modo sombra.

- **Motor**: [Clef-Flash](https://huggingface.co/Cloudflare/clef-flash) (Cloudflare, 9B,
  Apache-2.0), GGUF `Q4_K_M` servido por `llama-server` de llama.cpp en `/v1/systemone`.
- **Respaldo**: Haiku 5.5 vía `claude -p`, solo si la confianza del Motor queda bajo `0.6`.
- **Modo sombra**: todo se decide y se registra; nada se aplica todavía.

## Qué se decide

| Decisión | Cuándo | Opciones |
|---|---|---|
| `modelo-hilo` | Cada prompt del usuario | haiku / sonnet / opus / ninguna |
| `skill` | Cada prompt del usuario | 13 skills curadas / ninguna |
| `modelo-skill` | Si `skill` ≠ ninguna | haiku / sonnet / opus / ninguna |
| `modelo-subagente` | Cada `PreToolUse` de `Agent` | haiku / sonnet / opus / ninguna |

- Preguntas y criterios: [`claude/.claude/hooks/decisiones.json`](../claude/.claude/hooks/decisiones.json).
- Entrada: solo el texto del prompt (o `description` + `prompt` del agente), recortado a 6.000 caracteres.
- Los prompts que empiezan por `<` (notificaciones, comandos internos) no se deciden.

## Piezas

| Pieza | Qué hace |
|---|---|
| `claude/.claude/hooks/decision-shadow.mjs` | Hook de `UserPromptSubmit` y `PreToolUse(Agent)`; lanza un trabajador en segundo plano y sale en ~30 ms |
| `clef/.config/systemd/user/clef.socket` | Escucha en `127.0.0.1:8770`; la primera conexión arranca el Motor |
| `clef/.config/systemd/user/clef.service` | `systemd-socket-proxyd --exit-idle-time=300s` hacia `127.0.0.1:8771` |
| `clef/.config/systemd/user/clef-server.service` | `llama-server`; `StopWhenUnneeded`, espera a `/health` 200 |
| `clef/.local/bin/clef-server` | Wrapper: `LD_LIBRARY_PATH` de CUDA y los flags de `llama-server` |
| `clef/.local/bin/decisiones-report` | Resumen del registro por Decisión |
| `scripts/modules/llama.sh` | `ensure_clef()`: llama.cpp fijado, API key, activa el socket |
| `scripts/download-clef-model.sh` | Baja el GGUF (~6,5 GB) a `~/.local/share/clef/` |

## Ciclo de vida

- Nada corre al arrancar la máquina: solo `clef.socket` escucha.
- Primera Decisión: arranque en frío en ~4,6 s (medido por el socket en WSL2 con la RTX 3080).
- En caliente: ~90 ms (modelo) y ~170 ms (skill).
- 2 min sin uso: `--sleep-idle-seconds 120` descarga el modelo (VRAM 6,6 → ~0,8 GB); despierta en ~2 s.
- 5 min sin conexiones: el proxy sale y `clef-server` se para; se libera toda la VRAM.
- Todas las sesiones de Claude Code comparten el mismo servidor.

## Instalación

`scripts/bootstrap.sh` llama a `ensure_clef` tras enlazar los paquetes. Solo instala si
`nvidia-smi -L` responde:

1. Baja los tarballs `llama` y `cudart-llama` de la release `LLAMA_CPP_VERSION` (CUDA 12.8) a
   `~/.local/share/llama.cpp/<versión>` y apunta `current` ahí.
2. Genera `~/.config/clef/api-key` (permisos 600).
3. Activa `clef.socket` con `systemctl --user`.

El modelo va aparte por su tamaño:

```sh
scripts/download-clef-model.sh   # reanuda si se corta; HF_TOKEN acelera
```

- Para subir llama.cpp: cambia `LLAMA_CPP_VERSION` en `scripts/modules/llama.sh` y re-ejecuta el bootstrap.
- Clef necesita llama.cpp ≥ b11622 (PR ggml-org/llama.cpp#29831).
- Sin las libs del tarball `cudart` en `LD_LIBRARY_PATH`, `llama-server` corre en CPU sin avisar.

## Plataformas

| Setup | Estado |
|---|---|
| Ubuntu/WSL2 con NVIDIA | Instalado y probado de punta a punta |
| Arch/Omarchy, Bazzite con NVIDIA | Mismo tarball y mismas unidades; sin probar |
| macOS, Linux sin NVIDIA | No se instala nada; Fallo abierto |

- En CPU Clef-Flash acierta igual pero tarda ~9 s por Decisión: por eso no se instala sin GPU.
- Metal (Apple Silicon) y Vulkan están sin medir.

## Fallo abierto y Respaldo

- El hook nunca imprime nada ni bloquea: Claude Code sigue como si el Motor no existiera.
- Sin `~/.config/clef/api-key` (Motor no instalado), el trabajador sale sin registrar.
- Si el Motor falla o tarda más de 15 s: se registra `error` y **no** se llama al Respaldo.
- Si el Motor responde con confianza < `0.6`: decide Haiku 5.5 (`--setting-sources project`, sin sesión persistida).
- `DECISIONES_OFF=1` apaga el hook; `DECISIONES_WORKER=1` marca al trabajador para no decidir en bucle.

## Registro

Una línea JSON por Decisión en `~/.local/state/decisiones/AAAA-MM.jsonl`:

```json
{"ts":"…","session_id":"…","transcript_path":"…","decision":"skill","input":"…",
 "motor":{"choice":"code-review","confidence":0.93,"ms":322},"respaldo":null,
 "final":"code-review","applied":false,"error":null}
```

```sh
decisiones-report   # por Decisión: volumen, motor/respaldo/error, opciones elegidas
```

## Pasar de sombra a actuar

Por Decisión, no global. Requisitos:

- ≥ 200 registros reales de esa Decisión.
- ≥ 95 % de acierto de `final` sobre una muestra de 50 etiquetada a mano.
- `modelo-hilo` nunca espera al Respaldo al actuar: bajo el umbral, Fallo abierto.

Actuar no está implementado. Cada Decisión necesitará su enganche (ver
[`docs/claude-code.md`](claude-code.md)): `updatedInput.model` en `PreToolUse(Agent)`,
`additionalContext` en `UserPromptSubmit` para la skill, y un mod con `turn.step` para el hilo.

## Medición

84 casos propios (44 de modelo, 40 de skill) en la RTX 3080; muestra de etiquetas revisada el 2026-10-14:

| | modelo | skill | latencia |
|---|---|---|---|
| Clef-Flash Q4 | 89 % (97 % con conf ≥ 0,6, cubre 82 %) | 98 % (100 % con conf ≥ 0,6, cubre 85 %) | ~90 / ~170 ms |
| Clef-Flash Q8 | igual que Q4, 9,7 GB de VRAM | igual que Q4 | ~80 / ~160 ms |
| Haiku 5.5 | 98 % | 100 % | ~3,5 s |
