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

  # ── Fix Linux 7.0 PREEMPT config change on ARM64 ──
  boot.kernelPatches = [{
    name = "preempt-fix";
    patch = null;
    structuredExtraConfig = with lib.kernel; {
      PREEMPT = yes;
      PREEMPT_VOLUNTARY = no;
      FB_HYPERV = no;
      HIPPI = no;
      NFS_V4_1 = no;
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
