# Desktop host — Nvidia GTX 1080, B450 Tomahawk Max, dual SSD
{ config, lib, pkgs, nixpkgs-ollama, ... }:
let
  ollamaPkgs = import nixpkgs-ollama {
    system = pkgs.stdenv.hostPlatform.system;
    config.allowUnfree = true;
  };
in
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
    whatsie
    bambu-studio
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
