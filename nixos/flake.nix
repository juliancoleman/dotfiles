{
  description = "Julian's NixOS build with Niri + Waybar";
  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    apple-silicon = {
      url = "github:nix-community/nixos-apple-silicon";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # niri-flake — newer niri than nixpkgs provides. v26.04+ fixes Asahi
    # GPU auto-detection (cold-boot "Operation not supported" DRM error).
    niri-flake = {
      url = "github:sodiboo/niri-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # popover-shell — Wayland layer-shell popovers (wifi picker, etc.)
    popover-shell = {
      url = "path:./popover-shell";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs = { nixpkgs, home-manager, apple-silicon, niri-flake, popover-shell, ... }:
  let
    # Shared home-manager module
    homeManagerModule = {
      home-manager = {
        useGlobalPkgs = true;
        useUserPackages = true;
        users.julian = import ./shared/home.nix;
        backupFileExtension = "backup";
      };
    };
    # Helper to create a host
    mkHost = { system, modules }: nixpkgs.lib.nixosSystem {
      inherit system;
      modules = modules ++ [ home-manager.nixosModules.home-manager homeManagerModule ];
    };
    # Override niri with the unstable build from niri-flake (fixes Asahi GPU).
    niriOverride = { config, lib, pkgs, ... }: {
      programs.niri.package = lib.mkForce niri-flake.packages.${pkgs.system}.niri-unstable;
    };
    # Shared module: popover-shell package + polkit rule for NM wifi control.
    popoverShellModule = { config, lib, pkgs, ... }: {
      # Expose popover-shell to the user PATH so Waybar's on-click finds it.
      environment.systemPackages = [
        popover-shell.packages.${pkgs.system}.default
      ];
      # Polkit rule: let the wheel group control NetworkManager without a
      # password prompt. Unblocks the popover-shell wifi picker (scan + connect).
      security.polkit.extraConfig = builtins.readFile ./popover-shell/polkit-nm-wheel.js;
    };
  in {
    # Desktop — Nvidia GTX 1080, B450 Tomahawk Max
    nixosConfigurations.hyprland-btw = mkHost {
      system = "x86_64-linux";
      modules = [ ./hosts/desktop/configuration.nix niriOverride popoverShellModule ];
    };
    # MacBook Pro — Apple M2 Pro, Asahi Linux
    nixosConfigurations.macbook-pro = mkHost {
      system = "aarch64-linux";
      modules = [
        ./hosts/macbook/configuration.nix
        apple-silicon.nixosModules.apple-silicon-support
        {
          nixpkgs.overlays = [ apple-silicon.overlays.apple-silicon-overlay ];
        }
        niriOverride
        popoverShellModule
      ];
    };
  };
}
