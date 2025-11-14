{ config, pkgs, ... }:

{
  home.username = "julian";
  home.homeDirectory = "/home/julian";
  home.stateVersion = "25.05";
  programs.bash = {
    enable = true;
    profileExtra = ''
      if [ -z "$WAYLAND_DISPLAY" ] && [ "$XDG_VTNR" = 1 ]; then
        exec uwsm start hyprland-uwsm.desktop
      fi
    '';
  };
}
