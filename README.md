# booty :pirate_flag: :gift:

`booty` tracks home and system dotfiles in git, then applies them to a host.

## Install

```sh
curl -fsSL https://raw.githubusercontent.com/briceburg/booty/main/install | bash
```

The installer clones to `~/.booty/booty`, runs [`booty-bootstrap`](#bootstrap), and finishes with `booty sync` as the current user.

> [!NOTE]
> Run this as the user who should own the dotfiles, not as root. Bootstrap will ask for sudo when system changes need it.
>
> On a fresh OS, create a normal user with sudo access first. For example, on Arch:
>
> ```sh
> useradd -m -G wheel -s /bin/bash nesta
> passwd nesta
> su - nesta
> ```
>
> Configure sudo however your OS or admin policy expects; `booty` only requires that the installing user can run `sudo`.

> [!TIP]
> To use your own fork:
> ```sh
> curl -fsSL https://raw.githubusercontent.com/briceburg/booty/main/install |
>   BOOTY_REPO_URL=https://github.com/yourname/booty.git bash
> ```

## Sync

`booty sync` clones configured repos into `~/.booty/`, refreshes `booty*` command links, and applies dotfiles. Bootstrap runs it automatically; rerun it after repo URL changes or to re-initialize a machine.

```sh
booty sync
```

## Commands

`booty` is a git wrapper. `add`, `rm`, `mv`, `sync`, and `gpg` are booty-specific; other commands pass through to git. System files use sudo as needed.

```sh
booty status
booty diff
booty pull
booty add ~/.bashrc
booty add /etc/keyd/default.conf
booty rm ~/.bashrc
booty mv ~/.bashrc /etc/skel/.bashrc
booty commit -am "update .bashrc"
booty push
```

Always run `booty` as your regular user. Protected system files may prompt for sudo once per operation.

## Secrets

Secrets are optional and use a separate encrypted checkout:

```sh
booty-secrets pull
booty-secrets add ~/.aws/config
booty-secrets add /etc/ssh/sshd_config.d/private.conf
booty-secrets commit -m "update secrets"
booty-secrets push
```

Set `secrets_url` in [your user config](bootstrap/archlinux/config/users/). Bootstrap writes it to `~/.booty/config`; `booty sync` reads it.

```yaml
# bootstrap/$BOOTY_OS/config/users/$USER.yaml
repo_url: git@github.com:yourname/booty.git
secrets_url: gcrypt::git@github.com:yourname/booty-secrets.git
```

Requires GPG, git-remote-gcrypt, and age. Bootstrap installs them on supported OSes.

### GPG

Export keys to a passphrase-protected archive and store it somewhere secure:

```sh
booty gpg export /path/to/gnupg.tar.gz.age
```

On a new host, place the archive at `~/.booty/gnupg.tar.gz.age` for automatic import, or import it explicitly:

```sh
booty gpg import /path/to/gnupg.tar.gz.age
booty sync
```

## Bootstrap

`booty-bootstrap` provisions the OS for the current sudo-capable user:

```sh
booty-bootstrap           # full bootstrap
booty-bootstrap config    # print resolved config
```

Bootstrap state lives under `~/.booty/bootstrap`. `booty-bootstrap config` prints resolved `BOOTY_*` / `BOOTSTRAP_*` variables and exits before provisioning. Full bootstrap finishes by running `booty sync` as the target user.

Add an OS by creating `bootstrap/$OS/`:

```text
bootstrap/$OS/config/base.yaml
bootstrap/$OS/config/hosts/$host.yaml
bootstrap/$OS/config/users/$user.yaml
bootstrap/$OS/00-config.sh
bootstrap/$OS/hosts/$host.sh
bootstrap/$OS/users/$user.sh
```

### Arch Linux

Arch config merges `base.yaml` -> host yaml -> user yaml:

```yaml
features:          # reusable package/service bundles
enabled_features:  # features enabled for this host
pacman:            # additional pacman packages
aur:               # AUR packages
services:          # systemd services to enable
```

## Layout

Dotfiles map directly to target paths:

```text
dotfiles/$BOOTY_OS/rootfs/home/$USER/  ->  ~/
dotfiles/$BOOTY_OS/rootfs/             ->  /
dotfiles/$BOOTY_OS/hosts/$host/rootfs/ ->  /
```

Secrets overlay the public checkout and keep separate manifests.

## Development

Run from a checkout without installing:

```sh
./bin/booty status
BOOTSTRAP_ROOT="$PWD/bootstrap/archlinux" ./bin/booty-bootstrap config
```

`booty-bootstrap` defaults to `~/.booty/booty/bootstrap/$BOOTY_OS`. Set `BOOTSTRAP_ROOT` for development checkouts and `BOOTSTRAP_CONFIG_DIR` to redirect generated config.

To bootstrap from a development checkout, point sync back at the local clone:

```sh
BOOTSTRAP_ROOT="$PWD/bootstrap/archlinux" \
BOOTY_REPO_URL="file://$PWD" \
DEBUG=1 \
  ./bin/booty-bootstrap
```

Set `BOOTSTRAP_SKIP_REFLECTOR=1` to skip Arch mirror rating in CI or throwaway containers.

Run the regular suite:

```sh
./bin/ci
```

Run the Arch bootstrap simulation:

```sh
BOOTY_CI=archlinux ./bin/ci
```

[`gitbooty`](bin/gitbooty) renders layered dotfiles, applies them with git plumbing, tracks drift, and writes machine edits back on `commit`.
