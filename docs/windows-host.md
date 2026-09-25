# Windows host setup

Native Windows apps and Windows Terminal config — the Windows side of a WSL
machine. This is separate from [ubuntu-wsl.md](ubuntu-wsl.md), which covers
the Linux side.

## 1. Prerequisites

- [Git for Windows](https://git-scm.com/download/win)
- `winget` (ships with Windows 11; on Windows 10 install "App Installer"
  from the Microsoft Store)

## 2. Clone and run

From PowerShell:

```powershell
git clone git@github.com:savaf/dotfiles.git ~/dotfiles
cd ~/dotfiles
.\scripts\bootstrap-windows.cmd
```

The `.cmd` launcher runs `bootstrap-windows.ps1` with
`-ExecutionPolicy Bypass` for that one process only, so you don't need
`Set-ExecutionPolicy` (Windows blocks `.ps1` scripts by default).

This installs the apps in [`packages/winget.txt`](../packages/winget.txt) via
`winget`, then symlinks [`windows/settings.json`](../windows/settings.json)
to your Windows Terminal settings. Creating the symlink needs Developer Mode
(Settings → Privacy & security → For developers) or an elevated PowerShell.

Close Windows Terminal completely before running it (or restart it
afterwards). If Terminal is still open and you save anything from its
Settings UI, it writes its old in-memory config over the symlink and turns it
back into a plain file. Re-run the script to relink.

### Default profile

Terminal opens **Ubuntu (WSL)** by default. `windows/settings.json` defines
its own `Ubuntu` profile with a fixed GUID (`wsl.exe -d Ubuntu --cd ~`) and
points `defaultProfile` at it, so it works on any machine without looking up
GUIDs. The auto-generated WSL profiles are turned off with
`disabledProfileSources` so Ubuntu doesn't show up twice. If your distro has
a different name (check with `wsl -l`), change `-d Ubuntu` in that profile.

## 3. What's not automated

- **GlobalProtect** — no public winget package
  ([microsoft/winget-pkgs#188530](https://github.com/microsoft/winget-pkgs/issues/188530)).
  Install from your organization's VPN portal.
- **NVIDIA App** — blocked in winget by a hardware-validation issue
  ([microsoft/winget-pkgs#253660](https://github.com/microsoft/winget-pkgs/issues/253660)).
  Install from [nvidia.com/en-us/software/nvidia-app](https://www.nvidia.com/en-us/software/nvidia-app/).

## Notes

- `windows/` is not a Stow package — Stow doesn't run on Windows. The script
  symlinks it by hand with `New-Item -ItemType SymbolicLink`.
- Re-run `bootstrap-windows.cmd` any time; `winget install` skips apps
  already installed.
