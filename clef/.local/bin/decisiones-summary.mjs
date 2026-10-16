// Pure summary of the shadow-mode log rows, used by decisiones-report.
export function summarize(rows) {
    const lines = [];
    for (const [d, rs] of Object.entries(Object.groupBy(rows, (r) => r.decision))) {
        const count = (fn) => rs.filter(fn).length;
        const opts = Object.entries(Object.groupBy(rs.filter((r) => r.final), (r) => r.final))
            .map(([k, v]) => `${k} ${v.length}`).join(', ');
        lines.push(`${d}: ${rs.length} | motor ${count((r) => r.motor && !r.respaldo)}`
            + ` · respaldo ${count((r) => r.respaldo)} · error ${count((r) => r.error)} | ${opts}`);
        const sug = rs.filter((r) => r.suggested && r.final && r.final !== 'ninguna');
        if (sug.length) lines.push(`  vs frontmatter suggestion: differs in ${sug.filter((r) => r.final !== r.suggested).length}/${sug.length}`);
    }
    return lines;
}
