-- Mostrar archivos ocultos (.dotfiles) en el buscador (snacks picker, el finder
-- por defecto de LazyVim). Se deja `ignored` en su default para no inundar con
-- node_modules/.git; dentro del picker se alterna con <a-h> (hidden)/<a-i> (ignored).
return {
  "folke/snacks.nvim",
  opts = {
    picker = {
      sources = {
        files = { hidden = true },
        grep = { hidden = true },
      },
    },
  },
}
