# Desktop host — Nvidia GTX 1080, B450 Tomahawk Max, dual SSD
{ config, lib, pkgs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./steam-mount.nix
    ../../shared/system.nix
  ];

  # ── Boot ──
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelModules = [ "nct6775" ];  # fan control

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

  # ── Desktop-only packages ──
  environment.systemPackages = with pkgs; [
    lm_sensors
    pcsx2
    xwayland-satellite
  ];

  # ── EGL library path for Electron apps on Nvidia ──
  environment.variables.LD_LIBRARY_PATH = [
    "${pkgs.curl.out}/lib"
    "${pkgs.libglvnd}/lib"
    "${pkgs.linuxPackages.nvidia_x11}/lib"
  ];

  # ── Console ──
  console = {
    earlySetup = true;
    font = "${pkgs.terminus_font}/share/consolefonts/ter-v16n.psf.gz";
    packages = with pkgs; [ terminus_font ];
    keyMap = "us";
  };
}
