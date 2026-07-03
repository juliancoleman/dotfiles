# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{ config, lib, pkgs, ... }:

{
  imports =
    [
      ./hardware-configuration.nix
    ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelModules = [ "nct6775" ];
  
  networking.hostName = "hyprland-btw";
  networking.networkmanager.enable = true;
  hardware.bluetooth.enable = true;
  # Nvidia GTX 1080
  hardware.nvidia = {
    modesetting.enable = true;
    open = false;  # proprietary drivers
    package = config.boot.kernelPackages.nvidiaPackages.stable;
    nvidiaSettings = true;  # provides nvidia-smi
  };
  hardware.graphics.enable = true;
  services.xserver.videoDrivers = [ "nvidia" ];
  environment.sessionVariables = {
    GBM_BACKEND = "nvidia-drm";
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";
    WLR_NO_HARDWARE_CURSORS = "1";
    XDG_SESSION_TYPE = "wayland";
    NIXOS_OZONE_WL = "1";
  };

  time.timeZone = "America/Denver";
  # Boot login: greetd auto-launches Niri, hyprlock locks on startup
  # (seamless: swww paints wallpaper → hyprlock frosted glass → unlock → sharp wallpaper)
  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "niri-session";
        user = "julian";
      };
    };
  };
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = true;
    };
  };

  # XDG Desktop Portal: use GTK + wlr instead of GNOME
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

  programs.niri.enable = true;
  programs.xwayland.enable = true;
  programs.steam.enable = true;
  services.udisks2.enable = true;

  programs.fish.enable = true; # needs to be enabled here even though we use it also in home-manager
  users.users.julian = {
    shell = pkgs.fish;
    isNormalUser = true;
    extraGroups = [ "wheel" ];
  };

  # Lab-only: allow passwordless sudo so the harness can rebuild remotely
  security.sudo.wheelNeedsPassword = false;
  security.pam.services.hyprlock = {};
  # Allow julian to suspend/reboot/shutdown without interactive auth
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

  fonts.packages = with pkgs; [
    pkgs.plemoljp-nf			# IBM Plex Sans Mono Nerd Font with JP
    pkgs.nerd-fonts.jetbrains-mono	# Self-explanatory
    pkgs.ibm-plex                        # IBM Plex Sans for hyprlock clock
    pkgs.noto-fonts-color-emoji          # Color emoji support
  ];

  environment.systemPackages = with pkgs; [
    bat					# better than cat
    btop				# better than top/htop
    carapace				# completions on things you didn't know you needed
    eza					# better ls with icons!
    fd                                  # better find
    bun                                 # JavaScript runtime
    fastfetch				# we all know why you're here
    fzf					# lots of things depend on fzf, plus it's OP on its own
    gh					# API version of git
    ghostty				# yerp
    git					# yeet
    swww                                # wallpaper daemon (GPU-backed, no leak)
    hyprlock                            # session locker (GPU-accelerated, blur effects)
    bluetuith                            # TUI bluetooth manager (scan/pair/connect in one interface)
    udiskie                             # USB automount + notifications
    mako                                # lightweight Wayland notification daemon
    udisks2                             # D-Bus disk management backend
    lm_sensors                           # sensors-detect, pwmconfig, fancontrol
    libnotify                            # notify-send for bluetooth pairing notifications
    jujutsu				# Graphite, but local
    lazygit				# Because everyone can benefit from a git GUI
    mise				# asdf, direnv, and devtool on roids
    neovim				# hehe
    pay-respects			# f
    ripgrep				# lots of things depend on rg, plus it's OP on its own
    stow				# gotta get those dotfiles somehow
    tmux				# idk if I'm going to keep this or not
    uv					# can be used with mise, replacement for pip
    vim					# every other Linux distro comes with it, we should not discriminate
    waybar				# Cleeeaaaaaannnnn
    wget				# do we even need this?
    wofi				# modal list views for everything and everyone
    yazi				# because I don't have a GUI file manager
    zoxide				# better cd
    # ── Communication ──
    signal-desktop
    telegram-desktop
    vesktop
    element-desktop
    whatsie
    bitwarden-desktop
    spotify
    # ── Productivity ──
    libreoffice
    obsidian
    openscad
    bambu-studio
    # ── Fun ──
    pcsx2
    # ── Utilities ──
    noto-fonts-color-emoji
    wl-clipboard
    grim
    slurp
  ];
  environment.pathsToLink = [ "/share/wayland-sessions" ];

  # VTNR-specific configuration
  console = {
    earlySetup = true;
    font = "${pkgs.terminus_font}/share/consolefonts/ter-v16n.psf.gz";
    packages = with pkgs; [ terminus_font ];
    keyMap = "us";
  };

  nixpkgs.config.allowUnfree = true;
  nixpkgs.config.permittedInsecurePackages = [ "qtwebengine-5.15.19" ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  # This option defines the first version of NixOS you have installed on this particular machine,
  # and is used to maintain compatibility with application data (e.g. databases) created on older NixOS versions.
  #
  # Most users should NEVER change this value after the initial install, for any reason,
  # even if you've upgraded your system to a new NixOS release.
  #
  # This value does NOT affect the Nixpkgs version your packages and OS are pulled from,
  # so changing it will NOT upgrade your system - see https://nixos.org/manual/nixos/stable/#sec-upgrading for how
  # to actually do that.
  #
  # This value being lower than the current NixOS release does NOT mean your system is
  # out of date, out of support, or vulnerable.
  #
  # Do NOT change this value unless you have manually inspected all the changes it would make to your configuration,
  # and migrated your data accordingly.
  #
  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "25.11"; # Did you read the comment?
}
