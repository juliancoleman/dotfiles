# MacBook Pro M2 Pro host — Asahi Linux
{ config, lib, pkgs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ../../shared/system.nix
  ];

  # ── Boot (Asahi uses m1n1, not systemd-boot) ──
  # Asahi-specific bootloader config goes here after install

  # ── Networking ──
  networking.hostName = "macbook-pro";
  networking.networkmanager.enable = true;

  # ── Asahi hardware ──
  # These will be filled in after the Asahi install generates hardware-configuration.nix
  # hardware.asahi = {
  #   enable = true;
  #   withAudio = true;
  # };

  # ── No Steam (Asahi GPU doesn't support gaming) ──
  # programs.steam.enable = false;  # not enabled in shared config

  # ── No Nvidia-specific packages ──
  # No LD_LIBRARY_PATH, no nvidia drivers, no fan control

  # ── Battery: charge limit to 80% ──
  # TODO: Add services.udev.extraRules for battery charge limit
  # TODO: Add notification when capacity hits 80%

  # ── Console ──
  console = {
    earlySetup = true;
    keyMap = "us";
  };
}
