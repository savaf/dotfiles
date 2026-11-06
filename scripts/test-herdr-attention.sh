#!/usr/bin/env bash
set -euo pipefail

# Prueba el widget herdr-attention con un `herdr` falso en el PATH. Sin frameworks.
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="${ROOT_DIR}/omarchy/.config/omarchy/bar/scripts/herdr-attention"
SHELL_JSON="${ROOT_DIR}/omarchy/.config/omarchy/shell.json"

fail() { echo "FAIL: $*"; exit 1; }

tmp="$(mktemp -d)"
trap 'rm -rf "${tmp}"' EXIT
mkdir "${tmp}/bin"
cat >"${tmp}/bin/herdr" <<'FAKE'
#!/usr/bin/env bash
[[ "$1 $2" == "agent list" ]] || exit 2
[[ -z "${FAKE_FAIL:-}" ]] || exit 1
cat "${FAKE_JSON}"
FAKE
chmod +x "${tmp}/bin/herdr"

run() { PATH="${tmp}/bin:${PATH}" FAKE_JSON="${tmp}/list.json" bash "${SCRIPT}"; }

# Sin agentes: salida vacía.
echo '{"id":"cli:agent:list","result":{"agents":[],"type":"agent_list"}}' >"${tmp}/list.json"
[[ -z "$(run)" ]] || fail "con 0 agentes debe imprimir nada"

# Solo working/idle: vacío.
echo '{"result":{"agents":[{"agent_status":"working","name":"a"},{"agent_status":"idle","name":"b"}]}}' >"${tmp}/list.json"
[[ -z "$(run)" ]] || fail "working/idle no deben contar"

# Bloqueados y terminados: conteo y tooltip.
cat >"${tmp}/list.json" <<'JSON'
{"result":{"agents":[
 {"agent_status":"blocked","name":"fix","agent":"claude"},
 {"agent_status":"done","name":null,"display_agent":"codex"},
 {"agent_status":"working","name":"w"}]}}
JSON
out="$(run)"
jq -e '.text | endswith("2")' <<<"${out}" >/dev/null || fail "texto sin el conteo 2: ${out}"
jq -e '.class == "attention"' <<<"${out}" >/dev/null || fail "falta class attention: ${out}"
jq -e '.tooltip | contains("blocked: fix") and contains("done: codex")' <<<"${out}" >/dev/null \
  || fail "tooltip incorrecto: ${out}"

# herdr no responde: vacío y salida 0 (el widget no debe romper la barra).
rc=0
out="$(PATH="${tmp}/bin:${PATH}" FAKE_FAIL=1 bash "${SCRIPT}")" || rc=$?
[[ ${rc} -eq 0 && -z "${out}" ]] || fail "herdr caído debe dar salida vacía y rc 0"

# Entrada en shell.json.
jq -e '.version' "${SHELL_JSON}" >/dev/null || fail "shell.json inválido"
jq -e '.bar.layout.centerEnd[] | select(.id=="herdr-attention")
  | .type=="command" and .interval>=10 and (.onClick|test("omarchy-launch-terminal")) and (.onClick|test("herdr"))
    and (.exec|test("herdr-attention"))' "${SHELL_JSON}" | grep -q true || fail "falta la entrada herdr-attention en centerEnd"
jq -e '.bar.layout.centerEnd[-1].id=="herdr-attention"' "${SHELL_JSON}" >/dev/null || fail "herdr-attention debe ir al final de centerEnd"

echo "ok"
