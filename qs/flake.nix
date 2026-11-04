{
  description = "Quickshell desktop shell";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      systems = [
        "aarch64-linux"
        "x86_64-linux"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          fan-helper = pkgs.callPackage ./nix/fan-helper.nix { };
          secure-helper = pkgs.callPackage ./nix/secure-helper.nix { };
          meter-helper = pkgs.callPackage ./nix/meter-helper.nix { };
          qs = pkgs.callPackage ./nix/package.nix { inherit meter-helper; };
        in
        {
          default = qs;
          inherit qs fan-helper secure-helper meter-helper;
        }
      );

      nixosModules = rec {
        default = qs;
        qs = import ./nix/nixos-module.nix { inherit self; };
      };

      homeManagerModules = rec {
        default = qs;
        qs = import ./nix/home-manager-module.nix { inherit self; };
      };
    };
}
