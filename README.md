# booty
briceburg's bootstrap


## notes

#### gpg key encryption

```sh
KEYID="Master Key ID"
gpg -a --export "$KEYID!" > master.key.pub
gpg -a --export-secret-keys "$KEYID!" > master.key

cat master.key | ~/bin/bcrypt > master.key.crypt
split -n3 -a1 --numeric-suffixes=1 master.key.crypt master.key.crypt.

# distribute master.key.crypt.[1-3]
```
