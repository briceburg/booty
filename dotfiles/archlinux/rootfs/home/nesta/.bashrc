#!/usr/bin/env bash
# booty managed .bashrc

export PATH="$HOME/bin:$HOME/.fly/bin:$PATH"
export CAPACITOR_ANDROID_STUDIO_PATH="$HOME/android-studio/bin/studio"
export ANDROID_SDK_ROOT="$HOME/Android/Sdk"

# node fnm (vs nvm)
eval "$(fnm env --shell bash)"

# gnupg agent forwarding
if [[ -z "${SSH_AUTH_SOCK:-}" || ! -S "$SSH_AUTH_SOCK" ]]; then
  export SSH_AUTH_SOCK="$(gpgconf --list-dirs agent-ssh-socket)"
  export GPG_TTY="$(tty)"
  gpg-connect-agent updatestartuptty /bye >/dev/null 2>&1 || true
fi

# booty-secrets provided
source ~/.bashrc.encrypted || true

# skip configuration if non-interactive 
[[ $- != *i* ]] && return

PS1='[\u@\h \W]\[\e[31m\]${?#0}\[\e(B\e[m\]\$ '
alias edit='msedit'
alias grep='grep --color=auto'
alias ls='eza'
alias pbcopy='xsel --clipboard --input'
alias pbpaste='xsel --clipboard --output'
export VISUAL='msedit'

# proceed with fancy pants
eval "$(atuin init bash --disable-up-arrow)"
