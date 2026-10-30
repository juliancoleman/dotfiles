{ self }:
{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib) mkEnableOption mkIf mkOption types;
  cfg = config.services.qs;
  fans = cfg.fanControl;
  packages = self.packages.${pkgs.stdenv.hostPlatform.system};
  socketPath = "/run/qs-fan-helper.sock";
  fanGroup = "qs-fans";

  # While this marker exists GeoClue refuses to start, so nothing on the system can look up its location.
  locationOffMarker = "/var/lib/qs/location-off";
  systemctl = "${pkgs.systemd}/bin/systemctl";
  whereAmI = pkgs.writeShellScriptBin "where-am-i" ''
    exec ${config.services.geoclue2.package}/libexec/geoclue-2.0/demos/where-am-i "$@"
  '';

  policy = {
    schemaVersion = 2;
    inherit (fans) leaseSeconds renewalSeconds devices;
  };

  channelType = types.submodule {
    options = {
      name = mkOption {
        type = types.str;
        description = "Stable user-facing name for this fan header.";
      };
      channel = mkOption {
        type = types.ints.between 1 16;
        description = "One-based hwmon PWM channel number.";
      };
      minimumPercent = mkOption {
        type = types.ints.between 1 100;
        description = "Lowest manual duty cycle allowed for this channel.";
      };
    };
  };

  sensorType = types.submodule {
    options = {
      identity = mkOption {
        type = types.str;
        description = "Stable hwmon identity providing the safety temperature.";
      };
      input = mkOption {
        type = types.ints.between 1 64;
        description = "One-based hwmon temperature input number.";
      };
      warningCelsius = mkOption {
        type = types.number;
        description = "Temperature at which the helper begins warning.";
      };
      criticalCelsius = mkOption {
        type = types.number;
        description = "Temperature at which manual control is revoked and every fan returns to firmware control.";
      };
    };
  };

  deviceType = types.submodule {
    options = {
      identity = mkOption {
        type = types.enum [ "nct6797" ];
        description = "Stable hwmon identity of the fan controller, never a raw sysfs path.";
      };
      channels = mkOption {
        type = types.nonEmptyListOf channelType;
        description = "Explicitly allowed PWM channels and their safe minimums.";
      };
      thermalSensors = mkOption {
        type = types.nonEmptyListOf sensorType;
        description = "Temperature sensors that guard manual fan control.";
      };
    };
  };
in
{
  options.services.qs = {
    enable = mkEnableOption "the QS system integration";

    package = mkOption {
      type = types.package;
      default = packages.default;
      defaultText = lib.literalExpression "self.packages.\${pkgs.stdenv.hostPlatform.system}.default";
      description = "QS package installed system-wide.";
    };

    wallpaper = mkOption {
      type = types.nullOr types.path;
      default = null;
      example = lib.literalExpression "./wallpaper.jpg";
      description = "Optional immutable wallpaper exposed at /etc/qs/wallpaper for user configuration.";
    };

    locationServices.enable = mkEnableOption "GeoClue location services with a system-wide on/off switch in the shell";

    fanControl = {
      enable = mkEnableOption "manual fan control from the shell through a fail-safe root helper";

      package = mkOption {
        type = types.package;
        default = packages.fan-helper;
        defaultText = lib.literalExpression "self.packages.\${pkgs.stdenv.hostPlatform.system}.fan-helper";
        description = "Package containing bin/qs-fan-helper.";
      };

      users = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "Users added to the `${fanGroup}` group, which may connect to the helper socket.";
      };

      leaseSeconds = mkOption {
        type = types.ints.between 2 30;
        default = 5;
        description = "Seconds of client silence after which every fan returns to firmware control.";
      };

      renewalSeconds = mkOption {
        type = types.ints.positive;
        default = 2;
        description = "Interval at which the shell renews its lease.";
      };

      devices = mkOption {
        type = types.listOf deviceType;
        default = [ ];
        description = "Per-host hwmon allowlist and thermal safety policy.";
      };
    };
  };

  config = mkIf cfg.enable (lib.mkMerge [
    {
      environment.systemPackages = [ cfg.package ];
      # Battery state in the shell comes from UPower.
      services.upower.enable = true;
      # The shell writes the backlight directly; members of `video` may set it.
      services.udev.extraRules = ''
        ACTION=="add", SUBSYSTEM=="backlight", RUN+="${pkgs.coreutils}/bin/chgrp video /sys%p/brightness", RUN+="${pkgs.coreutils}/bin/chmod g+w /sys%p/brightness"
      '';
      environment.etc."qs/wallpaper" = mkIf (cfg.wallpaper != null) {
        source = cfg.wallpaper;
      };
    }

    (mkIf cfg.locationServices.enable {
      services.geoclue2 = {
        enable = true;
        appConfig."geoclue-where-am-i" = {
          isAllowed = true;
          isSystem = false;
        };
      };
      environment.systemPackages = [ whereAmI ];

      systemd.services.geoclue.unitConfig.ConditionPathExists = "!${locationOffMarker}";

      systemd.services.qs-location-off = {
        description = "Turn off location services";
        serviceConfig.Type = "oneshot";
        script = ''
          ${pkgs.coreutils}/bin/mkdir -p ${dirOf locationOffMarker}
          ${pkgs.coreutils}/bin/touch ${locationOffMarker}
          ${systemctl} stop geoclue.service
        '';
      };

      systemd.services.qs-location-on = {
        description = "Turn on location services";
        serviceConfig.Type = "oneshot";
        script = "${pkgs.coreutils}/bin/rm -f ${locationOffMarker}";
      };

      # The person at the machine may flip the switch without a password, and nothing else.
      security.polkit.extraConfig = ''
        polkit.addRule(function (action, subject) {
          if (action.id == "org.freedesktop.systemd1.manage-units"
              && (action.lookup("unit") == "qs-location-on.service" || action.lookup("unit") == "qs-location-off.service")
              && action.lookup("verb") == "start"
              && subject.local && subject.active) {
            return polkit.Result.YES;
          }
        });
      '';
    })

    (mkIf fans.enable {
      assertions = [
        {
          assertion = fans.devices != [ ];
          message = "services.qs.fanControl.devices must not be empty when fanControl is enabled";
        }
        {
          assertion = fans.renewalSeconds < fans.leaseSeconds;
          message = "services.qs.fanControl.renewalSeconds must be shorter than leaseSeconds";
        }
        {
          assertion = lib.all (device: lib.all (sensor: sensor.warningCelsius < sensor.criticalCelsius) device.thermalSensors) fans.devices;
          message = "each QS fan warning temperature must be below its critical temperature";
        }
      ];

      users.groups.${fanGroup} = { };
      users.users = lib.genAttrs fans.users (_: {
        extraGroups = [ fanGroup ];
      });

      environment.etc."qs/fan-policy.json" = {
        mode = "0444";
        text = builtins.toJSON policy;
      };

      systemd.sockets.qs-fan-helper = {
        description = "QS fan control socket";
        wantedBy = [ "sockets.target" ];
        socketConfig = {
          ListenStream = socketPath;
          SocketUser = "root";
          SocketGroup = fanGroup;
          SocketMode = "0660";
          Accept = false;
        };
      };

      systemd.services.qs-fan-helper = {
        description = "QS fail-safe fan control helper";
        requires = [ "qs-fan-helper.socket" ];
        after = [ "qs-fan-helper.socket" ];
        restartTriggers = [ config.environment.etc."qs/fan-policy.json".source ];
        startLimitIntervalSec = 30;
        startLimitBurst = 5;
        serviceConfig = {
          ExecStart = lib.getExe fans.package;
          ExecStopPost = "${lib.getExe fans.package} --restore";
          Restart = "on-failure";
          RestartSec = "2s";
          UMask = "0077";

          AmbientCapabilities = "";
          CapabilityBoundingSet = "";
          LockPersonality = true;
          MemoryDenyWriteExecute = true;
          NoNewPrivileges = true;
          PrivateDevices = true;
          PrivateNetwork = true;
          PrivateTmp = true;
          ProtectClock = true;
          ProtectControlGroups = true;
          ProtectHome = true;
          ProtectHostname = true;
          ProtectKernelLogs = true;
          ProtectKernelModules = true;
          ProtectProc = "invisible";
          ProtectSystem = "strict";
          ReadOnlyPaths = [ "/sys" ];
          ReadWritePaths = [ "/sys/devices" ];
          RemoveIPC = true;
          RestrictAddressFamilies = [ "AF_UNIX" ];
          RestrictNamespaces = true;
          RestrictSUIDSGID = true;
          SystemCallArchitectures = "native";
          SystemCallFilter = [ "@system-service" ];
          SystemCallErrorNumber = "EPERM";
        };
      };
    })
  ]);
}
