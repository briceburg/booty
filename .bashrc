#!/usr/bin/env bash
# gitbooty managed .bashrc

export PATH="$HOME/bin:$PATH"
export PATH="$HOME/.fly/bin:$PATH"
export CAPACITOR_ANDROID_STUDIO_PATH="/opt/android-studio/bin/studio"
export ANDROID_SDK_ROOT="$HOME/Android/Sdk"
source /usr/share/nvm/init-nvm.sh

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
