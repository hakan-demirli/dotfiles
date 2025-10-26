#!/usr/bin/env bash

# Navigation and session
alias :q='exit'
alias q:='exit'
alias :wq='exit'
alias hx.='hx .'
alias ..='cd ..'
alias c='clear'
alias cd..='cd ..'
alias helix='hx'
alias lf='echo "Did you mean f?"'
alias f='yazi_cd'
alias ff='yazi_cd'
alias cdf='cd "$(find . -type d | fzf)"'
alias da='direnv allow'
alias ch='cheat_sheet.sh'

# Git
alias git='git_cached'
alias ga.='git add .'
alias ga='git add'
alias gd='git -c core.pager=delta -c interactive.diffFilter="delta --color-only" -c delta.navigate=true -c delta.dark=true -c delta.syntax-theme=Dracula -c delta.line-numbers=true -c delta.hyperlinks=true -c delta.features=Dracula -c delta.hunk-header-style=omit -c delta.side-by-side=true -c delta.decorations=true -c merge.conflictStyle=zdiff3 diff'
alias gdc='git -c core.pager=delta -c interactive.diffFilter="delta --color-only" -c delta.navigate=true -c delta.dark=true -c delta.syntax-theme=Dracula -c delta.line-numbers=true -c delta.hyperlinks=true -c delta.features=Dracula -c delta.hunk-header-style=omit -c delta.side-by-side=true -c delta.decorations=true -c merge.conflictStyle=zdiff3 diff --cached'
alias gp='git push'
alias gpc='git push && clear'
alias gpf='git push --force'
alias gr='git restore'
alias gr.='git restore .'
alias grs='git restore --staged'
alias gs='git status'
alias gb='fzf_git_branches'
alias gc='git commit'
alias gcm='git commit -m'
alias gca='git commit --amend'
alias gl='fzf_git_commits'

# Notifications & Sound
alias bell='source $HOME/.local/bin/prompt-bell'
alias tbell='source $HOME/.local/bin/prompt-tnotify.sh'
alias tbell-fg='source $HOME/.local/bin/prompt-tnotify-fg.sh'

# Tools
alias yarn='yarn --use-yarnrc "$XDG_CONFIG_HOME/yarn/config"'
alias wget='wget --hsts-file="$XDG_DATA_HOME/wget-hsts"'
alias arduino-cli='arduino-cli --config-file $XDG_CONFIG_HOME/arduino15/arduino-cli.yaml'

# Tmux
alias tmux='tmux -f ~/.config/tmux/tmux.conf'
alias txa='tmux attach-session -t $(tmux list-sessions -F "#{session_name}" | head -n 1)'
alias txls='tmux list-sessions'
alias txks='tmux kill-session -t'
alias txn='tmux new-session -s'
alias txs='tmux switch-client -n'
alias txkw='tmux kill-window -t'
alias txlw='tmux list-windows'

# Hardware specific (Asus)
if [ -d "/sys/devices/platform/asus-nb-wmi" ]; then
  alias fan-turbo='cd /sys/devices/platform/asus-nb-wmi; sudo sh -c "echo 1 >>  fan_boost_mode"; sudo sh -c "echo 1 >> throttle_thermal_policy"; source ~/.bashrc; cd ~;'
  alias fan-performance='cd /sys/devices/platform/asus-nb-wmi; sudo sh -c "echo 0 >>  fan_boost_mode"; sudo sh -c "echo 0 >> throttle_thermal_policy"; source ~/.bashrc; cd ~;'
  alias fan-silent='cd /sys/devices/platform/asus-nb-wmi; sudo sh -c "echo 2 >>  fan_boost_mode"; sudo sh -c "echo 2 >> throttle_thermal_policy"; source ~/.bashrc; cd ~;'
fi
