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
    qs = {
      url = "path:../qs";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    omp = {
      url = "github:can1357/oh-my-pi";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    codex-cli = {
      url = "github:sadjow/codex-cli-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    claude-code = {
      url = "github:sadjow/claude-code-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs = { nixpkgs, nixpkgs-ollama, home-manager, apple-silicon, qs, omp, codex-cli, claude-code, ... }@inputs:
  let
    # Shared home-manager module
    mkHomeManagerModule = homeArgs: {
      home-manager = {
        useGlobalPkgs = true;
        useUserPackages = true;
        users.julian = { pkgs, lib, config, ... }@hmArgs: import ./shared/home.nix (hmArgs // homeArgs);
        backupFileExtension = "backup";
	extraSpecialArgs = { inherit inputs; };
      };
    };
    # Helper to create a host
    mkHost = { system, modules, specialArgs ? { }, homeArgs ? { } }: nixpkgs.lib.nixosSystem {
      inherit system;
      specialArgs = { inherit nixpkgs-ollama; } // specialArgs // { nixpkgs.overlays = [ codex-cli.overlays.default claude-code.overlays.default ]; };
      modules = modules ++ [ home-manager.nixosModules.home-manager (mkHomeManagerModule homeArgs) ];
    };
  in {
    # Desktop — Nvidia GTX 1080, B450 Tomahawk Max
    nixosConfigurations.hyprland-btw = mkHost {
      system = "x86_64-linux";
      modules = [
        ./hosts/desktop/configuration.nix
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
            locationServices.enable = true;
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
        nixpkgs.overlays = [ apple-silicon.overlays.apple-silicon-overlay codex-cli.overlays.default claude-code.overlays.default ];
        }
        { programs.niri.package = nixpkgs.legacyPackages.aarch64-linux.niri; }
      ];
    };
  };
}
