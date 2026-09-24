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
.\scripts\bootstrap-windows.ps1
```

This installs the apps in [`packages/winget.txt`](../packages/winget.txt) via
`winget`, then symlinks [`windows/settings.json`](../windows/settings.json)
to your Windows Terminal settings. Creating the symlink needs Developer Mode
(Settings → Privacy & security → For developers) or an elevated PowerShell.

## 3. What's not automated

- **GlobalProtect** — no public winget package
  ([microsoft/winget-pkgs#188530](https://github.com/microsoft/winget-pkgs/issues/188530)).
  Install from your organization's VPN portal.
- **NVIDIA App** — blocked in winget by a hardware-validation issue
  ([microsoft/winget-pkgs#253660](https://github.com/microsoft/winget-pkgs/issues/253660)).
  Install from [nvidia.com/en-us/software/nvidia-app](https://www.nvidia.com/en-us/software/nvidia-app/).
- **`defaultProfile`** in `windows/settings.json` — commented out; the GUID
  is generated per machine. Set it from Windows Terminal Settings (Ctrl+,) →
  your Ubuntu profile → "Open JSON file".

## Notes

- `windows/` is not a Stow package — Stow doesn't run on Windows. The script
  symlinks it by hand with `New-Item -ItemType SymbolicLink`.
- Re-run `bootstrap-windows.ps1` any time; `winget install` skips apps
  already installed.
