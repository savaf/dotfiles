# Receta de ajuste de Laya con datos propios

Fecha: 2026-10-14. Fuente: repo `NandhaKishorM/laya` en `main`, commit `432312b` (paquete 0.4.7, `pyproject.toml`).
Rutas citadas relativas al repo. Todo lo no verificado está en la sección final.

## Respuesta corta

- Laya trae entrenamiento propio: CLI `laya-train` y API `laya.train.finetune` (`docs/finetune.md`, `laya/train.py`, `laya/train_cli.py`). Una sola GPU, MPS o CPU.
- Método: **ajuste completo** (encoder + cabeza de decisión) por defecto; `--freeze-encoder` entrena solo la cabeza (cabe en GPU pequeña, "gana mucho menos"). **LoRA no existe**: no hay referencias a `peft`/`lora` en el código ni en la documentación de entrenamiento; la única mención es que un adaptador LoRA solo "no es un checkpoint completo" (`docs/docker.md`).
- Formato: CSV (columna de texto + columna de etiqueta, que se convierte en una pregunta `choice` con las etiquetas distintas como opciones) o JSONL con `state`, `questions` y `expected`.
- Datos usados: typed-decisions pasó de 0,362 a 0,766 con **6.000 decisiones de entrenamiento** (1.200 casos), evaluadas en 2.000 decisiones de test, 4 épocas.
- Calibración: **sí** viene incluida. `laya-train` aparta una porción de calibración antes de entrenar y ajusta una temperatura por tipo de pregunta.
- Carga en `laya-serve`: `LAYA_EXTRA_MODELS='{"nombre": "/ruta/al/checkpoint"}'`, y el cliente fija `model: "nombre"`; o se registra bajo un nombre integrado para sustituirlo.

## 1. Método soportado

`docs/finetune.md` ("Fine-tune with `laya-train`", "Options"): `laya-train` "builds the training items, fine-tunes, fits calibration temperatures on a slice held out before training, and saves a checkpoint `laya.load` opens. It runs on one device: CUDA, MPS or CPU."

- Ajuste completo por defecto (`freeze_encoder: bool = False`, `laya/train.py`). Dos tasas de aprendizaje: encoder 2,5e-5, cabeza 1e-4 (AdamW, coseno).
- `--freeze-encoder`: solo cabeza; "fits a small GPU or a CPU, but gains much less than a full fine-tune" (`docs/finetune.md`). La documentación leída no cuantifica cuánto menos.
- Pérdida: `rlcd` (por defecto: gradiente de política con ruido tipo GRPO más entropía cruzada suave) o `soft-ce` (solo entropía cruzada suave). Medición del propio repo en una T4, 6.000 decisiones, una semilla (`docs/finetune.md`, tabla "What the options are worth", issue #887):

  | ejecución | exactitud | ECE |
  |---|---|---|
  | checkpoint base | 0,362 | 0,174 |
  | `rlcd` (defecto) | 0,7715 | 0,150 |
  | `soft-ce` | 0,790 | 0,157 |
  | `soft-ce --shuffle-options` | 0,7875 | 0,159 |

  Con 4 opciones el barajado de opciones "changes nothing measurable"; con 20 opciones sube 0,55 puntos. Para 4 opciones basta `soft-ce` sin barajar.
- LoRA / PEFT: no soportado. Habría que escribir el bucle propio sobre `train_model` y `calibration_records`, las dos mitades de `finetune`.

## 2. API y CLI de entrenamiento

```bash
laya-train --data decisiones.csv --text-column texto --label-column modelo \
           --base multilingual --loss soft-ce --out ./laya-subagente
laya-train ... --dry-run     # sin cargar pesos: filas, ítems, motivos de descarte y presupuesto de updates
```

```python
from laya.train import TrainConfig, finetune
report = finetune("train.jsonl", "multilingual", "./out", TrainConfig(loss="soft-ce"))
```

Opciones (`docs/finetune.md`): `--epochs 4`, `--micro-batch 8`, `--grad-accum 8` (batch efectivo 64), `--max-len`/`--head-max-len` (por defecto los del checkpoint base), `--label-smoothing`, `--shuffle-options`, `--eval/--eval-data`, `--target-error 0.10`, `--min-abstain-n 10`, `--device`, `--seed`. AMP activo en CUDA; `gradient_checkpointing` sigue a AMP por defecto (`laya/train.py`). Entry point `laya-train` en `pyproject.toml`; el extra de dependencias de entrenamiento no lo identifiqué (sin verificar).

Presupuesto: `updates = epochs * ceil(ceil(train_items / micro_batch) / grad_accum)`; el defecto gasta 352 updates sobre 6.000 decisiones.

## 3. Formato de datos para una pregunta `choice` con opciones fijas

CSV (`docs/finetune.md`): una fila por decisión; la columna de etiqueta pasa a ser una pregunta `choice` sobre sus valores distintos "in the order they first appear"; id con `--question-id` (por defecto `label`), instrucciones con `--instructions`; se guarda `questions.json` junto al checkpoint y hay que hacer la misma pregunta en inferencia. Filas con texto o etiqueta vacíos se omiten.

JSONL, un caso por línea, para controlar las descripciones de opciones:

```json
{"state": "...texto de la tarea...",
 "questions": {"modelo": {"type": "choice", "instructions": "¿Qué modelo debe ejecutar el subagente?",
                          "criteria": {"haiku": "...", "sonnet": "...", "opus": "...", "ninguna": "..."}}},
 "expected": {"modelo": "sonnet"}}
```

- `expected` = una respuesta por pregunta; mismo formato que lee `laya-evals`, así el mismo fichero sirve para entrenar y evaluar.
- Alternativa `gold` con probabilidades de un maestro por opción (formato del notebook).
- Etiquetas: el README ("Honest limits") avisa que no se usen etiquetas booleanas (`true`/`false`, `yes`/`no`) y que las claves semánticas no garantizan seguridad con negaciones (#377). `haiku/sonnet/opus/ninguna` son claves semánticas, válidas; `ninguna` es una opción más, no una abstención (la abstención de Laya es por umbral de confianza, véase §7).
- Descartes que reporta `--dry-run`: `options_collapsed`, `options_beyond_max_len` (si las descripciones de opciones no caben).

## 4. Cuántos ejemplos

- typed-decisions: 1.200 casos = 6.000 decisiones de entrenamiento, 4 épocas, batch efectivo 64; test de 400 casos = 2.000 decisiones (`docs/finetune.md`). El 0,766 publicado es del checkpoint `laya-typed-decisions`; la repetición con `laya-train` dio 0,7715 (`rlcd`) y 0,790 (`soft-ce`).
- MASSIVE inglés, 20 opciones: 11.514 filas de entrenamiento, 0,730 a 0,936 (base a ajustado).
- Ejemplo del navegador: ~14.000 decisiones (5.244 + 700 + 659 + 7.296 + 177), 4 épocas (`docs/finetune_browser_agent.md`).
- **Límite inferior**: el código avisa de que el presupuesto por defecto "is sized for a few thousand typed decisions"; con unos cientos o ~1.000 filas la cabeza puede colapsar al prior en silencio (issue #963: 1.100 ítems de entrenamiento = 72 updates colapsó; 8 épocas seguía fallando; 9 de 15 ejecuciones salieron de la meseta y 6 no en 32 épocas con idénticos datos; `laya/train.py` `prior_collapse_message`, `docs/finetune.md`). Se avisa por pantalla; hay que repetir con semillas distintas y subir épocas.
- Consecuencia para este caso: unas 1.000-6.000 etiquetas sintéticas es el orden de magnitud validado; una muestra de 50-100 revisadas a mano sirve para validar, no para entrenar.

## 5. VRAM y tiempo en RTX 3080 10 GB (WSL2)

No hay cifra publicada para 10 GB ni para WSL2. Lo que sí hay:

- Notebook de Kaggle: 2 x T4 (16 GB cada una), `max_len` 1024, `head_max_len` 256, micro-batch 8, fp16, gradient checkpointing en encoder y cabeza, tope de 4096 tokens por lote. Demo de 6.000 decisiones: 4-6 min en 2xT4; ~4-5 h para cuatro épocas sobre ~30.000 preguntas (`docs/finetune.md`).
- `docs/finetune_browser_agent.md`: una RTX 4070 Ti SUPER de 16 GB, **sin** gradient checkpointing (1,25x más rápido): 4 épocas en ~2 h para el modelo de 421M y ~1 h para el de 322M, con ~14.000 decisiones y cabeza de 768 tokens.
- Guía para Mac de 16 GB: `--micro-batch 1 --grad-accum 32` con checkpointing en encoder y cabeza (README, "Fine-Tuning").
- Estimación propia, sin medir: el modelo de 421M en AdamW fp32 ocupa del orden de 421M x 16 B ~ 6,7 GB entre pesos, gradientes y dos estados, antes de activaciones. En 10 GB es ajustado; plan prudente: `--micro-batch 1-2 --grad-accum 32-64`, mantener gradient checkpointing, `--max-len 512`. Para el multilingual (322M) hay más margen.
- Duración orientativa por extrapolación (no medida): con 1.000-6.000 ejemplos cortos, de minutos a pocas decenas de minutos en una 3080.

## 6. Checkpoint base recomendado

Tabla del README: `laya` (ModernBERT-large, 421M, contexto 512, inglés); `laya-multilingual` (mmBERT-base, 322M, 1024 hasta 8.192, 100+ idiomas, 2x más rápido); `laya-typed-decisions` (ModernBERT-large, 421M, 1024, workflows typed-decisions). `--base` acepta directorio, alias (`english`, `multilingual`, `typed-decisions`) o repo del Hub.

Para texto en español e inglés: `multilingual` es la elección razonable por idioma, contexto y velocidad. Razones del repo: el checkpoint inglés "collapses on non-Latin scripts" (README), y desde 0.4.0 el `Router` manda el texto corto sin evidencia de idioma al multilingual. Tras ajustar, el punto de partida zero-shot (typed-decisions 58 % en nuestro caso base) importa menos que el idioma y el tamaño; partir de `typed-decisions` no tiene ventaja documentada fuera de sus 4 workflows. No hay publicada comparación `multilingual` vs `typed-decisions` ajustados en español: sin verificar, hay que medirla. El multilingual sale "sin temperaturas ajustadas" (README, Calibration), así que la recalibración de §7 pesa más.

## 7. Calibración de temperaturas

Incluida en `laya-train` (`docs/finetune.md`, "Calibration is part of the run"):

- Aparta hasta 400 ítems o el 10 % (el menor) antes de entrenar (`calib_max=400`, `calib_frac=0.1`), con semilla fija.
- Tras la última época ajusta **una temperatura por tipo** (`choice`, `score`, `noul`) con LBFGS sobre log-temperatura, acotada a [0,1, 10]; 1,0 si hay menos de 10 ítems, 1,2 si el ajuste falla. Se escribe en `rl_agent_config.json` (`temperature`) y se elimina `temperature_by_options` heredado (si sobreviviera enmascararía el nuevo ajuste). Al cargar se recorta a [0,5, 5,0] (README).
- Informe de calibración en `training.laya_train_calibration` del config; avisa si no se pudo ajustar.
- También ajusta umbrales de abstención por cubo (`--target-error 0.10`, `--min-abstain-n 10`) que `min_confidence` consume (README). Un cubo con menos de 10 ítems se gatea a 0,0 (nada se abstiene) salvo que el llamador fije `min_confidence`.
- Límites: la porción es pequeña "on purpose" (suficiente para tres escalares, no para validar). Escalar la temperatura no cambia el argmax. En 4 opciones el ECE tras el ajuste con `soft-ce` fue 0,157 (base 0,174): mejora modesta, sin garantía. El umbral de confianza y la tasa de escalado a Haiku se deben fijar con datos reales del modo sombra.

## 8. Cargar el checkpoint resultante en `laya-serve`

Layout que escribe `--out`: `model.safetensors`, `encoder/`, `tokenizer/`, `rl_agent_config.json`, `questions.json`, `checkpoint_latest/` (por época) (`docs/finetune.md`). `laya.load("./out")` lo abre sin API específica.

Servidor (`docs/http-api.md`, tabla de configuración y sección `model`):

```bash
LAYA_EXTRA_MODELS='{"subagente": "/ruta/disco/laya-subagente"}' laya-serve
# petición a /v1/systemone con "model": "subagente"
```

- `LAYA_EXTRA_MODELS` registra nombres adicionales con ruta local, repo del Hub o par `[repo, subfolder]`; "including a name that re-points a built-in, which is how a fine-tune is served under `english` without a code change". Un `model` que es ruta o repo no registrado da 422.
- `laya-serve` se configura solo con variables de entorno ("one image serves a laptop dev run and a systemd unit"); `LAYA_IDLE_UNLOAD_SECONDS` y `LAYA_MAX_LOADED` existen para uso intermitente.
- Docker: `LAYA_MODEL_PATH` con la ruta montada y `LAYA_MODEL=auto`; directorio escribible por el UID 10001 porque el cargador puede actualizar la configuración del tokenizador (`docs/docker.md`).
- En inferencia hay que hacer la misma pregunta que en el entrenamiento (`questions.json`).

## 9. Qué cambia para nuestro caso

- Pregunta `choice` de 4 opciones: caso favorable, con barajado de opciones sin efecto medible; usar `--loss soft-ce`.
- Datos sintéticos y etiquetas subjetivas (`ninguna`): el techo es la calidad del etiquetado; el repo lo dice así ("only as good as the targets"). Dejar un test separado y real.
- Vigilar el colapso al prior con pocos datos (§4) y no usar `min_confidence` hasta ver que la calibración se ajustó (§7).
- No afirmar mejora sin evaluar en datos reales del modo sombra: el propio repo lo exige.

## Sin verificar

- VRAM pico y tiempo reales en RTX 3080 10 GB / WSL2: no hay cifra publicada; la estimación de §5 es mía.
- Problemas específicos de CUDA en WSL2 con `laya-train` (no revisé issues).
- Nombre del extra de pip que instala las dependencias de entrenamiento, y si `pip install laya` basta.
- Diferencia numérica entre `--freeze-encoder` y ajuste completo.
- Comparación `multilingual` vs `typed-decisions` ajustados con texto en español.
- Número mínimo fiable de ejemplos con 4 opciones: solo se conocen los 6.000 que funcionaron y el colapso con ~1.100; no hay barrido intermedio.
- Que `LAYA_EXTRA_MODELS` registre y sirva el nombre sin más (no lo ejecuté), y su interacción con `LAYA_MODELS` para precarga.
- Tarjetas de modelo del Hub (`convaiinnovations/*`) y el cuaderno de Kaggle: solo leí README, docs y partes de `laya/train.py` y `train_cli.py`.
- No ejecuté nada de Laya.
