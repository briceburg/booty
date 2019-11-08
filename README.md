# booty
briceburg's bootstrap

## notes

#### client bootstrap

```sh
curl https://raw.githubusercontent.com/briceburg/booty/master/bootstrap | bash
```

#### gpg key encryption

```sh
KEYID="Master Key ID"
KEYID=$GPG_PUBKEY
gpg -a --export "$KEYID!" > master.key.pub
gpg -a --export-secret-keys "$KEYID!" > master.key
gpg -a --export-secret-subkeys "$KEYID" > master.subkeys

cat master.key | ../bin/bcrypt > master.key.crypt
split -n3 -a1 --numeric-suffixes=1 master.key.crypt master.key.crypt.

cat master.subkeys | ../bin/bcrypt > master.subkeys.crypt
split -n3 -a1 --numeric-suffixes=1 master.subkeys.crypt master.subkeys.crypt.

# distribute master.key.crypt.[1-3]
```
