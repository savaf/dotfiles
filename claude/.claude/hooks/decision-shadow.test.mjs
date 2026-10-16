import {
    decisionsFor,
    haikuArgs,
    logLine,
    needsRespaldo,
    parseHaiku,
    respaldoEnv,
    respaldoError,
    suggestedModel,
    systemoneBody,
} from './decision-shadow.mjs';
import { mkdtempSync, writeFileSync } from 'node:fs';
import os from 'node:os';
import path from 'node:path';

let fail = 0;
const check = (label, actual, expected) => {
    const ok = JSON.stringify(actual) === JSON.stringify(expected);
    if (!ok) { fail++; console.log(`      got ${JSON.stringify(actual)}`); }
    console.log(`${ok ? 'ok  ' : 'FAIL'}  ${label}`);
};

const cfg = {
    maxInput: 10,
    threshold: 0.6,
    respaldo: { model: 'claude-haiku-5-5' },
    questions: {
        modelo: { instructions: '¿Modelo?', criteria: { haiku: 'h', opus: 'o', ninguna: 'n' } },
        skill: { instructions: '¿Skill?', criteria: { tdd: 't', ninguna: 'n' } },
    },
};

console.log('--- qué se decide ---');
check('user prompt: thread, skill and agent',
    decisionsFor({ hook_event_name: 'UserPromptSubmit', prompt: 'arregla x' }, cfg).map((d) => d.decision),
    ['modelo-hilo', 'skill', 'agent']);
const agents = mkdtempSync(path.join(os.tmpdir(), 'agents-'));
writeFileSync(path.join(agents, 'builder.md'), '---\nname: builder\nmodel: sonnet\n---\nbody');
writeFileSync(path.join(agents, 'nomodel.md'), '---\nname: Nomodel\ntools: Read\n---\nbody');
check('suggestion: the model from the agent frontmatter', suggestedModel('builder', agents), 'sonnet');
check('suggestion: the name is case-insensitive', suggestedModel('BUILDER', agents), 'sonnet');
check('suggestion: agent without a model', suggestedModel('nomodel', agents), null);
check('suggestion: unknown agent or missing dir', [suggestedModel('x', agents), suggestedModel('builder', '/no/existe')], [null, null]);
check('subagent with a suggestion: it goes in the text and in the Decision',
    decisionsFor({ hook_event_name: 'PreToolUse', tool_name: 'Agent', tool_input: { description: 'a', prompt: 'b', subagent_type: 'builder' } }, { ...cfg, agentsDir: agents }),
    [{ decision: 'modelo-subagente', question: 'modelo', text: '[agent suggests model: sonnet]\na\n\nb', suggested: 'sonnet' }]);
check('lanzar un agente: modelo del subagente',
    decisionsFor({ hook_event_name: 'PreToolUse', tool_name: 'Agent', tool_input: { description: 'busca', prompt: 'todo' } }, cfg),
    [{ decision: 'modelo-subagente', question: 'modelo', text: 'busca\n\ntod' }]);
check('notificaciones y comandos internos no se deciden',
    decisionsFor({ hook_event_name: 'UserPromptSubmit', prompt: '<task-notification>x' }, cfg), []);
check('prompt vacío no se decide',
    decisionsFor({ hook_event_name: 'UserPromptSubmit', prompt: '   ' }, cfg), []);
check('otra tool no se decide',
    decisionsFor({ hook_event_name: 'PreToolUse', tool_name: 'Bash', tool_input: {} }, cfg), []);
check('el texto se recorta a maxInput',
    decisionsFor({ hook_event_name: 'UserPromptSubmit', prompt: '0123456789abc' }, cfg)[0].text, '0123456789');

console.log('\n--- contrato con el Motor ---');
check('cuerpo de /v1/systemone',
    systemoneBody(cfg.questions.skill, 'hola'),
    { model: 'clef-flash', state: 'hola', questions: { d: { type: 'choice', instructions: '¿Skill?', criteria: { tdd: 't', ninguna: 'n' } } } });
check('confianza bajo el umbral pide Respaldo', needsRespaldo({ choice: 'tdd', confidence: 0.59 }, 0.6), true);
check('confianza en el umbral no pide Respaldo', needsRespaldo({ choice: 'tdd', confidence: 0.6 }, 0.6), false);
check('Motor caído: Fallo abierto, sin Respaldo', needsRespaldo(null, 0.6), false);

console.log('\n--- Respaldo (Haiku) ---');
const args = haikuArgs(cfg.questions.skill, 'hola', cfg.respaldo);
check('usa el modelo del Respaldo', args[args.indexOf('--model') + 1], 'claude-haiku-5-5');
check('no carga settings de usuario (evita recursión)', args[args.indexOf('--setting-sources') + 1], 'project');
check('el enum del schema son las opciones',
    JSON.parse(args[args.indexOf('--json-schema') + 1]).properties.choice.enum, ['tdd', 'ninguna']);
check('parsea structured_output y normaliza la confianza',
    parseHaiku('{"structured_output":{"choice":"tdd","confidence":4}}'), { choice: 'tdd', confidence: 0.8 });

check('Haiku sin tools ni MCP', args.slice(-3), ['--strict-mcp-config', '--tools', '']);
const env = respaldoEnv({ PATH: '/bin', CLAUDE_CONFIG_DIR: '/c', CLAUDECODE: '1', CLAUDE_CODE_SESSION_ID: 's', CLAUDE_CODE_MESSAGING_TOKEN: 't' });
check('no hereda la sesión padre, conserva el perfil', env, { PATH: '/bin', CLAUDE_CONFIG_DIR: '/c', DECISIONES_WORKER: '1' });
check('el error del Respaldo no incluye el prompt', respaldoError({ code: 1, message: 'Command failed: claude -p secreto' }), 'exit 1');
check('timeout del Respaldo', respaldoError({ killed: true, signal: 'SIGTERM', message: 'claude -p secreto' }), 'timeout SIGTERM');

console.log('\n--- registro ---');
const line = JSON.parse(logLine({
    ts: 't', session_id: 's', transcript_path: 'p', decision: 'skill', text: 'x'.repeat(600),
    motor: { choice: 'tdd', confidence: 0.4, ms: 80 }, respaldo: { choice: 'ninguna', confidence: 1, ms: 3000 }, error: null,
}));
check('final = Respaldo cuando lo hubo', line.final, 'ninguna');
check('nunca aplicado en sombra', line.applied, false);
check('input recortado a 500', line.input.length, 500);
check('final = Motor sin Respaldo',
    JSON.parse(logLine({ decision: 'skill', text: 'x', motor: { choice: 'tdd', confidence: 0.9 }, respaldo: null })).final, 'tdd');
check('final null si nadie respondió',
    JSON.parse(logLine({ decision: 'skill', text: 'x', motor: null, respaldo: null, error: 'down' })).final, null);

console.log(fail ? `\n${fail} FAIL` : '\ntodo ok');
process.exit(fail ? 1 : 0);
