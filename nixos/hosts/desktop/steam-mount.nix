{
  # Mount the 860 EVO as Steam library. nofail: the system still boots when the disk is missing.
  fileSystems."/mnt/steam" = {
    device = "/dev/disk/by-label/steam-library";
    fsType = "ext4";
    options = [ "nofail" ];
  };
}
