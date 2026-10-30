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
  # wpa_supplicant scans reliably on brcmfmac here; iwd scans time out before
  # reaching later channels. WPA3-only networks may not join with it.
  networking.networkmanager.wifi.backend = "wpa_supplicant";
  # Prevent the USB Ethernet dongle from being autosuspended during s2idle.
  boot.kernelParams = [ "usbcore.autosuspend=-1" ];

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

  # Signal's AppImage is x86_64-only, so this host uses the nixpkgs build. Signal
  # refuses clients that fall too far behind, so keep nixpkgs current.
  home-manager.users.julian = { pkgs, config, ... }: {
    home.packages = [ pkgs.signal-desktop ];

    home.file.".local/bin/signal-desktop" = {
      executable = true;
      text = ''
        #!/bin/sh
        exec ${pkgs.signal-desktop}/bin/signal-desktop --password-store=gnome-libsecret "$@"
      '';
    };

    xdg.dataFile."applications/signal.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Name=Signal
      Comment=Private messenger
      Exec=${config.home.homeDirectory}/.local/bin/signal-desktop %U
      Icon=signal-desktop
      Categories=Network;InstantMessaging;
      Terminal=false
      StartupWMClass=signal
      MimeType=x-scheme-handler/sgnl;x-scheme-handler/signalcaptcha;
    '';
  };

  # ── Console ──
  console = {
    earlySetup = true;
    keyMap = "us";
  };
}
