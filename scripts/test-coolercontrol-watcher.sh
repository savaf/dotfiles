#!/usr/bin/env bash
set -euo pipefail

# Prueba del watcher ante un token rechazado: no debe llamar a coolercontrol-provision
# ni reintentar en bucle. curl, notify-send y provision son falsos; HOME y runtime temporales.
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT
fail() { echo "FAIL: $*"; exit 1; }
command -v jq >/dev/null || { echo "skip: falta jq"; exit 0; }

mkdir -p "${TMP}/bin" "${TMP}/state/coolercontrol-modes" "${TMP}/run" "${TMP}/watch"
cp "${ROOT_DIR}/coolercontrol/.local/bin/coolercontrol-mode-watcher" "${TMP}/watch/"
printf '#!/bin/sh\ntouch "%s/provision-called"\n' "${TMP}" >"${TMP}/watch/coolercontrol-provision"
printf '#!/bin/sh\necho x >>"%s/curl-calls"\necho "$CURL_BODY"\n' "${TMP}" >"${TMP}/bin/curl"
printf '#!/bin/sh\ntouch "%s/notified"\n' "${TMP}" >"${TMP}/bin/notify-send"
chmod +x "${TMP}/watch/"* "${TMP}/bin/"*
echo "token_falso" >"${TMP}/state/coolercontrol-modes/api-token"

run() {  # run CUERPO_DE_LA_API -> salida del watcher en ${TMP}/out
  rm -f "${TMP}/provision-called" "${TMP}/curl-calls" "${TMP}/notified"
  CURL_BODY="$1" PATH="${TMP}/bin:${PATH}" XDG_STATE_HOME="${TMP}/state" XDG_RUNTIME_DIR="${TMP}/run" \
    AUTH_BACKOFF_START=60 timeout 3 bash "${TMP}/watch/coolercontrol-mode-watcher" >"${TMP}/out" 2>&1 || true
}

# 1. 429: no aprovisiona, avisa una vez, hace una sola consulta y espera
run '{"error":"Too many failed authentication attempts. Try again in 98s."}'
[[ ! -e "${TMP}/provision-called" ]] || fail "429: llamó a provision"
[[ -e "${TMP}/notified" ]] || fail "429: no avisó"
[[ "$(wc -l <"${TMP}/curl-calls")" -eq 1 ]] || fail "429: reintentó sin esperar"
grep -q "no acepta el token" "${TMP}/out" || fail "429: no explica el motivo"
echo "OK: 429 sin provision ni bucle"

# 2. credenciales inválidas: igual
run '{"error":"Invalid Credentials"}'
[[ ! -e "${TMP}/provision-called" ]] || fail "401: llamó a provision"
[[ "$(wc -l <"${TMP}/curl-calls")" -eq 1 ]] || fail "401: reintentó sin esperar"
echo "OK: credenciales inválidas sin provision ni bucle"

# 3. el fichero de bloqueo queda en el futuro (lo respeta reconcile)
[[ -f "${TMP}/run/coolercontrol-mode-watcher.authfail" ]] || fail "no anotó el fallo"
(( $(<"${TMP}/run/coolercontrol-mode-watcher.authfail") > $(date +%s) )) || fail "bloqueo ya vencido"
echo "OK: bloqueo anotado"
