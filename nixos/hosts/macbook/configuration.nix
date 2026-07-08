# MacBook Pro M2 Pro host — Asahi Linux
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
    {
      # ── Asahi kernel config fix ──
      # The asahi kernel (7.0) still lacks several options nixpkgs expects.
      # Use `option` to suppress the config checker error for missing options.
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
    }
  ];

  # ── Networking ──
  networking.hostName = "macbook-pro";
  networking.networkmanager.enable = true;
  networking.networkmanager.wifi.backend = "iwd";

  # ── Local LLM runtime ──
  # Laptop runs Ollama locally for offline chat/coding. Keep it bound to localhost;
  # the desktop remains the LAN-facing GPU-backed server.
  services.ollama = {
    enable = true;
    package = ollamaPkgs.ollama;
    host = "127.0.0.1";
    port = 11434;
    openFirewall = false;
  };

  environment.systemPackages = [
    ollamaPkgs.ollama
  ];

  # ── Keyboard layout fix ──
  boot.extraModprobeConfig = ''
    options hid_apple iso_layout=0
  '';

  # ── Asahi firmware ──
  # Explicit path is needed because the default uses builtins.pathExists
  # which can fail under Nix's sandboxed evaluator on newer nixpkgs.
  hardware.asahi.peripheralFirmwareDirectory = lib.mkDefault /boot/vendorfw;
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
