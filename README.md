# booty
briceburg's dotfiles :pirate_flag: :gift:

## notes

* dotfiles exist in [branches](https://github.com/briceburg/booty/branches), e.g. [archlinux-xmonad](https://github.com/briceburg/booty/tree/archlinux-xmonad), and are managed by the [gitbooty](#usage) command. 
* `gitbooty` is based on [familiar patterns](https://www.atlassian.com/git/tutorials/dotfiles) for keeping dotfiles in a bare git repository and setting `--work_tree=$HOME`.
* branches supporting [nix home manager](https://github.com/nix-community/home-manager) are possible.


## installation

### system bootstrap

the [system bootystrap](https://github.com/briceburg/bootystrap) configures a fresh OS. it's idempotent and provides an easy way for installing `gitbooty` as well as managing all the other good things such as packages and /etc file configuration. fork and modify to your needs.

### manual

it may be preferable to skip the system bootstrap and manually setup `gitbooty`. follow these steps;

* create the ~/.gitbooty git repository for housing dotfiles
  ```sh
  dir="$HOME/.gitbooty"      # where to keep the repo. modifty accordingly.
  branch="archlinux-xmonad"  # dotfile branch to initially checkout. modify accordingly.
  git clone --bare --branch "$branch" https://github.com/briceburg/booty "$dir"
  git --git-dir="$dir" config status.showUntrackedFiles no
  git --git-dir="$dir" config remote.origin.fetch '+refs/heads/*:refs/remotes/origin/*'
  git --git-dir="$dir" fetch
  git --git-dir="$dir" branch -u "origin/$branch" "$branch"
  ```
* add the `gitbooty` command to a directory in your PATH (e.g. `/usr/local/bin/gitbooty`) and mark it executable.
  ```sh
  #!/bin/sh
  exec git --git-dir="$HOME/.gitbooty" --work-tree="$HOME" "$@"
  ```
* use the gitbooty command to checkout initial dotfiles
  ```sh
  gitbooty checkout --force
  ```

## usage

:bulb: **use `gitbooty` as you would `git`**.

:zap: gitbooty files _must_ exist under the user's home directory, e.g. ~/.bashrc, ~/.ssh/config, &c.
* if a conifg is sensitive, keep it in the gitbootycrypt and unavailable to the public.
* to manage system files outside the user's home, e.g. /etc/keyd/foo.conf, do so via [gitbootystrap](https://github.com/briceburg/bootystrap).

#### add a new dotfile

```sh
gitbootystrap add /path/to/new-file
gitbootystrap commit -m "adding new-file" && gitbootystrap push origin HEAD
```

#### update dotfiles

```sh
# check for local changes
gitbootystrap status
gitbootystrap pull
```