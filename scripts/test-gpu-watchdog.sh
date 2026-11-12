#!/usr/bin/env bash
set -euo pipefail

# gpu-watchdog con nvidia-smi, logger y notify falsos; STATE_DIR temporal. Sin GPU ni root.
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WD="${ROOT_DIR}/system/usr/local/bin/gpu-watchdog"
TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT
fail() { echo "FAIL: $*"; exit 1; }

mkdir -p "${TMP}/bin"
printf '#!/bin/sh\necho "$@" >>"%s/crit-log"\n' "${TMP}" >"${TMP}/bin/logger"
printf '#!/bin/sh\nexit 0\n' >"${TMP}/bin/runuser"
for c in sensors fuser; do printf '#!/bin/sh\necho %s-falso\n' "$c" >"${TMP}/bin/$c"; done
printf '#!/bin/sh\ntrue\n' >"${TMP}/bin/journalctl"
printf '#!/bin/sh\nexit 1\n' >"${TMP}/smi-roto"
printf '#!/bin/sh\nexit 0\n' >"${TMP}/smi-ok"
chmod +x "${TMP}/bin/"* "${TMP}/smi-roto" "${TMP}/smi-ok"
export PATH="${TMP}/bin:${PATH}"
export INTERVAL=0.2 CONFIRM_DELAY=0.2

run() {  # run NVIDIA_SMI JOURNAL_CMD
  rm -rf "${TMP}/state" "${TMP}/crit-log"
  STATE_DIR="${TMP}/state" NVIDIA_SMI="$1" JOURNAL_CMD="$2" timeout 3 bash "$WD" >/dev/null 2>&1 || true
}

# 1. nvidia-smi roto dos veces: una sola alerta crit y una instantánea
run "${TMP}/smi-roto" 'true'
[[ "$(grep -c 'GPU colgada' "${TMP}/crit-log")" -eq 1 ]] || fail "debía haber una sola alerta crit"
[[ "$(find "${TMP}/state" -mindepth 1 -maxdepth 1 -type d | wc -l)" -eq 1 ]] || fail "debía haber una instantánea"
grep -q "nvidia-smi no responde" "${TMP}/state"/*/resumen.txt || fail "motivo mal registrado"
echo "OK: nvidia-smi roto -> una alerta y una instantánea"

# 2. GPU sana: no hace nada
run "${TMP}/smi-ok" 'true'
[[ ! -e "${TMP}/crit-log" ]] || fail "alertó con la GPU sana"
echo "OK: GPU sana sin alertas"

# 3. coolercontrold dice 'stopped answering' aunque nvidia-smi conteste
run "${TMP}/smi-ok" 'echo "Device NVIDIA GeForce RTX 3080 stopped answering after 8 timed out requests"'
grep -q 'GPU colgada' "${TMP}/crit-log" || fail "no alertó con el mensaje de coolercontrold"
grep -q "coolercontrold" "${TMP}/state"/*/resumen.txt || fail "motivo del journal mal registrado"
echo "OK: mensaje de coolercontrold dispara la alerta"
