# Desk communication: the keyring Signal stores its key in, and tools for the desktop's Signal AppImage.
{ config, lib, pkgs, ... }:
{
  services.gnome.gnome-keyring.enable = lib.mkDefault true;

  security.pam.services.greetd.enableGnomeKeyring = lib.mkDefault true;

  environment.systemPackages = with pkgs; [
    appimage-run
    curl
  ];
}
