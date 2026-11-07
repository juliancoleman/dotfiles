{ self }:
{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib) mkEnableOption mkIf mkOption types;
  cfg = config.programs.qs;
  secure = cfg.secureInput;
  defaultPackage = self.packages.${pkgs.stdenv.hostPlatform.system}.default;
  askpass = "${secure.package}/bin/qs-askpass";
  askpassVariables = lib.optionalAttrs secure.sudo { SUDO_ASKPASS = askpass; }
    // lib.optionalAttrs secure.ssh {
      SSH_ASKPASS = askpass;
      # ssh only uses askpass without a terminal unless asked to prefer it; git follows SSH_ASKPASS.
      SSH_ASKPASS_REQUIRE = "prefer";
    };
  wallpaperPath = if cfg.wallpaper == null then ""
    else if builtins.isPath cfg.wallpaper then "${cfg.wallpaper}"
    else cfg.wallpaper;
  wallpaperCommand = lib.escapeShellArgs [
    "${pkgs.swaybg}/bin/swaybg"
    "-i"
    wallpaperPath
    "-m"
    cfg.wallpaperMode
  ];
  restartPolicy = {
    Restart = "on-failure";
    RestartSec = "2s";
  };
in
{
  options.programs.qs = {
    enable = mkEnableOption "the QS desktop shell";

    package = mkOption {
      type = types.package;
      default = defaultPackage;
      defaultText = lib.literalExpression "self.packages.\${pkgs.stdenv.hostPlatform.system}.default";
      description = "QS package containing shell launchers and packaged defaults.";
    };

    wallpaper = mkOption {
      type = types.nullOr (types.either types.path (types.strMatching "^/.*"));
      default = null;
      example = "/etc/qs/wallpaper";
      description = "Wallpaper passed to swaybg. The wallpaper service is omitted when null.";
    };

    wallpaperMode = mkOption {
      type = types.enum [ "stretch" "fit" "fill" "center" "tile" ];
      default = "fill";
      description = "swaybg image scaling mode.";
    };

    secureInput = {
      enable = mkEnableOption "routing sudo, ssh, git, and gpg secrets through the shell's secure prompt" // {
        default = true;
      };

      package = mkOption {
        type = types.package;
        default = self.packages.${pkgs.stdenv.hostPlatform.system}.secure-helper;
        defaultText = lib.literalExpression "self.packages.\${pkgs.stdenv.hostPlatform.system}.secure-helper";
        description = "Package providing qs-askpass and pinentry-qs.";
      };

      sudo = mkOption {
        type = types.bool;
        default = true;
        description = "Alias sudo to `sudo -A` with qs-askpass. Over SSH it falls back to the terminal.";
      };

      ssh = mkOption {
        type = types.bool;
        default = true;
        description = "Use qs-askpass for ssh passphrases and git credentials.";
      };

      gpg = mkOption {
        type = types.bool;
        default = config.services.gpg-agent.enable;
        defaultText = lib.literalExpression "config.services.gpg-agent.enable";
        description = "Use pinentry-qs as gpg-agent's pinentry.";
      };
    };

    paths.configFile = mkOption {
      type = types.strMatching "^/.*";
      default = "${config.xdg.configHome}/qs/config.json";
      description = "Mutable configuration seeded on first activation.";
    };
  };

  config = mkIf cfg.enable {
    home.sessionVariables = {
      QS_CONFIG_FILE = cfg.paths.configFile;
    } // lib.optionalAttrs secure.enable askpassVariables;

    # Apps started by niri or systemd never read the login shell's variables.
    systemd.user.sessionVariables = mkIf secure.enable askpassVariables;

    home.shellAliases = mkIf (secure.enable && secure.sudo) { sudo = "sudo -A"; };

    services.gpg-agent.pinentry.package = mkIf (secure.enable && secure.gpg) secure.package;

    home.packages = lib.optional secure.enable secure.package ++ [
      cfg.package
      pkgs.quickshell
      pkgs.swaybg
      pkgs.ibm-plex
      pkgs.plemoljp-nf
    ];

    systemd.user.services.qs-shell = {
      Unit = {
        Description = "QS desktop shell";
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session-pre.target" ];
        StartLimitIntervalSec = 30;
        StartLimitBurst = 5;
      };
      Service = restartPolicy // {
        ExecStart = "${cfg.package}/bin/qs-shell";
        # The matugen palette generates its colors from the wallpaper.
        Environment = [ "QS_CONFIG_FILE=${cfg.paths.configFile}" ]
          ++ lib.optional (cfg.wallpaper != null) "QS_WALLPAPER=${wallpaperPath}";
      };
    };

    systemd.user.services.qs-wallpaper = mkIf (cfg.wallpaper != null) {
      Unit = {
        Description = "QS wallpaper";
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session.target" ];
        StartLimitIntervalSec = 30;
        StartLimitBurst = 5;
      };
      Service = restartPolicy // {
        ExecStart = wallpaperCommand;
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };

    # A hand-installed dev shim earlier on PATH would keep shadowing the packaged qs-shell after a switch.
    home.activation.qsRemoveDevShim = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      shim=${lib.escapeShellArg "${config.home.homeDirectory}/.local/bin/qs-shell"}
      if [ -f "$shim" ] && ${pkgs.gnugrep}/bin/grep -q 'qs-dev-shim' "$shim"; then
        $DRY_RUN_CMD rm -f "$shim"
      fi
    '';

    home.activation.qsSeedConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if [ ! -e ${lib.escapeShellArg cfg.paths.configFile} ] && [ ! -L ${lib.escapeShellArg cfg.paths.configFile} ]; then
        $DRY_RUN_CMD mkdir -p ${lib.escapeShellArg (builtins.dirOf cfg.paths.configFile)}
        $DRY_RUN_CMD install -m 0600 \
          ${lib.escapeShellArg "${cfg.package}/share/qs/config/default.json"} \
          ${lib.escapeShellArg "${cfg.paths.configFile}.qs-seed"}".$$"
        $DRY_RUN_CMD mv -n \
          ${lib.escapeShellArg "${cfg.paths.configFile}.qs-seed"}".$$" \
          ${lib.escapeShellArg cfg.paths.configFile}
        $DRY_RUN_CMD rm -f ${lib.escapeShellArg "${cfg.paths.configFile}.qs-seed"}".$$"
      fi
    '';
  };
}
