#!/usr/bin/env node

// PreToolUse Bash: deniega `git worktree add|move` cuyo destino cae fuera de
// <repo>/.claude/worktrees/. Respeta `cd X &&` y `git -C X`.
//
// Un destino que solo se conoce en ejecucion ($VAR, $(...)) se deja pasar: no se
// puede resolver y bloquearlo seria adivinar.
//
// Nota: `horde` crea sus worktrees con `herdr worktree create`, no con
// `git worktree add`, asi que este guard no le afecta; protege el resto de usos.
//
// Env:
//   AI_GUARD_WORKTREE_DIRS=<dir,dir>  directorios extra permitidos (relativos al repo)
//   AI_GUARD_DISABLE=worktree-path    desactiva la regla
//
// Falla abierto: un error del propio hook nunca bloquea trabajo ajeno.

import { execFileSync } from 'node:child_process';
import { readFileSync, realpathSync } from 'node:fs';
import os from 'node:os';
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

const within = (child, parent) => child === parent || child.startsWith(parent + path.sep);
const dynamic = (s) => /[$`]/.test(s);
const unquote = (s) => s.replace(/^['"]|['"]$/g, '');
const resolveFrom = (base, p) => path.resolve(base, p.replace(/^~(?=\/|$)/, os.homedir()));

const WORKTREE = /^git\s+(?:-C\s+(\S+)\s+)?worktree\s+(add|move)\b\s*(.*)$/;
const VALUE_OPTS = new Set(['-b', '-B', '--reason']);

const positionals = (rest) => {
    const out = [];
    const tokens = rest.split(/\s+/).filter(Boolean).map(unquote);
    for (let i = 0; i < tokens.length; i++) {
        if (VALUE_OPTS.has(tokens[i])) {
            i++;
        } else if (!tokens[i].startsWith('-')) {
            out.push(tokens[i]);
        }
    }
    return out;
};

export function evaluate(command, { cwd, repoRoot } = {}, env = process.env) {
    if (typeof command !== 'string' || !command.trim() || !repoRoot) {
        return;
    }
    if (parseList(env.AI_GUARD_DISABLE).includes('worktree-path')) {
        return;
    }
    const allowed = [
        path.join(repoRoot, '.claude', 'worktrees'),
        ...parseList(env.AI_GUARD_WORKTREE_DIRS).map((d) => resolveFrom(repoRoot, d)),
    ];

    let dir = cwd || repoRoot;
    let dirKnown = true;
    for (const segment of command.split(/\n|&&|\|\||;|\|/).map((s) => s.trim())) {
        const cd = segment.match(/^cd\s+(\S+)$/);
        if (cd) {
            const target = unquote(cd[1]);
            dirKnown = dirKnown && !dynamic(target);
            dir = dirKnown ? resolveFrom(dir, target) : dir;
            continue;
        }
        const match = segment.match(WORKTREE);
        if (!match) {
            continue;
        }
        const [, gitC, sub, rest] = match;
        const args = positionals(rest);
        const target = sub === 'add' ? args[0] : args[1];
        if (!target || dynamic(target) || (gitC && dynamic(gitC))) {
            continue;
        }
        const base = gitC ? resolveFrom(dir, unquote(gitC)) : dir;
        if (!dirKnown && !path.isAbsolute(target)) {
            continue;
        }
        const resolved = resolveFrom(base, target);
        if (!allowed.some((a) => within(resolved, a))) {
            return (
                `worktree-path: git worktree ${sub} target ${resolved} is outside ` +
                `${allowed[0]}. Create worktrees there, or add the directory to AI_GUARD_WORKTREE_DIRS.`
            );
        }
    }
}

const isMain = (() => {
    try {
        return realpathSync(process.argv[1]) === fileURLToPath(import.meta.url);
    } catch {
        return false;
    }
})();

if (isMain) {
    try {
        const input = JSON.parse(readFileSync(0, 'utf8'));
        const command = input?.tool_input?.command;
        // Casi todo comando Bash sale aqui, sin lanzar git.
        if (typeof command === 'string' && /worktree/.test(command)) {
            const cwd = input.cwd || process.cwd();
            const repoRoot =
                process.env.CLAUDE_PROJECT_DIR ||
                execFileSync('git', ['rev-parse', '--show-toplevel'], { cwd, encoding: 'utf8' }).trim();
            const reason = evaluate(command, { cwd, repoRoot });
            if (reason) {
                process.stdout.write(deny(reason));
            }
        }
    } catch (e) {
        process.stderr.write(`[guard-worktree-path] ${e.message}\n`);
    }
}
