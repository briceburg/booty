#!/usr/bin/env shell-helpers

dotfiles()(
  is/cmd git-remote-gcrypt || die "dotfiles: git-remote-gcrypt is required"
  local dir="$HOME/.gitbooty"

  p/log "dotfiles: ensure 'gitbooty' alias"
  file/interpolate '^alias gitbooty=.*$' \
    "alias gitbooty='/usr/bin/git --git-dir=\"$dir/\" --work-tree=\"$HOME\"'" "$HOME/.bashrc"

  file/interpolate '^/.gitbooty$' \
    '/.gitbooty' "$HOME/.gitignore"

  p/log "dotfiles: clone dotfiles into $dir"
  [ -d "$dir" ] || \
    git clone --bare gcrypt::git@github.com:briceburg/booty-dotfiles.git "$dir"

  p/log "dotfiles: prepare repository and checkout contents"
  gitbooty config status.showUntrackedFiles no
  gitbooty checkout --force
)

gitbooty(){
  git --git-dir="$dir/" --work-tree="$HOME" "$@"
}
