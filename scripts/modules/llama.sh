#!/usr/bin/env bash
# Local decision engine: llama.cpp + Clef-Flash on demand (see docs/decision-engine.md).
#
# Only where there is an NVIDIA GPU: on CPU Clef-Flash takes ~9 s per Decision,
# so on macOS or without NVIDIA nothing is installed and the hook fails open.
# One path on Linux (Arch, Ubuntu/WSL2): the pinned release's CUDA
# tarball, in $HOME, no root. The GGUF (6.5 GB) is separate:
# scripts/download-clef-model.sh.

# Clef support since b11622 (PR ggml-org/llama.cpp#29831). Bump by hand, together
# with the sha256 of both tarballs (a release's assets can change).
LLAMA_CPP_VERSION="b12179"
declare -A LLAMA_CPP_SHA256=(
  [llama]=9a5b9bf36ff80ea58bf9d5ea11fb2462d61430ec9f9a752230eb4bcf8ee68c3d
  [cudart-llama]=111c2e4c7a770d4c22a0f07e3e9f72cfeaacd27ecaec1ab2bd3cd2d3781b094c
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
    # The binary and the CUDA libs come in two tarballs; both are checked and
    # extracted into a temp dir, which is moved only if both succeeded.
    local tmp t f
    tmp="$(mktemp -d)"
    mkdir -p "${tmp}/x"
    for t in llama cudart-llama; do
      f="${t}-${LLAMA_CPP_VERSION}-bin-ubuntu-cuda-12.8-x64.tar.gz"
      # shellcheck disable=SC2015 # la rama || es el manejo de error de toda la cadena, a propósito
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

  # The API key is also the hook's "engine installed" signal: it is created
  # before starting the socket (clef-server reads it) and deleted if that fails,
  # so prompts are never sent to a port we do not own.
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
