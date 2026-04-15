# booty

briceburg's system bootstrap and dotfiles :pirate_flag: :gift:

`booty` keeps system files and home dotfiles in git under a familiar interface:

```sh
# home dotfiles
booty pull                          # apply upstream changes into $HOME
booty status                        # see local drift for tracked home files
booty diff                          # inspect local home-file changes
booty add ~/.bashrc                 # start tracking a file from $HOME
booty mv ~/.bashrc ~/.bashrc.old    # move an already tracked file
booty commit -am "update bashrc"    # write tracked local changes back into the repo
booty push                          # push repo changes upstream

# system files
sudo booty status                   # see local drift for tracked system files
sudo booty bootstrap                # provision a fresh machine

# private encrypted overlay
booty-secrets status                # same commands as booty, but with secrets enabled
```

* Normal user mode targets files under `$HOME`, e.g. /home/briceburg.
* Root mode (e.g. when run via `sudo` above) targets files under `/`.
* `booty-secrets` uses [`git-remote-gcrypt`](https://github.com/spwhitton/git-remote-gcrypt) to protect sensitive dotfiles in a [booty-secrets repo](https://github.com/briceburg/booty-secrets).

## Install

```sh
curl -fsSL https://raw.githubusercontent.com/briceburg/booty/main/install | sudo bash
```

## Development

Run directly from a local checkout:

```sh
# repo-aware wrapper
./bin/booty status
sudo ./bin/booty bootstrap

# lower-level git-backed engine
./bin/gitbooty
```

### Make It Yours

The current bootstrap implementation targets Arch Linux, but the repo shape is meant to stay flexible enough for other OS profiles.

Fork it, rename it, or rewrite the profile tree for your own machines.

### My Layout

```text
profiles/
  archlinux/
    config.yaml
    root/
    hosts/
      hartford/
        config.yaml
        bootstrap.d/
      zb14x/
        config.yaml
    users/
      briceburg/
        home/
        bootstrap.d/
```

The structure is:

- `bin/`: `booty` wrapper plus the lower-level `gitbooty` engine
- `profiles/<os>/...`: config organized by OS, host, user, and scope
- `bootstrap/`: OS bootstrap entrypoints and hooks
- `install`: the repo install entrypoint

### Tests

```sh
./bin/ci
```

`bin/ci` runs shell checks and the `bats` suite in `tests/`.
