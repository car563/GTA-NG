from __future__ import annotations

import json
import tempfile
import unittest
import zipfile
from pathlib import Path

from tools.inventory_beamng_vehicles import InventoryError, inventory


class InventoryTests(unittest.TestCase):
    def _write_archive(self, path: Path, info: str, members: tuple[str, ...]) -> None:
        with zipfile.ZipFile(path, "w") as archive:
            archive.writestr(f"vehicles/{path.stem}/info.json", info)
            for member in members:
                archive.writestr(member, b"fixture marker, not a game asset")

    def test_lists_only_manifest_car_archives_and_does_not_extract_assets(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            game_dir = Path(temporary)
            vehicle_dir = game_dir / "content" / "vehicles"
            vehicle_dir.mkdir(parents=True)

            (game_dir / "integrity.json").write_text(
                json.dumps(
                    {
                        "version": "test-build",
                        "integritydata": [
                            ["/content/vehicles/covet.zip", 1, "hash"],
                            ["/content/vehicles/prop.zip", 1, "hash"],
                        ],
                    }
                ),
                encoding="utf-8",
            )

            self._write_archive(
                vehicle_dir / "covet.zip",
                '{\n"Brand": "Ibishu",\n"Type": "Car",\n}',
                (
                    "vehicles/covet/covet.dae",
                    "vehicles/covet/covet_body.jbeam",
                ),
            )
            self._write_archive(
                vehicle_dir / "prop.zip",
                '{\n"Type": "Prop",\n}',
                ("vehicles/prop/prop.dae",),
            )

            result = inventory(game_dir)

            self.assertEqual(result["beamng_version"], "test-build")
            self.assertEqual(result["vehicle_count"], 1)
            self.assertEqual(result["vehicles"][0]["vehicle_id"], "covet")
            self.assertEqual(result["vehicles"][0]["brand"], "Ibishu")
            self.assertEqual(
                result["vehicles"][0]["model_asset_paths"],
                ["vehicles/covet/covet.dae"],
            )
            self.assertFalse(result["vehicles"][0]["assets_copied"])
            self.assertFalse(result["asset_bytes_extracted"])
            self.assertFalse((game_dir / "vehicles").exists())

    def test_missing_integrity_manifest_is_reported(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            with self.assertRaises(InventoryError):
                inventory(Path(temporary))


if __name__ == "__main__":
    unittest.main()

