import { summarize } from './decisiones-summary.mjs';

let fail = 0;
const check = (label, actual, expected) => {
    const ok = JSON.stringify(actual) === JSON.stringify(expected);
    if (!ok) { fail++; console.log(`      got ${JSON.stringify(actual)}`); }
    console.log(`${ok ? 'ok  ' : 'FAIL'}  ${label}`);
};

const row = (decision, over = {}) => ({
    decision, motor: { choice: 'tdd', confidence: 0.9 }, respaldo: null, final: 'tdd', error: null, ...over,
});

console.log('--- per-Decision summary ---');
check('counts who decided and the chosen options',
    summarize([
        row('skill'),
        row('skill', { final: 'ninguna' }),
        row('skill', { respaldo: { choice: 'tdd', confidence: 1 } }),
        row('skill', { motor: null, final: null, error: 'down' }),
    ]),
    ['skill: 4 | motor 2 · respaldo 1 · error 1 | tdd 2, ninguna 1']);
check('one line per Decision, in order of appearance',
    summarize([row('skill'), row('agent', { final: 'builder' })]).map((l) => l.split(':')[0]),
    ['skill', 'agent']);

console.log('\n--- frontmatter suggestion ---');
check('counts how often the engine differed from the suggestion',
    summarize([
        row('modelo-subagente', { suggested: 'sonnet', final: 'sonnet' }),
        row('modelo-subagente', { suggested: 'sonnet', final: 'opus' }),
    ]).slice(1),
    ['  vs frontmatter suggestion: differs in 1/2']);
check('no suggestions, no extra line', summarize([row('skill')]).length, 1);
check('a row with no final is not counted',
    summarize([
        row('modelo-subagente', { suggested: 'sonnet', final: 'sonnet' }),
        row('modelo-subagente', { suggested: 'sonnet', final: null, motor: null, error: 'down' }),
    ]).slice(1),
    ['  vs frontmatter suggestion: differs in 0/1']);
check('an engine answer of ninguna is no opinion, so it is not counted',
    summarize([
        row('modelo-subagente', { suggested: 'sonnet', final: 'ninguna' }),
        row('modelo-subagente', { suggested: 'sonnet', final: 'opus' }),
    ]).slice(1),
    ['  vs frontmatter suggestion: differs in 1/1']);
check('no rows, no output', summarize([]), []);

console.log(fail ? `\n${fail} FAIL` : '\nall ok');
process.exit(fail ? 1 : 0);
