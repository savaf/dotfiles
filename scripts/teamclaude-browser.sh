#!/usr/bin/env bash
# Hace de `xdg-open` / `open` durante un login de teamclaude: abre la URL en un perfil de
# navegador AISLADO ($TC_BROWSER_PROFILE, cookies propias), para que el login de la segunda
# cuenta no herede la sesión de claude.ai de la primera. Lo prepara setup-teamclaude.sh.
set -uo pipefail

url="${1:-}"
dir="${TC_BROWSER_PROFILE:-}"
[[ -n "${url}" && -n "${dir}" ]] || exit 1

flags=(--no-first-run --no-default-browser-check --new-window)

if grep -qi microsoft /proc/version 2>/dev/null; then
  # WSL: Chrome/Edge de Windows; el perfil debe vivir en el disco de Windows.
  for exe in "/mnt/c/Program Files/Google/Chrome/Application/chrome.exe" \
             "/mnt/c/Program Files (x86)/Google/Chrome/Application/chrome.exe" \
             "/mnt/c/Program Files (x86)/Microsoft/Edge/Application/msedge.exe"; do
    if [[ -x "${exe}" ]]; then
      "${exe}" "--user-data-dir=$(wslpath -w "${dir}")" "${flags[@]}" "${url}" >/dev/null 2>&1 &
      exit 0
    fi
  done
elif [[ "$(uname -s)" == Darwin ]]; then
  for app in "Google Chrome" "Microsoft Edge" "Brave Browser"; do
    if [[ -d "/Applications/${app}.app" ]]; then
      /usr/bin/open -na "${app}" --args "--user-data-dir=${dir}" "${flags[@]}" "${url}"
      exit 0
    fi
  done
else
  for bin in google-chrome google-chrome-stable chromium chromium-browser brave-browser microsoft-edge; do
    if command -v "${bin}" >/dev/null 2>&1; then
      "${bin}" "--user-data-dir=${dir}" "${flags[@]}" "${url}" >/dev/null 2>&1 &
      exit 0
    fi
  done
fi

# Sin navegador chromium conocido: URL por pantalla para abrirla a mano en incógnito.
echo "[teamclaude] No hay Chrome/Edge/Brave: abre esta URL en una ventana de incógnito NUEVA:" >&2
echo "${url}" >&2
exit 0
