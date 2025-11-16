# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{ config, lib, pkgs, ... }:

{
  imports =
    [
      ./hardware-configuration.nix
    ];

  # Uncomment if doing this in a VirtualBox instance
  # virtualisation.virtualbox.guest.enable = true;
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  
  networking.hostName = "hyprland-btw";
  networking.networkmanager.enable = true;

  time.timeZone = "America/Denver";

  services.getty.autologinUser = "julian";

  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
    withUWSM = true;
  };

  programs.fish.enable = true; # needs to be enabled here even though we use it also in home-manager
  users.users.julian = {
    shell = pkgs.fish;
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    packages = with pkgs; [  ];
  };

  environment.systemPackages = with pkgs; [
    bat
    btop
    carapace
    eza
    fastfetch
    fzf
    gh
    ghostty
    git
    hyprpaper
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
  system.stateVersion = "25.05"; # Did you read the comment?

}

