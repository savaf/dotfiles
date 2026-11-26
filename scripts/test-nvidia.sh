#!/usr/bin/env bash
# shellcheck disable=SC2016,SC2031 # falsos: $ se expande dentro; ROOT_DIR no cambia en la subshell
set -euo pipefail

# NVIDIA según hardware: comandos falsos al frente del PATH y SYSTEM_ROOT temporal. Sin GPU ni root.
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT
fail() { echo "FAIL: $*"; exit 1; }

export CALLS="${TMP}/calls" PKGS="${TMP}/pkgs" SYSTEM_ROOT="${TMP}/root"
unset NVIDIA_FORCE
mkdir -p "${TMP}/bin"
fake() { printf '#!/usr/bin/env bash\n%s\n' "$2" >"${TMP}/bin/$1"; chmod +x "${TMP}/bin/$1"; }
# sudo falso: ejecuta sin privilegios (una ruta real de /etc fallaría, nunca se escribe).
fake sudo 'echo "sudo $*" >>"$CALLS"; "$@"'
for c in systemctl sysctl limine-mkinitcpio; do fake "$c" "echo \"$c \$*\" >>\"\$CALLS\""; done
# shellcheck disable=SC2016 # se expande dentro del falso, no aquí
fake pacman 'echo "pacman $*" >>"$CALLS"
case "$1" in
  -Qq) grep -qx "$2" "$PKGS" ;;
  -Rns) [[ -z "${PACMAN_REFUSES:-}" ]] ;;
esac'
fake hostname 'echo andrea'
gpu() { fake lspci "echo '00:02.0 VGA compatible controller: $1'"; }
export PATH="${TMP}/bin:${PATH}"

run() { : >"${CALLS}"; ( source "${ROOT_DIR}/scripts/install-packages.sh"; "$@" ) >"${TMP}/out" 2>&1; }
called() { grep -q -- "$1" "${CALLS}"; }
reset() { rm -rf "${SYSTEM_ROOT}"; mkdir -p "${SYSTEM_ROOT}/etc/modprobe.d"; : >"${PKGS}"; }

CONF="${SYSTEM_ROOT}/etc/modprobe.d/nvidia.conf"
UNIT="${SYSTEM_ROOT}/etc/systemd/system/gpu-watchdog.service"
BIN="${SYSTEM_ROOT}/usr/local/bin/gpu-watchdog"

# 1. Sin GPU NVIDIA, un equipo llamado "andrea" no instala nvidia-utils.
reset; gpu "Intel Corporation UHD Graphics 770"
run ensure_nvidia_userspace
called 'pacman -S' && fail "andrea sin NVIDIA instaló paquetes"
echo "OK: el hostname no cuenta"

# 2. Con GPU NVIDIA se instala el userspace, la modprobe (+ initramfs) y el watchdog.
reset; gpu "NVIDIA Corporation GA102"; fake hostname 'echo songbird'
run ensure_nvidia_userspace
called 'pacman -S --needed --noconfirm nvidia-utils' || fail "no instaló nvidia-utils"
run ensure_nvidia_modprobe
cmp -s "${CONF}" "${ROOT_DIR}/system/etc/modprobe.d/nvidia.conf" || fail "no instaló la modprobe"
called 'limine-mkinitcpio' || fail "no regeneró el initramfs"
run ensure_crash_resilience
[[ -x "${BIN}" && -f "${UNIT}" ]] || fail "no instaló gpu-watchdog"
called 'systemctl enable gpu-watchdog.service' || fail "no habilitó gpu-watchdog"
echo "OK: con NVIDIA se instala todo"

# 3. Sin NVIDIA, nvidia-utils presente (aunque haya nvidia-smi) no activa nada y se quita.
gpu "Intel Corporation UHD Graphics 770"; fake nvidia-smi 'exit 0'
printf 'nvidia-utils\nlib32-nvidia-utils\n' >"${PKGS}"
run ensure_nvidia_userspace
called 'pacman -Rns --noconfirm lib32-nvidia-utils nvidia-utils' || fail "no quitó nvidia-utils"
PACMAN_REFUSES=1 run ensure_nvidia_userspace || fail "debía seguir si pacman se niega"
grep -q 'AVISO' "${TMP}/out" || fail "no avisó"

# 4. Limpieza de modprobe e initramfs (sobre los restos del caso 2), idempotente.
run ensure_nvidia_modprobe
[[ ! -e "${CONF}" ]] || fail "no borró la modprobe propia"
called 'limine-mkinitcpio' || fail "no regeneró el initramfs al limpiar"
run ensure_nvidia_modprobe
[[ ! -s "${CALLS}" ]] || fail "la 2.ª limpieza de modprobe no es idempotente"
echo "options nvidia mio=1" >"${CONF}"
run ensure_nvidia_modprobe
[[ "$(<"${CONF}")" == "options nvidia mio=1" ]] || fail "tocó una modprobe ajena"
called 'limine-mkinitcpio' && fail "regeneró sin haber borrado nada"
echo "OK: modprobe: borra solo la propia"

# 5. Limpieza de gpu-watchdog, idempotente.
run ensure_crash_resilience
[[ ! -e "${BIN}" && ! -e "${UNIT}" ]] || fail "no borró gpu-watchdog"
called 'systemctl disable --now gpu-watchdog.service' || fail "no deshabilitó gpu-watchdog"
called 'systemctl daemon-reload' || fail "sin daemon-reload"
run ensure_crash_resilience
called 'gpu-watchdog' && fail "la 2.ª limpieza de gpu-watchdog no es idempotente"
echo "OK: gpu-watchdog: deshabilita y borra"

# 6. Sin poder consultar lspci no se sabe qué hay: no se limpia nada.
fake lspci 'exit 1'
cp "${ROOT_DIR}/system/etc/modprobe.d/nvidia.conf" "${CONF}"
mkdir -p "$(dirname "${BIN}")"; touch "${BIN}"; echo nvidia-utils >"${PKGS}"
run ensure_nvidia_userspace; called 'pacman -Rns' && fail "quitó nvidia-utils sin lspci"
run ensure_nvidia_modprobe; [[ -f "${CONF}" ]] || fail "borró la modprobe sin lspci"
run ensure_crash_resilience; [[ -f "${BIN}" ]] || fail "borró gpu-watchdog sin lspci"
echo "OK: sin lspci no se limpia"
