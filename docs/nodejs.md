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
