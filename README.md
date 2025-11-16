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

This one is a doozy, so strap in. First up, home-manager maintains this section of
`.config` (shoot me, I know). If you're using NixOS, this means we're pre-installing
`fenv`. You're going to need this.

### I'm using NixOS

```bash
rm -rf ~/.config/fish
sudo nixos-rebuild switch --flake ~/dotfiles/nixos#hyprland-btw
rm ~/.config/fish/config.fish
cd ~/dotfiles
stow --adopt fish
```

Please. For the love of God.
The reason we have to do this is because home-manager will fail if something already
lives here. So we need to nuke it to generate a new hash for the home-manager fish
completions. Then we need to put everything back.

I recommend collecting garbage and removing the last generation at this point. This
needlessly creates a whole new generation for no good reason.

### I'm not using NixOS

Okay, you're cool then.

```bash
cd ~/.config/fish
rm -rf functions conf.d config.fish
cd ~/dotfiles
stow --adopt fish
```
You will want to keep your `fish_variables` as Fish actually generates these and
maintains them on your behalf.

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
