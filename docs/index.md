---
layout: home
---

<div style="display: flex; justify-content: space-between; align-items: center;">
<img src="assets/godot-logo.png" style="width: 40%; height: auto"/>
<img src="assets/maszyna-logo.jpg" style="width: 40%; height: auto" />
</div>

## MaSzyna Reloaded - the game

This repository is the game: the screens a player goes through, the HUD over a running scenery,
the settings, the problem reports and the releases. Everything that simulates, loads or draws
MaSzyna's world is **libmaszyna** (MaSzyna Reloaded Core), a submodule in `vendor/libmaszyna`
whose addon stands in `addons/libmaszyna`; its own documentation describes the servers, the
vehicles, the scenery and the Lua API this game is built on.

What lives here:

* **Screens** - `startup/` (the first scene, loading the game scene in the background),
  `scenery_selector/` (scenery, trainset and vehicle selection), `loading_screen/`, `settings/`
  and `game.tscn`, the scene that loads a scenery into a `SceneryWorld` (`world/`).
* **[UI components](ui)** - `ui/`: the windows, dialogs, buttons, switches, sliders and chips
  every screen is built from.
* **[HUD](hud)** - `hud/`: the top bar and its menus, the driving aid, the hints, the timetable,
  the vehicle card and selector, the transcripts, the logs; the diagnostic windows are
  libmaszyna's `DebugHud`, instanced by the game's HUD.
* **The sky** - `world/sky/`: the backends drawing libmaszyna's `MaszynaEnvironmentNode`
  (gnd-skydome with gnd-weather); Tokisan's Sky3D is the separate
  [maszyna-environment-tokisan-sky3d](https://github.com/MaSzyna-Reloaded/maszyna-environment-tokisan-sky3d)
  addon.
* **The original's driver** - `ai_driver/`: the AI driver (Driver.cpp, mtable.cpp ported), the
  `DriverImplementation` libmaszyna's `DriverServer` runs for the drivers a scenery declares.
* **Road traffic** - `world/world_pck.tscn` and `world/traffic/`: the cars, buses and lorries of
  `dynamic/` (`RoadTrafficVehicles`, by the weights of the world's scene) driven by libmaszyna's
  `RoadTrafficServer` on the roads of a world's sectors while they are loaded
  (`MaszynaWorld.sector_roads_built` / `sector_roads_freeing`); how busy the roads are by the hour
  and where is the scene's curve and heat map, how busy and how many vehicles the settings' two
  rows (Vehicles).
* **[Problem reports](bug-reports)** - `bug_report/`: what the game sends to the reporting
  endpoint.
* **Releases** - `make release-linux`, `release-windows`, `release-android` and the CI workflow
  publishing a branch's prerelease.

## Building

```
git submodule update --init --recursive
make compile-debug        # libmaszyna from vendor/libmaszyna into bin/libmaszyna/
godot-double --path . -e
```

During development against a local checkout of libmaszyna rather than the submodule:
`make libmaszyna-local LIBMASZYNA_LOCAL=<path>`, and `make libmaszyna-submodule` to go back.
