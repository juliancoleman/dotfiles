# Desk communication: the keyring Signal stores its key in, and the runner for the desktop's Signal AppImage.
{ config, lib, pkgs, ... }:
{
  services.gnome.gnome-keyring.enable = lib.mkDefault true;

  # The password typed at the greeter unlocks the keyring.
  security.pam.services.greetd.enableGnomeKeyring = lib.mkDefault true;

  # appimage-run runs the desktop's Signal; seahorse shows what the keyring holds.
  environment.systemPackages = [ pkgs.appimage-run pkgs.seahorse ];
}
