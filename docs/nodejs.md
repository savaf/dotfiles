# Node.js

I use [nvm](https://github.com/nvm-sh/nvm) to manage Node.js versions, so I can
switch versions per project.

> The [bootstrap](../README.md#quick-start-recommended) installs nvm into
> `~/.config/nvm` (the zsh config loads it from there), so on these dotfiles you
> usually don't need to install it by hand.

Manual install (check the latest version on the
[nvm releases](https://github.com/nvm-sh/nvm/releases)):

```sh
export NVM_DIR="$HOME/.config/nvm" && mkdir -p "$NVM_DIR"
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
```

Install and use a Node version:

```sh
nvm install --lts
nvm use --lts
node --version
```

## Global modules

Global npm packages I rely on are tracked in
[`packages/global-node-packages.txt`](../packages/global-node-packages.txt) and
installed by the [bootstrap](../README.md#quick-start-recommended). Install them
manually with:

```sh
xargs npm install -g < packages/global-node-packages.txt
```

Examples:

- **lite-server** — auto-refreshing static file server.
- **http-server** — simple static file server.
- **license** — generate open-source license files.
- **gitignore** — generate `.gitignore` files for the current project type.

## mise alongside nvm

[mise](https://mise.jdx.dev) is also loaded (per-project tools and `[env]` from a
`mise.toml`), but **nvm owns Node**: `MISE_DISABLE_TOOLS=node` makes mise ignore it,
so never put `node` in a `mise.toml`. The installer sets mise up itself (`ensure_mise`
on Ubuntu/Fedora, `install_arch` on Arch/Omarchy, `brew-cli.txt` on macOS).

### CLI tools via mise

Besides per-project config, mise owns the global CLI tools: `mise/.config/mise/config.toml`
(a Stow package) declares the global CLI tools (see the cascade in the [README](../README.md#package-lists)), and the installer
runs `mise install` against it (`ensure_mise_tools`, no sudo). Their shims directory
(`~/.local/share/mise/shims`) is on `PATH` from `path.zsh`/`path.sh`, so they also resolve
outside interactive shells (tmux popups, launchers, scripts). mise downloads from GitHub;
if the anonymous API limit is hit, export `GITHUB_TOKEN` and re-run the bootstrap.
