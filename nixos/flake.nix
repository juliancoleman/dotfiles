{
  description = "Julian's NixOS build with Niri + Quickshell";
  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    # Keep the base system pinned while allowing newer Ollama builds for model compatibility.
    nixpkgs-ollama.url = "github:NixOS/nixpkgs/nixos-unstable";
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
    qs = {
      url = "path:/home/julian/code/qs";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs = { nixpkgs, nixpkgs-ollama, home-manager, apple-silicon, niri-flake, qs, ... }:
  let
    # Shared home-manager module
    mkHomeManagerModule = homeArgs: {
      home-manager = {
        useGlobalPkgs = true;
        useUserPackages = true;
        users.julian = { pkgs, lib, config, ... }@hmArgs: import ./shared/home.nix (hmArgs // homeArgs);
        backupFileExtension = "backup";
      };
    };
    # Helper to create a host
    mkHost = { system, modules, specialArgs ? { }, homeArgs ? { } }: nixpkgs.lib.nixosSystem {
      inherit system;
      specialArgs = { inherit nixpkgs-ollama; } // specialArgs;
      modules = modules ++ [ home-manager.nixosModules.home-manager (mkHomeManagerModule homeArgs) ];
    };
    # Override niri with the unstable build from niri-flake (fixes Asahi GPU).
    niriOverride = { config, lib, pkgs, ... }: {
      programs.niri.package = lib.mkForce niri-flake.packages.${pkgs.system}.niri-unstable;
    };
  in {
    # Desktop — Nvidia GTX 1080, B450 Tomahawk Max
    nixosConfigurations.hyprland-btw = mkHost {
      system = "x86_64-linux";
      modules = [
        ./hosts/desktop/configuration.nix
        niriOverride
        qs.nixosModules.default
        {
          services.qs = {
            enable = true;
            wallpaper = ./niri/wallpapers/tj-holowaychuk-mist-over-banff-ave.jpg;
          };
          home-manager.users.julian = {
            imports = [ qs.homeManagerModules.default ];
            programs.qs = {
              enable = true;
              wallpaper = ./niri/wallpapers/tj-holowaychuk-mist-over-banff-ave.jpg;
            };
          };
        }
      ];
    };
    # MacBook Pro — Apple M2 Pro, Asahi Linux
    nixosConfigurations.macbook-pro = mkHost {
      system = "aarch64-linux";
      modules = [
        ./hosts/macbook/configuration.nix
        apple-silicon.nixosModules.apple-silicon-support
        qs.nixosModules.default
        {
          services.qs = {
            enable = true;
            wallpaper = ./niri/wallpapers/tj-holowaychuk-mist-over-banff-ave.jpg;
          };
          home-manager.users.julian = {
            imports = [ qs.homeManagerModules.default ];
            programs.qs = {
              enable = true;
              wallpaper = ./niri/wallpapers/tj-holowaychuk-mist-over-banff-ave.jpg;
            };
          };
        }
        {
          nixpkgs.overlays = [ apple-silicon.overlays.apple-silicon-overlay ];
        }
        { programs.niri.package = nixpkgs.legacyPackages.aarch64-linux.niri; }
      ];
    };
  };
}
