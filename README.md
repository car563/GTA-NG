# GTA-NG

A solo, GTA V Legacy Story Mode mod project: replace GTA cars with vehicles sourced from the player's own BeamNG.drive installation, then add BeamNG-inspired handling and crash deformation.

## First playable

Start with a small set of replacements. The player should encounter a replaced car in the world and drive it. Expand the roster after the first cars work.

GTA V Online is out of scope. The initial physics target is a GTA-side approximation; BeamNG's full soft-body physics is not being transplanted into GTA V.

## Current status

The repository currently contains a BeamNG vehicle inventory utility. It reads the local BeamNG integrity manifest and official vehicle archives to report car IDs, brands, and model file paths. It does not extract or copy game assets.

The vehicle replacements, GTA-side handling and deformation, one-click Melty recipe, and in-game test are not implemented yet. This repository is not a playable mod release.

## Inventory tool

Requires Python 3.10 or newer. Run it from the repository root:

```powershell
python tools/inventory_beamng_vehicles.py --game-dir "C:\Program Files (x86)\Steam\steamapps\common\BeamNG.drive" --output work\beamng-vehicles.local.json
```

The tool lists only archives recorded in BeamNG's local `integrity.json`. Its output is machine-specific and should stay local; do not commit the generated inventory or any game assets.

## Checks

Run the inventory unit tests with the Python standard library:

```powershell
python -m unittest discover -s tests -v
```

## Safety and asset handling

- Story Mode only. Do not use this mod in GTA Online.
- Do not include BeamNG or GTA V game assets in this repository or release packages.
- Use only files from the player's own installed games as input to any later conversion step.
