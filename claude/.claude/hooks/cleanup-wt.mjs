#!/usr/bin/env node

// Limpia worktrees y ramas locales ya mergeadas en la rama base.
//
// Uso:
//   cleanup-wt.mjs                 dry-run: imprime el plan y no toca nada
//   cleanup-wt.mjs --apply         ejecuta el plan
//   cleanup-wt.mjs --auto          SessionStart: ejecuta solo si la base se movio desde
//                                  la ultima sesion; silencioso (mensajes a stderr)
//   cleanup-wt.mjs --post-merge    ejecuta siempre; para llamarlo tras mergear un ticket
//   --base <rama>                  rama base extra (ademas de main, master y
//                                  AI_GUARD_PROTECT_BRANCHES)
//
// Nunca borra trabajo sin mergear, nunca toca una rama base ni el worktree donde
// corre. Un worktree sucio en una rama mergeada se guarda con un wip-commit y se
// conserva su rama. Antes de borrar ramas escribe un TSV de recuperacion en
// <git-common-dir>/cleanup-wt/<timestamp>.tsv; restaura con `git branch <rama> <sha>`.
//
// Una rama cuyo tip coincide con el de la base (recien creada o fast-forward) NO se
// considera mergeada: es indistinguible de una rama nueva sin commits. Los squash
// merges tampoco se detectan. Ambos se quedan, que es lo seguro.
//
// AI_GUARD_DISABLE=cleanup-wt lo desactiva (tambien en --auto).
//
// Falla abierto: un error aqui nunca debe bloquear una sesion.

import { execFileSync } from 'node:child_process';
import { existsSync, mkdirSync, readFileSync, realpathSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const within = (child, parent) => child === parent || child.startsWith(parent + path.sep);

export function planCleanup({ worktrees, branches, merged, bases, currentPath }) {
    const mergedSet = new Set(merged.filter((b) => !bases.includes(b)));
    const inWorktree = new Set(worktrees.map((w) => w.branch).filter(Boolean));
    const actions = [];
    for (const w of worktrees) {
        if (w.main || !w.branch || !mergedSet.has(w.branch)) {
            continue;
        }
        if (currentPath && within(currentPath, w.path)) {
            continue;
        }
        if (w.dirty) {
            actions.push({ action: 'wip-commit', path: w.path, branch: w.branch });
            actions.push({ action: 'remove-worktree', path: w.path, branch: w.branch });
        } else {
            actions.push({ action: 'remove-worktree', path: w.path, branch: w.branch });
            actions.push({ action: 'delete-branch', branch: w.branch });
        }
    }
    for (const b of branches) {
        if (mergedSet.has(b) && !inWorktree.has(b)) {
            actions.push({ action: 'delete-branch', branch: b });
        }
    }
    return actions;
}

export const recoveryTsv = (actions, shaOf, failed = new Set()) => {
    const rows = actions
        .filter((a) => a.action === 'delete-branch' && !failed.has(a.branch))
        .map((a) => `${a.branch}\t${shaOf(a.branch)}`);
    return rows.length ? rows.join('\n') + '\n' : '';
};

export const isDisabled = (env) =>
    (env.AI_GUARD_DISABLE || '').split(',').some((s) => s.trim() === 'cleanup-wt');

export const baseMoved = (previous, current) => Boolean(current) && previous !== current;

// ---- git (capa fina, sin tests unitarios: se prueba con dry-run) ----

const git = (args, cwd) =>
    execFileSync('git', args, { cwd, encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] }).trim();

const real = (p) => {
    try {
        return realpathSync(p);
    } catch {
        return path.resolve(p);
    }
};

const listWorktrees = (cwd) => {
    const blocks = git(['worktree', 'list', '--porcelain'], cwd).split('\n\n').filter(Boolean);
    return blocks.map((block, i) => {
        const lines = block.split('\n');
        const wtPath = real(lines.find((l) => l.startsWith('worktree '))?.slice(9) || '');
        const ref = lines.find((l) => l.startsWith('branch '))?.slice(7);
        const dirty = i > 0 && git(['status', '--porcelain'], wtPath) !== '';
        return { path: wtPath, branch: ref?.replace('refs/heads/', '') || null, dirty, main: i === 0 };
    });
};

const refExists = (ref, cwd) => {
    try {
        git(['rev-parse', '--verify', '--quiet', `refs/heads/${ref}`], cwd);
        return true;
    } catch {
        return false;
    }
};

function main() {
    if (isDisabled(process.env)) {
        return;
    }
    const argv = process.argv.slice(2);
    const auto = argv.includes('--auto');
    const apply = argv.includes('--apply') || argv.includes('--post-merge');
    const extraBase = argv[argv.indexOf('--base') + 1];
    const log = auto ? (m) => process.stderr.write(`[cleanup-wt] ${m}\n`) : (m) => console.log(m);

    const cwd = process.cwd();
    const common = real(path.resolve(cwd, git(['rev-parse', '--git-common-dir'], cwd)));
    const protectedEnv = (process.env.AI_GUARD_PROTECT_BRANCHES || '').split(',').map((s) => s.trim());
    const wanted = ['main', 'master', ...protectedEnv, argv.includes('--base') ? extraBase : ''];
    const bases = [...new Set(wanted.filter(Boolean))].filter((b) => refExists(b, cwd));
    if (!bases.length) {
        return;
    }

    const tipOf = (b) => git(['rev-parse', `refs/heads/${b}`], cwd);
    const tips = bases.map((b) => `${b}=${tipOf(b)}`).join(' ');
    const stateDir = path.join(common, 'cleanup-wt');
    const stateFile = path.join(stateDir, 'state');
    const previous = existsSync(stateFile) ? readFileSync(stateFile, 'utf8').trim() : undefined;

    if (auto && !baseMoved(previous, tips)) {
        return;
    }

    const baseTips = new Set(bases.map(tipOf));
    const merged = new Set();
    for (const b of bases) {
        const out = git(['branch', '--merged', `refs/heads/${b}`, '--format=%(refname:short)'], cwd);
        for (const name of out.split('\n').filter(Boolean)) {
            if (!baseTips.has(tipOf(name))) {
                merged.add(name);
            }
        }
    }
    const branches = git(['branch', '--format=%(refname:short)'], cwd).split('\n').filter(Boolean);
    const actions = planCleanup({
        worktrees: listWorktrees(cwd),
        branches,
        merged: [...merged],
        bases,
        currentPath: real(cwd),
    });

    if (!apply && !auto) {
        log(actions.length ? 'Plan (dry-run, usa --apply para ejecutar):' : 'Nada que limpiar.');
        for (const a of actions) {
            log(`  ${a.action}  ${a.path ?? ''}${a.path && a.branch ? '  ' : ''}${a.branch ?? ''}`);
        }
        return;
    }

    mkdirSync(stateDir, { recursive: true });
    const failedWorktrees = new Set();
    const run = (a) => {
        try {
            if (a.action === 'wip-commit') {
                git(['add', '-A'], a.path);
                git(['commit', '-q', '--no-verify', '-m', 'wip: cleanup-wt autosave'], a.path);
            } else if (a.action === 'remove-worktree') {
                git(['worktree', 'remove', a.path], cwd);
            } else if (a.action === 'delete-branch') {
                git(['branch', '-D', a.branch], cwd);
            }
            log(`ok  ${a.action} ${a.path ?? a.branch}`);
        } catch (e) {
            failedWorktrees.add(a.branch);
            log(`skip ${a.action} ${a.path ?? a.branch}: ${String(e.stderr || e.message).trim()}`);
        }
    };

    // Primero los worktrees; el TSV solo lista ramas que se van a borrar de verdad.
    actions.filter((a) => a.action !== 'delete-branch').forEach(run);
    const deletions = actions.filter((a) => a.action === 'delete-branch' && !failedWorktrees.has(a.branch));
    const tsv = recoveryTsv(deletions, tipOf, failedWorktrees);
    if (tsv) {
        const file = path.join(stateDir, `${new Date().toISOString().replace(/[:.]/g, '-')}.tsv`);
        writeFileSync(file, tsv);
        log(`Recuperacion: ${file}`);
    }
    deletions.forEach(run);
    writeFileSync(stateFile, tips + '\n');
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
        main();
    } catch (e) {
        process.stderr.write(`[cleanup-wt] ${e.message}\n`);
    }
}
