# Shared system configuration — common to all hosts
{ config, lib, pkgs, inputs, ... }:
{
  imports = [
    inputs.qs.nixosModules.default
    ./modules/greeter.nix
    ./modules/messaging.nix
    ./modules/files.nix
  ];

  # ── Time ──
  time.timeZone = "America/Denver";

  # ── SSH ──
  # Keys only. The keys are declared here so both hosts accept them without a password ever being needed
  # to put one in place.
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
    };
  };

  # ── XDG Desktop Portal ──
  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-gtk
      xdg-desktop-portal-wlr
    ];
    config = {
      niri = {
        default = lib.mkForce [ "gtk" "wlr" ];
        "org.freedesktop.impl.portal.FileChooser" = [ "gtk" ];
        "org.freedesktop.impl.portal.Screenshot" = [ "wlr" ];
        "org.freedesktop.impl.portal.ScreenCast" = [ "wlr" ];
      };
    };
  };

  # ── Compositor ──
  programs.niri.enable = true;

  # ── Shell (Quickshell bar, wallpaper) ──
  services.qs = {
    enable = true;
    wallpaper = ../niri/wallpapers/tj-holowaychuk-mist-over-banff-ave.jpg;
  };

  # ── Bluetooth ──
  hardware.bluetooth.enable = true;

  # ── Disk automount ──
  services.udisks2.enable = true;

  # ── Fish ──
  programs.fish.enable = true;

  # ── User ──
  users.users.julian = {
    shell = pkgs.fish;
    isNormalUser = true;
    extraGroups = [ "wheel" "video" "render" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKTAb71YzUdWLk+hh7H9ebO/MMibcBc50uQ1jkuvPpwP"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINL3Z21QY/cIzOG9JP+mtcoFpvCUJT1U3SVWDWd0x+xW julian@macbook-pro"
    ];
  };

  # ── Security ──
  security.sudo.wheelNeedsPassword = false;
  # The lock screen (niri/lock.sh), with the PAM service it checks the password against.
  programs.hyprlock.enable = true;
  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if ((action.id == "org.freedesktop.login1.suspend" ||
           action.id == "org.freedesktop.login1.reboot" ||
           action.id == "org.freedesktop.login1.power-off" ||
           action.id == "org.freedesktop.login1.hibernate") &&
          subject.isInGroup("wheel")) {
        return polkit.Result.YES;
      }
    });
    polkit.addRule(function(action, subject) {
      if ((action.id == "org.freedesktop.udisks2.filesystem-mount" ||
           action.id == "org.freedesktop.udisks2.filesystem-mount-system" ||
           action.id == "org.freedesktop.udisks2.filesystem-unmount-others") &&
          subject.isInGroup("wheel")) {
        return polkit.Result.YES;
      }
    });
    polkit.addRule(function(action, subject) {
      if (action.id.indexOf("org.freedesktop.NetworkManager.") === 0 &&
          subject.isInGroup("wheel")) {
        return polkit.Result.YES;
      }
    });
  '';

  # ── Fonts ──
  fonts.packages = with pkgs; [
    plemoljp-nf
    nerd-fonts.jetbrains-mono
    ibm-plex
    noto-fonts-color-emoji
  ];

  # ── Shared packages (work on all hosts) ──
  environment.systemPackages = with pkgs; [
    bat
    btop
    eza
    fd
    bun
    fastfetch
    fzf
    gh
    ghostty
    git
    bluetuith
    udiskie
    libnotify
    jujutsu
    lazygit
    mise
    neovim
    ripgrep
    stow
    tmux
    uv
    vim
    wget
    yazi
    # Communication (Signal and WhatsApp are set per host)
    telegram-desktop
    vesktop
    element-desktop
    bitwarden-desktop
    # Productivity
    obsidian
    openscad
    # Utilities
    wl-clipboard
    brightnessctl
    grim
    slurp
    wf-recorder
  ];

  # ── Nix settings ──
  nixpkgs.config.allowUnfree = true;
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  # Everything comes from the flake; no channels.
  nix.channel.enable = false;

  # ── Generation pruning ──
  # A week of generations stays to roll back to; older ones and what only they used are collected daily.
  nix.gc = {
    automatic = true;
    dates = "daily";
    options = "--delete-older-than 7d";
  };
  boot.loader.systemd-boot.configurationLimit = 10;
}
