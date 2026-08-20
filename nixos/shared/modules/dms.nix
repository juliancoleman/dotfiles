# DankMaterialShell — Banff Mist, frosted bar, niri workspace filter, no Wallpapers tab.
# On by default for every host so `nixos-rebuild switch` matches desktop and laptop.
{ config, lib, pkgs, dank-material-shell ? null, ... }:
let
  cfg = config.julian.dms;
  themeFile = ../../niri/dms-theme-banff-mist.json;
  wallpaperFile = ../../niri/wallpapers/tj-holowaychuk-mist-over-banff-ave.jpg;
in
{
  options.julian.dms.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "DankMaterialShell with the shared Banff Mist look";
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = dank-material-shell != null;
        message = "julian.dms.enable requires flake specialArgs.dank-material-shell";
      }
    ];

    nixpkgs.overlays = [ (import ../../overlays/dms-niri-named-workspaces.nix) ];

    home-manager.users.julian = { pkgs, config, ... }: {
      imports = [ dank-material-shell.homeModules.dank-material-shell ];

      xdg.configFile."DankMaterialShell/themes/banff-mist.json".source = themeFile;

      programs.dank-material-shell = {
        enable = true;
        package = pkgs.dms-shell;
        systemd.enable = true;
        systemd.target = "graphical-session.target";

        settings = {
          currentThemeName = "custom";
          customThemeFile = "${config.xdg.configHome}/DankMaterialShell/themes/banff-mist.json";
          popupTransparency = 0.90;
          use24HourClock = false;
          useFahrenheit = true;
          weatherEnabled = true;
          frameLauncherEdgeHover = false;
          showWorkspaceIndex = false;
          showWorkspaceName = false;
          showWorkspaceApps = false;
          showWorkspacePadding = false;
          barConfigs = [
            {
              id = "default";
              name = "Main Bar";
              enabled = true;
              position = 3;
              screenPreferences = [ "all" ];
              showOnLastDisplay = true;
              leftWidgets = [ "workspaceSwitcher" ];
              centerWidgets = [ "clock" ];
              rightWidgets = [
                "bluetooth"
                "cpuUsage"
                "memUsage"
                "diskUsage"
                "notificationButton"
                "controlCenterButton"
              ];
              spacing = 2;
              innerPadding = -6;
              barLengthPadding = 0;
              bottomGap = 0;
              attachToScreenEdge = true;
              fontScale = 1.0;
              # Frosted pills: translucent gray glass, high-contrast text from custom theme
              # 0.65 is the experimental lower bound (time ~6.8:1 / date ~4.6:1 over forest)
              transparency = 0;
              widgetTransparency = 0.65;
              noBackground = false;
              borderEnabled = false;
              widgetOutlineEnabled = true;
              widgetOutlineColor = "surfaceText";
              widgetOutlineOpacity = 1.00;
              widgetOutlineThickness = 1;
            }
          ];
        };

        session = {
          wallpaperPath = "${wallpaperFile}";
          wallpaperTransition = "none";
          isLightMode = true;
        };
      };
    };
  };
}
