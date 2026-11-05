#!/usr/bin/env bash
set -euo pipefail

# Tests de scripts/check-skills.sh por su salida y código de salida, con HOME falsos y un `gh`
# falso en el PATH. Sin frameworks.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK="${SCRIPT_DIR}/check-skills.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT

REQUIRED=(tdd diagnosing-bugs implement codebase-design code-review
  domain-modeling ask-matt to-spec to-tickets implement-spec improve-codebase-architecture
  ponytail ponytail-review verification-before-completion testing-strategy pr-security-review)
OPTIONAL=(resolving-merge-conflicts vitest playwright-best-practices security-audit humanizer)

fail() { echo "FAIL: $*"; echo "--- salida:"; echo "${OUT}"; exit 1; }

# gh falso: $1 = línea "Token scopes" ('' = sin línea), $2 = código de salida de auth status.
fake_gh() {
  mkdir -p "${TMP}/bin"
  cat >"${TMP}/bin/gh" <<EOF
#!/usr/bin/env bash
[[ "\$1 \$2" == "auth status" ]] || exit 0
echo "github.com"
echo "  - Token scopes: $1"
exit ${2:-0}
EOF
  chmod +x "${TMP}/bin/gh"
}

# HOME con las skills dadas como directorios con SKILL.md.
make_home() {  # $1 nombre del HOME, resto skills
  local h="${TMP}/$1"; shift
  mkdir -p "${h}/.claude/skills"
  local s
  for s in "$@"; do
    mkdir -p "${h}/.claude/skills/${s}"
    echo "# ${s}" >"${h}/.claude/skills/${s}/SKILL.md"
  done
}

run() {  # $1 HOME ; PATH con el gh falso delante. Guarda OUT y RC.
  RC=0
  OUT="$(HOME="${TMP}/$1" PATH="${TMP}/bin:${PATH}" bash "${CHECK}" 2>&1)" || RC=$?
}

GOOD_SCOPES="'gist', 'project', 'read:org', 'read:project', 'repo', 'workflow'"

# 1. Todo presente: exit 0, una línea con check por ítem.
fake_gh "${GOOD_SCOPES}"
make_home full "${REQUIRED[@]}" "${OPTIONAL[@]}"
run full
[[ ${RC} -eq 0 ]] || fail "todo presente debía salir 0 (salió ${RC})"
for s in "${REQUIRED[@]}"; do grep -q "✓ ${s}\$" <<<"${OUT}" || fail "falta línea ✓ de ${s}"; done
grep -q "✓ gh scopes" <<<"${OUT}" || fail "falta ✓ gh scopes"
echo "OK: todo presente"

# 2. Falta una requerida: exit 1, cruz con ese nombre.
make_home nopony "${REQUIRED[@]/ponytail-review/}" "${OPTIONAL[@]}"
rm -rf "${TMP}/nopony/.claude/skills/ponytail-review"
run nopony
[[ ${RC} -eq 1 ]] || fail "falta requerida debía salir 1 (salió ${RC})"
grep -q "✗ ponytail-review" <<<"${OUT}" || fail "falta ✗ ponytail-review"
echo "OK: requerida ausente"

# 3. Falta una opcional: aviso, exit 0.
make_home noopt "${REQUIRED[@]}"
run noopt
[[ ${RC} -eq 0 ]] || fail "opcionales ausentes no deben fallar (salió ${RC})"
grep -q "vitest" <<<"${OUT}" || fail "no menciona la opcional vitest"
! grep -q "✗ vitest" <<<"${OUT}" || fail "una opcional no debe llevar ✗"
echo "OK: opcional ausente solo avisa"

# 4. SKILL.md vacío o enlace roto cuenta como ausente; enlace a archivo legible cuenta.
make_home bad "${REQUIRED[@]}"
: >"${TMP}/bad/.claude/skills/tdd/SKILL.md"
rm "${TMP}/bad/.claude/skills/implement/SKILL.md"
ln -s "${TMP}/nowhere" "${TMP}/bad/.claude/skills/implement/SKILL.md"
rm -rf "${TMP}/bad/.claude/skills/code-review"
mkdir -p "${TMP}/real/code-review"; echo "# cr" >"${TMP}/real/code-review/SKILL.md"
ln -s "${TMP}/real/code-review" "${TMP}/bad/.claude/skills/code-review"
run bad
[[ ${RC} -eq 1 ]] || fail "vacío/roto debía salir 1"
grep -q "✗ tdd" <<<"${OUT}" || fail "SKILL.md vacío debía ser ✗"
grep -q "✗ implement" <<<"${OUT}" || fail "enlace roto debía ser ✗"
grep -q "✓ code-review" <<<"${OUT}" || fail "enlace a skill legible debía ser ✓"
echo "OK: vacío, roto y symlink"

# 5. CLAUDE_CONFIG_DIR manda sobre $HOME/.claude.
RC=0
OUT="$(HOME="${TMP}/noopt" CLAUDE_CONFIG_DIR="${TMP}/nowhere-cfg" PATH="${TMP}/bin:${PATH}" bash "${CHECK}" 2>&1)" || RC=$?
[[ ${RC} -eq 1 ]] || fail "CLAUDE_CONFIG_DIR vacío debía salir 1"
echo "OK: CLAUDE_CONFIG_DIR"

# 6. Faltan scopes de gh: exit 1 con el comando exacto de arreglo.
fake_gh "'gist', 'read:org', 'repo'"
run full
[[ ${RC} -eq 1 ]] || fail "scopes incompletos debía salir 1"
grep -q "gh auth refresh -s project,read:project,repo" <<<"${OUT}" || fail "falta el comando de arreglo"
echo "OK: scopes de gh"

# 7. gh sin sesión: exit 1.
fake_gh "" 1
run full
[[ ${RC} -eq 1 ]] || fail "gh sin sesión debía salir 1"
echo "OK: gh sin sesión"

# 8. Herramienta ausente (jq): exit 1 con ✗ jq. PATH mínimo sin jq.
fake_gh "${GOOD_SCOPES}"
mkdir -p "${TMP}/nojq"
for t in bash gh python3 node npx git curl tar cat grep sed tr sort head cut awk; do
  p="$(command -v "${t}" 2>/dev/null || true)"
  if [[ -x "${TMP}/bin/${t}" ]]; then p="${TMP}/bin/${t}"; fi
  [[ -n "${p}" ]] && ln -sf "${p}" "${TMP}/nojq/${t}"
done
RC=0
OUT="$(HOME="${TMP}/full" PATH="${TMP}/nojq" "${TMP}/nojq/bash" "${CHECK}" 2>&1)" || RC=$?
[[ ${RC} -eq 1 ]] || fail "jq ausente debía salir 1 (salió ${RC})"
grep -q "✗ jq" <<<"${OUT}" || fail "falta ✗ jq"
echo "OK: herramienta ausente"

# 9. impeccable es opt-in: presente o ausente no produce ✗ ni aviso, y no cambia el exit 0.
fake_gh "${GOOD_SCOPES}"
make_home impno "${REQUIRED[@]}" "${OPTIONAL[@]}"
make_home impyes "${REQUIRED[@]}" "${OPTIONAL[@]}" impeccable
for h in impno impyes; do
  run "${h}"
  [[ ${RC} -eq 0 ]] || fail "impeccable (${h}) no debe fallar (salió ${RC})"
  ! grep -q "^✗" <<<"${OUT}" || fail "impeccable (${h}) no debe producir ✗"
  ! grep -q "^!" <<<"${OUT}" || fail "impeccable (${h}) no debe producir avisos"
  grep -q "0 optional missing" <<<"${OUT}" || fail "impeccable (${h}) no debe contar como opcional ausente"
done
echo "OK: impeccable opt-in sin fallo ni aviso"
