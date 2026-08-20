# Visual file management: Nautilus + GVfs for NAS sidebar and removable media.
{ config, lib, pkgs, ... }:
{
  services.gvfs.enable = lib.mkDefault true;

  environment.systemPackages = with pkgs; [
    nautilus
    seahorse
    gvfs
  ];
}
