{
  description = "Julian's NixOS build with Hyprland + Waybar";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, ... }: {
    nixosConfigurations.hyprland-btw = nixpkgs.lib.nixosSystem {
      modules = [
        ./configuration.nix
        home-manager.nixosModules.home-manager
        {
          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
            users.julian = import ./home.nix;
            backupFileExtension = "backup";
          };
        }
      ];
    };
  };
}
