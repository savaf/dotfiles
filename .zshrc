neofetch

# ============================================================================
# ENVIRONMENT VARIABLES
# ============================================================================

# Default editor
export EDITOR='nvim'
export VISUAL='nvim'

# Language and locale
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# Colors for ls and completion
export CLICOLOR=1
export LSCOLORS=ExFxBxDxCxegedabagacad

# History timestamp format
export HISTTIMEFORMAT="[%F %T] "

# FZF default options
export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"

# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# ============================================================================
# PACKAGE MANAGERS
# ============================================================================

# Homebrew - Linux
if [[ -f "/home/linuxbrew/.linuxbrew/bin/brew" ]]; then
  eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
fi

# Homebrew - macOS
if [[ -f "/opt/homebrew/bin/brew" ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# ============================================================================
# ZINIT PLUGIN MANAGER
# ============================================================================

# Set the directory we want to store zinit and plugins
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"

# Download Zinit, if it's not there yet
if [[ ! -d "$ZINIT_HOME" ]]; then
   mkdir -p "$(dirname $ZINIT_HOME)"
   git clone --depth=1 https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
fi

# Source/Load zinit
source "${ZINIT_HOME}/zinit.zsh"

# ============================================================================
# PROMPT THEME
# ============================================================================

# Add in Powerlevel10k
zinit ice depth=1; zinit light romkatv/powerlevel10k

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# ============================================================================
# PLATFORM-SPECIFIC INTEGRATIONS
# ============================================================================

# macOS iTerm2 integrations
if [[ $OSTYPE == darwin* ]]; then
  test -e "${HOME}/.iterm2_shell_integration.zsh" && source "${HOME}/.iterm2_shell_integration.zsh"
fi

# ============================================================================
# ZSH PLUGINS
# ============================================================================

# Essential plugins
zinit light zsh-users/zsh-syntax-highlighting
zinit light zsh-users/zsh-completions
zinit light zsh-users/zsh-autosuggestions

# Enhanced functionality
zinit light Aloxaf/fzf-tab
zinit light zap-zsh/fzf
zinit light MichaelAquilina/zsh-you-should-use

# ============================================================================
# OH-MY-ZSH SNIPPETS
# ============================================================================

# Core functionality
zinit snippet OMZP::git
zinit snippet OMZP::sudo
zinit snippet OMZP::command-not-found
zinit snippet OMZP::colored-man-pages
zinit snippet OMZP::colorize

# Development tools
zinit snippet OMZP::nvm
zinit snippet OMZP::node
zinit snippet OMZP::pm2
zinit snippet OMZP::bun

# Platform specific
zinit snippet OMZP::ubuntu

# macOS specific
if [[ $OSTYPE == darwin* ]]; then
  # zinit snippet OMZP::macos
  :
fi

# ============================================================================
# COMPLETION SYSTEM
# ============================================================================

# Load completions
autoload -Uz compinit && compinit

# Replay cached completions
zinit cdreplay -q

# ============================================================================
# HISTORY CONFIGURATION
# ============================================================================

HISTSIZE=5000
HISTFILE=~/.zsh_history
SAVEHIST=$HISTSIZE
HIST

# History options
setopt appendhistory
setopt sharehistory
setopt hist_ignore_space
setopt hist_ignore_all_dups
setopt hist_save_no_dups
setopt hist_ignore_dups
setopt hist_find_no_dups

# ============================================================================
# KEY BINDINGS
# ============================================================================

# History search with arrow keys
bindkey '^[[A' history-search-backward
bindkey '^[[B' history-search-forward
bindkey '^[w' kill-region

# ============================================================================
# COMPLETION STYLING
# ============================================================================

# Case insensitive completion
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' menu no

# FZF tab completion previews
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'ls --color $realpath'
zstyle ':fzf-tab:complete:__zoxide_z:*' fzf-preview 'ls --color $realpath'


# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

### ARCHIVE EXTRACTION
# usage: ex <file>
function ex() {
  if [[ -z "$1" ]]; then
    # display usage if no parameters given
    echo "Usage: ex <path/file_name>.<zip|rar|bz2|gz|tar|tbz2|tgz|Z|7z|xz|ex|tar.bz2|tar.gz|tar.xz>"
    echo "       extract <path/file_name_1.ext> [path/file_name_2.ext] [path/file_name_3.ext]"
  else
    for n in "$@"; do
      if [[ -f "$n" ]]; then
        case "${n%,}" in
          *.cbt|*.tar.bz2|*.tar.gz|*.tar.xz|*.tbz2|*.tgz|*.txz|*.tar)
            tar xvf "$n" ;;
          *.lzma)      unlzma ./"$n" ;;
          *.bz2)       bunzip2 ./"$n" ;;
          *.cbr|*.rar) unrar x -ad ./"$n" ;;
          *.gz)        gunzip ./"$n" ;;
          *.cbz|*.epub|*.zip) unzip ./"$n" ;;
          *.z)         uncompress ./"$n" ;;
          *.7z|*.arj|*.cab|*.cb7|*.chm|*.deb|*.dmg|*.iso|*.lzh|*.msi|*.pkg|*.rpm|*.udf|*.wim|*.xar)
            7z x ./"$n" ;;
          *.xz)        unxz ./"$n" ;;
          *.exe)       cabextract ./"$n" ;;
          *.cpio)      cpio -id < ./"$n" ;;
          *.cba|*.ace) unace x ./"$n" ;;
          *)
            echo "ex: '$n' - unknown archive method"
            return 1 ;;
        esac
      else
        echo "'$n' - file does not exist"
        return 1
      fi
    done
  fi
}




# ============================================================================
# SHELL INTEGRATIONS
# ============================================================================

# ---- FZF -----
# Set up fzf key bindings and fuzzy completion
eval "$(fzf --zsh)"

# FZF theme configuration
fg="#CBE0F0"
bg="#011628"
bg_highlight="#143652"
purple="#B388FF"
blue="#06BCE4"
cyan="#2CF9ED"

export FZF_DEFAULT_OPTS="--color=fg:${fg},bg:${bg},hl:${purple},fg+:${fg},bg+:${bg_highlight},hl+:${purple},info:${blue},prompt:${cyan},pointer:${cyan},marker:${cyan},spinner:${cyan},header:${cyan}"

# ---- ZOXIDE -----
eval "$(zoxide init zsh)"


# ============================================================================
# ALIASES
# ============================================================================

# Basic utilities
alias vim='nvim'
alias vi='nvim'
alias v='nvim'
alias c='clear'

# ZSH shortcuts
alias rzsh='source ~/.zshrc'
alias ezsh='nvim ~/.zshrc'

# Navigation shortcuts
alias ..='cd ..'
alias ...='cd ../..'
alias .3='cd ../../..'
alias .4='cd ../../../..'
alias .5='cd ../../../../..'

# Process management
alias psa="ps auxf"
alias psgrep="ps aux | grep -v grep | grep -i -e VSZ -e"
alias psmem='ps auxf | sort -nr -k 4'
alias pscpu='ps auxf | sort -nr -k 3'

# Enhanced grep with colors
alias grep='grep --color=auto'
alias egrep='egrep --color=auto'
alias fgrep='fgrep --color=auto'

# Safe file operations
alias cp="cp -i"
alias mv='mv -i'
alias rm='rm -i'

# EZA (better ls)
alias tree='eza --tree'
alias l='eza -F --grid --color=always --group-directories-first'
alias ls='eza -alF --color=always --group-directories-first' # my preferred listing
alias la='eza -a --color=always --group-directories-first'  # all files and dirs
alias ll='eza -l --color=always --group-directories-first'  # long format
alias lt='eza -aT --color=always --group-directories-first' # tree listing
alias l.='eza -al --color=always --group-directories-first ../' # ls on the PARENT directory
alias l..='eza -al --color=always --group-directories-first ../../' # ls on directory 2 levels up
alias l...='eza -al --color=always --group-directories-first ../../../' # ls on directory 3 levels up

# BAT (better cat)
alias cat='batcat -p'
if [[ $OSTYPE == darwin* ]]; then
  alias cat='bat -p'
fi

# Zoxide (better cd)
alias cd="z"

# File associations
alias -s md=code
alias -s {css,ts,html}=code

# Git shortcuts
alias addup='git add -u'
alias addall='git add .'
alias branch='git branch'
alias checkout='git checkout'
alias clone='git clone'
alias commit='git commit -m'
alias fetch='git fetch'
alias pull='git pull origin'
alias push='git push origin'
alias stat='git status'  # 'status' is protected name so using 'stat' instead
alias tag='git tag'
alias newtag='git tag -a'

# ============================================================================
# DEVELOPMENT ENVIRONMENTS
# ============================================================================

# ---- NVM (Node Version Manager) ----
NVM_DIR="$HOME/.nvm"
if [[ ! -d "$NVM_DIR" ]]; then
  echo "nvm is not installed. Installing nvm..."
  mkdir -p "$(dirname $NVM_DIR)"
  git clone --depth=1 https://github.com/nvm-sh/nvm.git "$NVM_DIR"
  echo "nvm installed successfully."
fi

export NVM_DIR="$([ -z "${XDG_CONFIG_HOME-}" ] && printf %s "${HOME}/.nvm" || printf %s "${XDG_CONFIG_HOME}/nvm")"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" # This loads nvm

# ---- PHP Brew ----
[[ -e ~/.phpbrew/bashrc ]] && source ~/.phpbrew/bashrc
# ============================================================================
# PATH CONFIGURATION
# ============================================================================

# Snap packages
if [[ -d "/snap/bin" ]]; then
  export PATH="/snap/bin:$PATH"
fi

# ============================================================================
# PERFORMANCE OPTIMIZATIONS
# ============================================================================

# Reduce startup time by loading completions only when needed
autoload -Uz compinit
if [[ -n ${ZDOTDIR}/.zcompdump(#qN.mh+24) ]]; then
  compinit;
else
  compinit -C;
fi

# ============================================================================
# ADDITIONAL UTILITY FUNCTIONS
# ============================================================================

# Create directory and navigate to it
function mkcd() {
  mkdir -p "$1" && cd "$1"
}

# Quick find function
function ff() {
  find . -name "*$1*" -type f
}

# Quick grep in files
function fgrep_files() {
  grep -r "$1" . --include="*.$2"
}

# Git log with graph
function glog() {
  git log --oneline --graph --all --decorate "${@}"
}

# Quick weather check (requires curl)
function weather() {
  curl -s "wttr.in/${1:-}" | head -7
}

# Quick file backup
function backup() {
  cp "$1" "$1.backup.$(date +%Y%m%d_%H%M%S)"
}

# ============================================================================
# ADDITIONAL ALIASES
# ============================================================================

# Docker shortcuts (if docker is installed)
if command -v docker >/dev/null 2>&1; then
  alias dps='docker ps'
  alias dpsa='docker ps -a'
  alias di='docker images'
  alias dex='docker exec -it'
  alias dlog='docker logs'
  alias dstop='docker stop $(docker ps -q)'
  alias drm='docker rm $(docker ps -aq)'
  alias drmi='docker rmi $(docker images -q)'
fi

# System info
alias myip='curl -s ifconfig.me'
alias ports='netstat -tulanp'
alias meminfo='free -m -l -t'
alias cpuinfo='lscpu'
alias diskusage='df -h'

# Network
alias ping='ping -c 5'
alias wget='wget -c'

# ============================================================================
