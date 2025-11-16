# Dotfiles

Simple dotfiles for use with GNU stow.

## Installation

Simply `cd` to your home directory and `git clone` this repo, or download via the button
above.

> Caution: this will attempt to overwrite your existing configuration in `~/.config`. You
> can either backup your existing configuration with `mv ~/.config /.config-backup` or
> use the `stow --adopt` flag.

From here you can run `stow .` and it'll put your files in the correct spot. If you don't
want the nixos stuff, either ignore it via the stow command, or delete it after running
the installation.

## Fish

If you're going to stow Fish, you will probably want to use the `--adopt` flag as your
`fish_variables` are per-system and is auto-generated and maintained by Fish itself. This
will look something like

```bash
cd ~/dotfiles
stow --adopt fish # will adopt the current fish_variables and then symlink them
```

If you're going to do this, you probably want to empty the `~/.config/fish` directory
besides that one file first as we want our changes, not the ones that get generated the
first time you enter Fish.

If you did `stow .` without reading the above, I suppose you could just

```fish
for var in (set -U)
  echo "set -Ux $var (set -U $var)"
end
```
and write the output to `~/.config/fish/fish_variables`

## NixOS

If you're using this with NixOS (I am btw), you'll want to ensure your initial setup has
`git` and `stow` listed as a system package. You can then clone this repo to your home
directory.

Copy your `hardware-configuration.nix` file into this folder after it's been cloned

```bash
cp /etc/nixos/hardware-configuration.nix ~/dotfiles
sudo chown -R <your_username>:users hardware-configuration.nix
```

You will need to rebuild your system

```bash
nixos-rebuild switch --flake ~/nixos
```

> Note: go touch some grass or get a coffee. This is going to take up to an hour
> depending on how fast your system is.

### Home Manager

While this config does make use of home manager, it is only responsible for the GUI apps
that I have installed on my system. It otherwise has no affect on things you might want
to change often, such as your Neovim or Kitty config.
