# My PC Setup Guide

This guide covers the basics of setting up a development environment on a new PC. Whether you are an experienced programmer or not, this guide is intended for everyone to use as a reference for setting up your environment or installing languages/libraries.

Some environments we will set up are Node (JavaScript) and Dart. Even if you don't program in all of them, they are useful to have as many command-line tools rely on them. We'll also show you some useful daily use applications. As you read and follow these steps, feel free to post any feedback or comments you may have.

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->

- [My PC Setup Guide](#my-pc-setup-guide)
  - [What setup PC do I have?](#what-setup-pc-do-i-have)
  - [Mac OS System Preferences](#mac-os-system-preferences)
    - [Users \& Groups](#users--groups)
    - [Desktop](#desktop)
    - [Finder](#finder)
    - [Dock](#dock)
    - [Trackpad](#trackpad)
    - [Menubar](#menubar)
    - [Spotlight](#spotlight)
    - [Accounts](#accounts)
    - [User Defaults](#user-defaults)
  - [Quick Launching](#quick-launching)
  - [Homebrew](#homebrew)
    - [RayCast Homebrew Plugin](#raycast-homebrew-plugin)
  - [Window Management](#window-management)
  - [App Switching](#app-switching)
  - [Menu Bar Utilities](#menu-bar-utilities)
    - [Hidden Bar](#hidden-bar)
    - [System Stats Widgets](#system-stats-widgets)
    - [Menu Bar Calendar](#menu-bar-calendar)
  - [Other Apps I Use Daily](#other-apps-i-use-daily)
    - [Docker](#docker)
  - [Terminal](#terminal)
    - [Shell](#shell)
    - [zsh](#zsh)
      - [Load dotfiles](#load-dotfiles)
    - [Github SSH Setup](#github-ssh-setup)
      - [Other command line tools I use](#other-command-line-tools-i-use)
  - [Node.js](#nodejs)
    - [Global Modules](#global-modules)
  - [VS Code](#vs-code)
- [My dotfies](#my-dotfies)
  - [Requirements](#requirements)
    - [Git](#git)
    - [Stow](#stow)
  - [Installation](#installation)
  - [Install desktop apps](#install-desktop-apps)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->


## What setup PC do I have?

- Laptop: Macbook M1 Pro 2021 | 16" | Ram 16GB
- Case: Corsair 4000D Airflow
- Motherboard: MSI MPG Z690 FORCE WIFI ATX LGA1700
- CPUI: Intel Core i7-12700K 3.6 GHz
- CPU: ZOTAC Gaming GeForce RTX™ 3080 Trinity OC White Edition LHR 10GB
- RAM: Corsair Dominator Platinum RGB 64 GB (4 x 16 GB) DDR5-5200
- Cooling: NZXT Kraken Z73 RGB 52.44 CFM Liquid CPU Cooler
- Storage: WD Black SN850 500 GB M.2-2280 NVME | WD Black SN850 1 TB M.2-2280 NVME | 2 Samsung M.2 980 PRO 2TB PCIe NVMe Gen4
- Mouse: Logitech G Mouse 305 LIGHTSPEED
- Keyboard: Keychron K2


## Mac OS System Preferences

These are my preferred settings for  `Users & Groups`, `Trackpad`, `Desktop`, `Finder`, the `Dock`.

### Users & Groups
* Login Options -> Change fast user switching menu as Icon
* Set up Password, Apple ID, Picture, etc.

### Desktop
I don't like the new Desktop, Stage Manager or Widget features in Sonoma, so I disable them.

* System Preferences
  * Desktop & Dock
    * Desktop & Stage Manager
      * Show Items
        * On Desktop -> uncheck
        * In Stage Manager -> uncheck
      * Click wallpaper to reveal desktop -> Only in Stage Manager
      * Stage Manager -> uncheck
      * Widgets
        * On Desktop -> uncheck
        * In Stage Manager -> uncheck

### Finder

* Finder -> Preferences
  * General -> Show these on the desktop -> Select None
      * I try to keep my desktop completely clean.
  * General -> New Finder windows show -> Home Folder
      * I prefer to see my home folder in each new finder window instead of recent documents
  * Advanced -> Show all filename extensions -> Yes
  * Advanced -> Show warning before changing an extension -> No
  * Advanced -> When performing a search -> Search the current folder
  * Sidebar -> uncheck Movies, Music, Tags, Pictures, None of iCloud Stuff, Airdrop
* View
  * Show Status Bar
  * Show Path Bar
  * Show Tab Bar
  * Change view to List
* Change the toolbar -> remove Tags, Groups, add Airdrop and edit share options

### Dock

I don't use the Dock at all. It takes up screen space, and I can use RayCast to launch apps and AltTab to switch between apps. I make the dock as small as possible and auto hide it.

* System Preferences
  * Desktop & Dock
    * Size -> Small as possible
    * Automatically hide and show the Dock -> Yes
    * Animate opening applications -> No
    * Show suggested and recent apps in the Dock -> No
    * Other settings
      * Remove workspace auto-switching by running the following command:
```
defaults write com.apple.dock workspaces-auto-swoosh -bool NO
killall Dock # Restart the Dock process
```

### Trackpad
- Point & Click
  - Enable Tap to click with one finger
  - Change Secondary click to Right corner
  - Uncheck Three Finger Drag
- Scroll & Zoom
  - Uncheck all apart from Zoom in and out

### Menubar
- Remove the Display and Bluetooth, Battery icons
- Change clock minimal size

### Spotlight
- Uncheck fonts, images, files etc.
- Uncheck the keyboard shortcuts as we'll be replacing them with Alfred or RayCast

### Accounts
- Add an iCloud account and sync Calendar, Find my Mac, Contacts etc.

### User Defaults
- Enable repeating keys by pressing and holding down keys: `defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false` (and restart any app that you need to repeat keys in)
- Change the default folder for screenshots
Open the terminal and create the folder where you would like to store your screenshots: `mkdir -p /path/to/screenshots/`
Then run the following command: `defaults write com.apple.screencapture location /path/to/screenshots/ && killall SystemUIServer`

## Quick Launching

The built in spotlight search is a bit slow for me and usually has web search results as the default instead of apps or folders on my machine.

I recently switched from [Alfred](https://www.alfredapp.com/) to [RayCast](https://www.raycast.com/). I'm really liking it so far.

```sh
brew install raycast
```

## Homebrew

[Homebrew](https://brew.sh/) allows us to install tools and apps from the command line.

To install it, open up the built in `Terminal` app and run this command:

```sh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

This will also install the xcode build tools which is needed by many other developer tools.

After Homebrew is done installing, we will use it (via RayCast) to install everything else we need.


### RayCast Homebrew Plugin

Install the [RayCast Homebrew Plugin](https://www.raycast.com/nhojb/brew) so we can easily install formulae and casks directly from RayCast.

## Window Management

I know this feature is built in to a lot of other operating systems, but it is not built in to a Mac, so we need an app for it.

RayCast has this feature built in, but I am still using a separate app for this.

I use [rectangle](https://rectangleapp.com/) to move and resize windows using keyboard shortcuts. I used to use [spectacle](https://www.spectacleapp.com/), but rectangle is more regularly maintained and allows me to use all of the same keyboard shortcuts as spectacle.

I highly recommend installing this and memorizing the keyboard shortcuts. Fluid and seamless window management is key to being productive while coding.

Search for `rectangle` in RayCast `brew search` or:

```
brew install rectangle
```

## App Switching

The built in App switcher only shows application icons, and only shows 1 icon per app regardless of how many windows you have open in that app.

I use an app switcher called [AltTab](https://alt-tab-macos.netlify.app/). It shows full window previews, and has an option to show a preview for every open window in all applications (even minimized ones).

I replace the built-in `CMD+TAB` shortcut with AltTab.

Search for `alt-tab` in RayCast `brew search` or:

```sh
brew install alt-tab
```

## Menu Bar Utilities

### Hidden Bar

If you have several apps running that have menu bar icons, [Hidden Bar](https://github.com/dwarvesf/hidden) will let you choose which ones should be hidden after a timeout. This cleans things up if you have a ton of background apps running.

Search for `hiddenbar` in RayCast `brew search` or:

```sh
brew install hiddenbar
```

### System Stats Widgets

I use [stats](https://github.com/exelban/stats) to see my network traffic, CPU temp / usage and RAM usage at a glance.

In each widget, a key setting to look for is under "widget settings", choose "merge widgets into one".

Search for `stats` in RayCast `brew search` or:

```sh
brew install stats
```

### Menu Bar Calendar

I like to have a calendar in the menu bar that I can quickly look at. stats does not include one, so I found [itsycal](https://www.mowglii.com/itsycal/).

```sh
brew install itsycal
```

itsycal shows the date, so I hide the date in the system menu bar widget:

* System Preferences
  * Dock & Menu Bar
      * Clock
          * Show Date -> Never
          * Show Day of Week -> No

## Other Apps I Use Daily

* android-file-transfer - Transfer files to / from my android phone
* android-platform-tools - Installs `adb` without the need for the full android studio.
* [keepingyouawake](https://keepingyouawake.app/) - Prevents my Mac from going to sleep when I'm presenting / live streaming
* [discord](https://discord.com/) - Messaging / Community
* [vlc](https://www.videolan.org/) - I use VLC to watch videos instead of the built in QuickTime.
* [keka](https://www.keka.io/en/) - Can extract 7z / rar and other types of archives
* [kap](https://getkap.co/) - Screen recorder / gif maker
* [figma](https://www.figma.com/) - Image editor
* [visual-studio-code](https://code.visualstudio.com/) - Code Editor
* 

You can install them in one go by placing them all into a text file and then running brew install:

```
android-file-transfer
android-platform-tools
keepingyouawake
discord
slack
vlc
keka
kap
time-out
figma
visual-studio-code
sublime-text
insomnia
```

```sh
xargs brew install < apps.txt
```

### Docker

There are multiple results when you search `docker` within `brew`. To install Docker desktop:

```sh
brew install --cask docker
```

## Terminal

I prefer [iTerm2](https://iterm2.com/) because:
* Lots of customization options
* Clickable links
* Native OS notifications

There are a lot of options for a terminal replacement, but I've been using iTerm2 for years and it works great for my needs.

Checkout their documentation for more info on what iTerm2 can do: [https://iterm2.com/documentation.html](https://iterm2.com/documentation.html)


```
brew install iterm2
```

Once installed, launch it and customize the settings / preferences to your liking. These are my preferred settings:

* Appearance
  * Theme
    * Minimal
* Profiles
  * Default
      * General -> Working Directory -> Reuse previous session's directory
      * Colors -> Basic Colors -> Foreground -> Lime Green
      * Text -> Font -> MonaspiceAr Nerd Font
          * You can download this font [here](https://www.nerdfonts.com/).
          * I use this font in VS Code as well
      * Text -> Font Size -> 16
      * Keys -> Key Mappings -> Presets -> Natural Text Editing
          * This allows me to use the [keyboard shortcuts](https://gist.github.com/w3cj/022081eda22081b82c52) I know and love inside of iTerm2

### Shell

Mac now comes with `zsh` as the default [shell](https://en.wikipedia.org/wiki/Comparison_of_command_shells). I've switched to using this with [Oh My Zsh](https://ohmyz.sh/).

### zsh
The Z shell (also known as zsh) is a Unix shell that is built on top of bash (the default shell for macOS) with additional features. It's recommended to use zsh over bash. It's also highly recommended to install a framework with zsh as it makes dealing with configuration, plugins and themes a lot nicer.

We've also included an env.sh file where we store our aliases, exports, path changes etc. We put this in a separate file to not pollute our main configuration file too much. This file is found in the bottom of this page.

Install zsh using Homebrew:
```
brew install zsh
```
The configuration file for `zsh` is called `.zshrc` and lives in your home folder (`~/.zshrc`).

Change shell to zsh
```
chsh -s $(which zsh)
```

#### Load dotfiles

All my dotfiles are stored on [github](https://github.com/w3cj/dotfiles).

I clone this repo to my machine and copy the files into my home directory.

### Github SSH Setup

* Follow [this guide](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent) to setup an ssh key for github
* Follow [this guide](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/adding-a-new-ssh-key-to-your-github-account) to add the ssh key to your github account

#### Other command line tools I use

* [ffmpeg](https://en.wikipedia.org/wiki/FFmpeg) - edit videos from the command line
* [imagemagick](https://en.wikipedia.org/wiki/ImageMagick) - edit images from the command line

```sh
brew install ffmpeg
brew install imagemagick
```

## Node.js

I use nvm to manage the installed versions of Node.js on my machine. This allows me to easily switch between Node.js versions depending on the project I'm working in.

See installation instructions [here](https://github.com/nvm-sh/nvm#installing-and-updating).

OR run this command (make sure v0.39.7 is still the latest)

```sh
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
```

Now that nvm is installed, you can install a specific version of node.js and use it:

```sh
nvm install 20
nvm use 20
node --version
```

### Global Modules

There are a few global node modules I use a lot:

* lite-server
  * Auto refreshing static file server. Great for working on static apps with no build tools.
* http-server
  * Simple static file server.
* license
  * Auto generate open source license files
* gitignore
  * Auto generate `.gitignore` files base on the current project type

```
npm install -g lite-server http-server license gitignore
```

## VS Code

VS Code is my preferred code editor.

You can view all of my VS Code settings / extensions [here](https://github.com/CodingGarden/vscode-settings).



# My dotfies

This directory contains the dotfiles for my system

## Requirements

Ensure you have the following installed on your system

### Git

```
pacman -S git
```

### Stow

```
pacman -S stow
```

## Installation

First, check out the dotfiles repo in your $HOME directory using git

```
$ git clone git@github.com/dreamsofautonomy/dotfiles.git
$ cd dotfiles
```

then use GNU stow to create symlinks

```
$ stow .
```

## Install desktop apps
```
$ xargs brew install < app-cask.txt
```
