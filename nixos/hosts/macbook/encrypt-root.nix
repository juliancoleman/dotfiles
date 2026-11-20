# Transitional: at boot, offers to encrypt the root partition in place (LUKS2), and unlocks it on
# every boot after that. A machine with this module starts whether or not the disk is encrypted yet.
# Once the disk is encrypted, replace this module with `boot.initrd.luks.devices`.
{ config, lib, pkgs, utils, ... }:
let
  cfg = config.boot.initrd.encryptRoot;
  # The script finds its tools on the initrd's own PATH (/bin); `initrdBin` below puts them there.
  # A store path named only inside a script is not copied into the initrd.
  tool = pkgs.writeShellApplication {
    name = "encrypt-root";
    text = builtins.readFile ./encrypt-root.sh;
  };
  deviceUnit = "${utils.escapeSystemdPath cfg.device}.device";
  rootFsck = "systemd-fsck@${utils.escapeSystemdPath config.fileSystems."/".device}.service";
in
{
  options.boot.initrd.encryptRoot = {
    device = lib.mkOption {
      type = lib.types.str;
      description = "Partition holding the root filesystem.";
    };
    name = lib.mkOption {
      type = lib.types.str;
      default = "cryptroot";
      description = "Device-mapper name of the unlocked partition.";
    };
  };

  config = {
    boot.initrd.availableKernelModules = [ "dm_mod" "dm_crypt" ];
    boot.initrd.systemd.storePaths = [ tool ];
    boot.initrd.systemd.initrdBin = [
      pkgs.cryptsetup
      pkgs.e2fsprogs
      pkgs.util-linux
      pkgs.kmod
      pkgs.gnused
      pkgs.gnugrep
    ];

    # The root filesystem appears only after the passphrase is typed; do not give up on it after 90 s.
    boot.initrd.systemd.settings.Manager.DefaultDeviceTimeoutSec = "infinity";

    boot.initrd.systemd.services.encrypt-root = {
      description = "Encrypt or unlock the root partition";
      wantedBy = [ "initrd.target" ];
      # Nothing else may have the partition open while it is shrunk and encrypted.
      before = [ "sysroot.mount" "systemd-fsck-root.service" rootFsck ];
      after = [ deviceUnit "systemd-modules-load.service" ];
      requires = [ deviceUnit ];
      unitConfig.DefaultDependencies = false;
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${tool}/bin/encrypt-root ${cfg.device} ${cfg.name}";
        StandardInput = "tty-force";
        StandardOutput = "tty";
        StandardError = "tty";
        TTYPath = "/dev/console";
        TimeoutStartSec = "infinity";
      };
    };
  };
}
