#!/usr/bin/env node

// PreToolUse: bloquea leer archivos con secretos (dotenv, claves SSH, .npmrc,
// credentials, service accounts, .pem) con Read, Grep o Bash. `.env.example`,
// `.env.sample` y `.env.template` siguen legibles.
//
// Una llamada simple a env-check.sh KEY... pasa: dice present/empty/missing sin
// imprimir el valor. Con pipes, cadenas o redirecciones ya no cuenta como simple.
//
// Tambien bloquea escribir (Write, Edit, MultiEdit, NotebookEdit, Bash) una API
// key de aspecto real, y avisa tras escribir (PostToolUse) si ya hay una en
// disco. Solo informa numeros de linea, nunca el valor.
//
// Reglas (ids para AI_GUARD_DISABLE): secret-read, key-literal
// Falla abierto: un error del propio hook nunca bloquea trabajo ajeno.

import { readdirSync, readFileSync, realpathSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const deny = (reason) =>
    JSON.stringify({
        hookSpecificOutput: {
            hookEventName: 'PreToolUse',
            permissionDecision: 'deny',
            permissionDecisionReason: reason,
        },
    });

const parseList = (raw) =>
    (raw || '')
        .split(',')
        .map((s) => s.trim())
        .filter(Boolean);

const disabled = (id, env) => parseList(env.AI_GUARD_DISABLE).includes(id);

const TEMPLATE_SUFFIX = /\.(example|sample|template)$/;
// `.env`, `.env.local`, `.env*`; no `.envrc` ni `environment.ts`.
const DOTENV = /^\.env(?![A-Za-z0-9_-])/;
const SSH_KEY = /^id_(rsa|dsa|ecdsa|ed25519)(_[\w-]+)?$/;
const SERVICE_ACCOUNT = /service[-_]?account.*\.json$/i;

export const isSecretPath = (p) => {
    const base = String(p).replace(/^['"]|['"]$/g, '').split('/').pop();
    if (!base || TEMPLATE_SUFFIX.test(base)) {
        return false;
    }
    return (
        DOTENV.test(base) ||
        SSH_KEY.test(base) ||
        base === '.npmrc' ||
        base.startsWith('credentials') ||
        SERVICE_ACCOUNT.test(base) ||
        base.endsWith('.pem')
    );
};

// Nombres de ejemplo contra los que se prueba un glob: si puede expandirse a uno, se deniega.
const SAMPLES = ['.env', '.env.local', '.env.production', 'id_rsa', 'id_ed25519', '.npmrc', 'credentials', 'credentials.json', 'credentials.yml', 'credentials.yaml', 'service-account.json', 'server.pem'];

// `[!x]` y `[^x]` son clases negadas de la shell; el resto de la clase pasa tal cual.
const globToRegExp = (g) => {
    let re = '';
    for (let i = 0; i < g.length; i++) {
        const c = g[i];
        if (c === '*') {
            re += '.*';
        } else if (c === '?') {
            re += '.';
        } else if (c === '[') {
            const end = g.indexOf(']', i + 2);
            if (end < 0) {
                re += '\\[';
                continue;
            }
            const body = g.slice(i + 1, end).replace(/^[!^]/, '^').replace(/\\/g, '\\\\');
            re += `[${body}]`;
            i = end;
        } else {
            re += c.replace(/[.+^${}()|\\\]]/g, '\\$&');
        }
    }
    return new RegExp(`^${re}$`);
};

// Un glob se deniega solo si trae al menos dos caracteres literales antes del primer comodin
// (`s*`, `.n*`, `.*` no); `.e` es el unico prefijo de dos que se acepta (dotenv). `[e]` cuenta
// como literal. `*.pem` solo tambien se deniega.
export const globHitsSecret = (token) => {
    const base = token.replace(/^['"]|['"]$/g, '').split('/').pop();
    if (!/[*?[]/.test(base)) {
        return false;
    }
    const prefix = base.replace(/\[([^\]!^])\]/g, '$1').match(/^[^*?[]*/)[0];
    if (prefix.length < 3 && prefix !== '.e' && !(prefix === '' && base.endsWith('.pem'))) {
        return false;
    }
    try {
        const re = globToRegExp(base);
        return SAMPLES.some((s) => re.test(s) && isSecretPath(s));
    } catch {
        return false;
    }
};

// Una sola llamada al helper, solo con nombres de variable como argumentos. La ruta previa admite
// solo caracteres de ruta: ningun separador, sustitucion ni variable puede colar otra lectura.
const ENV_CHECK = /^(?:bash[ \t]+)?[\w.\/~-]*env-check\.sh(?:[ \t]+[A-Za-z_][A-Za-z0-9_]*)+$/;

// Junto al hook, donde viva (~/.claude, ~/.claude-b0...): argv[1] conserva la ruta del symlink de stow.
const HELPER = path.join(path.dirname(path.resolve(process.argv[1] || fileURLToPath(import.meta.url))), 'env-check.sh');

const REASON = (what) =>
    `secret-read: ${what} may hold secrets and cannot be read. ` +
    `Use \`bash ${HELPER} KEY\` to see whether a variable is set, or read the .example file.`;

// Regla: un directorio con un secreto en su primer nivel no se busca entero.
function searchDirReason(tool, dir) {
    try {
        const secret = readdirSync(dir).find(isSecretPath);
        if (secret) {
            return (
                `secret-read: ${dir} holds ${secret} at its top level, so ${tool} over the whole directory is blocked. ` +
                'Name the files to search (path to a file, or a subdirectory without secrets).'
            );
        }
    } catch {
        // No es un directorio legible (archivo o ruta inexistente): nada que revisar.
    }
}

const SEARCHERS = new Set(['grep', 'egrep', 'fgrep', 'rg', 'ag', 'ack']);

// `grep -r`, `rg`, `ag`, `ack` recorren el directorio objetivo (o el cwd si no hay operando).
function recursiveSearchReason(command) {
    for (const segment of command.split(/[;&|\n]+/)) {
        const [cmd, ...args] = segment.trim().split(/\s+/);
        const name = String(cmd).split('/').pop();
        if (!SEARCHERS.has(name)) {
            continue;
        }
        const isGrep = name.endsWith('grep');
        if (isGrep && !args.some((a) => /^-[A-Za-z]*[rR]/.test(a) || a === '--recursive')) {
            continue;
        }
        // El primer operando es el patron; el resto son destinos.
        const targets = args.filter((a) => !a.startsWith('-')).slice(1).map((a) => a.replace(/^['"]|['"]$/g, ''));
        for (const dir of targets.length ? targets : [process.cwd()]) {
            const reason = searchDirReason(name, dir);
            if (reason) {
                return reason;
            }
        }
    }
}

function checkRead(toolName, input) {
    if (toolName === 'Read') {
        return isSecretPath(input.file_path || '') ? REASON(input.file_path) : undefined;
    }
    if (toolName === 'Grep') {
        const hit = [input.path, input.glob].find((v) => v && isSecretPath(v));
        if (hit) {
            return REASON(hit);
        }
        return searchDirReason('Grep', input.path || process.cwd());
    }
    if (toolName === 'Bash') {
        const command = String(input.command || '').trim();
        if (ENV_CHECK.test(command)) {
            return;
        }
        const dirReason = recursiveSearchReason(command);
        if (dirReason) {
            return dirReason;
        }
        const hit = command.split(/[\s<>|;&()${}`:]+/).find((t) => t && (/[*?[]/.test(t) ? globHitsSecret(t) : isSecretPath(t)));
        return hit ? REASON(hit.replace(/^['"]|['"]$/g, '')) : undefined;
    }
}

// Prefijos de alta confianza: pocos falsos positivos antes que cubrirlo todo.
const KEY_PATTERNS = [
    /sk-ant-[A-Za-z0-9_-]{20,}/,
    /\bsk-(?:proj-)?[A-Za-z0-9_-]{32,}/,
    /\bAKIA[0-9A-Z]{16}\b/,
    /\bgh[pousr]_[A-Za-z0-9]{36,}/,
    /\bgithub_pat_[A-Za-z0-9_]{22,}/,
    /\bxox[baprs]-[A-Za-z0-9-]{10,}/,
    /\bAIza[0-9A-Za-z_-]{35}\b/,
    /-----BEGIN (?:[A-Z]+ )?PRIVATE KEY-----/,
];
const KNOWN_PREFIX = /^(?:sk-ant-|sk-proj-|sk-|AKIA|gh[pousr]_|github_pat_|xox[baprs]-|AIza)/;
// Marcador obvio de ejemplo: el cuerpo tras el prefijo (no todo el match) debe ser solo marcadores
// (`x`, `your`, `example`, `placeholder`, `-`, `_`); una clave real que los contenga sigue bloqueada. Sin cuerpo (clave PEM) nunca es marcador.
const isPlaceholderBody = (body) => body.replace(/x|your|example|placeholder|[-_]/gi, '') === '';

const hasKey = (line) =>
    KEY_PATTERNS.some((re) => {
        const m = line.match(re);
        return m && !isPlaceholderBody(m[0].replace(KNOWN_PREFIX, '') || '-');
    });

export const keyLines = (text) =>
    String(text || '')
        .split('\n')
        .flatMap((line, i) => (hasKey(line) ? [i + 1] : []));

const lineWord = (lines) => `line${lines.length > 1 ? 's' : ''} ${lines.join(', ')}`;

const writtenText = (toolName, input) => {
    switch (toolName) {
        case 'Write':
            return input.content;
        case 'Edit':
            return input.new_string;
        case 'MultiEdit':
            return (input.edits || []).map((e) => e.new_string).join('\n');
        case 'NotebookEdit':
            return input.new_source;
        case 'Bash':
            return input.command;
    }
};

export function evaluate(toolName, input, env = process.env) {
    if (!input) {
        return;
    }
    if (!disabled('secret-read', env)) {
        const reason = checkRead(toolName, input);
        if (reason) {
            return reason;
        }
    }
    if (!disabled('key-literal', env)) {
        const lines = keyLines(writtenText(toolName, input));
        if (lines.length) {
            return `key-literal: possible API key on ${lineWord(lines)}. Use an environment variable instead of writing the value.`;
        }
    }
}

// PostToolUse: avisa si el archivo escrito ya trae una clave.
export function evaluatePost(toolName, input, env = process.env) {
    const file = input?.notebook_path || input?.file_path;
    if (disabled('key-literal', env) || !file) {
        return;
    }
    try {
        const lines = keyLines(readFileSync(file, 'utf8'));
        if (lines.length) {
            return `key-literal: ${file} holds a possible API key on ${lineWord(lines)}. Remove it and rotate the key.`;
        }
    } catch {
        // Archivo ilegible o inexistente: nada que avisar.
    }
}

// Se ejecuta a traves de un symlink (stow): comparamos rutas reales.
const isMain = (() => {
    try {
        return realpathSync(process.argv[1]) === fileURLToPath(import.meta.url);
    } catch {
        return false;
    }
})();

if (isMain) {
    try {
        const { hook_event_name, tool_name, tool_input } = JSON.parse(readFileSync(0, 'utf8'));
        if (hook_event_name === 'PostToolUse') {
            const warning = evaluatePost(tool_name, tool_input);
            if (warning) {
                process.stdout.write(
                    JSON.stringify({
                        hookSpecificOutput: { hookEventName: 'PostToolUse', additionalContext: warning },
                    }),
                );
            }
            process.exit(0);
        }
        const reason = evaluate(tool_name, tool_input);
        if (reason) {
            process.stdout.write(deny(reason));
        }
    } catch (e) {
        process.stderr.write(`[guard-secrets] ${e.message}\n`);
    }
}
