import { checkDestructive, evaluate } from './git-guardrails.mjs';

let fail = 0;
const check = (label, actual, expected) => {
    const ok = expected ? Boolean(actual) : !actual;
    if (!ok) { fail++; }
    console.log(`${ok ? 'ok  ' : 'FAIL'}  ${label}`);
};
const denies = (label, cmd, env) => check(label, checkDestructive(cmd, env), true);
const allows = (label, cmd, env) => check(label, checkDestructive(cmd, env), false);

console.log('--- SAFETY: deben denegar ---');
denies('rm -rf', 'rm -rf build');
denies('rm -r -f separados', 'rm -r -f build');
denies('reset --hard', 'git reset --hard HEAD~1');
denies('clean -fd', 'git clean -fd');
denies('force push main', 'git push --force-with-lease origin main');
denies('push -f sin lease', 'git push -f origin feature');
denies('branch -D', 'git branch -D feature');
denies('reflog expire', 'git reflog expire --expire=now --all');
denies('checkout .', 'git checkout .');
denies('restore .', 'git restore .');
denies('destructivo en 2o segmento', 'npm test && rm -rf dist');

console.log('\n--- FALSOS POSITIVOS: deben pasar ---');
allows('rm -r con [ -f ] en heredoc', 'cat > f <<EOF\n[ -f "$x" ] || exit 0\nEOF\nrm -r /tmp/dir');
allows('rm sin flags', 'rm /tmp/uno.txt');
allows('rm -r solo', 'rm -r /tmp/dir');
allows('grep -rf en linea distinta a rm', 'grep -rf patrones.txt src/\nrm archivo.txt');
allows('push a rama normal con lease', 'git push --force-with-lease origin mi-rama');
allows('reset suave', 'git reset HEAD~1');
allows('checkout de archivo', 'git checkout -- src/app.ts');
allows('comandos inocuos', 'git status && npm test');
allows('branch -d normal', 'git branch -d feature');

console.log('\n--- POLICY: off por defecto, on con AI_GUARD_ENABLE ---');
allows('git add -A off', 'git add -A', {});
denies('git add -A on', 'git add -A', { AI_GUARD_ENABLE: 'git-add-all' });
denies('policy all', 'git commit --amend', { AI_GUARD_ENABLE: 'all' });
allows('amend off', 'git commit --amend', {});

console.log('\n--- AI_GUARD_DISABLE ---');
allows('rm-rf desactivada', 'rm -rf x', { AI_GUARD_DISABLE: 'rm-rf' });
denies('otra sigue activa', 'git reset --hard', { AI_GUARD_DISABLE: 'rm-rf' });

console.log('\n--- rama protegida ---');
check('commit en main sin env', evaluate('git commit -m x', 'main', {}), false);
check('commit en main con env', evaluate('git commit -m x', 'main', { AI_GUARD_PROTECT_BRANCHES: 'main' }), true);
check('commit en feature con env', evaluate('git commit -m x', 'feat', { AI_GUARD_PROTECT_BRANCHES: 'main' }), false);
check('git -C otro repo permitido', evaluate('git -C ../otro commit -m x', 'main', { AI_GUARD_PROTECT_BRANCHES: 'main' }), false);
check('comando vacio deniega', evaluate('', null, {}), true);

console.log('\n--- push a rama protegida (Conuco) ---');
const prot = { AI_GUARD_PROTECT_BRANCHES: 'main' };
check('push origin main', evaluate('git push origin main', 'feat', prot), true);
check('push HEAD:main', evaluate('git push origin HEAD:main', 'feat', prot), true);
check('push refs/heads/main', evaluate('git push origin feat:refs/heads/main', 'feat', prot), true);
check('push sin refspec desde main', evaluate('git push', 'main', prot), true);
check('push -u origin desde main', evaluate('git push -u origin', 'main', prot), true);
check('push en 2o segmento', evaluate('npm test && git push origin main', 'feat', prot), true);
check('push de rama de feature', evaluate('git push -u origin feat/x', 'feat/x', prot), false);
check('push sin refspec desde feature', evaluate('git push', 'feat/x', prot), false);
check('rama que contiene main en el nombre', evaluate('git push origin main-fix', 'main-fix', prot), false);
check('push a main sin env', evaluate('git push origin main', 'feat', {}), false);
check('git -C otro repo push a main', evaluate('git -C ../otro push origin main', 'feat', prot), true);
check('git -C otro repo push de feature', evaluate('git -C ../otro push origin feat/x', 'main', prot), false);
check('git -C otro repo sin refspec', evaluate('git -C ../otro push', 'main', prot), false);

console.log(`\n${fail === 0 ? 'TODOS OK' : fail + ' FALLOS'}`);
process.exit(fail ? 1 : 0);
