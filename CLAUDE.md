# CLAUDE.md

Dotfiles multiplataforma (Ubuntu/WSL, Fedora/Bazzite, Arch/Omarchy, macOS) gestionados como
paquetes de [GNU Stow](https://www.gnu.org/software/stow/).

Este archivo es solo un **índice**. La documentación real vive en `README.md` y `docs/`; no
la dupliques aquí. Antes de cambiar algo, lee lo que corresponda en lugar de re-escanear el
repo entero.

## Empieza por aquí

**`README.md`** ya cubre: estructura del repo, cómo enlaza Stow, el flujo de
`scripts/bootstrap.sh`, los package lists (`packages/*.txt`) y las notas por plataforma.

## Qué leer según la tarea

| Si vas a tocar… | Lee |
|---|---|
| Estructura del repo / aplicar dotfiles con Stow | `docs/shell-and-dotfiles.md` |
| zsh, prompt, aliases o funciones | `docs/shell-and-dotfiles.md` + `zsh/.config/zsh/*.zsh` |
| nvim (LazyVim) | `docs/nvim.md` |
| tmux | `docs/tmux.md` |
| git / ssh | `docs/git-and-ssh.md` |
| lazygit | `docs/lazygit.md` |
| VS Code | `docs/vscode.md` |
| Node.js | `docs/nodejs.md` |
| Setup de una plataforma concreta | `docs/{ubuntu-wsl,bazzite,omarchy,macos-setup}.md` |

## Dónde editar

- **Config de una herramienta**: su paquete Stow, espejando la ruta de `$HOME`
  (p.ej. `tmux/.config/tmux/tmux.conf`, `git/.gitconfig`).
- **zsh** (modular): `zsh/.zshrc` es un loader delgado que carga `zsh/.config/zsh/*.zsh`
  (`exports`, `path`, `plugins`, `completion`, `history`, `keybindings`, `aliases`,
  `functions`, `integrations`).
- **Instalación / enlazado**: `scripts/bootstrap.sh` y los manifiestos `packages/*.txt`.

## Añadir un paquete Stow nuevo

1. Crea `<tool>/` espejando la estructura de `$HOME` (p.ej. `<tool>/.config/<tool>/...`).
2. Añádelo al array `STOW_PACKAGES` en `scripts/bootstrap.sh` para que se auto-enlace.
3. Si trae paquetes que instalar, añádelos a los manifiestos `packages/*.txt` por gestor.

## Notas

- `.claude/` está en `.gitignore` (estado local de sesión; no se versiona).
- Mantén este archivo corto: es un índice, no un espejo de la documentación.
