"""Mirror Obsidian contact notes tagged `phone` into a Radicale address book.

One-way: the vault is the source of truth and the address book is rebuilt from it.
Notes are written by the VCF Contacts plugin, whose frontmatter keys are vCard
properties: `FN`, `N.GN`, `TEL[CELL]`, `TEL[1:]`, `ADR[HOME].STREET`, ...

Rules:
- A note is exported when its frontmatter `tags` contain `phone`.
- Untagging or deleting a note removes the contact from the address book.
- Phone numbers must carry a country code (`+1-555-...`). A tagged note with a
  bad number is rejected and reported; a copy exported earlier is left as it was.
"""

import argparse
import fcntl
import os
import re
import sys
from pathlib import Path

import yaml

TAG = "phone"
# The address book is served by Radicale, which parses and rewrites every card with vobject.
# vobject speaks vCard 3.0: a 4.0 `PHOTO:data:...` URI comes back with its `;` escaped and no
# longer loads on the phone, while a 3.0 `PHOTO;ENCODING=b` survives byte for byte.
DATA_URI = re.compile(r"data:image/(?P<type>[A-Za-z0-9.+-]+);base64,(?P<data>[A-Za-z0-9+/=]+)")
# Order of the structured values, per RFC 2426.
N_PARTS = ["FN", "GN", "MN", "PREFIX", "SUFFIX"]
ADR_PARTS = ["PO", "EXT", "STREET", "LOCALITY", "REGION", "POSTAL", "COUNTRY"]
# URL is here too: vobject cuts an unescaped value off at its first comma.
TEXT_PROPS = {"FN", "NICKNAME", "ORG", "TITLE", "ROLE", "NOTE", "EMAIL", "URL"}
RAW_PROPS = {"BDAY", "ANNIVERSARY", "GENDER"}
E164 = re.compile(r"\+[1-9][0-9]{6,14}")
KEY = re.compile(r"(?P<name>[A-Z][A-Z0-9-]*)(?:\[(?P<bracket>[^\]]*)\])?(?:\.(?P<part>[A-Z]+))?")


class Rejected(Exception):
    pass


def frontmatter(text):
    lines = text.splitlines()
    if not lines or lines[0].strip() != "---":
        return None
    for end in range(1, len(lines)):
        if lines[end].strip() == "---":
            # BaseLoader keeps every scalar a string: no dates, no octal phone numbers.
            data = yaml.load("\n".join(lines[1:end]), Loader=yaml.BaseLoader)
            return data if isinstance(data, dict) else None
    return None


def is_tagged(meta):
    tags = meta.get("tags", [])
    if isinstance(tags, str):
        tags = re.split(r"[,\s]+", tags)
    return any(isinstance(t, str) and t.lstrip("#") == TAG for t in tags)


def escape(value):
    return (
        value.replace("\\", "\\\\")
        .replace("\n", "\\n")
        .replace(",", "\\,")
        .replace(";", "\\;")
    )


def fold(line):
    """Fold to 75 octets per line; continuation lines start with a space."""
    data = line.encode()
    if len(data) <= 75:
        return line
    chunks, limit = [], 75
    while data:
        cut = min(limit, len(data))
        while cut < len(data) and (data[cut] & 0xC0) == 0x80:  # not inside a UTF-8 sequence
            cut -= 1
        chunks.append(data[:cut].decode())
        data, limit = data[cut:], 74
    return "\r\n ".join(chunks)


def phone(value):
    number = re.sub(r"[\s\-.()]", "", value)
    if not E164.fullmatch(number):
        raise Rejected(f"phone number {value!r} has no country code (want +1-555-...)")
    return number


def scalar(value, key):
    if not isinstance(value, str):
        raise Rejected(f"{key} is not a plain value")
    return value.strip()


def vcard(meta):
    uid = scalar(meta.get("UID", ""), "UID")
    if not uid:
        raise Rejected("no UID")
    if not scalar(meta.get("FN", ""), "FN"):
        raise Rejected("no FN")

    # Group `NAME[bracket].PART` keys into one property instance per `NAME[bracket]`.
    instances = {}
    for key, value in meta.items():
        match = KEY.fullmatch(key)
        if not match or match["name"] in {"VERSION", "UID", "REV", "PRODID"}:
            continue
        slot = instances.setdefault((match["name"], match["bracket"]), {})
        slot[match["part"]] = value

    lines = []
    for (name, bracket), parts in instances.items():
        kind = (bracket or "").rpartition(":")[2].lower()
        params = f";TYPE={kind}" if re.fullmatch(r"[a-z0-9-]+", kind) else ""
        if name == "N" or name == "ADR":
            order = N_PARTS if name == "N" else ADR_PARTS
            value = ";".join(escape(scalar(parts.get(p, ""), f"{name}.{p}")) for p in order)
        elif None not in parts:
            continue
        elif name == "CATEGORIES":
            raw = parts[None]
            items = raw if isinstance(raw, list) else scalar(raw, name).split(",")
            value = ",".join(escape(str(i).strip()) for i in items if str(i).strip())
        else:
            raw = scalar(parts[None], name)
            if name == "TEL":
                value = phone(raw)
            elif name == "PHOTO":
                # The plugin unfolds long values with spaces; neither form of the value has any.
                raw = re.sub(r"\s+", "", raw)
                inline = DATA_URI.fullmatch(raw)
                if inline:
                    params = f";ENCODING=b;TYPE={inline['type'].upper()}"
                    value = inline["data"]
                else:
                    params = ";VALUE=uri"
                    value = raw
            elif name in TEXT_PROPS:
                value = escape(raw)
            elif name in RAW_PROPS or name.startswith("X-"):
                value = raw
            else:
                continue
        if value.strip(";"):
            lines.append(f"{name}{params}:{value}")

    if ("N", None) not in instances:
        # vCard 3.0 requires N; a note with only a display name gets it as the given name.
        lines.append("N:;" + escape(scalar(meta["FN"], "FN")) + ";;;")
    body = ["BEGIN:VCARD", "VERSION:3.0", f"UID:{uid}", *sorted(lines), "END:VCARD"]
    return uid, "".join(fold(line) + "\r\n" for line in body)


def filename(uid):
    stem = re.sub(r"[^A-Za-z0-9._-]", "_", uid.removeprefix("urn:uuid:")).lstrip(".")
    return f"{stem}.vcf"


def collect(source):
    """Read the notes.

    Returns (wanted: filename -> vCard text, held: filenames to leave alone,
    problems, complete). `complete` is False when a note could not be read at
    all, so nothing can be said about which contact it used to be.
    """
    wanted, held, problems, complete = {}, set(), [], True
    owners = {}
    for note in sorted(source.rglob("*.md")):
        try:
            meta = frontmatter(note.read_text(encoding="utf-8"))
        except (OSError, UnicodeDecodeError, yaml.YAMLError) as error:
            problems.append(f"{note.name}: unreadable ({error.__class__.__name__})")
            complete = False
            continue
        if not meta or not is_tagged(meta):
            continue
        uid = meta.get("UID")
        try:
            uid, text = vcard(meta)
            name = filename(uid)
            owners.setdefault(name, []).append(note.name)
            wanted[name] = text
        except Rejected as error:
            problems.append(f"{note.name}: {error}")
            if isinstance(uid, str) and uid.strip():
                held.add(filename(uid.strip()))
    for name, notes in owners.items():
        if len(notes) > 1:
            del wanted[name]
            held.add(name)
            problems.extend(f"{note}: shares its UID with {len(notes) - 1} other note(s)" for note in notes)
    return wanted, held, problems, complete


def mirror(collection, lock_path, wanted, held, remove):
    written = removed = 0
    with open(lock_path, "a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)  # the lock Radicale itself takes around storage access
        for name, text in wanted.items():
            target = collection / name
            data = text.encode()
            if target.exists() and target.read_bytes() == data:
                continue
            temp = collection / f".Radicale.tmp-{name}"
            temp.write_bytes(data)
            os.replace(temp, target)
            written += 1
        for existing in collection.glob("*.vcf") if remove else ():
            if existing.name not in wanted and existing.name not in held:
                existing.unlink()
                removed += 1
    return written, removed


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--source", type=Path, required=True, help="folder of contact notes")
    parser.add_argument("--storage", type=Path, required=True, help="Radicale filesystem_folder")
    parser.add_argument("--collection", required=True, help="address book path, e.g. julian/phone")
    args = parser.parse_args()

    collection = args.storage / "collection-root" / args.collection
    if not any(args.source.rglob("*.md")):
        # An empty folder is a vault that has not synced yet, not a wish to delete everyone.
        sys.exit(f"no notes in {args.source}; address book left untouched")
    if not (collection / ".Radicale.props").is_file():
        sys.exit(f"{collection} is not a Radicale collection")

    wanted, held, problems, complete = collect(args.source)
    written, removed = mirror(collection, args.storage / ".Radicale.lock", wanted, held, remove=complete)
    print(f"{len(wanted)} contacts tagged {TAG!r}: {written} written, {removed} removed")
    for problem in problems:
        print(f"rejected: {problem}", file=sys.stderr)
    sys.exit(1 if problems else 0)


if __name__ == "__main__":
    main()
