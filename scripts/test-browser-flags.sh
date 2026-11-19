#!/usr/bin/env bash
set -euo pipefail

# browser-flags-select: --use-gl=egl solo en NVIDIA; la variante nvidia = base + ese flag (anti-deriva).
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SEL="${ROOT_DIR}/omarchy/.local/bin/browser-flags-select"
CFG="${ROOT_DIR}/omarchy/.config"
TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT
fail() { echo "FAIL: $*"; exit 1; }

for nav in brave chromium; do
  grep -q 'use-gl=egl' "${CFG}/${nav}-flags.conf" && fail "${nav} base no debe llevar --use-gl=egl"
  diff <(cat "${CFG}/${nav}-flags.conf") <(grep -v 'use-gl=egl' "${CFG}/${nav}-flags.nvidia.conf") >/dev/null \
    || fail "${nav}: la variante nvidia difiere de la base en algo más que --use-gl=egl"
  grep -q 'use-gl=egl' "${CFG}/${nav}-flags.nvidia.conf" || fail "${nav} nvidia sin --use-gl=egl"
done

run() { FLAGS_HOME="${TMP}" NVIDIA_FORCE="$1" bash "${SEL}"; }
run 0
[[ "$(readlink -f "${TMP}/.config/brave-flags.conf")" == "$(readlink -f "${CFG}/brave-flags.conf")" ]] || fail "sin NVIDIA debe enlazar la base"
run 1
[[ "$(readlink -f "${TMP}/.config/brave-flags.conf")" == "$(readlink -f "${CFG}/brave-flags.nvidia.conf")" ]] || fail "con NVIDIA debe enlazar la variante nvidia"
[[ "$(readlink -f "${TMP}/.config/chromium-flags.conf")" == "$(readlink -f "${CFG}/chromium-flags.nvidia.conf")" ]] || fail "chromium con NVIDIA"
run 1  # idempotente
run 0
HOSTNAME_OVERRIDE=andrea FLAGS_HOME="${TMP}" bash "${SEL}"
[[ "$(readlink -f "${TMP}/.config/brave-flags.conf")" == "$(readlink -f "${CFG}/brave-flags.nvidia.conf")" ]] || fail "hostname andrea debe enlazar la variante nvidia"
echo "OK: browser-flags-select"
