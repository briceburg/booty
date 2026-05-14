# booty :pirate_flag: :gift:

`booty` tracks your dotfiles and system files in git and applies them to your host.

## Install

```sh
curl -fsSL https://raw.githubusercontent.com/briceburg/booty/main/install | bash
```

Clones to `~/.booty/booty`, symlinks `bin/booty*` into `/usr/local/bin`, and runs [`booty-bootstrap`](#bootstrap).

> [!TIP]
> This installs [briceburg's dotfiles](https://github.com/briceburg/booty). To use your own, [fork this repo](https://github.com/briceburg/booty/fork) and set `BOOTY_REPO_URL`:
> ```sh
> curl -fsSL https://raw.githubusercontent.com/briceburg/booty/main/install |
>   BOOTY_REPO_URL=https://github.com/yourname/booty.git bash
> ```

### Setup

`booty setup` clones the configured dotfiles repo(s) into `~/.booty/` and applies them to the host. The OS bootstrap calls it automatically during provisioning. Rerun when a repo URL changes or to re-initialize a fresh machine.

If you use [secrets](#secrets), `booty setup` also clones and configures the encrypted checkout — see [GPG](#gpg) to prepare your keys first.

```sh
booty setup
```

## Commands

`booty` is a git wrapper — `add`, `rm`, `mv`, `setup`, and `gpg` are booty-specific; everything else is plain git. The booty-specific commands handle the home/system file distinction (invoking sudo as needed) via [`gitbooty`](bin/gitbooty) underneath:

```sh
booty status
booty diff
booty pull                       # pulls and applies dotfiles
booty add ~/.bashrc              # start tracking a file
booty add /etc/keyd/default.conf # system files tracked and applied via sudo
booty rm ~/.bashrc               # stop tracking (removes from host)
booty mv ~/.bashrc /etc/skel/.bashrc  # move between home and system
booty commit -am "update .bashrc"
booty push
booty log --oneline -5
```

> [!TIP]
> Always run `booty` as your regular user — sudo is invoked automatically for system files.

## Secrets

> [!NOTE]
> Optional. Requires [GPG](https://gnupg.org), [git-remote-gcrypt](https://github.com/spwhitton/git-remote-gcrypt), and [age](https://age-encryption.org). The OS bootstrap is responsible for installing all three.

`booty-secrets` is identical to `booty` but targets a separate encrypted checkout:

```sh
booty-secrets pull
booty-secrets add ~/.aws/config
booty-secrets add /etc/ssh/sshd_config.d/private.conf
booty-secrets commit -m "update secrets"
booty-secrets push
```

Set `secrets_url` in [your user config](bootstrap/archlinux/config/users/) — `booty setup` picks it up automatically:

```yaml
# bootstrap/$BOOTY_OS/config/users/$USER.yaml
secrets_url: gcrypt::git@github.com:yourname/booty-secrets.git
```

### GPG

If you don't have a GPG key yet, [create one](https://docs.github.com/en/authentication/managing-commit-signature-verification/generating-a-new-gpg-key) first.

Export your keys to a passphrase-protected archive and store it somewhere secure and accessible from new machines — a password manager attachment, encrypted cloud storage, or an offline backup:

```sh
booty gpg export /path/to/gnupg.tar.gz.age
```

On a new host, import before running `booty setup`. Place the archive at `~/.booty/gnupg.tar.gz.age` for automatic import, or import explicitly:

```sh
booty gpg import /path/to/gnupg.tar.gz.age
booty setup
```

## Bootstrap

`booty-bootstrap` provisions the OS. Run by the installer; rerun anytime to converge:

```sh
booty-bootstrap           # full bootstrap
booty-bootstrap config    # print resolved config (dry run)
```

Add support for a new OS by creating `bootstrap/$OS/` with numbered scripts and config:

```text
bootstrap/$OS/config/base.yaml          # feature definitions
bootstrap/$OS/config/hosts/$host.yaml   # host packages and features
bootstrap/$OS/config/users/$user.yaml   # booty_url, secrets_url
bootstrap/$OS/00-config.sh              # resolve config (numbered scripts run in order)
bootstrap/$OS/hosts/$host.sh            # host hook (optional)
bootstrap/$OS/users/$user.sh            # user hook (optional)
```

### Arch Linux

See [`bootstrap/archlinux/`](bootstrap/archlinux/). Config is composed from `base.yaml` → host yaml → user yaml:

```yaml
features:          # reusable bundles of packages/services defined in base.yaml
enabled_features:  # features to activate for this host
pacman:            # additional packages
aur:               # AUR packages
services:          # systemd services to enable
```

## Layout

Dotfiles live under [`dotfiles/`](dotfiles/), mapped directly to target paths:

```text
dotfiles/$BOOTY_OS/rootfs/home/$USER/  ->  ~/           (home files)
dotfiles/$BOOTY_OS/rootfs/             ->  /            (system files, applied via sudo)
dotfiles/$BOOTY_OS/hosts/$host/rootfs/ ->  /            (host overlay)
```

When a secrets checkout is configured it overlays the public one, each with its own manifest.

## Development

Run from a checkout without installing:

```sh
./bin/booty status
BOOTSTRAP_ROOT="$PWD/bootstrap/archlinux" ./bin/booty-bootstrap config
```

`booty-bootstrap` defaults to `~/.booty/booty/bootstrap/$BOOTY_OS`, matching an installed system. Set `BOOTSTRAP_ROOT` when testing bootstrap scripts from a development checkout.

To run a real bootstrap from a development checkout before the public repo is available, point setup back at the local clone:

```sh
BOOTSTRAP_ROOT="$PWD/bootstrap/archlinux" \
BOOTY_REPO_URL="file://$PWD" \
DEBUG=1 \
  ./bin/booty-bootstrap
```

Run shellcheck + bats:

```sh
./bin/ci
```

Run the Arch Linux bootstrap simulation:

```sh
BOOTY_CI=archlinux ./bin/ci
```

[`gitbooty`](bin/gitbooty) is the rendering engine — it builds a layered file manifest, applies files via git plumbing, tracks drift, and writes machine edits back on `commit`.
