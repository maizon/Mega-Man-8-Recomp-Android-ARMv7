#!/usr/bin/env python3
"""Validate a local Mega Man 8 USA cue and its track-01 identity against game.toml."""
from __future__ import annotations

import hashlib
import re
import sys
import tomllib
from pathlib import Path

FILE_RE = re.compile(r'^\s*FILE\s+(?:"([^"]+)"|(\S+))\s+\S+', re.IGNORECASE)
TRACK_RE = re.compile(r'^\s*TRACK\s+(\d{2})\s+\S+', re.IGNORECASE)


def fail(message: str) -> None:
    print(f"ERROR: {message}", file=sys.stderr)
    raise SystemExit(1)


def digest_file(path: Path) -> tuple[str, str, str]:
    sha1 = hashlib.sha1()
    md5 = hashlib.md5(usedforsecurity=False)
    sha256 = hashlib.sha256()
    with path.open("rb") as stream:
        while chunk := stream.read(1024 * 1024):
            sha1.update(chunk)
            md5.update(chunk)
            sha256.update(chunk)
    return sha1.hexdigest(), md5.hexdigest(), sha256.hexdigest()

# Exact SHA-256 of the user's published PT-BR patched disc image. This narrow
# allowlist preserves a strong content identity check; it does not disable
# validation for arbitrary modified or unknown images.
PTBR_PATCHED_DISC_SHA256 = "86a68a2782208f820cf217e89b3cdd8cf8ec688af7060ebc4eef9ef106c04728"


def main() -> None:
    if len(sys.argv) != 3:
        fail("usage: validate-cue.py /path/to/disc.cue /path/to/game.toml")

    cue_path = Path(sys.argv[1]).expanduser()
    config_path = Path(sys.argv[2])
    if not cue_path.is_file():
        fail("the supplied .cue file does not exist")
    if cue_path.suffix.lower() != ".cue":
        fail("supply the complete .cue file, not an individual .bin track")
    if not config_path.is_file():
        fail("the pinned upstream game.toml is missing")

    cue_path = cue_path.resolve()
    config = tomllib.loads(config_path.read_text(encoding="utf-8"))
    expected = config.get("prepare_disc", {})
    game_id = config.get("game", {}).get("id")
    if game_id != "SLUS-00453":
        fail("the pinned game.toml is not configured for Mega Man 8 USA (SLUS-00453)")

    referenced_files: list[Path] = []
    current_file: Path | None = None
    track_01_file: Path | None = None
    for line_number, line in enumerate(cue_path.read_text(encoding="utf-8-sig").splitlines(), 1):
        match = FILE_RE.match(line)
        if match:
            name = match.group(1) or match.group(2)
            raw_path = Path(name).expanduser()
            current_file = raw_path if raw_path.is_absolute() else cue_path.parent / raw_path
            referenced_files.append(current_file)
            continue
        match = TRACK_RE.match(line)
        if match and match.group(1) == "01":
            if current_file is None:
                fail(f".cue line {line_number}: TRACK 01 appears before a FILE entry")
            track_01_file = current_file

    if not referenced_files:
        fail("the .cue contains no FILE entries")
    missing = [p for p in referenced_files if not p.is_file()]
    if missing:
        names = ", ".join(p.name for p in missing[:5])
        fail(f"one or more files referenced by the .cue are missing: {names}")
    if track_01_file is None:
        fail("the .cue contains no TRACK 01 entry")

    try:
        expected_size = int(expected["track_01_size"])
        expected_sha1 = str(expected["track_01_sha1"]).lower()
        expected_md5 = str(expected["track_01_md5"]).lower()
    except (KeyError, TypeError, ValueError):
        fail("game.toml does not contain complete track_01 size/SHA-1/MD5 identity values")

    actual_size = track_01_file.stat().st_size
    if actual_size != expected_size:
        fail("TRACK 01 size does not match the pinned Mega Man 8 USA game.toml")
    actual_sha1, actual_md5, actual_sha256 = digest_file(track_01_file)
    if actual_sha1 != expected_sha1 or actual_md5 != expected_md5:
        if actual_sha256 != PTBR_PATCHED_DISC_SHA256:
            fail(
                "TRACK 01 hashes do not match the pinned Mega Man 8 USA game.toml, "
                "and SHA-256 is not the explicitly recognized PT-BR patched image"
            )
        print("NOTICE: standard USA track hashes differ, but exact SHA-256 matches the recognized PT-BR patched disc image.")
        print("The image will be tested by the upstream generator; this does not guarantee executable compatibility.")
    else:
        print("Disc identity passed: Mega Man 8 USA / SLUS-00453 track-01 size, SHA-1 and MD5 match.")

    print("Cue validation passed: all referenced tracks exist.")


if __name__ == "__main__":
    main()
