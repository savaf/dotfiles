# Git & SSH

Git defaults live in [`git/.gitconfig`](../git/.gitconfig) (aliases,
`pull.rebase = true`, `push.autoSetupRemote`, `nvim` as editor, etc.). For a TUI
on top of git, see [lazygit.md](lazygit.md).

## GitHub SSH setup

Generate a key and add it to GitHub for SSH auth over Git.

> [!NOTE]
> GitHub dropped older insecure key types (DSA) in 2022. Use Ed25519.

### 1. Generate a new SSH key

```sh
ssh-keygen -t ed25519 -C "your_email@example.com"
```

If your system can't use Ed25519, fall back to RSA:

```sh
ssh-keygen -t rsa -b 4096 -C "your_email@example.com"
```

Press Enter to accept the default path (`~/.ssh/id_ed25519`) and set a
passphrase when prompted. See
[Working with SSH key passphrases](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/working-with-ssh-key-passphrases).

### 2. Add the key to the ssh-agent

```sh
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519
```

> Depending on your environment you may need `exec ssh-agent zsh` first.

### 3. Add the public key to GitHub

Copy the public key and add it under GitHub → Settings → SSH and GPG keys. See
[Adding a new SSH key to your GitHub account](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/adding-a-new-ssh-key-to-your-github-account).

```sh
cat ~/.ssh/id_ed25519.pub      # copy this
```

### 4. Test the connection

```sh
ssh -T git@github.com
```

## Bitwarden SSH agent (Omarchy)

Las llaves SSH viven solo en el vault de Bitwarden; nunca en disco. El agente del
escritorio (`pacman -S bitwarden`, binario `bitwarden-desktop`) crea el socket
`$HOME/.bitwarden-ssh-agent.sock`.

- **`SSH_AUTH_SOCK`**: una sola definición, en `omarchy/.config/uwsm/env`
  (→ `~/.config/uwsm/env`), para que la vean también las apps gráficas. No la
  redefinas en `.bashrc`/`.zshrc`: una ruta distinta pisa la correcta.
- **Autostart**: `omarchy/.config/hypr/autostart.lua` lanza `bitwarden-desktop`.
  Hyprland usa la config Lua; un `autostart.conf` se ignora.
- **`~/.ssh/config`** (paquete `ssh`): cada `Host` apunta a la llave **pública**
  con `IdentitiesOnly yes`, así el agente ofrece solo esa llave.
- **Llaves públicas**: exporta `github.pub` desde Bitwarden (campo *Public key*) a
  `ssh/.ssh/github.pub` y commitéala. Nunca commitees una llave privada.
- **Firma de commits**: `git/.gitconfig` usa `gpg.format = ssh` con
  `~/.ssh/github.pub`. Registra la misma llave en GitHub como *Signing key*.
  Cada commit pide aprobación en Bitwarden (abierto y desbloqueado).
- Tras el bootstrap, cierra sesión y vuelve a entrar para que uwsm cargue el env.

Comprobar: `echo $SSH_AUTH_SOCK`, `ssh-add -L`, `ssh -T git@github.com`.
