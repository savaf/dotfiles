#!/usr/bin/env bash
# Motor de decisiones local: llama.cpp + Clef-Flash bajo demanda (ver docs/decisiones.md).
#
# Solo donde hay GPU NVIDIA: en CPU Clef-Flash tarda ~9 s por Decisión, así que
# en macOS o sin NVIDIA no se instala nada y el hook aplica Fallo abierto.
# Un solo camino en Linux (Arch, Ubuntu/WSL2, Bazzite): el tarball CUDA de la
# release fijada, en $HOME, sin root. El GGUF (6,5 GB) va aparte:
# scripts/download-clef-model.sh.

# Soporte de Clef desde b11622 (PR ggml-org/llama.cpp#29831). Subir a mano,
# junto con los sha256 de los dos tarballs (los assets de una release pueden cambiar).
LLAMA_CPP_VERSION="b11622"
declare -A LLAMA_CPP_SHA256=(
  [llama]=9791b0d14779a2fc1d12c5db1da494338a9861f4fd592f13ec35ee7042fe24b5
  [cudart-llama]=6a09354b71429d9cc7ab651825000ee5ddc807b8a7fae02ae4882b57cb683b50
)

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
    # El binario y las libs CUDA vienen en dos tarballs; se verifican y se
    # extraen juntos a un temporal, y solo se mueve si ambos salieron bien.
    local tmp t f
    tmp="$(mktemp -d)"
    mkdir -p "${tmp}/x"
    for t in llama cudart-llama; do
      f="${t}-${LLAMA_CPP_VERSION}-bin-ubuntu-cuda-12.8-x64.tar.gz"
      curl -fsSL -o "${tmp}/${f}" "${base}/${f}" \
        && echo "${LLAMA_CPP_SHA256[$t]}  ${tmp}/${f}" | sha256sum -c --quiet \
        && tar xzf "${tmp}/${f}" --strip-components=1 -C "${tmp}/x" \
        || { log "No se pudo descargar o verificar llama.cpp; se omite el Motor."; rm -r "${tmp}"; return 0; }
    done
    mkdir -p "$(dirname "${dir}")"
    mv "${tmp}/x" "${dir}"
    rm -r "${tmp}"
  fi
  ln -sfn "${dir}" "${data}/llama.cpp/current"

  if ! systemctl --user show-environment >/dev/null 2>&1; then
    log "systemd --user no disponible: el Motor queda sin activar (Fallo abierto)."
    return 0
  fi

  # La API key es también la señal de "Motor instalado" para el hook: se crea
  # antes de arrancar el socket (clef-server la lee) y se borra si no arranca,
  # para no mandar prompts a un puerto que no es nuestro.
  local key="${XDG_CONFIG_HOME:-$HOME/.config}/clef/api-key"
  if [[ ! -s "${key}" ]]; then
    mkdir -p "$(dirname "${key}")"
    ( umask 077; od -An -tx1 -N32 /dev/urandom | tr -d ' \n' > "${key}" )
  fi
  systemctl --user daemon-reload || true
  if ! systemctl --user enable --now clef.socket; then
    log "No se pudo activar clef.socket; el Motor queda sin activar."
    rm -f "${key}"
    return 0
  fi

  [[ -f "${data}/clef/Clef-Flash-Q4_K_M.gguf" ]] \
    || log "Falta el modelo: ejecuta scripts/download-clef-model.sh (~6,5 GB)."
}
