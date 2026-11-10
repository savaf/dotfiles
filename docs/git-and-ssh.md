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
- **Llaves públicas (una por máquina)**: exporta cada una desde Bitwarden (campo
  *Public key*) a `ssh/.ssh/<hostname>.pub` (`songbird.pub`, `andrea.pub`…) y
  commitéala. El bootstrap crea `~/.ssh/github.pub -> <hostname>.pub`, que usan
  `~/.ssh/config` y `signingkey`. Nunca commitees una llave privada.
- **Firma de commits**: `git/.gitconfig` usa `gpg.format = ssh` con
  `~/.ssh/github.pub`. Registra cada llave en GitHub como *Signing key* y añádela
  a `ssh/.ssh/allowed_signers`. Cada commit pide aprobación en Bitwarden (abierto y
  desbloqueado); sin agente falla. Bypass puntual: `git -c commit.gpgsign=false commit`.
- Máquina nueva: añade `<hostname>.pub` y su línea en `allowed_signers`, reejecuta
  el bootstrap. Tras él, cierra sesión y vuelve a entrar para que uwsm cargue el env.

Comprobar: `echo $SSH_AUTH_SOCK`, `ssh-add -L`, `ssh -T git@github.com`.
