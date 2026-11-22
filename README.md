# Dotfiles

Two NixOS machines and the few configs that live outside Nix.

| Path | What it is |
| --- | --- |
| `nixos/` | The NixOS flake: system and Home Manager config for both hosts, the niri config and its scripts |
| `qs/` | The Quickshell desktop shell (bar, control center, launcher), its own flake; see `qs/README.md` |
| `ghostty/`, `yazi/` | Plain config, linked into `~/.config` with GNU stow |
| `RESTORE.md` | What is backed up, and how to get it back after losing a machine |

## NixOS

The checkout lives at `~/dotfiles`. Hosts:

| Flake output | Machine |
| --- | --- |
| `desktop` | Ryzen desktop, Nvidia GTX 1080 (`nixos/hosts/desktop`) |
| `macbook-pro` | MacBook Pro M2 Pro on Asahi Linux (`nixos/hosts/macbook`) |

Rebuild from `nixos/`:

```bash
sudo nixos-rebuild switch --flake .#desktop
sudo nixos-rebuild switch --impure --flake .#macbook-pro
```

The MacBook needs `--impure`: the Asahi module reads the peripheral firmware the Asahi installer left in
`/boot/vendorfw`, which is outside the flake. Its kernel is built locally, so a kernel update takes a while.

`shared/system.nix` and `shared/home.nix` hold what both hosts have in common; each host's
`configuration.nix` holds its hardware and the apps that differ. Login is greetd with ReGreet
(`shared/modules/greeter.nix`), the session is niri (`niri/config.kdl`), and the lock screen is hyprlock
(`niri/hyprlock.conf`, `niri/lock.sh`). The scripts in `niri/` are installed on `PATH` as `niri-<name>`, so
a change to one takes a rebuild.

SSH takes keys only; the accepted keys are listed in `shared/system.nix`.

A new machine needs its own `hosts/<name>/` with the `hardware-configuration.nix` that
`nixos-generate-config` wrote, and an entry in `flake.nix`.

## Stow

```bash
cd ~/dotfiles
stow ghostty yazi
```

`.stow-local-ignore` keeps `nixos/` and `qs/` out of `stow .`.
