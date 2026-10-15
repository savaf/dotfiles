# Instalación de llama.cpp y Clef-Flash en todos los setups

Ticket: `.scratch/laya-motor/issues/09-instalacion-llama-cpp-multi-os.md`. Investigado el 2026-10-14/15.
Leyenda: **[verificado]** = lo ejecuté o lo leí en la fuente primaria; **[no verificado]** = deducido, falta probarlo en esa máquina.

## Resumen

1. **Versión mínima**: Clef entró en llama.cpp con el PR #29831 (merge 2026-10-03, commit `99b9548`) y el release estable **v0.6.0** (2026-10-05) lo lista en sus notas. Sirve cualquier v0.6.0 o build `b11622+`. [verificado: API de GitHub]
2. **Trampa del versionado en GitHub**: `releases/latest` devuelve `v0.6.0`, que solo trae un asset (`nightly-tag.txt`). Los binarios están en los *prereleases* `bNNNNN` (36 assets cada uno; el último hoy es `b11630`). Un script no puede usar `/releases/latest` para bajar binarios. [verificado]
3. **El `llama` de llama.app es el mismo llama.cpp**: un launcher multicomando (`llama serve|cli|download|update|version`) del equipo de llama.cpp + Hugging Face. Los tarballs de GitHub `bNNNNN` también traen el binario `llama`. [verificado]
4. **Detección de GPU**: `llama-server --list-devices` lista solo aceleradores (`CUDA0: … (10239 MiB, 9071 MiB free)`); sin GPU, o con GPU pero sin las librerías, imprime `Available devices:` + `(none)`. Sirve para decidir Fallo abierto. [verificado en la 3080]
5. **GGUF**: `llama download -hf ggml-org/Clef-Flash-GGUF:Q4_K_M` lo guarda en la caché estándar de Hugging Face; se hace fuera del bootstrap. [comando y rutas de caché verificados en `--help` y en el código; la descarga de 6,5 GB no se repitió, el GGUF ya está en `~/clef-probe/models`]
6. **Recomendación**: un módulo `scripts/modules/llama.sh` con rama por OS (tabla abajo). Intel Mac: no instalar (sin GPU capaz, Fallo abierto).

## Qué es `llama` / llama.app

- llama.app es una app de escritorio (Mac/Windows) y, en Linux, solo CLI: `curl -LsSf https://llama.app/install.sh | sh`. Fuentes: https://llama.app y el README de llama.cpp (sección de instalación). [verificado]
- El script vive en https://github.com/ggml-org/llama-install.sh (`install.sh` se sirve desde llama.app). Detecta arch/OS, sondea GPU en Linux en orden **CUDA → ROCm → Vulkan → CPU** y en macOS **Metal** (solo Apple M1-M5/A18), baja **un único binario `llama-app.zst`** desde un bucket de Hugging Face (`huggingface.co/buckets/ggml-org/install.sh`, no desde GitHub), comprueba que `llama version` coincide con la versión pedida y lo copia a `~/.local/bin/llama` (copia también en `~/.llama-app/`). No pide root. [verificado leyendo el script]
- Variables: `LLAMA_VERSION=bNNNNN` fija versión (sin ella usa `…/resolve/latest`, hoy `b11630`); `SKIP_CUDA=1`, `SKIP_ROCM=1`, `SKIP_VULKAN=1`, `SKIP_INSTALL=1`. [verificado]
- Soporte (`REQUIREMENTS.md`): Linux x86_64 y aarch64 (cpu/cuda/vulkan; rocm solo x86_64); macOS **solo aarch64** (metal m1/m2 desde macOS 13.3, m3 14, m4/a18 15, m5 26); **Intel Mac no está soportado**. CUDA exige `libcuda.so.1` (driver) y glibc 2.35; Vulkan `libvulkan.so.1`. No lista cudart como dependencia (a diferencia del tarball de GitHub). [verificado en el doc; que de verdad funcione sin cudart no lo ejecuté]
- Actualización: `llama update`. Con el binario del tarball de GitHub responde "Updates are available only when installed from https://llama.app". [verificado]
- **No pude ejecutar `install.sh`** (el entorno bloqueó ejecutar código descargado). Es el mismo patrón `curl | sh` que ya usa `ensure_herdr`.

## Opciones por setup

| Setup | Opción recomendada | Backend | Versión / actualización | Estado |
|---|---|---|---|---|
| **Arch/Omarchy** (3080) | `sudo pacman -S llama-cpp ggml-cuda` (repo `extra`) | CUDA | `llama-cpp 0.6.0-1` (2026-10-06) + `ggml 0.26.0`; se actualiza con `pacman -Syu` | paquetes verificados; ejecución en Arch **no verificada** |
| **Ubuntu/WSL2** (3080) | tarball GitHub `ubuntu-cuda-12.8-x64` + `cudart-…` en `~/.local/share/llama/`, o llama.app | CUDA | tarball: fijo por constante `LLAMA_TAG`; llama.app: `llama update` | tarball **verificado** (b11622); llama.app **no verificado** |
| **Bazzite** | llama.app a `~/.local/bin` (sin rpm-ostree); alternativa `brew install llama.cpp` | CUDA/ROCm/Vulkan según GPU | `llama update` / `brew upgrade` | **no verificado** |
| **macOS Apple Silicon** | `brew install llama.cpp` (ya se usa brew; añadir a `packages/brew-cli.txt`) | Metal | fórmula stable `0.6.0`; `brew upgrade` | fórmula verificada; ejecución **no verificada** |
| **macOS Intel** | nada: Fallo abierto | — | — | ver abajo |

### Arch / Omarchy
- `llama-cpp 0.6.0-1` está en `extra` (JSON de archlinux.org, `last_update` 2026-10-06; depende de `ggml`). El backend lo aporta `ggml-cuda 0.26.0` (también `ggml-vulkan`, `ggml-hip`, `ggml-blas`): el PKGBUILD de `ggml` compila con `GGML_BACKEND_DL=ON` y `GGML_BACKEND_DIR=/usr/lib/ggml`, y los backends son paquetes aparte. `ggml-cuda` depende de `cuda` (el paquete en sí pesa 125 MB comprimido, más el toolkit que arrastra `cuda`). Para AMD/Intel sería `ggml-vulkan` o `ggml-hip`.
- AUR no hace falta: `llama.cpp-cuda-git b11433` (posterior al merge de Clef) y `llama.cpp-vulkan-bin`/`rocm-bin b11577` existen, pero el repo oficial ya cubre v0.6.0 y se actualiza con el sistema.

### Ubuntu / WSL2
- No hay paquete apt oficial con CUDA. Camino probado: `llama-b11622-bin-ubuntu-cuda-12.8-x64.tar.gz` (163 MiB) + `cudart-llama-b11622-bin-ubuntu-cuda-12.8-x64.tar.gz` (566 MiB). Existen también variantes `cuda-13.4`, `vulkan`, `rocm-10.0` y `openvino`.
- **Sin `LD_LIBRARY_PATH` que incluya el directorio de cudart y `/usr/lib/wsl/lib`, `llama-server` cae a CPU en silencio** (`--list-devices` imprime `(none)`). Con ellas: `CUDA0: NVIDIA GeForce RTX 3080 (10239 MiB, 9071 MiB free)`. Un wrapper en `~/.local/bin` que exporte esas rutas lo resuelve. [verificado]
- llama.app debería evitar cudart aparte (solo `libcuda.so.1`, que WSL expone en `/usr/lib/wsl/lib`), pero **no lo probé**.

### Bazzite (Fedora atómico)
- Fedora rawhide trae `llama-cpp b11232` (mdapi), anterior a la fusión de Clef; además en atómico implicaría `rpm-ostree` y reinicio. **Descartado.**
- `brew install llama.cpp` en Linux: existe bottle `x86_64_linux`, pero `ggml` en Linux se compila solo con **Vulkan + OpenBLAS** (`ggml.rb`: `-DGGML_VULKAN=ON`, sin CUDA/HIP). Funcionaría en cualquier GPU por Vulkan, más lento que CUDA en NVIDIA.
- llama.app instala en `$HOME` sin tocar la imagen y elige CUDA/ROCm/Vulkan por sondeo: mejor encaje en atómico. Falta saber qué GPU tiene el Bazzite del usuario.

### macOS
- `brew install llama.cpp`: stable `0.6.0`; bottles `arm64_golden_gate`, `arm64_tahoe`, `arm64_sequoia` y linux; **sin bottle para otras versiones de macOS ni Intel** (compilaría desde fuente con `node` y `cmake`). En Intel, `ggml` desactiva Metal (`-DGGML_METAL=OFF`).
- La cask `llama-app 0.44.0` es la app de barra de menú (macOS ≥ 15, solo arm64): no hace falta. `install.sh` también serviría en Apple Silicon.

## Descarga y caché del GGUF

- Ficheros reales de `ggml-org/Clef-Flash-GGUF` (API de HF): `Clef-Flash-Q4_K_M.gguf` (6,49 GB), `Clef-Flash-Q8_0.gguf` (9,66 GB), `Clef-Flash-BF16.gguf`, más `mmproj-*` para visión.
- Comando: `llama download -hf ggml-org/Clef-Flash-GGUF:Q4_K_M` (ayuda: "quant is optional… default to Q4_K_M"). `--no-mmproj` evita el proyector de visión; `-hff Clef-Flash-Q4_K_M.gguf` fija el fichero; `--offline` obliga a usar solo la caché.
- Caché (código `common/hf-cache.cpp` en v0.6.0), en este orden: `LLAMA_CACHE` > `HF_HUB_CACHE` > `$HF_HOME/hub` > `$XDG_CACHE_HOME/huggingface/hub` > `~/.cache/huggingface/hub`. Es la caché estándar de HF, compartida con otras herramientas. `llama-server --cache-list` la enumera.
- **Fuera de bootstrap**: 6,5 GB no debe bloquear el bootstrap ni el arranque en frío (presupuesto ~5 s). Propuesta: `scripts/clef-pull.sh` idempotente (solo corre `llama download` si `--cache-list` no lo contiene), invocable a mano y recordado por `boot-health.sh`. El servidor arranca con `-hf … --offline` (o `-m <ruta>`); si el GGUF falta, Fallo abierto.

## Detección de GPU capaz (decidir Fallo abierto)

Criterio: acelerador disponible y memoria libre ≥ ~8 GB (el Q4_K_M midió 6,7 GB de VRAM en la 3080, ticket 08).

Antes de instalar (barato, antes de bajar 160-700 MB):
- Linux/WSL: `nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits` (en WSL está en `/usr/lib/wsl/lib`); AMD: `/sys/class/drm/card*/device/mem_info_vram_total`; fallback `vulkaninfo --summary`.
- macOS: `uname -m` = `arm64` y `sysctl -n hw.memsize` ≥ 16 GiB (memoria unificada; con 8 GiB no caben 6,5 GB de pesos + KV).

Después de instalar (fuente de verdad: detecta "driver bien, librerías mal"):
```sh
gpu_line="$(llama-server --list-devices 2>/dev/null | grep -E '^[[:space:]]+[A-Za-z]+[0-9]+:' || true)"
[[ -n "$gpu_line" ]]   # hay acelerador; MiB: sed -n 's/.*(\([0-9]*\) MiB.*/\1/p'
```
Verificado: 3080 con librerías → `CUDA0`; sin `LD_LIBRARY_PATH` → `(none)`; `CUDA_VISIBLE_DEVICES=-1` → `ggml_cuda_init: failed to initialize CUDA` y `(none)`. No verificado: nombre exacto del dispositivo en Metal/Vulkan (esperable `MTL0`/`Vulkan0`).

El resultado se guarda (p. ej. `~/.local/state/clef/capable` con `yes`/`no`) y el hook lee ese fichero en vez de lanzar el binario. Sin fichero o `no` → Fallo abierto sin coste.

## Cómo encaja en el repo

Patrón actual: `scripts/bootstrap.sh` hace `source scripts/modules/*.sh` y llama a funciones `ensure_*` en `main()` (p. ej. `ensure_herdr`: `exists herdr && return 0; curl … | sh`). `scripts/lib/common.sh` aporta `log`, `exists`, `os_detect`. Paquetes por gestor en `packages/*.txt`.

Propuesta para el ticket de implementación:
- `scripts/modules/llama.sh` con `ensure_llama_server()`:
  1. pre-chequeo de GPU por OS; si no hay capaz, `log` y `return 0` sin instalar nada.
  2. `case "$OS"`: `omarchy` → `sudo pacman -S --needed llama-cpp ggml-cuda`; `macos` arm64 → `brew install llama.cpp`; `macos` Intel → saltar; `ubuntu/wsl` y `bazzite` → `curl -fsSL https://llama.app/install.sh | LLAMA_VERSION="$LLAMA_TAG" sh` (o tarball fijo + wrapper en WSL si llama.app no resulta).
  3. `llama-server --list-devices` y escribir el estado `capable`.
- Llamarla en `main()` tras `ensure_herdr`, sin abortar el bootstrap (`|| true`, como `install-claude-skills.sh`).
- Mejor en el módulo que en `packages/*.txt`: `ggml-cuda` arrastra `cuda` y `llama.cpp` en brew solo vale en arm64, es decir, depende de la GPU. Los `.txt` no tienen condición.
- Comprobar la versión: Arch/brew entregan `0.6.0`, cuyo número de build no es `11622`; mejor probar `llama version` ≥ v0.6.0 o build ≥ 11622.
- Docs: una línea en `docs/{ubuntu-wsl,omarchy,macos-setup,bazzite}.md` y un `docs/clef.md` nuevo.

## ¿Rinde Clef-Flash con Metal en Apple Silicon?

Sin medición real de Clef-Flash en Metal; lo siguiente es **estimación**. Datos primarios: discusión llama.cpp #4167 (LLaMA 7B Q4_0, pp512 / tg128 en t/s): M1 Pro 16 GPU 302 / 36; M2 Pro 19 GPU 384 / 39; M4 Pro 20 GPU 464 / 51; M4 Max 40 GPU 923 / 83. Clef-Flash Q4_K_M pesa 6,49 GB (≈1,7× el 7B Q4_0), así que cabe esperar ~170-190 t/s de prefill en un M1 Pro y ~270 en un M4 Pro. Una Decisión (un forward, prompt de N tokens): N=500 → ~3 s en M1 Pro y ~2 s en M4 Pro, frente a ~75 ms medidos en la 3080. v0.6.0 trae kernels Metal nuevos (flash attention con tensor API, mat-mul de pocas filas) que pueden mejorarlo. Conclusión: probable que funcione, pero con latencia de segundos; hay que medirlo en el Mac real antes de activarlo, y exigir ≥ 16 GiB de memoria unificada.

## Preguntas abiertas

1. ¿Qué GPU y driver tiene el Bazzite? (CUDA vs Vulkan/ROCm).
2. ¿Aceptas `curl | sh` de llama.app (binario desde un bucket de HF, no GitHub) o prefieres tarball de GitHub fijado para lo que no sea Arch/brew?
3. Primera prueba al implementar: `install.sh` en WSL con `LLAMA_VERSION=b11622` y ver si usa CUDA sin cudart ni `LD_LIBRARY_PATH`.
4. Confirmar en Arch que `llama-cpp` + `ggml-cuda` cargan CUDA (`--list-devices`) y sirven `/v1/systemone`.
5. Latencia real en Apple Silicon (hace falta un Mac).

## Fuentes

- Releases y notas: `gh api repos/ggml-org/llama.cpp/releases{,/latest,/tags/b11622,/tags/v0.6.0}`; PRs #29831 y #29818.
- llama.app: https://llama.app, https://llama.app/install.sh, https://github.com/ggml-org/llama-install.sh (`README.md`, `PRESETS.md`, `REQUIREMENTS.md`, `install.sh`).
- GGUF: https://huggingface.co/ggml-org/Clef-Flash-GGUF y `https://huggingface.co/api/models/ggml-org/Clef-Flash-GGUF`.
- Brew: `Formula/l/llama.cpp.rb` y `Formula/g/ggml.rb` en Homebrew/homebrew-core; API de formulae.brew.sh (cask `llama-app`).
- Arch: archlinux.org/packages `extra/x86_64/{llama-cpp,ggml,ggml-cuda}` (JSON) y PKGBUILD de `ggml`; AUR RPC v5.
- Fedora: https://mdapi.fedoraproject.org/rawhide/pkg/llama-cpp.
- Código: `common/hf-cache.cpp` en el tag `v0.6.0`; https://github.com/ggml-org/llama.cpp/discussions/4167.
- Pruebas locales: `~/clef-probe/bin/llama-b11622/{llama,llama-server}` (`--list-devices`, `download --help`, `update --help`, `help all`).
- Repo: `scripts/bootstrap.sh`, `scripts/modules/herdr.sh`, `packages/*.txt`.
