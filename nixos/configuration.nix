# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{ config, lib, pkgs, ... }:

{
  imports =
    [
      ./hardware-configuration.nix
      ./specialisations.nix
    ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  
  networking.hostName = "hyprland-btw";
  networking.networkmanager.enable = true;
  hardware.bluetooth.enable = true;

  time.timeZone = "America/Denver";

  services.getty.autologinUser = "julian";

  programs.fish.enable = true; # needs to be enabled here even though we use it also in home-manager
  users.users.julian = {
    shell = pkgs.fish;
    isNormalUser = true;
    extraGroups = [ "wheel" ];
  };

  fonts.packages = with pkgs; [
    pkgs.plemoljp-nf			# IBM Plex Sans Mono Nerd Font with JP
    pkgs.nerd-fonts.jetbrains-mono	# Self-explanatory
  ];

  environment.systemPackages = with pkgs; [
    bat					# better than cat
    btop				# better than top/htop
    carapace				# completions on things you didn't know you needed
    eza					# better ls with icons!
    fastfetch				# we all know why you're here
    fzf					# lots of things depend on fzf, plus it's OP on its own
    gh					# API version of git
    ghostty				# yerp
    git					# yeet
    hyprpaper				# I just wanna see TJ Holowaychuk photos
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
  ];

  # VTNR-specific configuration
  console = {
    earlySetup = true;
    font = "${pkgs.terminus_font}/share/consolefonts/ter-v16n.psf.gz";
    packages = with pkgs; [ terminus_font ];
    keyMap = "us";
  };

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
