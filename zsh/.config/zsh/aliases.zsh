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
# Ubuntu-only: map bat -> batcat
if [[ -r /etc/os-release ]]; then
  . /etc/os-release
  if [[ "${ID}" = "ubuntu" ]] && command -v batcat >/dev/null 2>&1; then
    alias bat='batcat'
  fi
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
alias gclean='git branch | grep -v "main" | xargs git branch -D'

# lazygit (terminal UI for git)
alias lzg='lazygit'

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

# tree
alias ptree="tree -L 2 -I 'node_modules|.git|dist'"
