# Sets one of this machine's service secrets. The secret is asked for through $SUDO_ASKPASS (the
# desktop's secure prompt) when there is one, and in the terminal otherwise.
#   home-secret radicale   password of the contacts and calendar login
#   home-secret backup     password of the backup repository on the NAS

ask() {
  local reply
  if [ -n "${SUDO_ASKPASS:-}" ] && [ -x "$SUDO_ASKPASS" ]; then
    "$SUDO_ASKPASS" "$1"
  else
    printf '%s ' "$1" >&2
    IFS= read -r -s reply
    printf '\n' >&2
    printf '%s\n' "$reply"
  fi
}

case "${1:-}" in
  radicale) what="Radicale password for @davUser@" ;;
  backup) what="backup repository password" ;;
  *)
    echo "usage: home-secret radicale|backup" >&2
    exit 2
    ;;
esac

first=$(ask "New $what:")
second=$(ask "The same $what again:")
if [ -z "$first" ] || [ "$first" != "$second" ]; then
  echo "Empty, or the two entries differ. Nothing was changed." >&2
  exit 1
fi

case "$1" in
  radicale)
    # bcrypt reads 72 bytes and no further; a longer password would be silently cut short.
    if [ "$(printf '%s' "$first" | wc -c)" -gt 72 ]; then
      echo "Longer than 72 bytes, which is all bcrypt reads. Nothing was changed." >&2
      exit 1
    fi
    hash=$(printf '%s' "$first" | mkpasswd --method=bcrypt --rounds=10 --stdin)
    printf '%s:%s\n' "@davUser@" "$hash" | sudo tee /var/lib/secrets/radicale.htpasswd >/dev/null
    ;;
  backup)
    printf '%s\n' "$first" | sudo install -m 0600 -o root -g root /dev/stdin /var/lib/secrets/restic-password
    ;;
esac
echo "Set."
