# booty :pirate_flag: :gift:

`booty` tracks home and system dotfiles in git⁰, then writes them to a host.

## Install

```sh
curl -fsSL https://booty.iceburg.net/install | bash
```

:zap: For unattended installs, or to use a fork, set the target user and repo explicitly:

```sh
curl -fsSL https://booty.iceburg.net/install |
  BOOTSTRAP_USER=nesta BOOTY_REPO_URL=https://github.com/yourname/booty.git bash
```

> `https://booty.iceburg.net/install` redirects to this repo's [install](./install) file.

## Sync

```sh
booty sync
```

`booty sync` clones or updates `BOOTY_REPO_URL` at `~/.booty/booty`, _optionally_ syncs `BOOTY_SECRETS_URL` at `~/.booty/booty-secrets`, then applies public dotfiles overlaid by secrets when available.

`booty sync` and `booty pull` refuse to overwrite changes to previously applied live files. Save them with the appropriate `booty` or `booty-secrets` command, or explicitly discard them with `booty sync --force` or `booty pull --force`.

`booty sync` runs during [booty-bootstrap](#bootstrap). Re-run whenever dotfile or secrets URLs change.

Unless set in the environment, `BOOTY_REPO_URL` and `BOOTY_SECRETS_URL` are read from `~/.booty/config`. [Bootstrap](#bootstrap) writes this file from resolved user config, e.g. [config/users/nesta.yaml](./bootstrap/archlinux/config/users/nesta.yaml).

## Commands

`booty` shares a familiar git interface; `add`, `rm`, `log`, `status`, `commit`, &c.

```sh
booty status
booty ls ~/.config
booty diff ~/.config
booty pull
booty add ~/.bashrc ~/.config
booty restore ~/.bashrc
booty add /etc/keyd/default.conf
booty rm ~/.bashrc
booty mv ~/.bashrc /etc/skel/.bashrc
booty commit -am "update .bashrc"
booty push
```

Run `booty` as the user whose dotfiles you want to manage, usually your user. Syncing [system files](#system-files) may prompt for sudo.

Commands that take paths use git-style pathspecs. `add` reads live files and recurses through named directories; `status`, `diff`, `restore`, `rm`, and `ls` operate on already-managed files. Quote globs you want `booty` to expand, for example `booty add '~/.config/*.toml'`.

In addition to the git interface, the [sync](#sync) and [gpg](#gpg) commands are available.

## Dotfiles Repository Layout

[Dotfiles](./dotfiles/) map directly to live paths:

```text
dotfiles/$BOOTY_OS/rootfs/home/$USER/  ->  ~/
dotfiles/$BOOTY_OS/rootfs/             ->  /
dotfiles/$BOOTY_OS/hosts/$host/rootfs/ ->  /
```

* base/common files are kept under `dotfiles/$BOOTY_OS/rootfs/`
* host specific files are kept under `dotfiles/$BOOTY_OS/hosts/$host/rootfs/`
* user dotfiles are kept under `dotfiles/$BOOTY_OS/rootfs/home/$USER/`
* and per-host user dotfiles go under `dotfiles/$BOOTY_OS/hosts/$host/rootfs/home/$USER/`

The [secrets](#secrets) repository maintains this same layout and overlays sensitive files.

> [!NOTE]
> `root` is treated as system rootfs. Put root's files under `dotfiles/$BOOTY_OS/rootfs/root/`, not `dotfiles/$BOOTY_OS/rootfs/home/root/`.

### System Files

Files outside of `rootfs/home/$USER/` directories are considered system files and owned by root.

## Secrets

`booty-secrets` targets an optional, encrypted dotfiles repo for managing sensitive files.

Set `secrets_url` in bootstrap config, or pass `BOOTY_SECRETS_URL` for ad hoc installs.

```yaml
# bootstrap/$BOOTY_OS/config/users/$USER.yaml
repo_url: git@github.com:yourname/booty.git
secrets_url: gcrypt::https://github.com/yourname/booty-secrets.git
```

After sync, work with sensitive files as you would with `booty`, but via the `booty-secrets` command:

```sh
booty-secrets pull
booty-secrets add ~/.aws/config
booty-secrets add /etc/ssh/sshd_config.d/private.conf
booty-secrets commit -m "update secrets"
booty-secrets push
```

> [!NOTE]
> Secrets require GPG, [git-remote-gcrypt](https://github.com/spwhitton/git-remote-gcrypt), and [age](https://github.com/filosottile/age). The OS [bootstrap](./bootstrap/) is responsible for installing them.

### GPG

`booty-secrets` requires a functioning GPG key. If you don't have a GPG key yet, [create one](https://docs.github.com/en/authentication/managing-commit-signature-verification/generating-a-new-gpg-key) first.

:thought_balloon: You may want to preserve this key across machines using the export/import mechanism;

#### Export

Export keys to a passphrase-protected archive and store it somewhere secure:

```sh
booty gpg export
```

By default this writes to `$BOOTY_HOME/gnupg.tar.gz.age`, normally `~/.booty/gnupg.tar.gz.age`; pass a path to override it.

#### Import

On a new host, place the archive at the default path for automatic import during bootstrap, or import it yourself and re-run [sync](#sync):

```sh
booty gpg import [path/to/gnupg.tar.gz.age]
booty sync
```

## Bootstrap

`booty-bootstrap` provisions the OS and syncs dotfiles for `BOOTSTRAP_USER`:

```sh
booty-bootstrap           # full bootstrap
booty-bootstrap config    # print resolved config
```

Bootstrap state lives under `~/.booty/bootstrap`. It is idempotent and meant to provision or refresh the underlying OS.

On Arch, configured AUR packages are installed through `/usr/local/bin/aur-install`, which is also available after bootstrap:

```sh
aur-install visual-studio-code-bin
```

Add an OS by creating `bootstrap/$OS/`:

```text
bootstrap/$OS/config/base.yaml
bootstrap/$OS/config/hosts/$host.yaml
bootstrap/$OS/config/users/$user.yaml
bootstrap/$OS/00-config.sh
bootstrap/$OS/hosts/$host.sh
bootstrap/$OS/users/$user.sh
```

Numbered OS scripts should prepare packages, create/configure `BOOTSTRAP_USER`, ensure `BOOTY_HOME/booty` exists for that user, then export `BOOTSTRAP_TARGET_READY=1`. `booty-bootstrap` applies rootfs once that target checkout is ready.

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

---

> ⁰ [git](https://git-scm.com/docs/user-manual) - "the stupid content tracker"
