import {
    decisionsFor,
    haikuArgs,
    logLine,
    needsRespaldo,
    parseHaiku,
    systemoneBody,
} from './decision-shadow.mjs';

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
check('prompt del usuario: hilo y skill',
    decisionsFor({ hook_event_name: 'UserPromptSubmit', prompt: 'arregla x' }, cfg).map((d) => d.decision),
    ['modelo-hilo', 'skill']);
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
