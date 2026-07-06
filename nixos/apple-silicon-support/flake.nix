{
  description = "Apple Silicon support for NixOS (vendored, linux-asahi 6.17.7)";
  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    flake-compat = {
      url = "github:nix-community/flake-compat";
      flake = false;
    };
  };
  outputs = { self, nixpkgs, ... }:
    let
      systems = [ "aarch64-linux" "x86_64-linux" ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f system);
    in {
      overlays = {
        apple-silicon-overlay = import ./packages/overlay.nix;
      };
      nixosModules = {
        apple-silicon-support = import ./default.nix;
      };
      packages = forAllSystems (system:
        let
          pkgs = import nixpkgs { inherit system; overlays = [ self.overlays.apple-silicon-overlay ]; };
        in {
          linux-asahi = pkgs.linux-asahi;
          uboot-asahi = pkgs.uboot-asahi;
        });
    };
}
