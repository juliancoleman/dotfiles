{
  description = "Julian's NixOS build with Niri + Waybar";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, ... }:
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
  in {
    # Desktop — Nvidia GTX 1080, B450 Tomahawk Max
    nixosConfigurations.hyprland-btw = mkHost {
      system = "x86_64-linux";
      modules = [ ./hosts/desktop/configuration.nix ];
    };

    # MacBook Pro — Apple M2 Pro, Asahi Linux
    nixosConfigurations.macbook-pro = mkHost {
      system = "aarch64-linux";
      modules = [ ./hosts/macbook/configuration.nix ];
    };
  };
}
