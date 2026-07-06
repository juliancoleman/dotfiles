# Shared system configuration — common to all hosts
{ config, lib, pkgs, ... }:
{
  # ── Time ──
  time.timeZone = "America/Denver";

  # ── Boot login ──
  # greetd auto-creates julian's session (no password here).
  # niri starts and immediately spawns hyprlock, which is the sole
  # authentication gate. Single login, GPU-rendered lock screen.
  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "${pkgs.greetd.tuigreet}/bin/tuigreet --time --remember --cmd niri-session";
        user = "greeter";
      };
    };
  };

  # Force niri to use the asahi GPU render node only (skip appledrm display card)
  environment.sessionVariables.WLR_DRM_DEVICES = "/dev/dri/card2:/dev/dri/renderD128";

  # ── SSH ──
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = true;
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
  programs.xwayland.enable = true;

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
  };

  # ── Security ──
  security.sudo.wheelNeedsPassword = false;
  security.pam.services.greetd.rules.session.systemd.settings = {
    type = "wayland";
  };
  security.pam.services.hyprlock = {};
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
  '';

  # ── Fonts ──
  fonts.packages = with pkgs; [
    pkgs.plemoljp-nf
    pkgs.nerd-fonts.jetbrains-mono
    pkgs.ibm-plex
    pkgs.noto-fonts-color-emoji
  ];

  # ── Shared packages (work on all hosts) ──
  environment.systemPackages = with pkgs; [
    bat
    btop
    carapace
    eza
    fd
    bun
    fastfetch
    fzf
    gh
    ghostty
    git
    swww
    hyprlock
    bluetuith
    udiskie
    mako
    udisks2
    libnotify
    jujutsu
    lazygit
    mise
    neovim
    pay-respects
    ripgrep
    stow
    tmux
    uv
    vim
    waybar
    wget
    wofi
    yazi
    zoxide
    # Communication
    signal-desktop
    libglvnd
    telegram-desktop
    vesktop
    element-desktop
    bitwarden-desktop
    # Productivity
    libreoffice
    obsidian
    openscad
    # Utilities
    noto-fonts-color-emoji
    wl-clipboard
    grim
    slurp
  ];

  environment.pathsToLink = [ "/share/wayland-sessions" ];

  # ── Nix settings ──
  nixpkgs.config.allowUnfree = true;
  nixpkgs.config.permittedInsecurePackages = [ "qtwebengine-5.15.19" "pnpm-10.29.2" "electron-39.8.10" ];
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  system.stateVersion = "25.11";
}
