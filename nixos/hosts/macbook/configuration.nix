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

  # ── Keyboard layout fix ──
  boot.extraModprobeConfig = ''
    options hid_apple iso_layout=0
  '';

  # ── Asahi firmware ──
  hardware.asahi.enable = true;
  hardware.asahi.peripheralFirmwareDirectory = /boot/vendorfw;

  # Upstream apple-silicon module defaults to /boot/vendorfw/firmware.cpio
  # (put there by the Asahi installer). No explicit config needed.

  # ── Battery: hold at 80%, top up to 100% once a week ──
  # The SMC limit is 80 or 100. Every 7 days the limit lifts to 100 until the
  # SMC reports the battery full, which stamps the week and drops back to 80.
  # (At a 100 limit macsmc-power says Full only from the SMC's own full flags;
  # Not charging there means an inhibitor such as heat, not a full battery.)
  # The stamp lives in /var/lib, so a reboot mid-charge doesn't cancel that
  # week's top-up.
  # Force one now: sudo touch -d '8 days ago' /var/lib/battery-charge-limit/last-full
  systemd.services.battery-charge-limit = {
    description = "Battery charge limit (80%, 100% once a week)";
    after = [ "sysinit.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      StateDirectory = "battery-charge-limit";
    };
    script = ''
      bat=/sys/class/power_supply/macsmc-battery
      stamp=/var/lib/battery-charge-limit/last-full
      [ -e "$stamp" ] || touch "$stamp"
      limit=$(cat $bat/charge_control_end_threshold)
      if [ "$limit" = 100 ] && [ "$(cat $bat/status)" = Full ]; then
        touch "$stamp"
      fi
      age=$(( $(date +%s) - $(stat -c %Y "$stamp") ))
      want=80
      [ "$age" -lt 604800 ] || want=100
      [ "$limit" = "$want" ] || echo "$want" > $bat/charge_control_end_threshold
    '';
  };
  systemd.timers.battery-charge-limit = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "5min";
      OnUnitActiveSec = "10min";
    };
  };

  # Signal's AppImage is x86_64-only, so this host uses the nixpkgs build. Signal
  # refuses clients that fall too far behind, so keep nixpkgs current.
  home-manager.users.julian = { pkgs, config, ... }: {
    home.packages = [ pkgs.signal-desktop pkgs.whatsapp-electron ];

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
