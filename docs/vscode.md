# VS Code

My VS Code setup is fully version-controlled, so there's nothing to copy by hand.

## Settings

The single source of truth is [`vscode/settings.json`](../vscode/settings.json).
`scripts/sync-vscode-settings.sh` symlinks it to the OS-specific location:

- **Linux/WSL:** `~/.config/Code/User/settings.json`
- **macOS:** `~/Library/Application Support/Code/User/settings.json`

The [bootstrap](../README.md#quick-start-recommended) runs this automatically.

Highlights: Monaspace Nerd Font, `vscode-great-icons`, format on save with Prettier +
ESLint, bracket-pair colorization, and a spell checker.

### `workbench.colorTheme` lo gestiona Omarchy

En Arch/Omarchy, `omarchy-theme-set-vscode` reescribe esa clave en cada cambio de tema
usando `sed -i --follow-symlinks`, así que **escribe a través del symlink, dentro de este
repo**. Es el comportamiento deseado (VS Code sigue al tema del escritorio), con dos
consecuencias que conviene tener presentes:

- Los commits "omarchy update" que solo tocan esa línea son **esperados**, no un accidente.
- El nombre del tema viaja al resto de plataformas, donde esa extensión puede no estar
  instalada; VS Code caerá entonces a su tema por defecto.

Para desactivarlo en esta máquina: `omarchy-toggle skip-vscode-theme-changes on`.

## Extensions

The extension list lives in
[`packages/vs-extensions.txt`](../packages/vs-extensions.txt) and is installed by
`scripts/install-vscode-extensions.sh` (run by the bootstrap). Install or refresh
manually:

```sh
# install all
cat packages/vs-extensions.txt | xargs -L1 code --install-extension

# export your current extensions back into the list
code --list-extensions > packages/vs-extensions.txt
```
