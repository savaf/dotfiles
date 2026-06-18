# VS Code

My VS Code setup is fully version-controlled, so there's nothing to copy by hand.

## Settings

The single source of truth is [`vscode/settings.json`](../vscode/settings.json).
`scripts/sync-vscode-settings.sh` symlinks it to the OS-specific location:

- **Linux/WSL:** `~/.config/Code/User/settings.json`
- **macOS:** `~/Library/Application Support/Code/User/settings.json`

The [bootstrap](../README.md#quick-start-recommended) runs this automatically.

Highlights: Monaspace Nerd Font, Ayu Dark theme, `vscode-great-icons`, format on
save with Prettier + ESLint, bracket-pair colorization, and a spell checker.

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
