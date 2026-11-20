# Runs in the initrd before the root filesystem is checked or mounted.
#   encrypt-root DEVICE NAME
# DEVICE not encrypted: offers to encrypt it in place; saying nothing starts the system as usual.
# DEVICE encrypted:     asks for the passphrase and opens it as /dev/mapper/NAME.
#
# The in-place step puts a LUKS2 header in front of the data, so the filesystem first gives up
# the space the header needs. Nothing is encrypted unless that shrink is confirmed by reading
# the filesystem's size back.

dev=$1
name=$2
header=$((32 * 1024 * 1024)) # what `--reduce-device-size 32M` takes from the end of the partition
slack=$((16 * 1024 * 1024))
secret=

say() { printf '\n%s\n' "$*"; }

ask_secret() { # prompt -> $secret; typing is not echoed
  printf '%s\n' "$1"
  IFS= read -r -s secret || secret=
}

filesystem_bytes() {
  local info count size
  info=$(dumpe2fs -h "$dev" 2>/dev/null) || return 1
  count=$(sed -n 's/^Block count: *//p' <<<"$info")
  size=$(sed -n 's/^Block size: *//p' <<<"$info")
  [ -n "$count" ] && [ -n "$size" ] && echo $((count * size))
}

unfinished() {
  local info
  info=$(cryptsetup luksDump "$dev")
  grep -qi 'reencrypt' <<<"$info"
}

open_with_secret() { printf '%s' "$secret" | cryptsetup open --allow-discards --key-file - "$dev" "$name"; }

unlock() {
  if [ -n "$secret" ] && open_with_secret; then
    return 0
  fi
  while true; do
    ask_secret "Passphrase for this disk (not shown while you type):"
    if open_with_secret; then
      return 0
    fi
    say "That did not unlock the disk."
  done
}

finish_interrupted() {
  say "Encrypting this disk was interrupted before it finished. It continues now; keep the charger connected."
  while true; do
    ask_secret "Passphrase you chose for this disk (not shown while you type):"
    printf '%s' "$secret" | cryptsetup repair --batch-mode --key-file - "$dev" || true
    if printf '%s' "$secret" | cryptsetup reencrypt --batch-mode --resume-only --key-file - "$dev"; then
      return 0
    fi
    say "That did not work."
  done
}

encrypt() {
  local size limit rc now first
  size=$(blockdev --getsize64 "$dev")
  limit=$((size - header))

  say "Checking the filesystem."
  rc=0
  e2fsck -f -p "$dev" || rc=$?
  if [ "$rc" -gt 1 ]; then
    say "The filesystem check reported problems (code $rc). Nothing was changed."
    return 1
  fi

  say "Making room for the encryption header."
  if ! resize2fs "$dev" "$(((limit - slack) / 1024))K"; then
    say "The filesystem could not be shrunk. Nothing was encrypted."
    return 1
  fi
  now=$(filesystem_bytes) || now=
  if [ -z "$now" ] || [ "$now" -gt "$limit" ]; then
    say "The filesystem still reaches the end of the partition. Nothing was encrypted."
    return 1
  fi

  while true; do
    ask_secret "Choose a passphrase for this disk (not shown while you type):"
    first=$secret
    ask_secret "Type it again:"
    if [ -n "$first" ] && [ "$first" = "$secret" ]; then
      break
    fi
    say "Those were empty or did not match."
  done

  say "Encrypting. This takes a while; keep the charger connected and the lid open."
  if ! printf '%s' "$secret" | cryptsetup reencrypt --batch-mode --encrypt --type luks2 \
    --reduce-device-size 32M --key-file - "$dev"; then
    say "Encrypting stopped with an error."
    return 1
  fi
  sync
}

# A missing tool must not look like "this disk is not encrypted".
for tool in cryptsetup blkid blockdev e2fsck resize2fs dumpe2fs modprobe sed grep systemctl; do
  if ! command -v "$tool" >/dev/null; then
    say "encrypt-root: $tool is missing from the initrd; leaving the disk alone."
    exit 1
  fi
done

modprobe -a dm_mod dm_crypt 2>/dev/null || true
mkdir -p /run/cryptsetup

# systemd redraws "A start job is running..." on the console every second; keep it off the prompts.
kill -s RTMIN+21 1 2>/dev/null || true
trap 'kill -s RTMIN+20 1 2>/dev/null || true' EXIT

if ! cryptsetup isLuks "$dev"; then
  if [ "$(blkid -o value -s TYPE "$dev" 2>/dev/null || true)" != ext4 ]; then
    exit 0
  fi
  say "This disk is not encrypted."
  say "Type ENCRYPT and press Enter to encrypt it now. Anything else, or waiting 60 seconds, starts the system as usual."
  answer=
  IFS= read -r -t 60 answer || true
  if [ "$answer" != ENCRYPT ]; then
    exit 0
  fi
  if encrypt; then
    say "Done. Restarting; the passphrase is asked for from now on."
    sleep 3
    systemctl reboot --force
    sleep infinity
  fi
  if ! cryptsetup isLuks "$dev"; then
    say "Starting the system unencrypted."
    exit 0
  fi
fi

if unfinished; then
  finish_interrupted
fi
unlock
