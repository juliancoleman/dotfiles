# Restoring from backup

Read this when the MacBook is lost, dead, or freshly reinstalled. It lists what is backed up, what you
need to get it back, and the commands. No secrets are written here; they are in Bitwarden.

## What is backed up

The MacBook backs up its service data every night with restic (`nixos/hosts/macbook/services.nix`):

| Path | What it is |
| --- | --- |
| `/var/lib/radicale` | Calendar and the phone address book. The calendar exists nowhere else. |
| `/var/lib/home-tls` | The HTTPS certificate for `macbook-pro.local` and its CA certificate |
| `/home/julian/obsidian-vault` | The MacBook's copy of the vault |
| `/home/julian/.config/syncthing/{config.xml,cert.pem,key.pem}` | Syncthing's identity and pairings |

The repository is `backups/macbook-pro` on the NAS (share `H` on the router, `192.168.0.1`). It is
encrypted; the NAS holds nothing readable. It keeps 14 daily, 8 weekly and 12 monthly snapshots.

**Not covered:** anything else on the MacBook, the desktop, and the NAS's own contents. The repository
lives only on the NAS, in the house. There is no off-site copy yet.

## What you need

From Bitwarden:

- **NAS login** (the router share's username and password)
- **MacBook restic backup (NAS)** (the repository password; without it the backup cannot be opened)
- **MacBook disk passphrase**, if the MacBook itself is being started
- **Radicale (contacts and calendar)**, to reconnect the phone afterwards

And a Linux machine on the home network with Nix (either NixOS host will do).

## Get the files back

Mount the NAS. The router speaks SMB 2.0 and nothing newer, so the version has to be named:

```bash
printf 'username=NAS_USER\npassword=NAS_PASSWORD\n' > /tmp/nas.credentials && chmod 600 /tmp/nas.credentials
sudo mkdir -p /mnt/nas
sudo mount -t cifs //192.168.0.1/H /mnt/nas -o credentials=/tmp/nas.credentials,vers=2.0
```

On the MacBook itself none of that is needed: `/mnt/nas` mounts by itself when you look into it.

List the snapshots and restore the newest into a scratch folder (restic asks for the repository password):

```bash
nix shell nixpkgs#restic
sudo restic -r /mnt/nas/backups/macbook-pro snapshots
sudo restic -r /mnt/nas/backups/macbook-pro restore latest --target /tmp/restore
```

The files are now under `/tmp/restore`, at their original paths. Remove `/tmp/nas.credentials` when done.

## Put them back on a rebuilt MacBook

After `nixos-rebuild switch --impure --flake .#macbook-pro` has created the services:

```bash
sudo systemctl stop radicale caddy syncthing contacts-export.timer
sudo cp -a /tmp/restore/var/lib/radicale/. /var/lib/radicale/
sudo cp -a /tmp/restore/var/lib/home-tls/. /var/lib/home-tls/
sudo cp -a /tmp/restore/home/julian/obsidian-vault /home/julian/
sudo cp -a /tmp/restore/home/julian/.config/syncthing/. /home/julian/.config/syncthing/
sudo systemctl start radicale caddy syncthing contacts-export.timer
```

All four copies need `sudo`: restic restores as root, and `/tmp/restore` is closed to everyone else.
`cp -a` keeps each file's owner, so the vault and Syncthing files still end up yours.

Restoring `/var/lib/home-tls` keeps the certificate the phone and the desktop already trust. Without it
the MacBook makes a new one on first start, and each device has to trust the new `ca.crt`: the phone
when DAVx⁵ next asks, and both NixOS hosts by copying `/var/lib/home-tls/ca.crt` over
`nixos/hosts/macbook/home-ca.crt` in this repo and rebuilding.

Then set the secrets again, which are never backed up:

```bash
home-secret radicale      # the Radicale password from Bitwarden
home-secret backup        # the repository password from Bitwarden
sudoedit /var/lib/secrets/nas.credentials   # username=… and password=… on two lines, mode 600
```

## Check that a restore still works

Once a year, do "Get the files back" and compare one folder with the live one:

```bash
sudo diff -rq /var/lib/radicale /tmp/restore/var/lib/radicale && echo identical
```
