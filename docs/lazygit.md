# lazygit

[lazygit](https://github.com/jesseduffield/lazygit) es una interfaz de terminal
(TUI) para git: hace las operaciones del día a día más rápidas y visuales sin
tener que memorizar flags.

## Por qué usarlo

- **Stage por archivo, hunk o línea** viendo el diff al lado.
- **Commit, amend, squash, fixup y rebase interactivo** con una tecla.
- **Branches, stash, cherry-pick y resolución de conflictos** de forma visual.
- **Push / pull / fetch** y navegación del log/gráfico de commits.
- **Undo / redo** de acciones de git (`z` / `Z`): experimenta sin miedo.
- Complementa (no reemplaza) tus aliases: `git lg`, `glog`, `stat`, etc.

## Instalación

Ya está integrado en estos dotfiles:

- **macOS:** se instala vía Homebrew (`packages/brew-cli.txt`).
- **Ubuntu/WSL:** `scripts/install-packages.sh` lo instala (apt o, si no está,
  el binario del último release de GitHub).

Instalación manual rápida:

```sh
brew install lazygit                 # macOS / linuxbrew
sudo apt install lazygit             # Ubuntu (si está disponible)
```

## Cómo lanzarlo

```sh
lzg        # alias de 'lazygit' (definido en zsh/.config/zsh/aliases.zsh)
lazygit    # comando completo
```

Ábrelo dentro de cualquier repositorio git. Pulsa `?` en cualquier momento para
ver la ayuda contextual del panel actual, y `q` para salir.

## Navegación

| Tecla | Acción |
|-------|--------|
| `1`–`5` | Saltar a un panel (Status, Files, Branches, Commits, Stash) |
| `tab` | Cambiar de panel / pestaña |
| `←` `→` `↑` `↓` o `h j k l` | Moverse |
| `[` `]` | Cambiar de subpestaña |
| `?` | Ayuda con todos los atajos del panel actual |
| `+` / `_` | Maximizar / restaurar el panel |
| `q` | Salir |

## Acciones básicas (panel Files)

| Tecla | Acción |
|-------|--------|
| `espacio` | Stage / unstage del archivo |
| `enter` | Entrar al archivo para stage por **línea/hunk** |
| `a` | Stage / unstage de **todo** |
| `c` | Commit |
| `C` | Commit usando el editor (`nvim`) |
| `A` | Amend al último commit |
| `d` | Descartar cambios (con confirmación) |
| `e` | Editar el archivo |
| `s` | Stash de los cambios |
| `` ` `` | Alternar vista en árbol / lista |

En el modo de stage por líneas: `espacio` selecciona la línea, `v` selecciona un
rango, `a` selecciona el hunk completo, `esc` vuelve.

## Branches, commits y remoto

| Tecla | Panel | Acción |
|-------|-------|--------|
| `n` | Branches | Nueva rama |
| `espacio` | Branches | Checkout de la rama |
| `M` | Branches | Merge en la rama actual |
| `r` | Branches | Rebase de la rama actual sobre la seleccionada |
| `d` | Branches | Borrar rama |
| `P` | (global) | Push |
| `p` | (global) | Pull |
| `f` | (global) | Fetch |
| `z` / `Z` | (global) | Undo / redo |

## Flujos útiles

- **Squash / fixup:** en el panel Commits, sitúate sobre un commit y usa `s`
  (squash hacia abajo) o `f` (fixup). Reordena commits con `ctrl-j` / `ctrl-k`.
- **Rebase interactivo:** `e` sobre un commit para iniciar un rebase interactivo;
  marca commits con `e` (edit), `d` (drop), `r` (reword), etc. Continúa con `m`.
- **Resolver conflictos:** durante un merge/rebase, los archivos en conflicto
  aparecen en Files; `enter` para elegir los bloques a conservar.
- **Editar el último commit:** `A` en Files para hacer amend rápidamente.
- **Mover/recuperar trabajo:** `z` deshace la última acción de git si te equivocas.

## Configuración

La configuración versionada vive en este repo:

```
lazygit/.config/lazygit/config.yml
```

- **Linux/WSL:** se enlaza con `stow lazygit` a `~/.config/lazygit/config.yml`.
- **macOS:** `scripts/bootstrap.sh` la enlaza a
  `~/Library/Application Support/lazygit/config.yml`.

Para ver dónde busca lazygit su config: `lazygit --print-config-dir`.

## Referencias

- Repositorio: <https://github.com/jesseduffield/lazygit>
- Opciones de config: <https://github.com/jesseduffield/lazygit/blob/master/docs/Config.md>
- Keybindings completos: <https://github.com/jesseduffield/lazygit/blob/master/docs/keybindings/Keybindings_en.md>
