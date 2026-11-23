# Photos: Immich, hosted here while the library is first built, then moved to the MacBook.
#
# Everything Immich keeps on disk lives on the NAS under Photos/: the originals (filed by year and
# month), thumbnails, and its nightly database dumps. Only the database itself is on this machine,
# so moving Immich to another host means restoring one dump there and importing this file.
{ config, lib, pkgs, ... }:
let
  media = "/mnt/photos";
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
    # Reached from this machine only for now (the launcher, and imports run here).
    host = "127.0.0.1";
    mediaLocation = media;
    settings.storageTemplate = {
      enabled = true;
      hashVerificationEnabled = true;
      template = "{{y}}/{{y}}-{{MM}}/{{filename}}";
    };
    # Two dumps land on days this machine is awake at 2:00 (Immich's own, and the timer below).
    settings.backup.database.keepLastAmount = 30;
  };

  # Without the NAS there is no library; do not start against an empty mount point.
  systemd.services.immich-server.unitConfig.RequiresMountsFor = [ media ];

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
