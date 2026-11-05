#!/usr/bin/env node
// Reporte de la fábrica a partir de .scratch/horde/results.tsv.
// Uso: report.mjs [ruta/results.tsv]
// Lee por nombre de columna: un log viejo sin minutes/tokens/cost sigue leyéndose.
import { readFileSync } from 'node:fs';

export const parse = (text) => {
    const [head, ...lines] = text.split('\n').filter((l) => l.trim());
    const cols = head.split('\t');
    return lines.map((l) => Object.fromEntries(l.split('\t').map((v, i) => [cols[i], v])));
};

const avg = (xs) => (xs.length ? xs.reduce((a, b) => a + b, 0) / xs.length : null);
const pct = (n, d) => (d ? `${Math.round((100 * n) / d)}%` : 'n/a');
const num = (v) => (v === undefined || v === '' || Number.isNaN(Number(v)) ? null : Number(v));

export const report = (rows) => {
    const byTicket = new Map();
    for (const r of rows) {
        byTicket.set(r.ticket, [...(byTicket.get(r.ticket) ?? []), r]);
    }
    const tickets = [...byTicket.values()];
    const n = tickets.length;
    const failures = new Map();
    for (const r of rows) {
        if (r.failure) {
            failures.set(r.failure, new Set([...(failures.get(r.failure) ?? []), r.ticket]));
        }
    }
    const repeated = [...failures].filter(([, t]) => t.size >= 2).sort((a, b) => b[1].size - a[1].size);
    const sums = (key) =>
        tickets.map((t) => t.map((r) => num(r[key])).filter((v) => v !== null)).filter((v) => v.length)
            .map((v) => v.reduce((a, b) => a + b, 0));
    const minutes = avg(sums('minutes'));
    const cost = avg(sums('cost_usd'));
    const lines = [
        `Tickets: ${n}`,
        `Gate en ronda 1: ${pct(tickets.filter((t) => t.some((r) => r.round === '1' && r.gate === 'pass')).length, n)}`,
        `Rondas promedio por ticket: ${n ? avg(tickets.map((t) => Math.max(...t.map((r) => Number(r.round))))).toFixed(1) : 'n/a'}`,
        `Con reinicio (plateau): ${pct(tickets.filter((t) => t.some((r) => r.action === 'restart')).length, n)}`,
        `Detenidos: ${tickets.filter((t) => t.some((r) => r.action === 'stopped')).length}`,
        `Disputas de check: ${tickets.filter((t) => t.some((r) => r.failure === 'check-dispute')).length}`,
        `Minutos promedio por ticket: ${minutes === null ? 'sin datos' : minutes.toFixed(1)}`,
        `Costo promedio por ticket (USD): ${cost === null ? 'sin datos' : cost.toFixed(2)}`,
        '',
        'Fallas en 2 o más tickets (candidatas para AGENTS.md):',
        ...(repeated.length ? repeated.map(([k, t]) => `- ${k} (${t.size} tickets)`) : ['- ninguna']),
    ];
    return lines.join('\n');
};

if (import.meta.url === `file://${process.argv[1]}`) {
    const file = process.argv[2] ?? '.scratch/horde/results.tsv';
    console.log(report(parse(readFileSync(file, 'utf8'))));
}
