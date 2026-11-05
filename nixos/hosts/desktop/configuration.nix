# Desktop host — Nvidia GTX 1080, B450 Tomahawk Max, dual SSD
{ config, lib, pkgs, nixpkgs-ollama, ... }:
let
  ollamaPkgs = import nixpkgs-ollama {
    system = pkgs.stdenv.hostPlatform.system;
    config.allowUnfree = true;
  };
  # PCSX2 overlay: patches assertion crash (FQC=0 on VIF FIFO READ) and
  # signal handler robustness (sigaltstack for SIGSEGV during JIT execution).
  pcsx2Overlay = import ../../overlays/pcsx2.nix;
in
{
  nixpkgs.overlays = [ pcsx2Overlay ];

  imports = [
    ./hardware-configuration.nix
    ./steam-mount.nix
    ../../shared/system.nix
  ];

  # ── Boot ──
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelPackages = pkgs.linuxPackages_6_18;
  # Expose the sensor/controller to QS's privileged, policy-gated fan helper.
  boot.kernelModules = [ "nct6775" ];
  # Bind nvidia-drm before userspace. Otherwise greetd can start niri while simpledrm (card0) is still
  # the only GPU; nvidia then replaces it and niri is left with no renderer (blank session).
  boot.initrd.kernelModules = [ "nvidia" "nvidia_modeset" "nvidia_uvm" "nvidia_drm" ];

  # ── Networking ──
  networking.hostName = "hyprland-btw";
  networking.networkmanager.enable = true;

  # ── Nvidia GTX 1080 ──
  hardware.nvidia = {
    modesetting.enable = true;
    open = false;
    package = config.boot.kernelPackages.nvidiaPackages.legacy_580;
    nvidiaSettings = true;
  };
  hardware.graphics.enable = true;
  hardware.graphics.enable32Bit = true;
  services.xserver.videoDrivers = [ "nvidia" ];

  # X11 apps (Steam, WhatsApp, Proton Mail) run through niri's xwayland-satellite integration.
  programs.xwayland.enable = true;

  environment.sessionVariables = {
    GBM_BACKEND = "nvidia-drm";
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";
    WLR_NO_HARDWARE_CURSORS = "1";
    XDG_SESSION_TYPE = "wayland";
    NIXOS_OZONE_WL = "1";
  };

  # ── Steam + gaming ──
  programs.steam.enable = true;

  # ── Local LLM runtime ──
  # GTX 1080: Nixpkgs CUDA builds target newer SMs; use Vulkan for Pascal GPU offload. Expose on LAN for
  # laptop clients while keeping the model store on the desktop.
  services.ollama = {
    enable = true;
    package = ollamaPkgs.ollama-vulkan;
    host = "0.0.0.0";
    port = 11434;
    openFirewall = true;
  };

  # ── Desktop-only packages ──
  environment.systemPackages = with pkgs; [
    lm_sensors
    ollamaPkgs.ollama
    llama-cpp
    pcsx2
    spotify
    protonmail-desktop
    xwayland-satellite
  ];

  # ── EGL library path for Electron apps on Nvidia ──
  environment.variables.LD_LIBRARY_PATH = [
    "${pkgs.curl.out}/lib"
    "${pkgs.libglvnd}/lib"
    "${config.hardware.nvidia.package}/lib"
  ];

  # WhatsApp via XWayland on Nvidia.
  home-manager.users.julian = { pkgs, lib, config, ... }: {
    home.packages = [ pkgs.whatsapp-electron ];

    # Official Signal AppImage — self-updating; avoids stale nixpkgs auth failures. x86_64 only.
    home.activation.installSignalAppImage = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      set -eu
      mkdir -p "$HOME/.local/opt/signal"
      APPIMAGE="$HOME/.local/opt/signal/signal-desktop.AppImage"
      if [ ! -f "$APPIMAGE" ]; then
        ${pkgs.curl}/bin/curl -fsSL -o "$APPIMAGE" https://updates.signal.org/desktop/signal-desktop.AppImage
        chmod +x "$APPIMAGE"
      fi
    '';

    home.file.".local/bin/signal-desktop" = {
      executable = true;
      text = ''
        #!/bin/sh
        exec ${pkgs.appimage-run}/bin/appimage-run         "$HOME/.local/opt/signal/signal-desktop.AppImage"         --password-store=gnome-libsecret         "$@"
      '';
    };

    xdg.dataFile."applications/signal-desktop.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Name=Signal
      Comment=Private messenger
      Exec=signal-desktop %U
      Icon=signal-desktop
      Categories=Network;InstantMessaging;
      Terminal=false
      StartupWMClass=Signal
    '';

    home.file.".local/bin/whatsapp-launch" = {
      executable = true;
      text = ''
        #!/bin/sh
        export NIXOS_OZONE_WL=0
        export DISPLAY="''${DISPLAY:-:0}"
        exec ${pkgs.whatsapp-electron}/bin/whatsapp-electron --ozone-platform=x11 "$@"
      '';
    };

    # Same file name as the package's own entry, so this replaces it instead of listing WhatsApp twice.
    xdg.dataFile."applications/com.github.dagmoller.whatsapp-electron.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Name=WhatsApp
      Comment=WhatsApp Desktop
      Exec=whatsapp-launch %U
      Icon=${pkgs.whatsapp-electron}/share/pixmaps/whatsapp.png
      Categories=Network;InstantMessaging;
      Terminal=false
      StartupWMClass=com.github.dagmoller.whatsapp-electron
    '';

    # Proton Mail needs XWayland (native Wayland doesn't work)
    xdg.dataFile."applications/proton-mail.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Name=Proton Mail
      Exec=proton-mail --ozone-platform=x11 --no-sandbox %U
      Icon=proton-mail
      Categories=Network;Email;
    '';

    # Steam's CEF UI must use XWayland; native Ozone Wayland can map a blank window.
    xdg.dataFile."applications/steam.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Name=Steam
      Exec=${pkgs.coreutils}/bin/env NIXOS_OZONE_WL=0 steam -cef-disable-gpu %U
      Icon=steam
      Categories=Game;
      Terminal=false
      MimeType=x-scheme-handler/steam;
    '';
  };

  # ── Console ──
  console = {
    earlySetup = true;
    font = "${pkgs.terminus_font}/share/consolefonts/ter-v16n.psf.gz";
    packages = with pkgs; [ terminus_font ];
    keyMap = "us";
  };
}
