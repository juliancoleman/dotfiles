{
  # Mount the 860 EVO as Steam library
  fileSystems."/mnt/steam" = {
    device = "/dev/disk/by-label/steam-library";
    fsType = "ext4";
    options = [ "defaults" ];
  };
}
