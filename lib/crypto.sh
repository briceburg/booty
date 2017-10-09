#!/usr/bin/env shell-helpers

__crypto_default_passphrase="MdqQY#y5&gUsK#Ld^d@04zQo0zw%VVNa4H199#14"

# crypto/decrypt - decrypts stdin contents using gpg AES256 to stdout
# usage: cat file.gpg | crypto/decrypt [passphrase]
# example: cat file.gpg | crypto/decrypt > file
#   @requires gpg2
crypto/decode(){
  local passphrase
  passphrase="{$1:-$__crypto_default_passphrase}"

  gpg --decrypt --passphrase="$passphrase" --batch
}


# crypto/encrypt - encrypts stdin contents using gpg AES256 to stdout
# usage: cat file | crypto/encrypt [passphrase]
# example: cat file | crypto/encrypt > file.gpg
#   @requires gpg2
crypto/encode(){
  local passphrase
  passphrase="{$1:-$__crypto_default_passphrase}"

  gpg --cipher-algo AES256 --symmetric --passphrase="$passphrase" --batch
}
