import { mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { evaluate, evaluatePost } from './guard-secrets.mjs';

let fail = 0;
const check = (label, actual, expected) => {
    const ok = expected ? Boolean(actual) : !actual;
    if (!ok) { fail++; }
    console.log(`${ok ? 'ok  ' : 'FAIL'}  ${label}`);
};

const read = (file_path, env) => evaluate('Read', { file_path }, env);
const grep = (input, env) => evaluate('Grep', input, env);
const bash = (command, env) => evaluate('Bash', { command }, env);

console.log('--- Read: deben denegar ---');
check('.env', read('/p/.env'), true);
check('.env.local', read('/p/.env.local'), true);
check('.env.production', read('/p/app/.env.production'), true);
check('clave ssh id_rsa', read('/home/u/.ssh/id_rsa'), true);
check('clave ssh id_ed25519', read('/home/u/.ssh/id_ed25519'), true);
check('.npmrc', read('/home/u/.npmrc'), true);
check('credentials', read('/home/u/.aws/credentials'), true);
check('credentials.json', read('/p/credentials.json'), true);
check('service account json', read('/p/service-account-prod.json'), true);
check('.pem', read('/p/certs/server.pem'), true);

console.log('\n--- Read: deben pasar ---');
check('.env.example', read('/p/.env.example'), false);
check('.env.sample', read('/p/.env.sample'), false);
check('.env.template', read('/p/.env.template'), false);
check('clave publica', read('/home/u/.ssh/id_ed25519.pub'), false);
check('archivo normal', read('/p/src/app.ts'), false);
check('"environment.ts" no es dotenv', read('/p/src/environment.ts'), false);

console.log('\n--- Grep ---');
check('grep sobre .env', grep({ pattern: 'KEY', path: '/p/.env' }), true);
check('grep con glob .env*', grep({ pattern: 'KEY', glob: '.env*' }), true);
check('grep normal', grep({ pattern: 'KEY', path: '/p/src' }), false);

console.log('\n--- Bash: deben denegar ---');
check('cat .env', bash('cat .env'), true);
check('head .env.local', bash('head -n 3 .env.local'), true);
check('pipe desde .env', bash('cat ./app/.env | grep KEY'), true);
check('redireccion de entrada', bash('grep KEY < .env'), true);
check('cat clave ssh', bash('cat ~/.ssh/id_rsa'), true);
check('encadenado', bash('ls && cat .env'), true);
check('cat .pem', bash('cat certs/server.pem'), true);

console.log('\n--- Bash: deben pasar ---');
check('cat .env.example', bash('cat .env.example'), false);
check('ls', bash('ls -la'), false);
check('comando normal', bash('npm test'), false);
check('env-check simple', bash('bash ~/.claude/hooks/env-check.sh API_KEY DB_URL'), false);
check('env-check con pipe se deniega si toca .env', bash('bash env-check.sh API_KEY | cat .env'), true);

console.log('\n--- AI_GUARD_DISABLE ---');
check('secret-read desactivado', read('/p/.env', { AI_GUARD_DISABLE: 'secret-read' }), false);
check('otro id no desactiva', read('/p/.env', { AI_GUARD_DISABLE: 'key-literal' }), true);

console.log('\n--- otras herramientas ---');
check('herramienta desconocida', evaluate('Glob', { pattern: '**/.env' }), false);
check('input vacio no rompe', evaluate('Read', undefined), false);

// Las claves de prueba se construyen por partes: ni este archivo dispara
// escaneres de secretos ni el propio hook al escribirlo.
const anthropic = 'sk-' + 'ant-' + 'api03-' + 'aB3dE5fG7hI9jK1lM3nO5pQ7';
const aws = 'AKIA' + 'IOSFODNN7EXAMPL3';
const github = 'ghp_' + 'aB3dE5fG7hI9jK1lM3nO5pQ7rS9tU1vW3xY5';
const write = (content, env) => evaluate('Write', { file_path: '/p/src/config.ts', content }, env);

console.log('\n--- key-literal: deben denegar ---');
check('Write con clave anthropic', write(`const k = "${anthropic}";`), true);
check('Write con clave AWS', write(`aws = ${aws}`), true);
check('Write con token de GitHub', write(`TOKEN=${github}`), true);
check('Write con clave privada PEM', write('-----BEGIN RSA PRIVATE KEY-----\nMIIE'), true);
check('Edit con clave', evaluate('Edit', { file_path: '/p/a.ts', new_string: anthropic }), true);
check('Bash que escribe la clave', bash(`echo "${github}" >> notes.txt`), true);
check('el motivo no contiene la clave', String(write(`k=${anthropic}`)).includes(anthropic), false);
check('el motivo trae el numero de linea', /line 2/.test(String(write(`a\nk=${anthropic}`))), true);

console.log('\n--- key-literal: deben pasar ---');
check('placeholder con x', write('KEY=sk-' + 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx'), false);
check('placeholder YOUR_KEY_HERE', write('KEY=YOUR_KEY_HERE'), false);
check('AKIA de ejemplo marcado', write(`# example: ${'AKIA' + 'XXXXXXXXXXXXXXXX'}`), false);
check('texto normal', write('const x = 1;'), false);
check('key-literal desactivado', write(anthropic, { AI_GUARD_DISABLE: 'key-literal' }), false);
check('secret-read desactivado no afecta key-literal', write(anthropic, { AI_GUARD_DISABLE: 'secret-read' }), true);

console.log('\n--- key-literal: aviso posterior (PostToolUse) ---');
const dir = mkdtempSync(path.join(tmpdir(), 'guard-secrets-'));
const withKey = path.join(dir, 'a.ts');
const clean = path.join(dir, 'b.ts');
writeFileSync(withKey, `ok\nconst k = "${anthropic}";\n`);
writeFileSync(clean, 'const x = 1;\n');
check('avisa si ya esta en disco', evaluatePost('Write', { file_path: withKey }), true);
check('el aviso da la linea', /line 2/.test(String(evaluatePost('Edit', { file_path: withKey }))), true);
check('el aviso no trae la clave', String(evaluatePost('Write', { file_path: withKey })).includes(anthropic), false);
check('archivo limpio no avisa', evaluatePost('Write', { file_path: clean }), false);
check('archivo inexistente no rompe', evaluatePost('Write', { file_path: path.join(dir, 'nope') }), false);
check('post respeta key-literal desactivado', evaluatePost('Write', { file_path: withKey }, { AI_GUARD_DISABLE: 'key-literal' }), false);
rmSync(dir, { recursive: true });

console.log(`\n${fail === 0 ? 'TODOS OK' : fail + ' FALLOS'}`);
process.exit(fail ? 1 : 0);
