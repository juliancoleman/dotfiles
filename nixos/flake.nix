{
  description = "Julian's NixOS build with Niri + DankMaterialShell";
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
    dank-material-shell = {
      url = "github:AvengeMedia/DankMaterialShell";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs = { nixpkgs, nixpkgs-ollama, home-manager, apple-silicon, niri-flake, dank-material-shell, ... }:
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
      specialArgs = { inherit nixpkgs-ollama dank-material-shell; } // specialArgs;
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
      modules = [ ./hosts/desktop/configuration.nix niriOverride ];
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
      ];
    };
  };
}
