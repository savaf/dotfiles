# macOS setup

My preferred macOS configuration: system preferences, apps and the terminal.

## System Preferences

Preferred settings for `Users & Groups`, `Desktop`, `Finder`, the `Dock`,
`Trackpad`, the menu bar and Spotlight.

### Users & Groups
- Login Options → change fast user switching menu to Icon.
- Set up password, Apple ID, picture, etc.

### Desktop
Disable Stage Manager and Desktop widgets:

- System Settings → Desktop & Dock → Desktop & Stage Manager
  - Show Items: On Desktop → off; In Stage Manager → off
  - Click wallpaper to reveal desktop → Only in Stage Manager
  - Stage Manager → off
  - Widgets: On Desktop → off; In Stage Manager → off

### Finder
- Appearance → Accent Color → Purple; Highlight → Yellow.
- Finder → Settings
  - General → Show these on the desktop → none (keep the desktop clean).
  - General → New Finder windows show → Home folder.
  - Advanced → Show all filename extensions → on.
  - Advanced → Show warning before changing an extension → off.
  - Advanced → When performing a search → Search the current folder.
  - Sidebar → uncheck Movies, Music, Tags, Pictures, iCloud, Airdrop.
- View → Show Status Bar, Show Path Bar, Show Tab Bar, change view to List.
- Toolbar → remove Tags, Groups and Actions; add Airdrop.

### Dock
I keep the Dock tiny and auto-hidden (Raycast launches apps, AltTab switches them):

- System Settings → Desktop & Dock
  - Size → as small as possible
  - Automatically hide and show the Dock → on
  - Animate opening applications → off
  - Show suggested and recent apps in the Dock → off

Disable workspace auto-switching:

```sh
defaults write com.apple.dock workspaces-auto-swoosh -bool NO
killall Dock
```

### Trackpad
- Point & Click → enable Tap to click; Secondary click → right corner; disable Three Finger Drag.
- Scroll & Zoom → keep only Zoom in/out.

### Menu bar / Control Center
- Remove Display, Bluetooth, Battery and Spotlight icons.
- Use a minimal clock (Analog icon).

### Spotlight
- Uncheck fonts, images, files, etc.
- Disable its keyboard shortcut (replaced by Raycast).

### User Defaults
Enable key repeat by holding a key:

```sh
defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false
```

Change the screenshots folder:

```sh
mkdir -p /path/to/screenshots/
defaults write com.apple.screencapture location /path/to/screenshots/ && killall SystemUIServer
```

Remap Caps Lock → Escape (applied by `scripts/apply-macos-defaults.sh` via `hidutil`,
persisted with a `~/Library/LaunchAgents/com.dotfiles.capslock-escape.plist` LaunchAgent):

```sh
hidutil property --set '{"UserKeyMapping":[{"HIDKeyboardModifierMappingSrc":0x700000039,"HIDKeyboardModifierMappingDst":0x700000029}]}'
```

## Xcode command line tools

Many developer tools need these:

```sh
xcode-select --install
```

## Homebrew

[Homebrew](https://brew.sh/) installs CLI tools and apps:

```sh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

The package lists for this setup live in [`packages/`](../packages); the
[bootstrap](../README.md#quick-start-recommended) installs from them automatically.

## Apps

### Quick launching — Raycast
Replaces Spotlight with a faster launcher (and a built-in window manager):

```sh
brew install raycast
```

Also install the [Raycast Homebrew plugin](https://www.raycast.com/nhojb/brew)
to install formulae/casks directly from Raycast.

### Window management — Rectangle
Move/resize windows with keyboard shortcuts:

```sh
brew install rectangle
```

### App switching — AltTab
Full window previews; replace the built-in `⌘+Tab`:

```sh
brew install alt-tab
```

### Menu bar utilities
- **Hidden Bar** — hide menu bar icons: `brew install hiddenbar`
- **Stats** — CPU/RAM/network in the menu bar: `brew install stats`
- **Itsycal** — menu bar calendar: `brew install itsycal`
  (then hide the system clock date: System Settings → Control Center → Clock).

### Docker Desktop

```sh
brew install --cask docker
```

### Other apps I use daily
Installed as casks (see [`packages/brew-casks.txt`](../packages/brew-casks.txt)):
Brave/Chrome, Discord, Slack, Telegram, WhatsApp, Notion, VLC, Keka, Kap,
Figma, iTerm2, Monaspace Nerd Font, quicklook plugins, and more.

```sh
xargs brew install --cask < packages/brew-casks.txt
```

## Terminal — iTerm2

I use [iTerm2](https://iterm2.com/) for its customization, clickable links and
native notifications:

```sh
brew install iterm2
```

Preferred settings:

- Appearance → Theme → Minimal
- Profiles → Default
  - General → Working Directory → Reuse previous session's directory
  - Colors → Foreground → Lime Green
  - Text → Font → MonaspiceAr Nerd Font (download from [Nerd Fonts](https://www.nerdfonts.com/)), size 16
  - Keys → Key Mappings → Presets → Natural Text Editing

For the shell, prompt and dotfiles, see [shell-and-dotfiles.md](shell-and-dotfiles.md).
