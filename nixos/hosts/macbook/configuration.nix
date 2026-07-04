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
  # Use structuredExtraConfig with mkForce to override nixpkgs defaults.
  boot.kernelPatches = [{
    name = "linux-7.0-arm64-fix";
    patch = null;
    structuredExtraConfig = with lib.kernel; {
      PREEMPT = lib.mkForce yes;
      PREEMPT_VOLUNTARY = lib.mkForce (option no);
      FB_HYPERV = lib.mkForce (option no);
      HIPPI = lib.mkForce (option no);
      NFS_V4_1 = lib.mkForce (option no);
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
