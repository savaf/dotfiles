# Instalación de Laya 0.4.7 en todos los setups

Fecha: 2026-10-14. Ticket: `.scratch/laya-motor/issues/02-instalacion-multi-os.md`.

Fuentes primarias: metadata de PyPI (`pypi.org/pypi/laya/json`), README de
`github.com/NandhaKishorM/laya` y su `setup_laya.sh`, API de HF
(`huggingface.co/api/models/convaiinnovations/laya?blobs=true`), PyPI de `torch`.
Lo marcado **[medido]** se verificó instalando en WSL2 (Ubuntu, Python 3.14.4, 8 cores,
15 GB RAM, disco real, uv 0.13.1) en un directorio desechable. Lo marcado
**[no verificado]** no se pudo probar aquí (macOS, Arch, Bazzite, CUDA).

## Conclusión corta

Usar **`uv tool install "laya[serve]==0.4.7" --torch-backend=cpu`**. Deja `laya`,
`laya-serve`, `laya-evals`, `laya-mcp-server` y `laya-train` en `~/.local/bin`, aislados
en su propio venv, sin sudo y sin tocar el Python del sistema. Es el mismo comando en
Ubuntu/WSL2, Arch/Omarchy, Bazzite y macOS Apple Silicon. Solo el Mac Intel necesita pins
extra (ver abajo). Los pesos se bajan solos de HF la primera vez que se usa un checkpoint.

## Metadata del paquete (PyPI, 0.4.7)

- Wheel `py3-none-any` de 400 KB; sdist 1.2 MB. Licencia Apache-2.0. `requires-python >=3.10`.
- Dependencias base: `torch>=2.0.0`, `transformers>=4.48.0`, `safetensors>=0.4.0`,
  `huggingface_hub>=0.20.0`, `numpy>=1.20.0`.
- Extra `serve`: `fastapi>=0.110.0`, `uvicorn>=0.27.0`, `python-multipart>=0.0.9`.
- Otros extras: `fast` (tilelang, solo GPU), `mcp`, `structured` (pydantic), `onnx`
  (con `numpy<2` en macOS x86_64), `langchain`, `langgraph`, `llamaindex`, `crewai`.
- Entry points **[medido]**: `laya`, `laya-evals`, `laya-mcp-server`, `laya-serve`, `laya-train`.
- No fija torch con `==`; sin indicación, pip/uv en Linux x86_64 resuelve el torch de PyPI,
  que es la build CUDA (wheel de 555 MB más las libs `nvidia-*`). Por eso hay que pedir CPU.

## Gestor: uv tool

README de Laya documenta `uv venv` + `uv pip install` y menciona
`--torch-backend=auto|cpu` ("funciona solo con `uv pip`"). Verificado en la práctica que
`uv tool install ... --torch-backend=cpu` también lo acepta en uv 0.13.1 **[medido]**.

| Opción | Veredicto |
|---|---|
| `uv tool` | Elegida: aislado, comandos en PATH, `uv tool upgrade/uninstall`, Python gestionado si falta, soporta `--python` y `--with`. |
| `pipx` | No necesita uv pero no tiene equivalente a `--torch-backend`; habría que usar `--pip-args="--index-url https://download.pytorch.org/whl/cpu --extra-index-url https://pypi.org/simple"`. Más frágil. |
| `python -m venv` (README) | Falla en Ubuntu sin `python3-venv`: en esta WSL falló con `ensurepip is not available` **[medido]**. Además exige gestionar a mano rutas y PATH. |

Instalación de uv por plataforma:
- Arch/Omarchy: `uv` está en `extra` (0.13.1 en la consulta a archlinux.org). Va en `pacman-cli.txt`.
- macOS: `brew install uv` (fórmula 0.13.1, formulae.brew.sh). Va en `brew-cli.txt`.
- Ubuntu/WSL2 y Bazzite: no tomar de apt/rpm-ostree (no se evaluó que exista versión usable;
  en Bazzite evitar layering). Usar el instalador oficial de Astral (`curl -LsSf https://astral.sh/uv/install.sh | sh`,
  sin sudo, instala en `~/.local/bin`), el mismo patrón que ya usa el repo para `mise`
  (`ensure_mise`) y `herdr`. No ejecuté ese script (sandbox); bajé el tarball de GitHub
  releases (`uv-x86_64-unknown-linux-gnu.tar.gz`, binario de 38 MB) y funciona.

## Comandos por plataforma

Linux x86_64 / Apple Silicon (CPU por defecto):

```sh
uv tool install "laya[serve]==0.4.7" --torch-backend=cpu
```

En macOS Apple Silicon `--torch-backend=cpu` es inocuo (PyPI solo tiene la build normal);
la GPU (MPS) se usa sola: orden automático CUDA → MPS → XPU → CPU (README).

Mac Intel (x86_64): PyPI solo publica wheels macOS x86_64 de torch hasta **2.2.2**
(cp38-cp312; confirmado en `pypi.org/pypi/torch/json`: 2.14.1 solo trae `macosx_14_0_arm64`).
El README y `setup_laya.sh` fijan: `numpy<2`, `torch==2.2.2`, `transformers==4.57.6`
(5.x pide torch>=2.4), `huggingface_hub>=0.34,<1.0`. Con uv tool, forma probable
**[no verificado]**:

```sh
uv tool install --python 3.12 "laya[serve]==0.4.7" \
  --with "numpy<2" --with "torch==2.2.2" --with "transformers==4.57.6" \
  --with "huggingface_hub>=0.34,<1.0"
```

Python debe ser <=3.12 en Intel (no hay wheels cp313+ de torch 2.2.2). Apple Silicon: la
wheel de torch 2.14.1 es `macosx_14_0_arm64`, o sea exige macOS 14+; con macOS menor habría
que fijar torch más viejo (**[no verificado]**).

CUDA opcional (Ubuntu/WSL2, Arch, Bazzite con NVIDIA): reinstalar con
`uv tool install --reinstall "laya[serve]==0.4.7" --torch-backend=auto` (o `cu128`, etc.).
Detecta el driver. La máquina de pruebas tiene RTX 3080, pero no instalé la build CUDA
(varios GB, **[no medido]**). Laya la usa sola (`LAYA_DEVICE=cuda`, bf16 por defecto;
`LAYA_CUDA_AMP`). `laya[fast]` (tilelang) es solo GPU y opcional.
En WSL2 el driver CUDA lo da Windows; no instalar toolkit en la distro.

## Tamaño en disco **[medido]**

| Concepto | Tamaño |
|---|---|
| venv de `uv tool` (laya + serve + torch 2.14.1+cpu + transformers 5.19.0 + fastapi/uvicorn) | 929 MB |
| Caché de uv | 24 MB tras la instalación |
| Pesos checkpoint `laya` (inglés) en caché HF | 808 MB |
| Python gestionado por uv (si no hay uno del sistema) | no medido; ~30-40 MB típico |
| Instalación completa (venv + inglés) | ~1.75 GB |
| Los tres checkpoints (API HF, suma de blobs) | 2.37 GB (≈ 2.3 GB del README) |

Detalle de la API HF (`siblings`, bytes): `model.safetensors` 842.6 MB (inglés);
`multilingual/model.safetensors` 643.8 MB + tokenizer 34.4 MB;
`typed-decisions/model.safetensors` 842.6 MB + tokenizer 3.6 MB. Resto son imágenes de
README (~1.9 MB) y utilidades `.py`. Con CUDA el venv crece varios GB (wheel torch 555 MB
más libs nvidia, **[no medido]**).

Tiempo en esta WSL2: instalar el tool 81 s; primera predicción (descarga del inglés,
5 ficheros) 196 s, dominada por la bajada desde HF sin token.

## Pesos y caché de HF

- Repo único `convaiinnovations/laya` con tres checkpoints: raíz = `laya` (English,
  ModernBERT-large 421M), `multilingual/` = `laya-multilingual` (mmBERT 322M, 100+ idiomas),
  `typed-decisions/` = `laya-typed-decisions` (421M). Licencia Apache-2.0 (tag `license:apache-2.0`).
- `Router()` es perezoso: la primera predicción baja **solo** el checkpoint al que enruta
  (inglés: 5 ficheros, 808 MB) a la caché estándar de HF **[medido]**; `Router(preload=True)`
  o `LAYA_PRELOAD=1` bajan los tres.
- Ubicación: `$HF_HOME/hub` (por defecto `~/.cache/huggingface/hub/models--convaiinnovations--laya`);
  `HF_HUB_CACHE` la mueve. En Bazzite/Omarchy `~/.cache` está en `/home`, no en tmpfs.
- Sin `HF_TOKEN` funciona (el repo es público) pero sale un aviso de límite de tasa.
- Offline tras la primera descarga **[medido]**: con `HF_HUB_OFFLINE=1` arrancó `laya-serve`
  sin red. Alternativa documentada: `Router(models={"english": "models/laya"}, preload=True)`
  y el script `setup_laya.sh` del repo (descarga con `snapshot_download` a `models/` y verifica
  hashes contra `verify/checkpoints.json`; pensado para Mac Intel).
- Aviso al cargar `laya`: `RuntimeWarning: this checkpoint ships invalid temperatures...`
  sobre `choice:11+`; es del checkpoint, no del entorno **[medido]**. Relevante para el
  ticket de umbrales: confianza de ciertas entradas no calibrada.

## Servidor **[medido]**

`HF_HUB_OFFLINE=1 LAYA_HOST=127.0.0.1 LAYA_PORT=8765 LAYA_MODELS=english laya-serve`
- Listo en ~5 s con pesos en caché; OpenAPI expone `/health`, `/v1/systemone`,
  `/v1/systemone/batch` (README: lote hasta 64 estados). `/predict` del README pertenece a
  `examples/server.py`, no a `laya-serve`: da 404.
- RSS en reposo con el checkpoint inglés cargado: ~2.07 GB (CPU fp32). Variables: `LAYA_HOST`
  (por defecto `0.0.0.0`: fijar `127.0.0.1`), `LAYA_PORT` (8000), `LAYA_DEVICE`, `LAYA_MODELS`,
  `LAYA_MAX_LOADED`, `LAYA_IDLE_UNLOAD_SECONDS` (descarga por inactividad, útil para el ticket
  de arranque bajo demanda), `LAYA_API_KEY`, `LAYA_THREADS`.
- CLI offline, sin descarga: `laya "texto"` solo enruta; `--predict` baja y corre el checkpoint
  (salida: difficulty, domain, needs_tools, is_sensitive).

## Encaje con el repo

Hoy no hay `uv`/`pipx` en `packages/*.txt` ni módulo Python. Patrón existente: un módulo
`scripts/modules/<x>.sh` con `ensure_<x>()` que usa `exists` y `log`, sourceado por glob en
`bootstrap.sh` y llamado en `main()` (ver `herdr.sh`, `node.sh`). Propuesta mínima (no aplicada):

1. `uv` en los manifiestos: `uv` en `packages/pacman-cli.txt` y `packages/brew-cli.txt`.
   Para apt/dnf no hay lista donde meterlo: añadir `ensure_uv()` (instalador de Astral) o
   resolverlo dentro del nuevo módulo, igual que `ensure_mise`/`ensure_herdr`. Omarchy ya
   usa pacman (ver cuidado con `mise`, docs/omarchy.md).
2. Nuevo `scripts/modules/laya.sh` con `ensure_laya()`: si `exists laya-serve` y la versión
   coincide, no hacer nada; si no, `uv tool install "laya[serve]==0.4.7" --torch-backend=cpu`,
   con rama `macos` + `uname -m == x86_64` que añade `--python 3.12` y los `--with` de arriba.
   Llamarlo en `main()` de `bootstrap.sh` tras `ensure_node` (mismo bloque de herramientas).
   Pin de versión en un solo sitio (variable en el módulo), como `@1.1.24` en
   `global-node-packages.txt`.
3. Los pesos **no** deben ir en el bootstrap (2.3 GB, red lenta); dejar que HF los baje al
   primer uso, o un `laya-warmup` opcional bajo demanda.
4. `~/.local/bin` debe estar en PATH en zsh (comprobar en `zsh/.config/zsh/path.zsh`).
   En Bazzite `~/.local/bin` ya está en PATH por defecto; **[no verificado]**.
5. Fallo no fatal (`|| log "..."`) como el resto de módulos opcionales; sin sudo.

## Riesgos y huecos

- `--torch-backend` es de uv reciente (0.13.1 aquí); el instalador de Astral y brew/pacman
  están en 0.13.1, suficiente. En distros con uv viejo falla.
- Intel Mac: forma exacta con `uv tool` sin probar; el único camino probado por el autor es
  venv + pip (`setup_laya.sh`).
- Python 3.14 funcionó aquí (torch 2.14.1+cpu cp314); README avisa de un crash en Windows con
  3.14 corregido en 0.3.7, no aplica.
- No se probó Arch, Bazzite ni macOS; el comportamiento de wheels en ellas se deduce de PyPI.
