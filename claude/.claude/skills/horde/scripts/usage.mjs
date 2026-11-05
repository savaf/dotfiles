#!/usr/bin/env node
// Uso acumulado de una sesión de Claude Code, desde su transcript.
// Uso: usage.mjs <transcript.jsonl> [--minus "<tokens_in>,<tokens_out>,<cost_usd>"]
// Imprime "tokens_in<TAB>tokens_out<TAB>cost_usd". Vacío si el transcript no trae un
// registro `cost-state` confiable (falta, o hasUnknownModelCost). Nunca estima.
// `cost-state` no está documentado: es un registro interno de Claude Code y puede cambiar.
// Solo vale si el proceso de claude de la sesión siguió vivo entre la base y la lectura: tras un
// `--resume` los tokens siguen acumulando pero el costo se reinicia (comprobado con una corrida
// real). Un delta negativo se descarta; un reinicio que no lo produzca no se puede detectar.
import { readFileSync } from 'node:fs';

export const readUsage = (text) => {
    let last = null;
    for (const line of text.split('\n')) {
        if (!line.includes('"cost-state"')) {
            continue;
        }
        try {
            const row = JSON.parse(line);
            if (row.type === 'cost-state') {
                last = row;
            }
        } catch {
            // línea truncada: se ignora
        }
    }
    if (!last || last.hasUnknownModelCost !== false || typeof last.totalCostUSD !== 'number') {
        return null;
    }
    let tokensIn = 0;
    let tokensOut = 0;
    for (const m of Object.values(last.modelUsage ?? {})) {
        tokensIn += (m.inputTokens ?? 0) + (m.cacheReadInputTokens ?? 0) + (m.cacheCreationInputTokens ?? 0);
        tokensOut += m.outputTokens ?? 0;
    }
    return { tokensIn, tokensOut, costUsd: last.totalCostUSD };
};

// Resta una base "in,out,cost" (la lectura al empezar la ronda). Base vacía = sesión nueva.
export const format = (usage, base = '') => {
    if (!usage) {
        return '\t\t';
    }
    const [bIn, bOut, bCost] = base.split(',').map((v) => (v === '' || v === undefined ? 0 : Number(v)));
    const delta = [
        usage.tokensIn - (bIn || 0),
        usage.tokensOut - (bOut || 0),
        Math.round((usage.costUsd - (bCost || 0)) * 1e6) / 1e6,
    ];
    return delta.some((d) => d < 0) ? '\t\t' : delta.join('\t');
};

if (import.meta.url === `file://${process.argv[1]}`) {
    const [file, flag, base] = process.argv.slice(2);
    let text = '';
    try {
        text = readFileSync(file, 'utf8');
    } catch {
        // sin transcript: campos vacíos
    }
    console.log(format(readUsage(text), flag === '--minus' ? base : ''));
}
