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

  boot.kernelPatches = [
    {
      # ── Asahi render patch ──
      # Remove ioctl::AUTH from asahi DRM ioctls so non-root render clients
      # (Mesa) can submit without master auth. Upstream keeps AUTH on; this
      # patch drops it. Flows into the kernel build via the apple-silicon
      # module's _kernelPatches mechanism.
      name = "asahi-render-no-auth";
      patch = ./asahi-render-auth.patch;
    }
  ];

  # ── Networking ──
  networking.hostName = "macbook-pro";
  networking.networkmanager.enable = true;
  networking.networkmanager.wifi.backend = "iwd";

  # Keep development sessions reachable while unattended. Explicit suspend
  # and Super+Alt+L locking remain available.
  services.logind.settings.Login = {
    IdleAction = "ignore";
  };

  # ── Keyboard layout fix ──
  boot.extraModprobeConfig = ''
    options hid_apple iso_layout=0
  '';

  # ── Asahi firmware ──
  hardware.asahi.enable = true;
  hardware.asahi.peripheralFirmwareDirectory = /boot/vendorfw;

  # Upstream apple-silicon module defaults to /boot/vendorfw/firmware.cpio
  # (put there by the Asahi installer). No explicit config needed.

  # ── Battery: limit charge to 80% to preserve lifespan ──
  systemd.services.battery-charge-limit = {
    description = "Limit battery charge to 80%";
    after = [ "sysinit.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      echo 80 > /sys/class/power_supply/macsmc-battery/charge_control_end_threshold
    '';
  };

  # ── Console ──
  console = {
    earlySetup = true;
    keyMap = "us";
  };
}
