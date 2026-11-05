import { evaluate } from './guard-worktree-path.mjs';

let fail = 0;
const check = (label, actual, expected) => {
    const ok = expected ? Boolean(actual) : !actual;
    if (!ok) { fail++; }
    console.log(`${ok ? 'ok  ' : 'FAIL'}  ${label}`);
};

const ctx = { cwd: '/r', repoRoot: '/r' };
const run = (command, env = {}, c = ctx) => evaluate(command, c, env);

console.log('--- deben denegar ---');
check('add fuera del repo', run('git worktree add ../x feat'), true);
check('add en /tmp', run('git worktree add /tmp/x -b feat'), true);
check('add dentro del repo pero fuera de .claude/worktrees', run('git worktree add wt/x'), true);
check('git -C con destino fuera', run('git -C /r worktree add /tmp/x'), true);
check('cd previo cambia el destino relativo', run('cd sub && git worktree add ../y'), true);
check('encadenado tras otro comando', run('ls && git worktree add ../x'), true);
check('move con destino fuera', run('git worktree move .claude/worktrees/a /tmp/a'), true);
check('con flags antes de la ruta', run('git worktree add -b feat --detach ../x'), true);
check('el motivo nombra la regla', /worktree-path/.test(String(run('git worktree add ../x'))), true);

console.log('\n--- deben pasar ---');
check('add dentro de .claude/worktrees', run('git worktree add .claude/worktrees/x -b feat'), false);
check('ruta absoluta permitida', run('git worktree add /r/.claude/worktrees/x'), false);
check('cd a la carpeta permitida', run('cd .claude/worktrees && git worktree add ./z'), false);
check('flag con valor antes de la ruta', run('git worktree add -b feat .claude/worktrees/x'), false);
check('move dentro de lo permitido', run('git worktree move .claude/worktrees/a .claude/worktrees/b'), false);
check('list', run('git worktree list'), false);
check('remove', run('git worktree remove .claude/worktrees/x'), false);
check('otro comando git', run('git status'), false);
check('ruta con variable no resoluble', run('git worktree add "$DIR/x"'), false);
check('sustitucion de comando no resoluble', run('git worktree add $(mktemp -d)'), false);

console.log('\n--- configuracion ---');
check('directorio extra permitido', run('git worktree add /srv/wt/x', { AI_GUARD_WORKTREE_DIRS: '/srv/wt' }), false);
check('directorio extra relativo al repo', run('git worktree add .wt/x', { AI_GUARD_WORKTREE_DIRS: '.wt' }), false);
check('un directorio extra no abre los demas', run('git worktree add /tmp/x', { AI_GUARD_WORKTREE_DIRS: '/srv/wt' }), true);
check('desactivado por AI_GUARD_DISABLE', run('git worktree add ../x', { AI_GUARD_DISABLE: 'worktree-path' }), false);
check('comando vacio no rompe', run(''), false);
check('comando no string no rompe', evaluate(undefined, ctx, {}), false);

console.log(`\n${fail === 0 ? 'TODOS OK' : fail + ' FALLOS'}`);
process.exit(fail ? 1 : 0);
