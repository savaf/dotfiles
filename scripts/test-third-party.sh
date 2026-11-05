#!/usr/bin/env bash
# Test de scripts/lib/third-party.sh (fetch_skill, tp_hash), del paso de skills fijadas por tarball de
# scripts/install-claude-skills.sh y del manifiesto packages/claude-skills.txt (líneas CLI vs líneas con tarball fijado).
# Sin red: el "GitHub" es un directorio local con tarballs de fixture (B0_TARBALL_BASE=file://...).
set -uo pipefail
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/third-party.sh
. "${repo}/scripts/lib/third-party.sh"

fails=0
ok() { echo "ok   $1"; }
bad() { echo "FAIL $1"; fails=$((fails + 1)); }
check() { if "${@:2}"; then ok "$1"; else bad "$1"; fi; }

work="$(mktemp -d)"
trap 'rm -rf "${work}"' EXIT
export TMPDIR="${work}/tmp"; mkdir -p "${TMPDIR}"

# Fixture: owner/repo con una skill de directorio y una SKILL.md en la raíz.
commit="0123456789abcdef0123456789abcdef01234567"
src="${work}/src/repo-${commit}"
mkdir -p "${src}/skills/demo/references" "${src}/skills/with space"
printf 'demo\n' > "${src}/skills/demo/SKILL.md"
printf 'ref\n' > "${src}/skills/demo/references/a.md"
printf 'root skill\n' > "${src}/SKILL.md"
base="${work}/gh"
mkdir -p "${base}/owner/repo/tar.gz"
tar -czf "${base}/owner/repo/tar.gz/${commit}" -C "${work}/src" "repo-${commit}"
export B0_TARBALL_BASE="file://${base}"

# Fórmula de las auditorías, escrita aparte de la librería.
ref_dir() { (cd "$1" && find . -type f | LC_ALL=C sort | xargs sha256sum) | sha256sum | cut -d' ' -f1; }
want_dir="$(ref_dir "${src}/skills/demo")"
want_file="$(printf '%s  ./SKILL.md\n' "$(sha256sum "${src}/SKILL.md" | cut -d' ' -f1)" | sha256sum | cut -d' ' -f1)"

dest="${work}/out"

check "tp_hash de un directorio sigue la fórmula de las auditorías" \
  test "$(tp_hash "${src}/skills/demo")" = "${want_dir}"

fetch_skill demo owner/repo "${commit}" skills/demo "${want_dir}" "${dest}" >/dev/null 2>&1
check "fetch_skill instala un directorio verificado" test -f "${dest}/demo/references/a.md"
check "el instalado coincide con el hash" test "$(tp_hash "${dest}/demo")" = "${want_dir}"

fetch_skill root owner/repo "${commit}" SKILL.md "${want_file}" "${dest}" >/dev/null 2>&1
check "fetch_skill instala un archivo único como <name>/SKILL.md" test -f "${dest}/root/SKILL.md"
check "un archivo único usa la fórmula sobre ./SKILL.md" test "$(tp_hash "${dest}/root")" = "${want_file}"

# Idempotente: sin red, la segunda corrida no descarga nada.
B0_TARBALL_BASE="file://${work}/no-existe" fetch_skill demo owner/repo "${commit}" skills/demo "${want_dir}" "${dest}" >/dev/null 2>&1
check "segunda corrida omite la descarga si el hash ya coincide" test $? -eq 0

# Hash distinto: rechaza, no instala, no deja temporales.
fetch_skill bad owner/repo "${commit}" skills/demo "$(printf 'f%.0s' $(seq 64))" "${dest}" >/dev/null 2>&1
check "hash distinto: falla" test $? -ne 0
check "hash distinto: no instala nada" test ! -e "${dest}/bad"
check "hash distinto: limpia los temporales" test -z "$(ls -A "${TMPDIR}")"

# Instalación vieja corrupta: se reemplaza solo si el nuevo contenido verifica.
mkdir -p "${dest}/stale"; echo tampered > "${dest}/stale/SKILL.md"
fetch_skill stale owner/repo "${commit}" skills/demo "${want_dir}" "${dest}" >/dev/null 2>&1
check "copia instalada alterada se rehace desde el tarball" test "$(tp_hash "${dest}/stale")" = "${want_dir}"

# Ruta inexistente.
fetch_skill nope owner/repo "${commit}" skills/nope "${want_dir}" "${dest}" >/dev/null 2>&1
check "ruta inexistente en el tarball: falla" test $? -ne 0

# Un symlink en el tarball no pasa (find -type f no lo vería).
sl="${work}/src2/repo-${commit}"; mkdir -p "${sl}/skills/demo" "${base}/owner/linky/tar.gz"
printf 'demo\n' > "${sl}/skills/demo/SKILL.md"; ln -s /etc/passwd "${sl}/skills/demo/leak"
tar -czf "${base}/owner/linky/tar.gz/${commit}" -C "${work}/src2" "repo-${commit}"
fetch_skill link owner/linky "${commit}" skills/demo "$(ref_dir "${sl}/skills/demo")" "${dest}" >/dev/null 2>&1
check "symlink dentro de la skill: falla" test $? -ne 0
check "symlink dentro de la skill: no instala" test ! -e "${dest}/link"

# Descarga imposible.
fetch_skill x owner/ausente "${commit}" skills/demo "${want_dir}" "${dest}" >/dev/null 2>&1
check "tarball inexistente: falla" test $? -ne 0

# Paso de skills fijadas de install-claude-skills.sh. Una línea del manifiesto con las columnas extra
# `owner/repo#<commit> <skill> <ruta> <sha256>` va por tarball verificado; sin ellas, por la CLI.
# `install-claude-skills.sh pinned` corre solo ese paso, con HOME falso y SKILLS_LIST de fixture.
INSTALL="${repo}/scripts/install-claude-skills.sh"
badsha="$(printf 'f%.0s' $(seq 64))"
mk_list() { printf '%s\n' "$@" > "${work}/list.txt"; echo "${work}/list.txt"; }
run_pinned() {  # $1 HOME, $2 manifiesto. Guarda OUT y RC.
  RC=0
  OUT="$(HOME="$1" SKILLS_LIST="$2" bash "${INSTALL}" pinned 2>&1)" || RC=$?
}
good="owner/repo#${commit} demo skills/demo ${want_dir}"

h1="${work}/home1"; mkdir -p "${h1}"
run_pinned "${h1}" "$(mk_list '# comentario' '' "${good}" 'owner/cli-repo#abc cli-skill')"
check "pinned: sale 0 y deja ~/.claude/skills/<name> como directorio real verificado" \
  test "${RC}" -eq 0 -a -d "${h1}/.claude/skills/demo" -a ! -L "${h1}/.claude/skills/demo" -a "$(tp_hash "${h1}/.claude/skills/demo")" = "${want_dir}"
check "pinned: ignora comentarios, líneas vacías y líneas de la CLI" test ! -e "${h1}/.claude/skills/cli-skill"

B0_TARBALL_BASE="file://${work}/no-existe" run_pinned "${h1}" "$(mk_list "${good}")"
check "pinned: idempotente, no descarga si ya coincide" test "${RC}" -eq 0

h2="${work}/home2"; mkdir -p "${h2}"
run_pinned "${h2}" "$(mk_list "owner/repo#${commit} demo skills/demo ${badsha}")"
check "pinned: hash distinto sale distinto de 0 y lo dice" \
  test "${RC}" -ne 0 && grep -q "hash no coincide" <<<"${OUT}"
check "pinned: hash distinto no deja bytes sin verificar" test ! -e "${h2}/.claude/skills/demo"

h3="${work}/home3"; mkdir -p "${h3}/.claude/skills/demo"; echo tampered > "${h3}/.claude/skills/demo/SKILL.md"
run_pinned "${h3}" "$(mk_list "owner/repo#${commit} demo skills/demo ${badsha}")"
check "pinned: una copia previa que no verifica se elimina al fallar" \
  test "${RC}" -ne 0 -a ! -e "${h3}/.claude/skills/demo"

# Líneas mal formadas: rechazadas en voz alta, y la buena de al lado sí se instala.
n=0
for malformed in \
  "owner/repo#${commit} demo skills/demo" \
  "owner/repo#${commit} demo skills/demo ${want_dir} sobra" \
  "owner/repo#${commit} demo skills/demo nohex" \
  "owner/repo demo skills/demo ${want_dir}" \
  "owner/repo#abc123 demo skills/demo ${want_dir}" \
  "owner/repo#${commit} a,b skills/demo ${want_dir}" \
  "owner/repo#${commit} demo ../fuera ${want_dir}"; do
  n=$((n + 1)); hm="${work}/homem${n}"; mkdir -p "${hm}"
  run_pinned "${hm}" "$(mk_list "${malformed}" "owner/repo#${commit} otra skills/demo ${want_dir}")"
  check "pinned: línea mal formada #${n} falla en voz alta y no instala" \
    test "${RC}" -ne 0 && grep -q "mal formada" <<<"${OUT}" && test ! -e "${hm}/.claude/skills/demo"
  check "pinned: la línea buena junto a la mal formada #${n} sí se instala" test -f "${hm}/.claude/skills/otra/SKILL.md"
done

# Corrida completa: la línea CLI sigue yendo por `npx skills add`, la del tarball no; un fallo del
# tarball no detiene el registro de MCP y hace salir distinto de 0.
fb="${work}/fakebin"; mkdir -p "${fb}"; calls="${work}/calls.log"; : > "${calls}"
printf '#!/usr/bin/env bash\necho "npx $*" >> "%s"\n' "${calls}" > "${fb}/npx"
printf '#!/usr/bin/env bash\necho "claude $*" >> "%s"\n[[ "$2" == get ]] && exit 1; exit 0\n' "${calls}" > "${fb}/claude"
chmod +x "${fb}/npx" "${fb}/claude"
hf="${work}/homefull"; mkdir -p "${hf}"
RC=0
OUT="$(HOME="${hf}" PATH="${fb}:${PATH}" SKILLS_LIST="$(mk_list 'owner/cli-repo#abc cli-skill' "owner/repo#${commit} demo skills/demo ${badsha}")" bash "${INSTALL}" 2>&1)" || RC=$?
check "completa: la línea CLI llama a npx skills add con su repo y skill" grep -q 'npx.*skills@.* add owner/cli-repo#abc .*-s cli-skill' "${calls}"
check "completa: la línea con tarball no pasa por npx" test "$(grep -c 'owner/repo' "${calls}")" -eq 0
check "completa: el fallo del tarball no detiene el MCP" grep -q 'claude mcp add' "${calls}"
check "completa: el fallo del tarball hace salir distinto de 0" test "${RC}" -ne 0

# Manifiesto real: líneas con tarball bien formadas; impeccable activa y fijada al tag skill-v4.8.0.
lock="${repo}/packages/claude-skills.txt"
real_ok() {
  local n=0 r o p h x
  while read -r r o p h x; do
    case "${r}" in ''|'#'*) continue ;; esac
    [ -n "${p}" ] || continue
    n=$((n + 1))
    [ -z "${x}" ] || return 1
    printf '%s' "${r}" | grep -Eq '^[^#[:space:]]+/[^#[:space:]]+#[0-9a-f]{40}$' || return 1
    printf '%s' "${h}" | grep -Eq '^[0-9a-f]{64}$' || return 1
  done < "${lock}"
  [ "${n}" -gt 0 ]
}
check "packages/claude-skills.txt: las líneas con tarball están bien formadas" real_ok
check "impeccable está activa en el manifiesto, fijada al tag skill-v4.8.0 (commit, ruta y hash auditados)" \
  grep -qx 'pbakaus/impeccable#414603bf14c7a344edb466bb1f85690c77ce8b7d impeccable \.claude/skills/impeccable 532aa98903b020071ea830f9a97b931e771fa42daea2308af6e4f9f572e65b8b' "${lock}"

[ "${fails}" -eq 0 ] && echo "todo ok" || { echo "${fails} fallos"; exit 1; }
