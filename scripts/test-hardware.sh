#!/usr/bin/env bash
# shellcheck disable=SC2016,SC2031 # falsos: $ se expande dentro; ROOT_DIR no cambia en la subshell
set -euo pipefail

# Paquetes y configuración según placa y USB: comandos falsos al frente del PATH, SYSFS_ROOT y
# SYSTEM_ROOT temporales. Sin hardware ni root.
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT
fail() { echo "FAIL: $*"; exit 1; }

export CALLS="${TMP}/calls" HOME="${TMP}/home"
mkdir -p "${TMP}/bin" "${HOME}/.local/bin"
fake() { printf '#!/usr/bin/env bash\n%s\n' "$2" >"${TMP}/bin/$1"; chmod +x "${TMP}/bin/$1"; }
# sudo falso: ejecuta sin privilegios (una ruta real de /etc fallaría, nunca se escribe).
fake sudo 'echo "sudo $*" >>"$CALLS"; "$@"'
for c in yay modprobe limine-mkinitcpio; do fake "$c" "echo \"$c \$*\" >>\"\$CALLS\""; done
# pacman -T imprime lo no satisfecho (PROVIDED = ya cubierto, p.ej. por un -git).
# PACMAN_FAILS hace fallar la instalación de openrgb.
fake pacman 'if [[ "$1" == -T ]]; then
  shift; rc=0
  for p in "$@"; do [[ " ${PROVIDED:-} " == *" $p "* ]] || { echo "$p"; rc=127; }; done
  exit "$rc"
fi
echo "pacman $*" >>"$CALLS"
[[ "$1" != -S || -z "${PACMAN_FAILS:-}" || " $* " != *" openrgb "* ]]'
# install_arch en Arch puro también limpia NVIDIA: que no dependa de la GPU de esta máquina.
export NVIDIA_FORCE=0
fake modinfo 'exit 0'
fake lsmod 'exit 0'
# is-enabled/is-active responden "no" para que se vea el enable.
fake systemctl 'echo "systemctl $*" >>"$CALLS"; [[ "$1" != is-* ]]'
printf '#!/usr/bin/env bash\necho coolercontrol-setup >>"$CALLS"\n' >"${HOME}/.local/bin/coolercontrol-setup"
chmod +x "${HOME}/.local/bin/coolercontrol-setup"
export PATH="${TMP}/bin:${PATH}"

run() { : >"${CALLS}"; ( source "${ROOT_DIR}/scripts/install-packages.sh"; "$@" ) >"${TMP}/out" 2>&1; }
called() { grep -q -- "$1" "${CALLS}"; }
# Cada caso estrena sysfs y raíz del sistema.
reset() {
  CASE="$(mktemp -d "${TMP}/case.XXXX")"
  export SYSFS_ROOT="${CASE}/sys" SYSTEM_ROOT="${CASE}/root"
  MODS="${SYSTEM_ROOT}/etc/modules-load.d"
  mkdir -p "${MODS}"
}
board() { mkdir -p "${SYSFS_ROOT}/class/dmi/id"; echo "$1" >"${SYSFS_ROOT}/class/dmi/id/board_vendor"; }
usb() { # $1 puerto, $2 idVendor, $3 manufacturer, $4 product
  local d="${SYSFS_ROOT}/bus/usb/devices/$1"; mkdir -p "$d"
  echo "$2" >"$d/idVendor"; echo "${3:-}" >"$d/manufacturer"; echo "${4:-}" >"$d/product"
}
# install_arch en Arch puro, sin los pasos ajenos al hardware (red, shell, fuentes).
# shellcheck disable=SC2329 # las funciones falsas las llama install_arch
arch() {
  ensure_mise_tools() { :; }; ensure_nerd_font() { :; }; ensure_zsh() { :; }; ensure_bash_installed() { :; }
  OS=arch; install_arch
}
HW='nct6687\|coolercontrol\|liquidctl\|openrgb\|i2c'

# 1. Sin hardware específico (placa Gigabyte, ratón Logitech): nada de esto se instala ni se activa.
reset; board "Gigabyte Technology Co., Ltd."; usb 1-1 046d Logitech "USB Receiver"
run arch
for p in lm_sensors linux-headers socat; do
  called "pacman -S .*${p}" || fail "${p} debe instalarse siempre"
done
called "${HW}" && fail "instaló paquetes sin su hardware"
for f in ensure_nct6687 ensure_i2c_dev ensure_coolercontrol; do
  run "$f"
  [[ ! -s "${CALLS}" ]] || fail "$f actuó sin su hardware"
  grep -q 'se omite' "${TMP}/out" || fail "$f no dejó log al omitir"
done
[[ -z "$(ls "${MODS}")" ]] || fail "persistió módulos sin hardware"
echo "OK: sin hardware no se instala ni activa nada"

# 2. Placa MSI: driver nct6687 instalado, persistido y cargado; nada de NZXT ni RGB.
reset; board "Micro-Star International Co., Ltd."
run arch
called 'yay -S --needed --noconfirm nct6687d-dkms-git$' || fail "MSI: no instaló el driver"
called 'coolercontrol\|liquidctl\|openrgb\|i2c' && fail "MSI: instaló de más"
run ensure_nct6687
[[ "$(<"${MODS}/nct6687.conf")" == nct6687 ]] || fail "MSI: no persistió nct6687"
called 'modprobe nct6687' || fail "MSI: no cargó nct6687"
echo "OK: placa MSI"

# 3. USB NZXT: CoolerControl + liquidctl + servicio, y además RGB.
reset; usb 1-2 1e71 NZXT "NZXT Kraken Z"
run arch
called 'pacman -S --needed --noconfirm liquidctl openrgb i2c-tools$' || fail "NZXT: faltan paquetes de repo"
called 'yay -S --needed --noconfirm coolercontrol$' || fail "NZXT: no instaló coolercontrol"
run ensure_coolercontrol
called 'systemctl enable --now coolercontrold.service' || fail "NZXT: no habilitó coolercontrold"
echo "OK: USB NZXT"

# 4. Lian Li y Keychron (un K2 se anuncia con el vendor de Apple): solo RGB.
for dev in "0cf2 ENE LianLi" "05ac Keychron Keychron_K2" "3434 x Keychron_Q1" "05ac Apple Keychron_K2"; do
  read -r vendor maker product <<<"${dev}"
  reset; usb 1-3 "${vendor}" "${maker}" "${product}"
  run arch
  called 'pacman -S --needed --noconfirm openrgb i2c-tools$' || fail "${dev}: no instaló OpenRGB"
  called 'nct6687\|coolercontrol\|liquidctl' && fail "${dev}: instaló de más"
  run ensure_i2c_dev
  [[ "$(<"${MODS}/i2c-dev.conf")" == i2c-dev ]] || fail "${dev}: no persistió i2c-dev"
  called 'modprobe i2c-dev' || fail "${dev}: no cargó i2c-dev"
done
reset; usb 1-4 05ac "Apple Inc." "Magic Keyboard"
run arch
called "${HW}" && fail "un teclado Apple activó RGB"
echo "OK: Lian Li y Keychron"

# 5. El watcher de modos (bootstrap) solo con USB NZXT.
# shellcheck disable=SC2034 # OS la lee el módulo
watcher() { source "${ROOT_DIR}/scripts/modules/coolercontrol.sh"; OS=omarchy; ensure_coolercontrol_mode_watcher; }
reset; usb 1-1 0cf2 ENE LianLi
run watcher
called coolercontrol-setup && fail "watcher activado sin NZXT"
usb 1-2 1e71 NZXT "NZXT Kraken Z"
run watcher
called coolercontrol-setup || fail "watcher no activado con NZXT"
echo "OK: watcher solo con NZXT"

# 6. Un paquete ya cubierto por provides (coolercontrol-git) no se reinstala: chocaría.
reset; usb 1-2 1e71 NZXT "NZXT Kraken Z"
PROVIDED="coolercontrol liquidctl" run ensure_hardware_packages
called 'coolercontrol\|liquidctl' && fail "reinstaló lo ya satisfecho"
called 'pacman -S --needed --noconfirm openrgb i2c-tools$' || fail "no instaló lo que faltaba"
PROVIDED="coolercontrol liquidctl openrgb i2c-tools" run ensure_hardware_packages
[[ ! -s "${CALLS}" ]] || fail "todo satisfecho y aun así instaló"
echo "OK: lo satisfecho por provides se omite"

# 7. Una instalación fallida avisa y sigue.
reset; board "Micro-Star International Co., Ltd."; usb 1-2 1e71 NZXT "NZXT Kraken Z"
PACMAN_FAILS=1 run ensure_hardware_packages || fail "pacman fallido abortó"
called 'yay -S --needed --noconfirm coolercontrol nct6687d-dkms-git$' || fail "no siguió con AUR"
grep -q 'AVISO' "${TMP}/out" || fail "pacman fallido sin aviso"
fake yay 'exit 1'
run ensure_hardware_packages || fail "yay fallido abortó"
grep -q 'AVISO' "${TMP}/out" || fail "yay fallido sin aviso"
echo "OK: una instalación fallida avisa y sigue"
