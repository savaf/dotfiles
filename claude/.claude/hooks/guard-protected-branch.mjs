#!/usr/bin/env node

// PreToolUse: bloquea Write/Edit sobre archivos del repo cuando la rama actual
// está en AI_GUARD_PROTECT_BRANCHES. Ediciones fuera del repo (p.ej. ~/.claude/)
// siempre pasan.
//
// Opt-in: sin AI_GUARD_PROTECT_BRANCHES sale en 0 sin tocar git. Actívalo en el
// .claude/settings.json del proyecto:
//   "env": { "AI_GUARD_PROTECT_BRANCHES": "main,master" }
//
// Falla cerrado: si está en una rama protegida y no puede resolver la ruta o la
// raíz del repo, deniega.

import { execSync } from 'node:child_process';
import { readFileSync, realpathSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const deny = (reason) =>
    JSON.stringify({
        decision: 'deny',
        reason,
        hookSpecificOutput: {
            hookEventName: 'PreToolUse',
            permissionDecision: 'deny',
            permissionDecisionReason: reason,
        },
    });

const resolveSafe = (p) => {
    try {
        return realpathSync(p);
    } catch {
        return path.resolve(p);
    }
};

export const protectedBranches = (env = process.env) =>
    (env.AI_GUARD_PROTECT_BRANCHES || '')
        .split(',')
        .map((s) => s.trim())
        .filter(Boolean);

export const isInsideRepo = (filePath, repoRoot) => {
    const f = resolveSafe(filePath);
    const r = resolveSafe(repoRoot);
    return f === r || f.startsWith(r + path.sep);
};

export function evaluate(filePath, branch, repoRoot, env = process.env) {
    if (!protectedBranches(env).includes(branch)) {
        return;
    }
    if (!filePath) {
        return `Cannot determine file path on protected branch "${branch}". Blocking for safety.`;
    }
    if (!repoRoot) {
        return `Cannot determine repo root on protected branch "${branch}". Blocking for safety.`;
    }
    if (isInsideRepo(filePath, repoRoot)) {
        return `Cannot Write/Edit repo files on protected branch "${branch}". Create a feature branch first.`;
    }
}

function currentBranch() {
    return execSync('git branch --show-current', { encoding: 'utf8' }).trim();
}

function failClosed() {
    let branch;
    try {
        branch = currentBranch();
    } catch {
        // Fuera de un repo git no hay nada que proteger.
        return;
    }
    if (protectedBranches().includes(branch)) {
        process.stdout.write(
            deny(`Hook error on protected branch "${branch}". Blocking for safety.`),
        );
    }
}

// Se ejecuta a traves de un symlink (stow), asi que comparamos rutas reales:
// Node resuelve el symlink en import.meta.url pero no en process.argv[1].
const isMain = (() => {
    try {
        return realpathSync(process.argv[1]) === fileURLToPath(import.meta.url);
    } catch {
        return false;
    }
})();

if (isMain) {
    // Sin ramas protegidas configuradas no hacemos ni un subproceso.
    if (!protectedBranches().length) {
        process.exit(0);
    }
    try {
        const { tool_input: { file_path } = {} } = JSON.parse(readFileSync(0, 'utf8'));
        const repoRoot =
            process.env.CLAUDE_PROJECT_DIR ||
            execSync('git rev-parse --show-toplevel', { encoding: 'utf8' }).trim();
        // Si el archivo cae fuera del repo no hay nada que vigilar: nos ahorramos
        // el subproceso de rama.
        if (file_path && repoRoot && !isInsideRepo(file_path, repoRoot)) {
            process.exit(0);
        }
        const reason = evaluate(file_path, currentBranch(), repoRoot);
        if (reason) {
            process.stdout.write(deny(reason));
        }
    } catch (e) {
        process.stderr.write(`[guard-protected-branch] ${e.message}\n`);
        failClosed();
    }
}
