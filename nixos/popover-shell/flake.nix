{
  description = "popover-shell — Wayland layer-shell popovers for niri + Waybar";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        rustToolchain = pkgs.rustPlatform;
      in
      {
        # ── Development shell ────────────────────────────────────
        # `nix develop` — gives you cargo, rustc, wayland deps, pkg-config.
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            rustc
            cargo
            pkg-config
            wayland
            wayland-protocols
            libxkbcommon
            # slint's femtovg renderer needs EGL/GLES + fontconfig for text
            libGL
            fontconfig
            freetype
            freetype.dev
            glib
            # NM dev headers for zbus (not strictly required — zbus is pure)
            networkmanager
          ];
          # Runtime library path — smithay-client-toolkit dlopens libwayland,
          # so the .so must be findable at runtime, not just link time.
          # Also pass WAYLAND_DISPLAY through (niri uses wayland-1, not the
          # default wayland-0).
          shellHook = ''
            export POPOVER_SHELL_UI="$PWD/ui/wifi.slint"
            export LD_LIBRARY_PATH="${pkgs.wayland}/lib:${pkgs.libxkbcommon}/lib:${pkgs.libGL}/lib:${pkgs.fontconfig}/lib:${pkgs.freetype}/lib:${pkgs.glib}/lib''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
            # Auto-detect the wayland socket if WAYLAND_DISPLAY is unset
            # (niri doesn't set it in spawned processes by default).
            if [ -z "''${WAYLAND_DISPLAY:-}" ]; then
              export WAYLAND_DISPLAY="$(ls ''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/wayland-* 2>/dev/null | head -1 | xargs basename 2>/dev/null)"
              if [ -z "$WAYLAND_DISPLAY" ]; then
                export WAYLAND_DISPLAY="wayland-1"
              fi
            fi
            echo "popover-shell dev shell"
            echo "  cargo run   — launches the wifi picker popup"
            echo "  UI file:    $POPOVER_SHELL_UI (hot-reloaded on save)"
            echo "  WAYLAND_DISPLAY=$WAYLAND_DISPLAY"
          '';
        };

        # ── Package ──────────────────────────────────────────────
        # `nix build` — produces the popover-shell binary.
        packages.popover-shell = rustToolchain.buildRustPackage {
          pname = "popover-shell";
          version = "0.1.0";
          src = ./.;
          cargoLock = {
            lockFile = ./Cargo.lock;
            # layer-shika is a git dep — allow fetching during build.
            allowBuiltinFetchGit = true;
          };
          nativeBuildInputs = with pkgs; [
            pkg-config
            makeWrapper
          ];
          buildInputs = with pkgs; [
            wayland
            wayland-protocols
            libxkbcommon
            libGL
            fontconfig
            freetype
            freetype.dev
            glib
          ];
          # Ship the .slint UI alongside the binary so the Nix package finds it.
          postInstall = ''
            mkdir -p $out/share/popover-shell/ui
            cp ui/wifi.slint $out/share/popover-shell/ui/
            # Wrap the binary to point at the installed UI file by default.
            wrapProgram $out/bin/popover-shell \
              --set POPOVER_SHELL_UI $out/share/popover-shell/ui/wifi.slint \
              --prefix LD_LIBRARY_PATH : "${pkgs.lib.makeLibraryPath (with pkgs; [ wayland libxkbcommon libGL fontconfig freetype glib ])}"
          '';
          meta = with pkgs.lib; {
            description = "Wayland layer-shell popover toolkit (wifi picker, bluetooth, power)";
            license = licenses.mit;
            platforms = platforms.linux;
          };
        };

        packages.default = self.packages.${system}.popover-shell;
      });
}
