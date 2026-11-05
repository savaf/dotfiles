import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { parse, report } from './report.mjs';
import { format, readUsage } from './usage.mjs';

const fx = (n) => new URL(`./fixtures/${n}`, import.meta.url);
const out = report(parse(readFileSync(fx('results.tsv'), 'utf8')));
const has = (s) => assert.ok(out.includes(s), `falta "${s}" en:\n${out}`);

has('Tickets: 4');
has('Gate en ronda 1: 25%');          // solo t-01 pasa en la ronda 1
has('Rondas promedio por ticket: 1.5'); // (1+3+1+1)/4
has('Con reinicio (plateau): 25%');
has('Detenidos: 2');
has('Disputas de check: 1');
has('- test:cart (2 tickets)');       // t-02 y t-03; check-dispute solo en uno
has('Minutos promedio por ticket: 28.5'); // t-01=12, t-02=45
has('Costo promedio por ticket (USD): 2.00'); // t-01=0.5, t-02=3.5

const old = report(parse(readFileSync(fx('results-old.tsv'), 'utf8')));
assert.ok(old.includes('Minutos promedio por ticket: sin datos'));
assert.ok(old.includes('Gate en ronda 1: 100%'));

const cs = (extra) => JSON.stringify({ type: 'cost-state', totalCostUSD: 2, hasUnknownModelCost: false,
    modelUsage: { a: { inputTokens: 10, cacheReadInputTokens: 20, cacheCreationInputTokens: 5, outputTokens: 7 },
                  b: { inputTokens: 1, cacheReadInputTokens: 2, cacheCreationInputTokens: 3, outputTokens: 4 } }, ...extra });
assert.equal(format(readUsage(`{"type":"user"}\n${cs()}\n`)), '41\t11\t2');
assert.equal(format(readUsage(cs()), '31,6,1.5'), '10\t5\t0.5');
assert.equal(format(readUsage(cs({ hasUnknownModelCost: true }))), '\t\t');
assert.equal(format(readUsage('{"type":"user"}\n')), '\t\t');
console.log('todo ok');
