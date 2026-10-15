#!/usr/bin/env bash
# Motor de decisiones local: llama.cpp + Clef-Flash bajo demanda (ver docs/decisiones.md).
#
# Solo donde hay GPU NVIDIA: en CPU Clef-Flash tarda ~9 s por Decisión, así que
# en macOS o sin NVIDIA no se instala nada y el hook aplica Fallo abierto.
# Un solo camino en Linux (Arch, Ubuntu/WSL2, Bazzite): el tarball CUDA de la
# release fijada, en $HOME, sin root. El GGUF (6,5 GB) va aparte:
# scripts/download-clef-model.sh.

# Soporte de Clef desde b11622 (PR ggml-org/llama.cpp#29831). Subir a mano.
LLAMA_CPP_VERSION="b11622"

ensure_clef() {
  if [[ "${OS}" == "macos" ]] || ! nvidia-smi -L >/dev/null 2>&1; then
    log "Sin GPU NVIDIA: no se instala el Motor de decisiones (Fallo abierto)."
    return 0
  fi

  local data="${XDG_DATA_HOME:-$HOME/.local/share}"
  local dir="${data}/llama.cpp/${LLAMA_CPP_VERSION}"
  local base="https://github.com/ggml-org/llama.cpp/releases/download/${LLAMA_CPP_VERSION}"
  if [[ ! -x "${dir}/llama-server" ]]; then
    log "Instalando llama.cpp ${LLAMA_CPP_VERSION} (CUDA) en ${dir}…"
    mkdir -p "${dir}"
    # El binario y las libs CUDA vienen en dos tarballs; ambos al mismo directorio.
    for t in llama cudart-llama; do
      curl -fsSL "${base}/${t}-${LLAMA_CPP_VERSION}-bin-ubuntu-cuda-12.8-x64.tar.gz" \
        | tar xz --strip-components=1 -C "${dir}" \
        || { log "No se pudo descargar llama.cpp; se omite el Motor."; return 0; }
    done
  fi
  ln -sfn "${dir}" "${data}/llama.cpp/current"

  local key="${XDG_CONFIG_HOME:-$HOME/.config}/clef/api-key"
  if [[ ! -s "${key}" ]]; then
    mkdir -p "$(dirname "${key}")"
    ( umask 077; od -An -tx1 -N32 /dev/urandom | tr -d ' \n' > "${key}" )
  fi

  if systemctl --user show-environment >/dev/null 2>&1; then
    systemctl --user daemon-reload || true
    systemctl --user enable --now clef.socket || log "No se pudo activar clef.socket."
  else
    log "systemd --user no disponible: clef.socket queda sin activar."
  fi

  [[ -f "${data}/clef/Clef-Flash-Q4_K_M.gguf" ]] \
    || log "Falta el modelo: ejecuta scripts/download-clef-model.sh (~6,5 GB)."
}
