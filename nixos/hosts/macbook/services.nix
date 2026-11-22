# Home services hosted on this machine: contacts and calendar (Radicale) behind TLS (Caddy),
# the vault → phone address book exporter, Syncthing for the vault itself, and a nightly backup
# of the service data to the NAS.
#
# Secrets stay out of the repo, in /var/lib/secrets:
#   radicale.htpasswd   home-secret radicale
#   restic-password     home-secret backup
#   nas.credentials     two lines by hand: username=…  password=…
{ config, lib, pkgs, ... }:
let
  site = "${config.networking.hostName}.local";
  davUser = "julian";
  storage = "/var/lib/radicale/collections";
  collections = "${storage}/collection-root/${davUser}";
  vaultContacts = "/home/julian/obsidian-vault/Contacts";
  tlsDir = "/var/lib/home-tls";

  exportPython = pkgs.python3.withPackages (ps: [ ps.pyyaml ]);
  owned = { user = "radicale"; group = "radicale"; };

  nasAddress = "192.168.0.1";
  homeSecret = pkgs.writeShellApplication {
    name = "home-secret";
    runtimeInputs = [ pkgs.mkpasswd ];
    text = builtins.replaceStrings [ "@davUser@" ] [ davUser ] (builtins.readFile ./home-secret.sh);
  };
in
{
  # ── Contacts + calendar ──
  services.radicale = {
    enable = true;
    settings = {
      server.hosts = [ "127.0.0.1:5232" ];
      auth = {
        type = "htpasswd";
        htpasswd_filename = "/var/lib/secrets/radicale.htpasswd";
        htpasswd_encryption = "bcrypt";
      };
      storage.filesystem_folder = storage;
    };
    # First matching section wins, and sections are written in name order.
    rights = {
      # The phone address book is a mirror of the vault: clients may read it, only the exporter writes it.
      "10-phone-read-only" = { user = davUser; collection = "${davUser}/phone"; permissions = "r"; };
      "20-root" = { user = ".+"; collection = ""; permissions = "R"; };
      "30-principal" = { user = ".+"; collection = "{user}"; permissions = "RW"; };
      "40-collections" = { user = ".+"; collection = "{user}/[^/]+"; permissions = "rw"; };
    };
  };

  systemd.tmpfiles.settings."10-home-services" = {
    "/var/lib/secrets".d = { mode = "0751"; user = "root"; group = "root"; };
    # Empty until filled in: nobody can log in, and Radicale still starts.
    "/var/lib/secrets/radicale.htpasswd".f = { mode = "0640"; user = "root"; group = "radicale"; };

    "${storage}".d = owned // { mode = "0750"; };
    "${storage}/collection-root".d = owned // { mode = "0750"; };
    "${collections}".d = owned // { mode = "0750"; };
    "${collections}/phone".d = owned // { mode = "0750"; };
    "${collections}/phone/.Radicale.props".f = owned // {
      mode = "0640";
      argument = builtins.toJSON { "D:displayname" = "Phone"; tag = "VADDRESSBOOK"; };
    };
    "${collections}/calendar".d = owned // { mode = "0750"; };
    "${collections}/calendar/.Radicale.props".f = owned // {
      mode = "0640";
      argument = builtins.toJSON {
        "C:supported-calendar-component-set" = "VEVENT,VTODO";
        "D:displayname" = "Calendar";
        tag = "VCALENDAR";
      };
    };
  };

  # ── Vault contacts tagged `phone` → the phone address book ──
  systemd.services.contacts-export = {
    description = "Mirror vault contacts tagged `phone` into the Radicale address book";
    # Skipped, not failed, until Syncthing has delivered the vault.
    unitConfig.ConditionPathIsDirectory = vaultContacts;
    serviceConfig = {
      Type = "oneshot";
      User = "radicale";
      Group = "radicale";
      ExecStart = lib.concatStringsSep " " [
        "${exportPython}/bin/python ${./contacts-export.py}"
        "--source ${vaultContacts}"
        "--storage ${storage}"
        "--collection ${davUser}/phone"
      ];
      # The service user sees nothing of /home except the contact notes, read-only.
      ProtectHome = "tmpfs";
      BindReadOnlyPaths = [ vaultContacts ];
      ProtectSystem = "strict";
      ReadWritePaths = [ storage ];
      PrivateTmp = true;
      NoNewPrivileges = true;
    };
  };
  systemd.timers.contacts-export = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "2min";
      OnUnitActiveSec = "5min";
    };
  };

  # ── TLS ──
  # A certificate authority that signs exactly one certificate and then loses its key: trusting
  # ca.crt on other devices trusts this site and nothing else, even if this machine is stolen.
  # Renew by deleting ${tlsDir} and re-distributing ca.crt (expiry: 5 years from first start).
  systemd.services.home-tls = {
    description = "One-time TLS certificate for ${site}";
    wantedBy = [ "multi-user.target" ];
    requiredBy = [ "caddy.service" ];
    before = [ "caddy.service" ];
    unitConfig.ConditionPathExists = "!${tlsDir}/server.crt";
    path = [ pkgs.openssl ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      set -eu
      umask 027
      work=$(mktemp -d)
      trap 'rm -rf "$work"' EXIT
      cd "$work"
      openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -nodes -days 1825 \
        -subj "/CN=${site} home CA" -keyout ca.key -out ca.crt \
        -addext "basicConstraints=critical,CA:TRUE,pathlen:0" -addext "keyUsage=critical,keyCertSign"
      openssl req -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -nodes \
        -subj "/CN=${site}" -keyout server.key -out server.csr
      printf 'subjectAltName=DNS:${site}\nbasicConstraints=CA:FALSE\nkeyUsage=digitalSignature\nextendedKeyUsage=serverAuth\n' > leaf.ext
      openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial -days 1825 \
        -extfile leaf.ext -out server.crt
      rm ca.key
      # ca.crt is public and has to be copied to other devices; only server.key is private.
      install -d -m 0755 -o root -g caddy ${tlsDir}
      install -m 0644 -o root -g caddy ca.crt ${tlsDir}/ca.crt
      install -m 0640 -o root -g caddy server.key ${tlsDir}/server.key
      cat server.crt ca.crt > chain.crt
      install -m 0644 -o root -g caddy chain.crt ${tlsDir}/server.crt
    '';
  };

  services.caddy = {
    enable = true;
    virtualHosts.${site}.extraConfig = ''
      tls ${tlsDir}/server.crt ${tlsDir}/server.key
      reverse_proxy 127.0.0.1:5232
    '';
  };
  networking.firewall.allowedTCPPorts = [ 443 ];

  # `${site}` has to resolve for the phone whatever address DHCP hands this machine.
  services.avahi = {
    enable = true;
    openFirewall = true;
    settings.publish = {
      disable-publishing = false;
      publish-addresses = true;
    };
  };

  # ── Vault sync ──
  # Devices and folders are paired in the GUI (http://127.0.0.1:8384) and kept as paired.
  services.syncthing = {
    enable = true;
    user = "julian";
    dataDir = "/home/julian";
    configDir = "/home/julian/.config/syncthing";
    openDefaultPorts = true;
    overrideDevices = false;
    overrideFolders = false;
  };

  # ── Backup to the NAS ──
  environment.systemPackages = [ homeSecret ];

  # The drive on the router, mounted when something looks into /mnt/nas.
  fileSystems."/mnt/nas" = {
    device = "//${nasAddress}/H";
    fsType = "cifs";
    options = [
      "credentials=/var/lib/secrets/nas.credentials"
      # The router's file server speaks SMB 2.0 and nothing newer; the kernel's default asks for 2.1+.
      "vers=2.0"
      "noauto"
      "nofail"
      "x-systemd.automount"
      "x-systemd.idle-timeout=10min"
      "x-systemd.mount-timeout=20s"
      "uid=julian"
      "gid=users"
      "file_mode=0600"
      "dir_mode=0700"
    ];
  };

  # Encrypted before it leaves this machine; the NAS only ever holds the repository.
  services.restic.backups.nas = {
    repository = "/mnt/nas/backups/${config.networking.hostName}";
    passwordFile = "/var/lib/secrets/restic-password";
    initialize = true;
    paths = [
      "/var/lib/radicale"
      tlsDir
      "/home/julian/obsidian-vault"
      "/home/julian/.config/syncthing/config.xml"
      "/home/julian/.config/syncthing/cert.pem"
      "/home/julian/.config/syncthing/key.pem"
    ];
    pruneOpts = [ "--keep-daily 14" "--keep-weekly 8" "--keep-monthly 12" ];
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
      RandomizedDelaySec = "20min";
    };
  };
  systemd.services.restic-backups-nas = {
    # Skipped, not failed, until `home-secret backup` has been run.
    unitConfig.ConditionFileNotEmpty = "/var/lib/secrets/restic-password";
    # Skipped, not failed, away from home.
    serviceConfig.ExecCondition =
      "${pkgs.coreutils}/bin/timeout 3 ${pkgs.bash}/bin/bash -c 'exec 3<>/dev/tcp/${nasAddress}/445'";
  };
}
