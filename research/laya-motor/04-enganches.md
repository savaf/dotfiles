# Ticket 04: puntos de enganche en Claude Code

Versión probada: `claude --version` = **2.1.300**. Fecha: 2026-10-14.
Modelos vistos en las pruebas: `claude-sonnet-5-5`, `claude-opus-5-5`, `claude-haiku-5-5`.

Fuentes primarias: docs oficiales (`code.claude.com/docs/en/{hooks,sub-agents,skills,model-config,prompt-caching}`),
los tipos de la API de mods que el propio binario escribe (`plugin-authoring/types/claude-code.d.ts`, build 2.1.300)
y pruebas reales con `claude -p` en `/tmp/laya-lab` (directorio desechable, `--setting-sources project`,
sin tocar `~/.claude` ni el repo). Cada afirmación lleva su origen: **[doc]**, **[tipos]** o **[prueba tN]**.

## Resumen

| | Mecanismo | Funciona | Falla abierto | Límite de latencia | Modo sombra |
|---|---|---|---|---|---|
| (a) modelo de subagente | `PreToolUse` (matcher `Agent`) + `updatedInput.model`; o mod `agent.spawn` | si, verificado | si | 600 s (settings) / 10 s propios (mod) | si, verificado |
| (b) modelo del hilo principal por mensaje | solo mod `turn.step` (reescribe `model` por petición). Ningún hook de settings | si, verificado (con id completo) | si | 10 s propios, suma por respuesta | si, verificado |
| (c) sugerir skill | `UserPromptSubmit` `additionalContext`; o mod `prompt.submit` `context` | si, ambos verificados | si | 30 s (settings) / 10 s (mod) | si |
| (d) modelo de una skill | frontmatter `model:` (y `context: fork` + `agent:`) | si, verificado | n/a (declarativo) | n/a | no aplica, ver (d) |

La pista del mapa anterior queda **confirmada** en lo esencial: `updatedInput.model` sobre la tool `Agent` se aplica,
y los mods con `agent.spawn`, `turn.step` y `prompt.submit` existen y funcionan en 2.1.300. Matices abajo (la sintaxis
de `turn.step` y el formato del modelo no eran obvios).

## (a) Decidir y cambiar el modelo de un subagente antes de lanzarlo

### Vía 1: hook de settings `PreToolUse` sobre `Agent`

- La tool se llama `Agent`; su `tool_input` trae `prompt`, `description`, `subagent_type`, `model` (alias opcional) **[doc hooks, "Agent tool input"]**.
- `hookSpecificOutput.updatedInput` "reemplaza el objeto de entrada entero" (hay que devolver también los campos sin cambios) **[doc hooks, "PreToolUse decision control"]**.
- **Prueba t1**: hilo principal `--model sonnet`, prompt pide `Agent` con `model: "opus"`. Hook devuelve
  `{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow","updatedInput":{...tool_input,"model":"haiku"}}}`.
  Resultado: `tool_response.resolvedModel = "claude-haiku-5-5"`. La reescritura se aplicó sobre lo que pidió el modelo.
- El hook recibe en stdin `tool_input` completo (prompt, subagent_type, model pedido) y `effort`, suficiente para decidir.
- Orden de resolución del modelo del subagente **[doc sub-agents, "Choose a model"]**: parámetro por invocación > `model` del frontmatter del agente > `CLAUDE_CODE_SUBAGENT_MODEL` > modelo del hilo principal.
  Un mod que fija modelo en `agent.spawn` gana sobre el parámetro por invocación.
  `CLAUDE_CODE_SUBAGENT_MODEL_FORCE=1` (v2.1.257+) ignora el frontmatter y el parámetro; sirve como forzado global sin hook.
- Valores aceptados: alias `sonnet|opus|haiku|fable`, id completo, `inherit`. Se validan contra `availableModels`; uno bloqueado cae al heredado o al más nuevo permitido de su familia **[doc sub-agents]**.
- Un alias de familia igual a la del hilo principal (p. ej. `opus` con hilo en Opus) resuelve al modelo exacto del hilo **[doc sub-agents]**.
- Cuidado: los forks y las skills con `context: fork`+`model: inherit` corren en el modelo del hilo principal; `PreToolUse` sobre `Agent` solo ve las llamadas a la tool, no los subagentes creados por una skill (ver `$.agent` en tipos: "a forked skill ... `agent.spawn` governs it") **[doc sub-agents; tipos]**.

### Vía 2: mod con hook `agent.spawn`

- `AgentSpawnInput` trae `prompt`, `description`, `subagentType`, `model` (el parámetro tal como se dio), `background`, `cwd`; un hook puede reescribir `model` con `next({...e, model})` o devolver `{ deny }` **[tipos]**.
- **Prueba t5** (mod cargado con `claude -p --plugin-dir /tmp/laya-lab/mod1`): el hook vio `{"model":"opus","type":"general-purpose"}` y devolvió `model:'haiku'`; `resolvedModel = claude-haiku-5-5`. Funciona en `-p`.
- Ventaja sobre la vía 1: cubre también subagentes que no pasan por la tool (workflows, resumidos) y tiene el tipo resuelto.

### Fallo abierto y latencia

- Settings: un timeout cancela el hook y descarta su salida, sin decisión; el `Agent` sigue con sus argumentos originales **[doc hooks, "Timeouts"]**. `timeout` por defecto 600 s en `command`/`http`/`mcp_tool`. Cualquier otro código de salida que no sea 0/2, o JSON inválido, también deja pasar. Solo `exit 2` o `"onFailure":"block"` (v2.1.295+) lo hacen fallar cerrado.
- **Prueba t7**: hook con `sleep 5` y `"timeout":1` devolviendo `model:"haiku"`; `resolvedModel = claude-opus-5-5` (el pedido original), la ejecución terminó bien. Es decir, falla abierto: cae al modelo original, sin error.
- Mod: un hook que lanza, excede el presupuesto o responde una forma incorrecta se salta ("fails open unless its registration carries a `.catch`") **[tipos, `EngineEventOf`]**. Presupuesto: `HookBudget.ms = 10_000` por despacho, contando solo tiempo propio (no el de `next(e)` ni de llamadas `$`); `catchMs = 1_000` **[tipos]**. `claude plugin validate` etiqueta `agent.spawn` como "gating hook without .catch".

### Modo sombra

- Settings: el hook escribe el JSON de stdin a un log y sale `exit 0` sin imprimir nada. **Prueba t2** (`LAB_MODE=shadow`): se registró la entrada completa y `resolvedModel = claude-opus-5-5` (sin cambio). La decisión hipotética se puede escribir en el mismo log (p. ej. `{"would_set":"haiku"}`) sin devolverla.
- Mod: el hook decide, lo escribe con `$.fs.write` y llama `next(e)` sin reescribir. **Prueba t6** (fichero `/tmp/laya-lab/SHADOW` presente): log con `shadow:true`, `resolvedModel = claude-opus-5-5`. En la prueba el interruptor era un fichero leído con `$.fs.exists`; en un mod real sería una opción de usuario (`userConfig`).
- `PostToolUse` sobre `Agent` recibe `tool_response.resolvedModel` y `modelsUsed`, útil para auditar qué modelo corrió realmente frente al decidido **[doc hooks; prueba t1]**.

## (b) Cambiar el modelo del hilo principal por mensaje, y coste en caché

### Qué existe

- **Hooks de settings: no hay ninguno que fije el modelo.** `UserPromptSubmit` solo puede bloquear o añadir `additionalContext`/`sessionTitle`; `SessionStart` recibe `model` pero no lo devuelve; los campos `model` de hooks `prompt`/`agent` solo eligen el modelo que evalúa el hook. `PreModelSwitch` solo puede permitir/denegar/pedir confirmación una conmutación que ya pidió el usuario o el cliente; `PostModelSwitch` solo añade contexto **[doc hooks]**. "No hay variable `$CLAUDE_MODEL`" **[doc hooks]**.
- **Mod con hook `turn.step`** (un evento por petición al modelo): `next({ ...e, model })` envía la petición con otro modelo; `e.model` trae el modelo que el motor había resuelto, `e.agentId` distingue hilo principal (ausente) de subagente, `e.effort` también se puede reescribir **[tipos]**.
  - **Prueba t5**: el hook vio `model: claude-sonnet-5-5` y lo reescribió; todos los mensajes del asistente del hilo principal salieron con `message.model = claude-haiku-5-5`, desde la primera petición del turno (index 0).
  - Detalles que fallaron al principio: (1) el hook **debe ser `async function*`** y devolver `yield* next(...)` (si es función normal, `claude plugin validate` lo rechaza); (2) el modelo en `turn.step` debe ser **id completo** (`claude-haiku-5-5`); con el alias `haiku` la petición falló con `unrecognized_model` y la sesión salió con `rc=1`. En cambio `agent.spawn` sí acepta alias.
  - `prompt.submit` no puede cambiar el modelo, pero lleva `text`/`context` y sirve para decidir (clasificar el prompt) y dejar el resultado en `$.state` para que `turn.step` lo lea.
- Otros métodos no programáticos (no sirven para decisión automática por mensaje): `/model` (en interactivo pide confirmación mientras la caché esté caliente), `--model`, `ANTHROPIC_MODEL`, el campo `model` de settings **[doc model-config]**; `model:` en el frontmatter de una skill, véase (d).
- `-p`: un `/model` aplica solo a la sesión (v2.1.205+) **[doc model-config]**.

### Coste de caché

- "Cada modelo tiene su propia caché. Al cambiar de modelo, la siguiente petición lee todo el historial sin aciertos de caché, aunque el contenido sea idéntico" **[doc prompt-caching, "Switching models"]**. Se reprocesa el contexto entero como entrada sin caché la primera vez (y escritura de caché al tarifa de escritura del modelo destino).
- La caché sigue caliente un TTL tras la última petición: 5 min por defecto; 1 h en suscripción dentro de uso incluido para la conversación principal **[doc prompt-caching, "Cache lifetime"]**. Pasado el TTL, cambiar de modelo no cuesta nada extra (ya estaba fría).
- Alternar modelos por mensaje mantiene dos cachés vivas solo mientras ambas se usen dentro del TTL; si se vuelve a un modelo cuya caché expiró, se recomputa. Cada cambio de modelo pagado sobre contexto grande es el peor caso; en contextos pequeños (inicio de sesión) es casi gratis.
- `PostModelSwitch` informa de `context_tokens`, `prompt_cache_warm`, `cache_ttl` y `estimated_cache_write_usd` del cambio **[doc/tipos]**, pero su `source` solo cubre `command|picker|sdk|auto|resume`. **No verificado** que se dispare cuando un mod reescribe el modelo en `turn.step`; para medir hay que mirar `usage.cache_creation_input_tokens` / `cache_read_input_tokens` de cada respuesta (en `-p --output-format stream-json`, `message.usage`).
- No se midió en vivo el coste de un cambio con contexto grande: una sesión `-p` de un turno no permite ver el "antes" cacheado. Queda como paso de medición para la implementación (el mod puede registrar `usage` por `turn.step`).
- El `effort` es independiente: en Opus 5.5, Sonnet 5.5, Haiku 5.5 y Fable 5.1 (API key o suscripción) cambiarlo mantiene la caché **[doc prompt-caching, "Changing effort level"]**.
- Un subagente tiene su propia conversación y su propia caché (otro prefijo), así que cambiar su modelo **no** afecta a la caché del hilo principal y es gratis en ese sentido **[doc prompt-caching, "Subagents and the cache"]**. Este es el motivo de que (a) sea la palanca barata y (b) la cara.

### Fallo abierto y sombra

- Mod: `turn.step` es streaming; su presupuesto cuenta solo código propio y se suma por toda la respuesta (10 s) **[tipos]**. Si falla, se salta y la petición sale con el modelo que resolvió el motor (abierto).
- Sombra: igual que (a); **prueba t6**: con `SHADOW`, el hook registró `e.model` y devolvió `next(e)`; los mensajes del asistente salieron en `claude-sonnet-5-5` (sin cambio).
- Solo se probó `claude -p`. No se probó la carga persistente del mod (instalación vía marketplace o carpeta de hot-reload); `--plugin-dir` carga el mod en `-p` sin pedir confirmación.

## (c) Inyectar una sugerencia de skill a partir del prompt

### Vía 1: `UserPromptSubmit` de settings

- Entrada: `prompt` (pegados ya expandidos), `session_title`. Salida: stdout en texto plano (exit 0) o `hookSpecificOutput.additionalContext`; ambos se inyectan como `<system-reminder>` que empieza con el nombre del hook, sin entrada visible en la transcripción. No puede reescribir el prompt **[doc hooks]**.
- **Prueba t2**: hook que imprime `additionalContext: "SKILL-HINT: consider skill lab-skill (codeword PINEAPPLE-77)"`; el modelo lo reprodujo literalmente al preguntársele.
- Fallo abierto: timeout por defecto **30 s** (más corto que los 600 s de otros eventos). Si se alcanza, la salida (incluido `additionalContext`) se descarta y el prompt llega sin contexto. **Prueba t2**: segundo hook con `sleep 6` y `timeout 2`; su marcador `SLOW-CONTEXT-MARKER-XYZ` no apareció y la ejecución continuó (el hook rápido sí aportó). Con `"onFailure":"block"` el fallo bloquearía el prompt **[doc hooks]**.
- Como bloquea el procesado del modelo hasta terminar, cada ms de este hook es latencia visible antes del primer token; conviene un script local de unos pocos ms (o `async: true`, que no puede inyectar contexto a tiempo).
- Efecto en caché: el contexto se añade al final de la conversación, no al prefijo, así que no invalida la caché **[doc prompt-caching: skills/hooks "append after the existing conversation"]**.

### Vía 2: mod `prompt.submit`

- `next({ ...e, context: [...(e.context ?? []), "texto"] })`: bloques que el modelo lee tras el prompt y el usuario no ve **[tipos]**. Se puede reescribir `text` salvo cuando el envío es un comando slash (`e.command`) o un prompt meta.
- **Prueba t5**: se inyectó `MOD-CONTEXT: skill suggestion ... (codeword MANGO-91)` y el modelo lo repitió. Ojo: `prompt.submit` también se disparó para la `<task-notification>` que llega cuando acaba un subagente en segundo plano (visto en el log), así que el hook debe filtrar `e.origin`/`e.isMeta`.
- Fallo abierto y presupuesto: 10 s propios; `claude plugin validate` etiqueta `prompt.submit` como "gating hook" (puede dejar `{drop}`), pero sin `.catch` un fallo se salta y el prompt pasa.
- Otro camino complementario sin hooks: la descripción y `when_to_use` de cada skill se cargan siempre en el contexto y el modelo decide invocarla; `paths:` la activa por ficheros **[doc skills]**. Un hook `UserPromptSubmit` solo añade la sugerencia explícita.

### Sombra

Escribir al log `{prompt, skill_sugerida}` y no devolver `additionalContext` / no añadir `context`. Trivial en ambas vías; no requirió prueba aparte (es el mismo patrón que (a) con `exit 0` sin salida).

## (d) Fijar con qué modelo corre una skill

- Frontmatter `model:` de la skill: "el override se aplica durante el resto del turno actual y no se guarda; el modelo de sesión se reanuda con tu siguiente prompt". Acepta lo mismo que `/model` o `inherit`; un valor excluido por `availableModels` se ignora **[doc skills, tabla de frontmatter]**.
  - **Prueba t3**: skill `lab-skill` con `model: haiku`, hilo `--model sonnet`; invocada como `/lab-skill`, todas las respuestas del asistente en ese turno salieron `message.model = claude-haiku-5-5` (también la que lanzó `Bash`).
- Con `context: fork` (+ `agent:`), `model:` fija el modelo del **subagente forkeado** y no el del hilo **[doc skills]**. **Prueba t4**: `lab-fork` con `model: haiku`, `context: fork`; la transcripción del subagente (`subagents/agent-*.jsonl`) muestra `claude-haiku-5-5`. En `-p` el fork espera el resultado.
- Caché: una skill cuyo `model` difiere del de la sesión es un cambio de modelo durante ese turno: la siguiente petición lee todo el historial sin caché, y vuelve a pasar al reanudar el modelo de sesión **[doc prompt-caching, "Switching models"]** (no medido en vivo). Es, por tanto, un coste doble (ida y vuelta) cuando el hilo es grande. La variante `context: fork` evita ese coste porque el subagente tiene su propia caché.
- `effort:` en el frontmatter también existe y anula el esfuerzo de la sesión.
- No hay fallo abierto que evaluar: es declarativo, sin hook ni timeout. Un modelo fuera de la lista permitida deja la sesión en su modelo actual.
- Modo sombra: no aplica al frontmatter (siempre se aplica). Alternativa para observar sin aplicar: un mod con `skill.prompt` (existe en tipos, `SkillPromptInput` con `frontmatter` y `source`) que registre y devuelva `next(e)`. **No probado**.
- Para hacer dinámica la elección por skill sin tocar su frontmatter: el hook `agent.spawn` del mod cubre los forks de skills (la doc dice que los spawns sin la tool Agent están en `agent.spawn`), pero esta combinación **no se probó**.

## Recomendaciones para el motor (derivadas, no verificadas como diseño)

1. Palanca barata y verificada: `PreToolUse` sobre `Agent` (hook de settings, sin instalar mod) para (a); script local rápido, falla abierto de serie.
2. Para (c), `UserPromptSubmit` de settings con `additionalContext`; mantener el script en pocos ms por el timeout de 30 s y por bloquear el primer token.
3. (b) solo existe vía mod (`turn.step`, generador, id de modelo completo). Antes de adoptarlo, medir `cache_creation_input_tokens` de cada cambio: es el único punto con coste de caché real; (a) y (d con fork) no lo tienen.
4. Para empezar, activar el modo sombra en todo: log JSONL con `{evento, entrada, decisión_hipotética}` y salida vacía, comparable luego con `resolvedModel`/`message.model` reales.

## Anexo: cómo se probó

- Lab: `/tmp/laya-lab` con `.claude/settings.json` propio y `claude -p --setting-sources project --output-format stream-json --verbose`. Mod de prueba en `/tmp/laya-lab/mod1` (`hooks/register.ts` con `agent.spawn`, `turn.step` generator y `prompt.submit`; `claude plugin validate` OK con avisos solo de autoría y de "gating hook sin .catch").
- t1: hook `PreToolUse` reescribe `model:opus -> haiku`; t2: modo sombra + `UserPromptSubmit` (contexto aplicado, hook lento descartado); t3: skill con `model: haiku`; t4: skill fork con `model: haiku`; t5: mod aplicado; t6: mod en sombra; t7: hook `PreToolUse` lento con `timeout 1` (falla abierto).
- Limitaciones: pruebas de un turno en `-p`, sin sesión interactiva; no se midió la penalización de caché con contexto grande; no se probó la instalación persistente del mod ni el hook `skill.prompt`.
