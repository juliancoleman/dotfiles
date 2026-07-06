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

  # ── Kernel config: asahi 6.17 kernel differs from nixpkgs ARM64 defaults ──
  # Several options nixpkgs expects don't exist in the asahi kernel.
  # Use `option` to suppress the config checker error for missing options.
  boot.kernelPatches = [{
    name = "asahi-kernel-config-fix";
    patch = null;
    structuredExtraConfig = with lib.kernel; {
      PREEMPT = lib.mkForce yes;
      PREEMPT_VOLUNTARY = lib.mkForce (option no);
      FB_HYPERV = lib.mkForce (option no);
      HIPPI = lib.mkForce (option no);
      NFS_V4_1 = lib.mkForce (option no);
      NFS_V4_2 = lib.mkForce (option no);
      NFS_V4_SECURITY_LABEL = lib.mkForce (option no);
      NOVA_CORE = lib.mkForce (option no);
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
