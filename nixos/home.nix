{ config, pkgs, ... }:

{
  home.username = "julian";
  home.homeDirectory = "/home/julian";
  home.stateVersion = "25.05";
  programs.fish = {
    enable = true;
    plugins = [
      {
        name = "foreign-env";
        src = pkgs.fishPlugins.foreign-env.src;
      }
    ];
  };
  home.sessionVariables = {
    IS_NIXOS = "1"; # we're going to use this with Fish to set some things in config.fish
  };
  # programs.bash = {
  #   enable = true;
  #   shellAliases = {
  #     nrs = "sudo nixos-rebuild switch --flake ~/dotfiles/nixos#hyprland-btw";
  #   };
  #   profileExtra = ''
  #     if [ -z "$WAYLAND_DISPLAY" ] && [ "$XDG_VTNR" = 1 ]; then
  #       exec uwsm start hyprland-uwsm.desktop
  #     fi
  #   '';
  # };
}
