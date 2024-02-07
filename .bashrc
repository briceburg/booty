#
# ~/.bashrc
#

# skip configuration if non-interactive 
[[ $- != *i* ]] && return

PATH="$HOME/bin:$PATH"
PS1='[\u@\h \W]\[\e[31m\]${?#0}\[\e[0m\]\]\$ '
alias ls='eza'
alias grep='grep --color=auto'
alias pbcopy='xsel --clipboard --input'
alias pbpaste='xsel --clipboard --output'

# proceed with fancy pants
eval "$(atuin init bash --disable-up-arrow)"
