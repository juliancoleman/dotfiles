# Desk communication: official Signal AppImage + Electron wrappers.
{ config, lib, pkgs, ... }:
{
  services.gnome.gnome-keyring.enable = lib.mkDefault true;

  security.pam.services.greetd.enableGnomeKeyring = lib.mkDefault true;

  environment.systemPackages = with pkgs; [
    appimage-run
    curl
  ];
}
