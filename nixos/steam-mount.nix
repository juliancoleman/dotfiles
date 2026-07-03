{ pkgs, ... }:
{
  # Mount the 860 EVO as Steam library
  fileSystems."/mnt/steam" = {
    device = "/dev/disk/by-label/steam-library";
    fsType = "ext4";
    options = [ "defaults" ];
  };

  # Auto-prune generations: keep only current and previous
  systemd.services.nixos-prune-generations = {
    description = "Prune old NixOS generations (keep current + 1)";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.bash}/bin/bash -c '${pkgs.nix}/bin/nix-env --profile /nix/var/nix/profiles/system --delete-generations +2 && ${pkgs.nix}/bin/nix-collect-garbage -d'";
    };
  };

  systemd.timers.nixos-prune-generations = {
    description = "Daily generation pruning";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
    };
  };
}
