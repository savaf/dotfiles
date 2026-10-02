-- Mostrar archivos ocultos (.dotfiles) por defecto en el explorador (<leader>e) y
-- en el buscador (snacks picker, el finder por defecto de LazyVim). Dentro del
-- picker/explorer se alterna en caliente con H (hidden) / I (ignored), o <a-h>/<a-i>.
--
-- `include` (solo explorer) tiene prioridad sobre hidden/ignored: los .env locales
-- (gitignored) se ven siempre sin abrir el resto de lo ignorado.
-- fd/rg no tienen "incluir solo estos ignorados", así que en files/grep se muestran
-- los ignorados (`ignored = true`) y se excluye el ruido a mano en `noise`.
local noise = {
  "node_modules", ".git", "dist", "build", ".next", ".nuxt", "coverage",
  ".cache", ".venv", "__pycache__", ".turbo", ".pnpm-store",
}

return {
  "folke/snacks.nvim",
  opts = {
    picker = {
      sources = {
        explorer = { hidden = true, include = { ".env.local", ".env.build.local" } },
        files = { hidden = true, ignored = true, exclude = noise },
        grep = { hidden = true, ignored = true, exclude = noise },
      },
    },
  },
}
