#!/usr/bin/env bash
set -euo pipefail

# Self-check de install.sh (instalador de una línea), sin red: usa un repo git
# local como DOTFILES_REPO con un scripts/bootstrap.sh falso que deja un marcador.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL="${SCRIPT_DIR}/../install.sh"

TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT

fail() { echo "FAIL: $*"; exit 1; }

export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t

# Repo origen falso.
SRC="${TMP}/src"
mkdir -p "${SRC}/scripts"
cat > "${SRC}/scripts/bootstrap.sh" <<'EOF'
#!/usr/bin/env bash
echo "args:$*" >> "${MARKER}"
EOF
git -C "${SRC}" init -q -b main
git -C "${SRC}" add -A
git -C "${SRC}" commit -qm init

export DOTFILES_REPO="${SRC}" DOTFILES_DIR="${TMP}/dest" MARKER="${TMP}/marker"

# Simula `curl | bash`: stdin no es una terminal.
run() { bash "${INSTALL}" "$@" < /dev/null; }

# 1. Clon nuevo + bootstrap con argumentos.
run --foo >/dev/null
[[ -d "${DOTFILES_DIR}/.git" ]] || fail "no clonó"
grep -qx "args:--foo" "${MARKER}" || fail "bootstrap no recibió args"

# 2. Segunda ejecución: pull ff-only (trae el commit nuevo), no re-clona.
echo x > "${SRC}/nuevo"
git -C "${SRC}" add -A && git -C "${SRC}" commit -qm nuevo
run >/dev/null
[[ -f "${DOTFILES_DIR}/nuevo" ]] || fail "no hizo pull"
[[ "$(wc -l < "${MARKER}")" -eq 2 ]] || fail "bootstrap no corrió en la 2.ª ejecución"

# 3. DOTFILES_NO_BOOTSTRAP=1 no lanza el bootstrap.
DOTFILES_NO_BOOTSTRAP=1 run >/dev/null
[[ "$(wc -l < "${MARKER}")" -eq 2 ]] || fail "corrió bootstrap con DOTFILES_NO_BOOTSTRAP=1"

# 4. Directorio existente con otro origin: sale ≠0 sin tocarlo.
OTHER="${TMP}/other"
git init -q "${OTHER}"
git -C "${OTHER}" remote add origin https://example.com/otro.git
if DOTFILES_DIR="${OTHER}" run >/dev/null 2>&1; then fail "aceptó un repo ajeno"; fi
[[ -z "$(find "${OTHER}" -mindepth 1 -maxdepth 1 ! -name .git)" ]] || fail "tocó el repo ajeno"

# 5. Directorio existente que no es repo git: sale ≠0.
mkdir -p "${TMP}/plain"
if DOTFILES_DIR="${TMP}/plain" run >/dev/null 2>&1; then fail "aceptó un dir no-git"; fi

echo "OK: install.sh"
