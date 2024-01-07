#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

PATH="$HOME/bin:$PATH"
PS1='[\u@\h \W]\[\e[31m${?#0}\e[0m\]\$ '
alias ls='eza'
alias grep='grep --color=auto'
alias pbcopy='xsel --clipboard --input'
alias pbpaste='xsel --clipboard --output'
