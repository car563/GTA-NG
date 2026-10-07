#!/usr/bin/env python3
"""List official BeamNG car archives without extracting or copying game assets.

The tool reads BeamNG's local integrity manifest and archive entry names. It
reads each official car archive's small ``info.json`` only to identify its
brand/type. DAE and JBeam paths in the output are references into the player's
own game installation; no asset bytes are written to the output.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
import zipfile
from pathlib import Path, PurePosixPath
from typing import Any


DEFAULT_GAME_DIR = Path(
    r"C:\Program Files (x86)\Steam\steamapps\common\BeamNG.drive"
)
INFO_LIMIT_BYTES = 1024 * 1024

_TYPE_RE = re.compile(
    r'^[ \t]*"Type"[ \t]*:[ \t]*"([^"]+)"[ \t]*,?[ \t]*$', re.MULTILINE
)
_BRAND_RE = re.compile(
    r'^[ \t]*"Brand"[ \t]*:[ \t]*"([^"]+)"[ \t]*,?[ \t]*$', re.MULTILINE
)


class InventoryError(Exception):
    """Raised when the local BeamNG install cannot be inventoried safely."""


def _official_vehicle_archives(game_dir: Path) -> tuple[str, list[str]]:
    manifest_path = game_dir / "integrity.json"
    if not manifest_path.is_file():
        raise InventoryError(f"BeamNG integrity manifest not found: {manifest_path}")

    try:
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        raise InventoryError(f"Cannot read BeamNG integrity manifest: {exc}") from exc

    rows = manifest.get("integritydata") if isinstance(manifest, dict) else None
    if not isinstance(rows, list):
        raise InventoryError("BeamNG integrity manifest has no integritydata list")

    archives: set[str] = set()
    for row in rows:
        if not isinstance(row, list) or not row or not isinstance(row[0], str):
            continue
        entry = row[0].replace("\\", "/").lstrip("/")
        path = PurePosixPath(entry)
        if path.parts[:2] == ("content", "vehicles") and path.suffix.lower() == ".zip":
            archives.add(path.name)

    version = str(manifest.get("version", "unknown"))
    return version, sorted(archives, key=str.casefold)


def _metadata(info_bytes: bytes, archive_name: str) -> tuple[str | None, str | None]:
    if len(info_bytes) > INFO_LIMIT_BYTES:
        raise InventoryError(f"{archive_name}: info.json exceeds the 1 MiB safety limit")
    text = info_bytes.decode("utf-8-sig", errors="replace")
    type_match = _TYPE_RE.search(text)
    brand_match = _BRAND_RE.search(text)
    return (
        type_match.group(1).strip() if type_match else None,
        brand_match.group(1).strip() if brand_match else None,
    )


def inventory(game_dir: Path) -> dict[str, Any]:
    version, archive_names = _official_vehicle_archives(game_dir)
    archive_dir = game_dir / "content" / "vehicles"
    cars: list[dict[str, Any]] = []
    warnings: list[str] = []

    for archive_name in archive_names:
        stem = Path(archive_name).stem
        archive_path = archive_dir / archive_name
        if not archive_path.is_file():
            warnings.append(f"Official archive missing from install: {archive_name}")
            continue

        try:
            with zipfile.ZipFile(archive_path) as archive:
                prefix = f"vehicles/{stem}/"
                members = [
                    name.replace("\\", "/")
                    for name in archive.namelist()
                    if name.replace("\\", "/").startswith(prefix)
                ]
                info_path = f"{prefix}info.json"
                if info_path not in members:
                    continue
                info = archive.getinfo(info_path)
                if info.file_size > INFO_LIMIT_BYTES:
                    warnings.append(f"Skipped oversized metadata: {archive_name}")
                    continue
                vehicle_type, brand = _metadata(archive.read(info_path), archive_name)
                if not vehicle_type or vehicle_type.casefold() != "car":
                    continue

                model_paths = sorted(
                    name
                    for name in members
                    if name.casefold().endswith(".dae")
                )
                jbeam_count = sum(
                    name.casefold().endswith(".jbeam") for name in members
                )
                cars.append(
                    {
                        "vehicle_id": stem,
                        "brand": brand,
                        "archive": f"content/vehicles/{archive_name}",
                        "model_asset_paths": model_paths,
                        "jbeam_file_count": jbeam_count,
                        "assets_copied": False,
                    }
                )
        except (OSError, zipfile.BadZipFile, KeyError, RuntimeError) as exc:
            warnings.append(f"Could not inspect {archive_name}: {exc}")

    return {
        "beamng_version": version,
        "source": "player_install_integrity_manifest",
        "asset_bytes_extracted": False,
        "vehicle_count": len(cars),
        "vehicles": sorted(cars, key=lambda row: row["vehicle_id"].casefold()),
        "warnings": warnings,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--game-dir",
        type=Path,
        default=DEFAULT_GAME_DIR,
        help="BeamNG.drive installation directory (default: common Steam location)",
    )
    parser.add_argument(
        "--output",
        type=Path,
        help="write the JSON inventory here instead of stdout",
    )
    args = parser.parse_args()

    try:
        result = inventory(args.game_dir.expanduser().resolve())
        rendered = json.dumps(result, indent=2, ensure_ascii=False) + "\n"
        if args.output:
            output_path = args.output.expanduser().resolve()
            output_path.parent.mkdir(parents=True, exist_ok=True)
            output_path.write_text(rendered, encoding="utf-8")
        else:
            sys.stdout.write(rendered)
    except InventoryError as exc:
        print(f"inventory error: {exc}", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

