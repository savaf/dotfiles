import type { Register } from 'claude-code'

// Short labels per account email domain; anything else shows the part before "@".
const LABELS: Record<string, string> = { 'gmail.com': 'personal', 'urbn.com': 'ccw' }
const POLL_MS = 10_000

type Quota = { unified5h: number | null; unified7d: number | null }
type Account = { name: string; quota?: Quota }
type Status = { currentAccount?: string; accounts?: Account[] }

const label = (name: string) => LABELS[name.split('@')[1] ?? ''] ?? name.split('@')[0]
const pct = (v: number | null | undefined) => (typeof v === 'number' ? `${Math.round(v * 100)}%` : '--')

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    const base = await $.env.get('ANTHROPIC_BASE_URL')
    // Direct sessions (no proxy) say so, so none shows an account it is not using.
    if (!base || !/:345[67]\/?$/.test(base)) {
      $.ui.status('directo')
    } else {
      const poll = async () => {
        try {
          const res = await $.http.fetch(`${base.replace(/\/$/, '')}/teamclaude/status`)
          const s = JSON.parse(res.text) as Status
          const a = s.accounts?.find(x => x.name === s.currentAccount)
          $.ui.status(a ? `${label(a.name)} · 5h ${pct(a.quota?.unified5h)} · 7d ${pct(a.quota?.unified7d)}` : 'proxy: sin cuenta')
        } catch {
          $.ui.status('proxy off')
        }
      }
      void poll()
      $.clock.every(POLL_MS, () => void poll())
    }
    return next(e)
  })
}
