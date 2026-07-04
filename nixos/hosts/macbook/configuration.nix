# MacBook Pro M2 Pro host — Asahi Linux
{ config, lib, pkgs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ../../shared/system.nix
  ];

  # ── Boot (Asahi uses m1n1 + U-Boot, not GRUB/systemd-boot) ──
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = false;

  # ── Fix Linux 7.0 kernel config for ARM64 ──
  # Linux 7.0 removed several config options on ARM64.
  # We need to override them with higher priority than nixpkgs defaults.
  boot.kernelPatches = [{
    name = "linux-7.0-arm64-fix";
    patch = null;
    extraStructuredConfig = {
      PREEMPT = "y";
      PREEMPT_VOLUNTARY = null;
      FB_HYPERV = null;
      HIPPI = null;
      NFS_V4_1 = null;
    };
  }];

  # ── Networking ──
  networking.hostName = "macbook-pro";
  networking.networkmanager.enable = true;
  networking.networkmanager.wifi.backend = "iwd";

  # ── Keyboard layout fix ──
  boot.extraModprobeConfig = ''
    options hid_apple iso_layout=0
  '';

  # ── Asahi firmware ──
  hardware.asahi.peripheralFirmwareDirectory = ./firmware;

  # ── Console ──
  console = {
    earlySetup = true;
    keyMap = "us";
  };
}
