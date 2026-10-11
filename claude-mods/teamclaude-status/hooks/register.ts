import type { Register } from 'claude-code'

// Short labels per account email domain; anything else shows the part before "@".
const LABELS: Record<string, string> = { 'gmail.com': 'personal', 'urbn.com': 'ccw' }
const POLL_MS = 10_000

type Account = { name: string }
type Status = { currentAccount?: string; accounts?: Account[] }

const label = (name: string) => LABELS[name.split('@')[1] ?? ''] ?? name.split('@')[0]

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    const base = await $.env.get('ANTHROPIC_BASE_URL')
    // Solo sesiones por el proxy; la barra de estado la dibuja statusline.sh.
    if (base && /:345[67]\/?$/.test(base)) {
      let last: string | undefined
      const poll = async () => {
        try {
          const res = await $.http.fetch(`${base.replace(/\/$/, '')}/teamclaude/status`)
          const s = JSON.parse(res.text) as Status
          const a = s.accounts?.find(x => x.name === s.currentAccount)
          // Failover: avisa cuando el proxy cambia de cuenta (el tráfico pasa a otra org).
          if (a && last && last !== a.name) $.ui.toast(`Proxy: ahora usando ${label(a.name)}`)
          last = a?.name
        } catch {
          // proxy caído: statusline.sh ya lo muestra; aquí no hay nada que avisar
        }
      }
      void poll()
      $.clock.every(POLL_MS, () => void poll())
    }
    return next(e)
  })
}
