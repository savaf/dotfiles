#!/usr/bin/env bash
# Hace de `xdg-open` / `open` durante un login de teamclaude: abre la URL en una sesión de
# navegador DISTINTA por cuenta, para que el login de la segunda no herede la sesión de
# claude.ai de la primera. Lo prepara setup-teamclaude.sh (TC_BROWSER_ACCOUNT, TC_BROWSER_PROFILE).
#
# 1. Brave (si está): un perfil de Brave por cuenta, con sus extensiones (p. ej. Bitwarden y
#    passkeys). personal -> TC_BRAVE_PROFILE_PERSONAL (def. "Default"), ccw -> TC_BRAVE_PROFILE_CCW
#    (def. "Profile 1", Brave lo crea vacío la primera vez: instala ahí Bitwarden una vez).
# 2. Sin Brave: Chrome/Edge/Chromium con un --user-data-dir limpio ($TC_BROWSER_PROFILE).
set -uo pipefail

url="${1:-}"
[[ -n "${url}" ]] || exit 1
acct="${TC_BROWSER_ACCOUNT:-personal}"
dir="${TC_BROWSER_PROFILE:-}"

case "${acct}" in
  personal) brave_profile="${TC_BRAVE_PROFILE_PERSONAL:-Default}" ;;
  *)        brave_profile="${TC_BRAVE_PROFILE_CCW:-Profile 1}" ;;
esac

flags=(--no-first-run --no-default-browser-check --new-window)
brave=(--profile-directory="${brave_profile}" --new-window)

if grep -qi microsoft /proc/version 2>/dev/null; then
  # WSL: navegadores de Windows; un --user-data-dir propio debe vivir en el disco de Windows.
  for exe in "/mnt/c/Program Files/BraveSoftware/Brave-Browser/Application/brave.exe" \
             "/mnt/c/Program Files (x86)/BraveSoftware/Brave-Browser/Application/brave.exe"; do
    if [[ -x "${exe}" ]]; then
      "${exe}" "${brave[@]}" "${url}" >/dev/null 2>&1 &
      exit 0
    fi
  done
  for exe in "/mnt/c/Program Files/Google/Chrome/Application/chrome.exe" \
             "/mnt/c/Program Files (x86)/Google/Chrome/Application/chrome.exe" \
             "/mnt/c/Program Files (x86)/Microsoft/Edge/Application/msedge.exe"; do
    if [[ -x "${exe}" && -n "${dir}" ]]; then
      "${exe}" "--user-data-dir=$(wslpath -w "${dir}")" "${flags[@]}" "${url}" >/dev/null 2>&1 &
      exit 0
    fi
  done
elif [[ "$(uname -s)" == Darwin ]]; then
  if [[ -d "/Applications/Brave Browser.app" ]]; then
    /usr/bin/open -na "Brave Browser" --args "${brave[@]}" "${url}"
    exit 0
  fi
  for app in "Google Chrome" "Microsoft Edge"; do
    if [[ -d "/Applications/${app}.app" && -n "${dir}" ]]; then
      /usr/bin/open -na "${app}" --args "--user-data-dir=${dir}" "${flags[@]}" "${url}"
      exit 0
    fi
  done
else
  for bin in brave-browser brave; do
    if command -v "${bin}" >/dev/null 2>&1; then
      "${bin}" "${brave[@]}" "${url}" >/dev/null 2>&1 &
      exit 0
    fi
  done
  for bin in google-chrome google-chrome-stable chromium chromium-browser microsoft-edge; do
    if command -v "${bin}" >/dev/null 2>&1 && [[ -n "${dir}" ]]; then
      "${bin}" "--user-data-dir=${dir}" "${flags[@]}" "${url}" >/dev/null 2>&1 &
      exit 0
    fi
  done
fi

# Sin navegador conocido: URL por pantalla para abrirla a mano en una ventana de incógnito nueva.
echo "[teamclaude] No hay Brave/Chrome/Edge: abre esta URL en una ventana de incógnito NUEVA:" >&2
echo "${url}" >&2
exit 0
