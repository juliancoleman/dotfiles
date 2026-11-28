# Shared system configuration — common to all hosts
{ config, lib, pkgs, inputs, ... }:
{
  imports = [
    inputs.qs.nixosModules.default
    ./modules/greeter.nix
    ./modules/messaging.nix
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
  # OpenSSH's own agent rather than the keyring's. A key joins it the first time it is used.
  services.gnome.gcr-ssh-agent.enable = false;
  programs.ssh = {
    startAgent = true;
    extraConfig = "AddKeysToAgent yes";
    # 10.6p2 (2026-11-05) is a security release that the pinned nixpkgs does not carry yet. The server,
    # the agent and `ssh` use it; this steps aside by itself once nixpkgs is at or past that version.
    package =
      if lib.versionOlder pkgs.openssh.version "10.6p2" then
        pkgs.openssh.overrideAttrs (old: rec {
          version = "10.6p2";
          src = pkgs.fetchurl {
            url = "mirror://openbsd/OpenSSH/portable/openssh-${version}.tar.gz";
            hash = "sha256-muRIcgkM8vBrPPn/FH5/FvMJZxNAdj7S+ZJIOYrinVs=";
          };
        })
      else
        pkgs.openssh;
  };

  # ── XDG Desktop Portal ──
  # File dialogs come from the GTK portal and screen capture from the wlroots one. The niri module also
  # installs the GNOME portal, which nothing here is routed to, so the list is stated in full: these two,
  # and the keyring's, which serves apps their secrets.
  xdg.portal = {
    enable = true;
    extraPortals = lib.mkForce (with pkgs; [
      xdg-desktop-portal-gtk
      xdg-desktop-portal-wlr
      gnome-keyring
    ]);
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
  # The module would otherwise install Nautilus to draw file dialogs; the GTK portal draws them here.
  programs.niri.useNautilus = false;

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
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDxF/F6bhTxPDpVXpaEFL5B7PEiqYyfS7Tsito2TAL5x julian@desktop"
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

  # ── Home services (what every machine needs to use them) ──
  # The MacBook serves contacts and calendar at https://macbook-pro.local (hosts/macbook/services.nix).
  # That name resolves over mDNS, and its certificate comes from the MacBook's own one-certificate CA.
  services.avahi = {
    enable = true;
    nssmdns4 = true;
  };
  security.pki.certificateFiles = [ ../hosts/macbook/home-ca.crt ];

  # ── Vault and game-save sync ──
  # Syncthing keeps ~/obsidian-vault and ~/game-saves the same on every machine. It stays on the home
  # network: no public discovery servers, relays or port mapping. Devices and folders are paired in the
  # GUI (http://127.0.0.1:8384) and kept as paired.
  services.syncthing = {
    enable = true;
    user = "julian";
    dataDir = "/home/julian";
    configDir = "/home/julian/.config/syncthing";
    openDefaultPorts = true;
    overrideDevices = false;
    overrideFolders = false;
    settings.options = {
      globalAnnounceEnabled = false;
      relaysEnabled = false;
      natEnabled = false;
      urAccepted = -1;
      crashReportingEnabled = false;
    };
  };

  # ── NAS ──
  # The drive on the router, mounted when something looks into /mnt/nas. Its login is not in the repo:
  # /var/lib/secrets/nas.credentials holds two lines, username=… and password=…, mode 600.
  systemd.tmpfiles.settings."10-secrets"."/var/lib/secrets".d = { mode = "0751"; user = "root"; group = "root"; };
  fileSystems."/mnt/nas" = {
    device = "//192.168.0.1/H";
    fsType = "cifs";
    options = [
      "credentials=/var/lib/secrets/nas.credentials"
      # The router's file server speaks SMB 2.0 and nothing newer; the kernel's default asks for 2.1+.
      "vers=2.0"
      "noauto"
      "nofail"
      "x-systemd.automount"
      "x-systemd.idle-timeout=10min"
      "x-systemd.mount-timeout=20s"
      "uid=julian"
      "gid=users"
      "file_mode=0600"
      "dir_mode=0700"
    ];
  };

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
    # Electron does not know niri as a desktop and would keep Obsidian's keychain in plain text; this
    # names the keyring that is running (the same flag Signal gets).
    (obsidian.override { commandLineArgs = "--password-store=gnome-libsecret"; })
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
