import { baseMoved, isDisabled, planCleanup, recoveryTsv } from './cleanup-wt.mjs';

let fail = 0;
const check = (label, actual, expected) => {
    const ok = expected ? Boolean(actual) : !actual;
    if (!ok) { fail++; }
    console.log(`${ok ? 'ok  ' : 'FAIL'}  ${label}`);
};

const bases = ['main'];
const main = { path: '/r', branch: 'main', dirty: false, main: true };
const wt = (name, extra = {}) => ({ path: `/r/.wt/${name}`, branch: `feat/${name}`, dirty: false, ...extra });
const plan = (worktrees, merged, extra = {}) =>
    planCleanup({
        worktrees: [main, ...worktrees],
        branches: ['main', ...worktrees.map((w) => w.branch).filter(Boolean), ...(extra.loose || [])],
        merged,
        bases,
        currentPath: '/r',
        ...extra,
    });
const has = (actions, action, key) => actions.some((a) => a.action === action && (a.path === key || a.branch === key));

console.log('--- worktree mergeado y limpio ---');
const a1 = plan([wt('a')], ['feat/a']);
check('quita el worktree', has(a1, 'remove-worktree', '/r/.wt/a'), true);
check('borra la rama', has(a1, 'delete-branch', 'feat/a'), true);
check('no hace wip-commit', a1.some((a) => a.action === 'wip-commit'), false);

console.log('\n--- nunca borra trabajo sin mergear ---');
const a2 = plan([wt('b')], []);
check('worktree sin mergear: nada', a2.length, false);
check('rama sin mergear: sigue', has(a2, 'delete-branch', 'feat/b'), false);

console.log('\n--- worktree sucio en rama mergeada ---');
const a3 = plan([wt('c', { dirty: true })], ['feat/c']);
check('wip-commit antes de tocar', has(a3, 'wip-commit', '/r/.wt/c'), true);
check('wip-commit va antes de quitar el worktree', a3.findIndex((a) => a.action === 'wip-commit') < a3.findIndex((a) => a.action === 'remove-worktree'), true);
check('la rama se conserva', has(a3, 'delete-branch', 'feat/c'), false);

console.log('\n--- protecciones ---');
const a4 = plan([], ['main']);
check('nunca la rama base', has(a4, 'delete-branch', 'main'), false);
check('nunca el worktree principal', has(a4, 'remove-worktree', '/r'), false);
const a5 = plan([wt('d')], ['feat/d'], { currentPath: '/r/.wt/d' });
check('nunca el worktree donde corre', has(a5, 'remove-worktree', '/r/.wt/d'), false);
check('ni su rama', has(a5, 'delete-branch', 'feat/d'), false);
const a6 = plan([wt('e', { branch: null })], []);
check('worktree detached: se ignora', a6.length, false);
const a7 = plan([wt('f')], ['feat/f'], { currentPath: '/r/.wt/f/src' });
check('cwd dentro de un subdirectorio del worktree tambien cuenta', has(a7, 'remove-worktree', '/r/.wt/f'), false);
const a8 = plan([wt('gg')], ['feat/gg'], { currentPath: '/r/.wt/g' });
check('prefijo de ruta parecido no cuenta', has(a8, 'remove-worktree', '/r/.wt/gg'), true);

console.log('\n--- ramas sueltas ---');
const a9 = plan([], ['loose/x'], { loose: ['loose/x'] });
check('rama mergeada sin worktree: se borra', has(a9, 'delete-branch', 'loose/x'), true);
const a10 = plan([], [], { loose: ['loose/y'] });
check('rama sin mergear sin worktree: se queda', has(a10, 'delete-branch', 'loose/y'), false);

console.log('\n--- recuperacion (TSV) ---');
const tsv = recoveryTsv(
    [
        { action: 'delete-branch', branch: 'feat/a' },
        { action: 'remove-worktree', path: '/r/.wt/a' },
    ],
    (b) => (b === 'feat/a' ? 'abc123' : ''),
);
check('una fila por rama borrada con su sha', tsv.trim() === 'feat/a\tabc123', true);
check('sin ramas borradas no hay filas', recoveryTsv([], () => 'x').trim(), false);

const failedTsv = recoveryTsv(
    [
        { action: 'delete-branch', branch: 'feat/ok' },
        { action: 'delete-branch', branch: 'feat/locked' },
    ],
    (b) => `sha-${b}`,
    new Set(['feat/locked']),
);
check('rama con worktree que no se pudo quitar: sin fila', failedTsv.includes('feat/locked'), false);
check('la otra rama sigue en el TSV', failedTsv.trim() === 'feat/ok\tsha-feat/ok', true);
check('todo fallido: TSV vacio', recoveryTsv([{ action: 'delete-branch', branch: 'x' }], () => 's', new Set(['x'])), false);

console.log('\n--- AI_GUARD_DISABLE ---');
check('id cleanup-wt desactiva', isDisabled({ AI_GUARD_DISABLE: 'cleanup-wt' }), true);
check('entre otros ids', isDisabled({ AI_GUARD_DISABLE: 'rm-rf, cleanup-wt' }), true);
check('otro id no desactiva', isDisabled({ AI_GUARD_DISABLE: 'rm-rf' }), false);
check('sin variable no desactiva', isDisabled({}), false);

console.log('\n--- cuando correr ---');
check('primera vez corre', baseMoved(undefined, 'sha1'), true);
check('la base se movio', baseMoved('sha1', 'sha2'), true);
check('la base no se movio', baseMoved('sha1', 'sha1'), false);
check('sin sha actual no corre', baseMoved('sha1', undefined), false);

console.log(`\n${fail === 0 ? 'TODOS OK' : fail + ' FALLOS'}`);
process.exit(fail ? 1 : 0);
