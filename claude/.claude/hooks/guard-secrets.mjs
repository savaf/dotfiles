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
const SAMPLES = ['.env', '.env.local', '.env.production', 'id_rsa', 'id_ed25519', '.npmrc', 'credentials', 'credentials.json', 'service-account.json', 'server.pem'];

const globToRegExp = (g) =>
    new RegExp(
        '^' +
            g.replace(/[.+^${}()|\\]/g, '\\$&').replace(/\*/g, '.*').replace(/\?/g, '.') +
            '$',
    );

// `*` o `*.json` solos no cuentan (romperian `ls *`): hace falta un literal al inicio, o `.pem` al final.
export const globHitsSecret = (token) => {
    const base = token.replace(/^['"]|['"]$/g, '').split('/').pop();
    if (!/[*?[]/.test(base) || (/^[*?[]/.test(base) && !base.endsWith('.pem'))) {
        return false;
    }
    try {
        const re = globToRegExp(base);
        return SAMPLES.some((s) => re.test(s) && isSecretPath(s));
    } catch {
        return false;
    }
};

// Una sola llamada al helper, solo con nombres de variable como argumentos.
const ENV_CHECK = /^(?:bash\s+)?\S*env-check\.sh(?:\s+[A-Za-z_][A-Za-z0-9_]*)+$/;

const REASON = (what) =>
    `secret-read: ${what} may hold secrets and cannot be read. ` +
    'Use env-check.sh KEY to see whether a variable is set, or read the .example file.';

function checkRead(toolName, input) {
    if (toolName === 'Read') {
        return isSecretPath(input.file_path || '') ? REASON(input.file_path) : undefined;
    }
    if (toolName === 'Grep') {
        const hit = [input.path, input.glob].find((v) => v && isSecretPath(v));
        if (hit) {
            return REASON(hit);
        }
        // Regla: un directorio con un secreto en su primer nivel no se busca entero.
        const dir = input.path || process.cwd();
        try {
            const secret = readdirSync(dir).find(isSecretPath);
            if (secret) {
                return (
                    `secret-read: ${dir} holds ${secret} at its top level, so Grep over the whole directory is blocked. ` +
                    'Name the files to search (path to a file, or a subdirectory without secrets).'
                );
            }
        } catch {
            // No es un directorio legible (archivo o ruta inexistente): nada que revisar.
        }
        return undefined;
    }
    if (toolName === 'Bash') {
        const command = String(input.command || '').trim();
        if (ENV_CHECK.test(command)) {
            return;
        }
        const hit = command.split(/[\s<>|;&()]+/).find((t) => t && (/[*?[]/.test(t) ? globHitsSecret(t) : isSecretPath(t)));
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
// Marcadores obvios de ejemplo: no son claves vivas.
const PLACEHOLDER = /x{4,}|your|example|placeholder/i;

const hasKey = (line) =>
    KEY_PATTERNS.some((re) => {
        const m = line.match(re);
        return m && !PLACEHOLDER.test(m[0]);
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
    if (disabled('key-literal', env) || !input?.file_path) {
        return;
    }
    try {
        const lines = keyLines(readFileSync(input.file_path, 'utf8'));
        if (lines.length) {
            return `key-literal: ${input.file_path} holds a possible API key on ${lineWord(lines)}. Remove it and rotate the key.`;
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
