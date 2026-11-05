# Procedencia: copia literal de scripts/lib/third-party.sh de b0-conuco (tp_hash, fetch_skill,
# tp_each_lock, tp_lock_tier). Las líneas siguientes son el original sin cambios.
# Librería para bajar skills de terceros fijadas por commit y verificadas por hash.
# Se hace `source`; no cambia opciones del shell. Compatible con bash 3.2.
# Solo usa curl, tar y sha256sum (o shasum). Nunca ejecuta nada de lo descargado.
#
# Env:
#   B0_TARBALL_BASE  reemplaza https://codeload.github.com (los tests usan file://...).
#                    El tarball se busca en <base>/<owner>/<repo>/tar.gz/<commit>.

tp_log() { printf '%s\n' "$*" >&2; }

# sha256 del stdin, solo el hash.
tp_sha() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum | cut -d' ' -f1; else shasum -a 256 | cut -d' ' -f1; fi
}

# Hash de contenido de las auditorías:
#   (cd <dir> && find . -type f | LC_ALL=C sort | xargs sha256sum) | sha256sum
# Para un archivo único, la misma fórmula sobre ese archivo llamado ./SKILL.md.
tp_hash() {
  local p="$1" f
  if [ -f "${p}" ]; then
    printf '%s  ./SKILL.md\n' "$(tp_sha < "${p}")" | tp_sha
    return
  fi
  (
    cd "${p}" || exit 1
    find . -type f | LC_ALL=C sort | while IFS= read -r f; do
      printf '%s  %s\n' "$(tp_sha < "${f}")" "${f}"
    done | tp_sha
  )
}

# fetch_skill <name> <owner/repo> <commit> <ruta-en-el-repo> <sha256> <dest_root>
# Instala en <dest_root>/<name>. Rechaza (y limpia) si el hash no coincide.
# Si lo ya instalado coincide, no descarga nada.
fetch_skill() {
  local name="$1" repo="$2" commit="$3" path="$4" want="$5" root="$6"
  local dest="${root}/${name}" base="${B0_TARBALL_BASE:-https://codeload.github.com}"
  local tmp rc=0

  if [ -d "${dest}" ] && [ "$(tp_hash "${dest}" 2>/dev/null)" = "${want}" ]; then
    tp_log "  ok  ${name} (ya instalada)"
    return 0
  fi

  tmp="$(mktemp -d)" || return 1
  _tp_fetch_into "${tmp}" "${name}" "${repo}" "${commit}" "${path}" "${want}" "${base}" || rc=$?
  if [ "${rc}" -eq 0 ]; then
    mkdir -p "${root}" && rm -rf "${dest}" && mv "${tmp}/stage" "${dest}" || rc=1
  fi
  rm -rf "${tmp}"
  [ "${rc}" -eq 0 ] || return "${rc}"
  tp_log "  ok  ${name} (${repo}@$(printf '%s' "${commit}" | cut -c1-8))"
}

# Descarga, extrae, verifica y deja el resultado en <tmp>/stage. No toca el destino final.
_tp_fetch_into() {
  local tmp="$1" name="$2" repo="$3" commit="$4" path="$5" want="$6" base="$7"
  local top found got
  mkdir "${tmp}/x" || return 1
  curl -fsSL --retry 2 -o "${tmp}/src.tgz" "${base}/${repo}/tar.gz/${commit}" \
    || { tp_log "  ERROR ${name}: no se pudo descargar ${repo}@${commit}"; return 1; }
  tar -xzf "${tmp}/src.tgz" -C "${tmp}/x" \
    || { tp_log "  ERROR ${name}: tarball ilegible"; return 1; }
  top="$(find "${tmp}/x" -mindepth 1 -maxdepth 1 -type d | head -n 1)"
  found="${top}/${path}"
  if [ -z "${top}" ] || { [ ! -d "${found}" ] && [ ! -f "${found}" ]; }; then
    tp_log "  ERROR ${name}: no existe ${path} en ${repo}@${commit}"
    return 1
  fi
  if [ -d "${found}" ] && [ -n "$(find "${found}" ! -type f ! -type d)" ]; then
    tp_log "  ERROR ${name}: la skill trae symlinks u otros archivos especiales; rechazada"
    return 1
  fi
  got="$(tp_hash "${found}")"
  if [ "${got}" != "${want}" ]; then
    tp_log "  ERROR ${name}: el hash no coincide (esperado ${want}, obtenido ${got}); rechazada"
    return 1
  fi
  mkdir "${tmp}/stage" || return 1
  if [ -f "${found}" ]; then cp "${found}" "${tmp}/stage/SKILL.md"; else cp -R "${found}/." "${tmp}/stage/"; fi
}

# Recorre el lock y llama a "$1 name repo commit path sha tier" por cada línea.
tp_each_lock() {
  local cb="$1" lock="$2" name r c p h t
  while IFS="$(printf '\t')" read -r name r c p h t; do
    case "${name}" in ''|'#'*) continue ;; esac
    "${cb}" "${name}" "${r}" "${c}" "${p}" "${h}" "${t}"
  done < "${lock}"
}

# tp_lock_tier <lock> <name>: imprime el tier de <name> en el lock (nada si no está).
tp_lock_tier() {
  awk -F'\t' -v n="$2" '$1 == n { print $6; exit }' "$1"
}
