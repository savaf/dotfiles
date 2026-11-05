#!/usr/bin/env bash
set -euo pipefail

# Tests de scripts/ci.sh por su salida y código de salida. Cada caso arma un repo git temporal
# con una copia de ci.sh y fixtures. Sin frameworks.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CI="${SCRIPT_DIR}/ci.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT

fail() { echo "FAIL: $*"; echo "--- salida:"; echo "${OUT}"; exit 1; }

# Repo temporal $1 con ci.sh y un script limpio.
make_repo() {
  local r="${TMP}/$1"
  mkdir -p "${r}/scripts"
  cp "${CI}" "${r}/scripts/ci.sh"
  printf '#!/usr/bin/env bash\necho "limpio"\n' >"${r}/scripts/clean.sh"
  (cd "${r}" && git init -q)
}

add_test() { # $1 repo, $2 nombre, $3 código de salida
  printf '#!/usr/bin/env bash\necho "corrió %s"\nexit %s\n' "$2" "$3" >"${TMP}/$1/scripts/$2"
}

run() { # $1 repo; resto: entorno extra. Guarda OUT y RC.
  local r="$1"
  shift
  (cd "${TMP}/${r}" && git add -A)
  RC=0
  OUT="$(env "$@" bash "${TMP}/${r}/scripts/ci.sh" 2>&1)" || RC=$?
}

# 1. Todo verde: exit 0 y resumen.
make_repo green
add_test green test-a.sh 0
run green
[[ ${RC} -eq 0 ]] || fail "todo verde debía salir 0 (salió ${RC})"
grep -q "✓ scripts/test-a.sh" <<<"${OUT}" || fail "falta ✓ del test"
grep -q "✓ shellcheck" <<<"${OUT}" || fail "falta ✓ de shellcheck"
echo "OK: todo verde"

# 2. Un test falla: exit ≠0 y el siguiente igual se ejecuta.
make_repo failing
add_test failing test-a.sh 1
add_test failing test-b.sh 0
run failing
[[ ${RC} -ne 0 ]] || fail "test fallido debía salir ≠0"
grep -q "✗ scripts/test-a.sh" <<<"${OUT}" || fail "falta ✗ del test fallido"
grep -q "corrió test-b.sh" <<<"${OUT}" || fail "el fallo ocultó el test siguiente"
echo "OK: test fallido no oculta los demás"

# 3. Hallazgo de shellcheck: exit ≠0.
make_repo finding
add_test finding test-a.sh 0
printf '#!/usr/bin/env bash\nx=$1\necho $x\n' >"${TMP}/finding/scripts/bad.sh"
run finding
[[ ${RC} -ne 0 ]] || fail "hallazgo de shellcheck debía salir ≠0"
grep -q "✗ shellcheck" <<<"${OUT}" || fail "falta ✗ de shellcheck"
echo "OK: hallazgo de shellcheck"

# 4. shellcheck ausente: mensaje claro y exit ≠0.
make_repo nosc
add_test nosc test-a.sh 0
run nosc SHELLCHECK=shellcheck-no-existe
[[ ${RC} -ne 0 ]] || fail "sin shellcheck debía salir ≠0"
grep -qi "shellcheck no está instalado" <<<"${OUT}" || fail "falta mensaje de shellcheck ausente"
echo "OK: shellcheck ausente"
