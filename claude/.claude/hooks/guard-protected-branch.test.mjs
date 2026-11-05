import { evaluate, isInsideRepo, protectedBranches } from './guard-protected-branch.mjs';

let fail = 0;
const check = (label, actual, expected) => {
    const ok = expected ? Boolean(actual) : !actual;
    if (!ok) { fail++; }
    console.log(`${ok ? 'ok  ' : 'FAIL'}  ${label}`);
};

const env = { AI_GUARD_PROTECT_BRANCHES: 'main' };
const repo = '/srv/b0-bb-cms';

console.log('--- ramas protegidas ---');
check('sin env no hay ramas', protectedBranches({}).length, false);
check('lista separada por comas', protectedBranches({ AI_GUARD_PROTECT_BRANCHES: 'main, release' }).length === 2, true);

console.log('\n--- dentro / fuera del repo ---');
check('archivo dentro del repo', isInsideRepo(`${repo}/src/app.ts`, repo), true);
check('la raiz misma cuenta como dentro', isInsideRepo(repo, repo), true);
check('prefijo parecido no cuenta', isInsideRepo('/srv/b0-bb-cms-old/x.ts', repo), false);

console.log('\n--- evaluate: deben denegar ---');
check('edit en main', evaluate(`${repo}/src/app.ts`, 'main', repo, env), true);
check('sin ruta en main', evaluate(undefined, 'main', repo, env), true);
check('sin raiz en main', evaluate(`${repo}/x`, 'main', undefined, env), true);

console.log('\n--- evaluate: deben pasar ---');
check('edit en rama de feature', evaluate(`${repo}/src/app.ts`, 'feat/x', repo, env), false);
check('edit fuera del repo en main', evaluate('/home/u/.claude-b0/x.md', 'main', repo, env), false);
check('main sin env configurado', evaluate(`${repo}/src/app.ts`, 'main', repo, {}), false);

console.log(`\n${fail === 0 ? 'TODOS OK' : fail + ' FALLOS'}`);
process.exit(fail ? 1 : 0);
