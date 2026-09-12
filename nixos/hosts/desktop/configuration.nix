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
  boot.kernelModules = [ "nct6775" ];  # fan control
  # NCT6797D PWM sysfs group-writable so the control center can set manual/auto
  # without sudo. Fires when the hwmon device appears at boot.
  services.udev.extraRules = ''
    SUBSYSTEM=="hwmon", ATTR{name}=="nct6797", RUN+="${pkgs.bash}/bin/bash -c 'chgrp wheel /sys/class/hwmon/%k/pwm* /sys/class/hwmon/%k/pwm*_enable; chmod g+w /sys/class/hwmon/%k/pwm* /sys/class/hwmon/%k/pwm*_enable'"
  '';

  # ── Networking ──
  networking.hostName = "hyprland-btw";
  networking.networkmanager.enable = true;

  # ── Nvidia GTX 1080 ──
  hardware.nvidia = {
    modesetting.enable = true;
    open = false;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
    nvidiaSettings = true;
  };
  hardware.graphics.enable = true;
  hardware.graphics.enable32Bit = true;
  services.xserver.videoDrivers = [ "nvidia" ];

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
    # Desktop-only heavy apps (qtwebengine — too heavy for MacBook)
    bambu-studio
  ];

  # ── EGL library path for Electron apps on Nvidia ──
  environment.variables.LD_LIBRARY_PATH = [
    "${pkgs.curl.out}/lib"
    "${pkgs.libglvnd}/lib"
    "${pkgs.linuxPackages.nvidia_x11}/lib"
  ];

  julian.dms.enable = true;

  # WhatsApp via XWayland on Nvidia.
  home-manager.users.julian = { pkgs, config, ... }: {
    home.packages = [ pkgs.whatsapp-electron ];

    home.file.".local/bin/whatsapp-launch" = {
      executable = true;
      text = ''
        #!/bin/sh
        export NIXOS_OZONE_WL=0
        export DISPLAY="''${DISPLAY:-:0}"
        exec ${pkgs.whatsapp-electron}/bin/whatsapp-electron --ozone-platform=x11 "$@"
      '';
    };

    xdg.dataFile."applications/whatsapp.desktop".text = ''
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
  };

  # ── Console ──
  console = {
    earlySetup = true;
    font = "${pkgs.terminus_font}/share/consolefonts/ter-v16n.psf.gz";
    packages = with pkgs; [ terminus_font ];
    keyMap = "us";
  };
}
