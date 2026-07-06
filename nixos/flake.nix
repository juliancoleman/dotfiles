{
  description = "Julian's NixOS build with Niri + Waybar";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    apple-silicon = {
      url = "path:./apple-silicon-support";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Asahi firmware blobs — local-only, outside git (Apple binary firmware).
    # Present only on the MacBook; the desktop never builds .#macbook-pro.
    asahi-firmware = {
      url = "path:/home/julian/asahi-firmware";
    };
  };

  outputs = { nixpkgs, home-manager, apple-silicon, asahi-firmware, ... }:
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
      modules = [
        ./hosts/macbook/configuration.nix
        apple-silicon.nixosModules.apple-silicon-support
        {
          nixpkgs.overlays = [ apple-silicon.overlays.apple-silicon-overlay ];
          hardware.asahi.peripheralFirmwareDirectory = asahi-firmware;
        }
      ];
    };
  };
}
