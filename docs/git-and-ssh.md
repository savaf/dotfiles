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
- **Llaves públicas (una por máquina)**: cada equipo tiene su propia llave en Bitwarden.
  Exporta su *Public key* a `ssh/.ssh/<hostname>.pub` (`andrea.pub`, `songbird.pub`) y
  commitéala; añade también la llave a `ssh/.ssh/allowed_signers`. El bootstrap enlaza
  `~/.ssh/github.pub` -> `~/.ssh/<hostname>.pub`, y tanto `ssh/.ssh/config` como
  `git/.gitconfig` usan `github.pub`, así que no hay overrides por máquina. Nunca commitees
  una llave privada. Las `.pub` quedan en 600 (OpenSSH 10 rechaza 644).
- **Firma de commits**: `git/.gitconfig` usa `gpg.format = ssh` con `~/.ssh/github.pub`
  (la llave de la máquina). Registra cada llave en GitHub como *Authentication key* y como
  *Signing key*. Cada commit pide aprobación en Bitwarden (abierto y desbloqueado).
- Tras el bootstrap, cierra sesión y vuelve a entrar para que uwsm cargue el env.

### Alta de máquina nueva

1. En Bitwarden crea (o reutiliza) la llave SSH de la máquina y copia su campo *Public key*.
2. Guárdala en `ssh/.ssh/$(hostname -s).pub` (una sola línea; solo la pública).
3. Añade su línea a `ssh/.ssh/allowed_signers`:
   `10409334+savaf@users.noreply.github.com namespaces="git" <tipo> <clave>`.
4. Regístrala en GitHub como *Authentication key* y como *Signing key*.
5. Reejecuta `scripts/bootstrap.sh`; luego cierra sesión y vuelve a entrar (uwsm carga el env).
6. Comprueba que `scripts/test-ssh-key.sh` (parte de `bash scripts/ci.sh`) sigue en verde: falla si
   alguna `.pub` versionada no está en `allowed_signers`.

### Si algo falla

| Síntoma | Causa probable |
|---|---|
| `Couldn't load public key …/github.pub` o `failed to write commit object` | `~/.ssh/github.pub` apunta a un `.pub` inexistente (falta `ssh/.ssh/<hostname>.pub`, o el enlace quedó viejo): añade el `.pub` y reejecuta el bootstrap |
| El bootstrap avisa `Falta ssh/.ssh/<host>.pub` | El hostname (`hostname -s`) no coincide con ningún `.pub` versionado |
| El bootstrap avisa que `github.pub` es un archivo real | Hay un archivo suelto en `~/.ssh/github.pub`; el bootstrap no lo pisa: bórralo o muévelo y reejecuta |
| `Load key … agent refused operation` / `incorrect passphrase` / sin respuesta al firmar | Bitwarden cerrado o bloqueado, o `SSH_AUTH_SOCK` no apunta a `~/.bitwarden-ssh-agent.sock` (`echo $SSH_AUTH_SOCK`, `ssh-add -L`) |
| Commit firmado pero GitHub no muestra *Verified* | La llave no está registrada como *Signing key*, o el correo del commit no es el noreply |
| `git log --show-signature` dice `No principal matched` | Falta la llave en `ssh/.ssh/allowed_signers` |

Sin agente disponible, bypass puntual: `git -c commit.gpgsign=false commit`.

Comprobar: `echo $SSH_AUTH_SOCK`, `ssh-add -L`, `ssh -T git@github.com`.
