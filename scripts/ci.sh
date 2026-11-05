#!/usr/bin/env bash
set -uo pipefail

# Entrada única de los chequeos del repo: corre scripts/test-*.sh y shellcheck sobre los .sh
# versionados. Corre todo aunque algo falle, imprime un resumen y sale ≠0 si hubo fallos.
# Los tests de hooks (*.test.mjs) ya los agrega test-hooks.sh, por eso no se descubren aparte.
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SHELLCHECK="${SHELLCHECK:-shellcheck}"
cd "${ROOT_DIR}" || exit 1

PASSED=()
FAILED=()

record() { # $1 nombre, $2 código de salida
  if [[ $2 -eq 0 ]]; then PASSED+=("$1"); else FAILED+=("$1"); fi
}

for t in scripts/test-*.sh; do
  [[ -e "${t}" ]] || continue
  echo "== ${t}"
  rc=0
  bash "${t}" || rc=$?
  record "${t}" "${rc}"
done

echo "== shellcheck"
if ! command -v "${SHELLCHECK}" >/dev/null 2>&1; then
  echo "shellcheck no está instalado: instálalo (apt/dnf/pacman/brew install shellcheck)." >&2
  FAILED+=("shellcheck (no instalado)")
else
  files=()
  while IFS= read -r f; do files+=("${f}"); done < <(git ls-files '*.sh')
  rc=0
  [[ ${#files[@]} -eq 0 ]] || "${SHELLCHECK}" "${files[@]}" || rc=$?
  record "shellcheck" "${rc}"
fi

echo
echo "== resumen"
# ${arr[@]+...}: con set -u, bash < 4.4 falla al expandir un array vacío.
for n in ${PASSED[@]+"${PASSED[@]}"}; do echo "✓ ${n}"; done
for n in ${FAILED[@]+"${FAILED[@]}"}; do echo "✗ ${n}"; done
[[ ${#FAILED[@]} -eq 0 ]]
