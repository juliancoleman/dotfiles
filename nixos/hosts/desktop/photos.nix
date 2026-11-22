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
  };

  # Without the NAS there is no library; do not start against an empty mount point.
  systemd.services.immich-server.unitConfig.RequiresMountsFor = [ media ];
}
