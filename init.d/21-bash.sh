#!/usr/bin/env shell-helpers

bash(){
  file/interpolate '^for f in ~/\.bash\.d/.*$' \
    "for f in ~/.bash.d/*; do source \"\$f\"; done" "$HOME/.bashrc"
}
