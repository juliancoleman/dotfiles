# Photos: Immich.
#
# Everything Immich keeps on disk lives on the NAS under Photos/: the originals (filed by year and
# month), thumbnails, and its nightly database dumps. Only the database itself is on this machine,
# so moving Immich to another host means restoring one dump there and importing this file.
{ config, lib, pkgs, ... }:
let
  media = "/mnt/photos";
  nasAddress = builtins.elemAt (lib.splitString "/" config.fileSystems.${media}.device) 2;
  site = "${config.networking.hostName}.local";
  # Immich wants an origin to itself, so it gets a port of its own beside the calendar's 443.
  httpsPort = 8443;
in
{
  # The same NAS share as /mnt/nas, entered at Photos/ and owned by the service user.
  fileSystems.${media} = {
    device = "//192.168.0.1/H/Photos";
    fsType = "cifs";
    options = [
      "credentials=/var/lib/secrets/nas.credentials"
      "vers=2.0"
      "noauto"
      "nofail"
      "x-systemd.automount"
      "x-systemd.mount-timeout=20s"
      "uid=${config.services.immich.user}"
      "gid=${config.services.immich.group}"
      "file_mode=0660"
      "dir_mode=0770"
    ];
  };

  services.immich = {
    enable = true;
    # Other devices come in through Caddy below.
    host = "127.0.0.1";
    mediaLocation = media;
    settings.server.externalDomain = "https://${site}:${toString httpsPort}";
    settings.storageTemplate = {
      enabled = true;
      hashVerificationEnabled = true;
      template = "{{y}}/{{y}}-{{MM}}/{{filename}}";
    };
    # Two dumps land on days this machine is awake at 2:00 (Immich's own, and the timer below).
    settings.backup.database.keepLastAmount = 30;
  };

  # The certificate services.nix makes is for this machine's name, whatever the port.
  services.caddy.virtualHosts."${site}:${toString httpsPort}".extraConfig = ''
    tls /var/lib/home-tls/server.crt /var/lib/home-tls/server.key
    reverse_proxy 127.0.0.1:${toString config.services.immich.port}
  '';
  networking.firewall.allowedTCPPorts = [ httpsPort ];

  # Without the NAS there is no library; do not start against an empty mount point.
  systemd.services.immich-server.unitConfig.RequiresMountsFor = [ media ];

  # Booted away from home, Immich cannot start, and nothing would start it on coming back. This does,
  # once the NAS answers; starting what already runs changes nothing.
  systemd.services.immich-when-home = {
    description = "Start Immich once the NAS is in reach";
    serviceConfig = {
      Type = "oneshot";
      ExecCondition = "${pkgs.coreutils}/bin/timeout 3 ${pkgs.bash}/bin/bash -c 'exec 3<>/dev/tcp/${nasAddress}/445'";
      ExecStart = "${pkgs.systemd}/bin/systemctl start --no-block immich-server.service";
    };
  };
  systemd.timers.immich-when-home = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "2min";
      OnUnitInactiveSec = "3min";
    };
  };

  # Immich dumps its database to Photos/backups on the NAS at 2:00, but only if this machine is awake
  # then. This asks it for the same dump once a day and catches up after sleep.
  systemd.services.immich-database-backup = {
    description = "Ask Immich for a database dump";
    after = [ "immich-server.service" ];
    requires = [ "immich-server.service" ];
    # Skipped until an API key has been saved.
    unitConfig.ConditionFileNotEmpty = "/var/lib/secrets/immich-api-key";
    serviceConfig = {
      Type = "oneshot";
      LoadCredential = "key:/var/lib/secrets/immich-api-key";
    };
    script = ''
      ${pkgs.curl}/bin/curl --fail --silent --show-error -X POST \
        -H "x-api-key: $(tr -d '\n' < "$CREDENTIALS_DIRECTORY/key")" \
        -H 'Content-Type: application/json' -d '{"name":"backup-database"}' \
        http://127.0.0.1:${toString config.services.immich.port}/api/jobs
    '';
  };
  systemd.timers.immich-database-backup = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
      RandomizedDelaySec = "10min";
    };
  };
}
