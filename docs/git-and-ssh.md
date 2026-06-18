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
