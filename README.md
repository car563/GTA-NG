# GTA-NG

A solo GTA V Legacy Story Mode mod project. The goal is to replace GTA cars with vehicles sourced from the player's own BeamNG.drive installation and add BeamNG-inspired handling and crash deformation.

## First playable prototype

The repository now includes a ScriptHookVDotNet raw C# script at `scripts/GTA-NG.3.cs`. It activates when the player drives one of these six GTA compact cars: Blista, Prairie, Issi, Panto, Dilettante, or Kanjo. It applies a modest power increase and grip reduction, then adds impact dents and engine damage after harder collisions.

This is a playable gameplay prototype, not a BeamNG vehicle conversion: the six vehicles still use their original GTA models. GTA's script natives cannot reproduce BeamNG's wheel-by-wheel soft-body physics. Actual BeamNG model imports and larger vehicle coverage need a separate conversion pipeline.

## Requirements and install

- GTA V Legacy on PC.
- A Script Hook V build compatible with the installed GTA V version.
- ScriptHookVDotNet v3 compatible with that Script Hook V/GTA build. These dependencies are installed manually and are not included here.
- Copy `scripts/GTA-NG.3.cs` into the GTA V game folder's `scripts` directory. Create the directory if needed. ScriptHookVDotNet compiles versioned `.3.cs` source scripts when the game starts.

Script Hook V and ScriptHookVDotNet are required, so this prototype is not currently a one-click Melty installation. Do not launch GTA Online with these files installed; this project is for Story Mode only.

## BeamNG inventory tool

The inventory utility reads the local BeamNG integrity manifest and official vehicle archives to report car IDs, brands, and model file paths. It does not extract or copy game assets.

Requires Python 3.10 or newer. Run it from the repository root:

```powershell
python tools/inventory_beamng_vehicles.py --game-dir "C:\Program Files (x86)\Steam\steamapps\common\BeamNG.drive" --output work\beamng-vehicles.local.json
```

The output is machine-specific and should stay local; do not commit generated inventories or game assets.

## Checks

Run the inventory unit tests with the Python standard library:

```powershell
python -m unittest discover -s tests -v
```

## Current status

Implemented: BeamNG local car inventory and first Story Mode driving/damage script.

Still needed: convert a BeamNG vehicle model and its data into a GTA-compatible format, tune and validate the physics in-game, test deformation behavior, and create a compatible installation package. The prototype script has not yet been installed or exercised in GTA V.

## Asset handling

- Story Mode only. Do not use this mod in GTA Online.
- Do not include BeamNG or GTA V game assets in this repository or release packages.
- Any later conversion step must use files from the player's own installed games and distribute only original mod code/configuration, not extracted game assets.
