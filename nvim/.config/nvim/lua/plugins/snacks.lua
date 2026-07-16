-- Mostrar archivos ocultos (.dotfiles) por defecto en el explorador (<leader>e) y
-- en el buscador (snacks picker, el finder por defecto de LazyVim). Se deja `ignored`
-- en su default para no inundar con node_modules/.git; dentro del picker/explorer se
-- alterna en caliente con H (hidden) / I (ignored), o <a-h>/<a-i> en el buscador.
return {
  "folke/snacks.nvim",
  opts = {
    picker = {
      sources = {
        explorer = { hidden = true },
        files = { hidden = true },
        grep = { hidden = true },
      },
    },
  },
}
