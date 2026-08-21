#!/usr/bin/env node

// Guardrail de shell para Claude (PreToolUse), Gemini (BeforeTool) y Cursor
// (beforeShellExecution). Bloquea comandos destructivos e irreversibles.
// La forma de la respuesta es específica de cada runtime.
//
// Dos familias de reglas:
//   SAFETY  siempre activas. Pérdida de datos sin vuelta atrás.
//   POLICY  opt-in. Convenciones de equipo, no seguridad universal.
//
// Variables de entorno (definibles en el settings.json del proyecto):
//   AI_GUARD_DISABLE=<id,id>  desactiva reglas SAFETY por id
//   AI_GUARD_ENABLE=<id,id>   activa reglas POLICY por id ("all" = todas)
//   AI_GUARD_PROTECT_BRANCHES=main,master  ramas donde `git commit` se bloquea

import { execSync } from 'node:child_process';
import { readFileSync, realpathSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

const RUNTIMES = new Set(['claude', 'gemini', 'cursor']);

export const parseRuntime = (argv) => {
    const arg = argv.find((a) => a.startsWith('--runtime='));
    if (!arg) {
        return null;
    }
    const value = arg.slice('--runtime='.length);
    return RUNTIMES.has(value) ? value : null;
};

export const extractCommand = (input, runtime) => {
    if (runtime === 'cursor') {
        return input?.command;
    }
    return input?.tool_input?.command;
};

export const deny = (reason, runtime) => {
    if (runtime === 'gemini') {
        return JSON.stringify({ decision: 'deny', reason });
    }
    if (runtime === 'cursor') {
        return JSON.stringify({
            permission: 'deny',
            user_message: reason,
            agent_message: reason,
        });
    }
    return JSON.stringify({
        hookSpecificOutput: {
            hookEventName: 'PreToolUse',
            permissionDecision: 'deny',
            permissionDecisionReason: reason,
        },
    });
};

// Pérdida de datos irreversible. Activas en todo proyecto.
export const SAFETY_RULES = [
    {
        id: 'rm-rf',
        test: (cmd) => {
            if (!/(?:^|\s)rm(?:\s|$)/.test(cmd)) {
                return false;
            }
            const compound =
                /\s-[a-zA-Z]*[rR][a-zA-Z]*[fF]/.test(cmd) ||
                /\s-[a-zA-Z]*[fF][a-zA-Z]*[rR]/.test(cmd);
            if (compound) {
                return true;
            }
            const recursive = /(?:\s|^)(-[a-zA-Z]*[rR](?:\s|$)|--recursive(?:\s|$))/.test(cmd);
            const force = /(?:\s|^)(-[a-zA-Z]*[fF](?:\s|$)|--force(?:\s|$))/.test(cmd);
            return recursive && force;
        },
        reason: 'rm -rf permanently deletes files with no recovery. Be specific about which files to remove.',
    },
    {
        id: 'git-reset-hard',
        test: (cmd) => /git\s+reset(?:\s|$)/.test(cmd) && /\s--hard(?:\s|$)/.test(cmd),
        reason: 'git reset --hard discards all uncommitted changes permanently. Use git stash to preserve them.',
    },
    {
        id: 'git-clean-force',
        test: (cmd) =>
            /git\s+clean(?:\s|$)/.test(cmd) &&
            (/\s-[a-zA-Z]*f/.test(cmd) || /--force/.test(cmd)),
        reason: 'git clean -f permanently deletes untracked files. List them with git clean -n first.',
    },
    {
        id: 'force-push-protected',
        test: (cmd) => {
            if (!/git\s+push(?:\s|$)/.test(cmd)) {
                return false;
            }
            const hasAnyForce =
                /(?:\s|^)(?:-f|--force|--force-with-lease|--force-if-includes)(?:[=\s]|$)/.test(cmd);
            if (!hasAnyForce) {
                return false;
            }
            return /(?:^|\s|:|\/)(?:main|master)(?:$|\s)/.test(cmd);
        },
        reason: 'Force pushing to main/master rewrites shared history even with --force-with-lease. Never force push to protected branches.',
    },
    {
        id: 'force-push-no-lease',
        test: (cmd) =>
            /git\s+push(?:\s|$)/.test(cmd) &&
            /(?:\s|^)(-f|--force)(?:\s|$)/.test(cmd) &&
            !/--force-with-lease/.test(cmd),
        reason: 'git push --force overwrites remote history. Use --force-with-lease instead.',
    },
    {
        id: 'git-branch-force-delete',
        test: (cmd) => {
            if (!/git\s+branch(?:\s|$)/.test(cmd)) {
                return false;
            }
            if (/(?:\s|^)-[a-zA-Z]*D[a-zA-Z]*(?:\s|$)/.test(cmd)) {
                return true;
            }
            const hasDelete = /(?:\s|^)(?:--delete|-d)(?:\s|$)/.test(cmd);
            const hasForce = /(?:\s|^)(?:--force|-f)(?:\s|$)/.test(cmd);
            return hasDelete && hasForce;
        },
        reason: 'git branch -D force-deletes a branch and can orphan commits. Merge first, or use git branch -d.',
    },
    {
        id: 'git-reflog-expire',
        test: (cmd) => /git\s+reflog\s+expire(?:\s|$)/.test(cmd),
        reason: 'git reflog expire purges the commit recovery net. Orphaned commits cannot be recovered afterward.',
    },
    {
        id: 'git-checkout-dot',
        test: (cmd) => /git\s+checkout\s+(?:--\s+)?\.(?:\s|$|["'\\])/.test(cmd),
        reason: 'git checkout . discards all unstaged changes. Be specific about which files to restore.',
    },
    {
        id: 'git-restore-dot',
        test: (cmd) =>
            /git\s+restore\s+/.test(cmd) && /(?:\s|^)\.(?:\s|$|["'\\])/.test(cmd),
        reason: 'git restore . discards changes across all files. Be specific about which files to restore.',
    },
];

// Convención de equipo, no seguridad. Se activan con AI_GUARD_ENABLE.
export const POLICY_RULES = [
    {
        id: 'git-add-all',
        test: (cmd) =>
            /git\s+add(?:\s|$)/.test(cmd) &&
            (/(?:\s|^)(-A|--all)(?:\s|$)/.test(cmd) || /(?:\s|^)\.(?:\s|$)/.test(cmd)),
        reason: 'git add -A / git add . stages all files indiscriminately. Add specific files by name.',
    },
    {
        id: 'git-no-verify',
        test: (cmd) =>
            /git\s+commit(?:\s|$)/.test(cmd) &&
            /(?:\s|^)(--no-verify|-n)(?:\s|$)/.test(cmd),
        reason: 'git commit --no-verify bypasses pre-commit hooks. Diagnose the hook failure instead.',
    },
    {
        id: 'git-amend',
        test: (cmd) =>
            /git\s+commit(?:\s|$)/.test(cmd) && /(?:\s|^)--amend(?:\s|$)/.test(cmd),
        reason: 'git commit --amend rewrites the previous commit. Create a new commit instead.',
    },
];

// Las reglas se evaluan por segmento, no sobre la cadena entera: un comando
// compuesto (o con heredoc) mezcla tokens de lineas distintas y dispara falsos
// positivos, p.ej. `rm -r x` en la ultima linea + un `[ -f ... ]` en el cuerpo
// del heredoc leidos juntos como `rm -rf`.
const SEGMENT_SEP = /\n|\s*(?:&&|\|\||[;|])\s*/;

export const segments = (command) =>
    command.split(SEGMENT_SEP).map((s) => s.trim()).filter(Boolean);

const parseList = (raw) =>
    (raw || '')
        .split(',')
        .map((s) => s.trim())
        .filter(Boolean);

export const activeRules = (env = process.env) => {
    const disabled = new Set(parseList(env.AI_GUARD_DISABLE));
    const enabled = parseList(env.AI_GUARD_ENABLE);
    const allPolicy = enabled.includes('all');
    const enabledSet = new Set(enabled);
    return [
        ...SAFETY_RULES.filter((r) => !disabled.has(r.id)),
        ...POLICY_RULES.filter((r) => allPolicy || enabledSet.has(r.id)),
    ];
};

export const checkDestructive = (command, env) => {
    const rules = activeRules(env);
    for (const segment of segments(command)) {
        const hit = rules.find((rule) => rule.test(segment));
        if (hit) {
            return hit.reason;
        }
    }
};

const GIT_COMMIT = /git\s+commit(?:\s|$)/;
const GIT_COMMIT_IN_OTHER_REPO = /git\s+-C\s+\S+\s+commit(?:\s|$)/;
const isBareCommit = (segment) =>
    GIT_COMMIT.test(segment) && !GIT_COMMIT_IN_OTHER_REPO.test(segment);

export const protectedBranches = (env = process.env) =>
    parseList(env.AI_GUARD_PROTECT_BRANCHES);

export const isCommitOnProtected = (command, branch, env) =>
    Boolean(branch) &&
    protectedBranches(env).includes(branch) &&
    segments(command).some(isBareCommit);

export function evaluate(command, branch, env = process.env) {
    if (typeof command !== 'string' || !command.trim()) {
        return 'Unable to parse command from tool input; denying for safety.';
    }
    const reason = checkDestructive(command, env);
    if (reason) {
        return reason;
    }
    if (isCommitOnProtected(command, branch, env)) {
        return `Cannot commit on protected branch "${branch}". Create a feature branch first.`;
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
    try {
        const runtime = parseRuntime(process.argv.slice(2));
        if (!runtime) {
            const reason =
                'Missing or invalid --runtime=claude|gemini|cursor; denying command for safety.';
            process.stderr.write(`[git-guardrails] ${reason}\n`);
            process.stdout.write(deny(reason, runtime));
            process.exitCode = 1;
        } else {
            const input = JSON.parse(readFileSync(0, 'utf8'));
            const command = extractCommand(input, runtime);
            const cmd = typeof command === 'string' ? command : '';
            const destructive = checkDestructive(cmd);
            // Solo pagamos el subproceso de git si hay ramas protegidas y el
            // comando es un commit: en la mayoría de sesiones no se ejecuta.
            const branch =
                !destructive && protectedBranches().length && GIT_COMMIT.test(cmd)
                    ? execSync('git branch --show-current', {
                          encoding: 'utf8',
                          timeout: 2000,
                      }).trim()
                    : null;
            const reason = destructive || evaluate(cmd, branch);
            if (reason) {
                process.stdout.write(deny(reason, runtime));
            }
        }
    } catch (e) {
        process.stderr.write(`[git-guardrails] ${e.message}\n`);
    }
}
