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
* **The sky** - `sky/`: the backends drawing libmaszyna's `EnvironmentNode`
  (gnd-skydome with gnd-weather); Tokisan's Sky3D is the separate
  [maszyna-environment-tokisan-sky3d](https://github.com/MaSzyna-Reloaded/maszyna-environment-tokisan-sky3d)
  addon.
* **The original's driver** - `ai_driver/`: the AI driver (Driver.cpp, mtable.cpp ported), the
  `DriverImplementation` libmaszyna's `DriverServer` runs for the drivers a scenery declares.
* **[Problem reports](bug-reports)** - `bug_report/`: what the game sends to the reporting
  endpoint.
* **Releases** - `make release-linux`, `release-windows`, `release-android` and the CI workflow
  keeping each run's games as its artifacts - a pull request's (`maszyna-reloaded-<branch>-<build>`),
  main's nightly (`maszyna-reloaded-nightly-<build>`) - and publishing a pull request from
  `release/<name>` as a pre-release (`maszyna-reloaded-rc-<name>-<build>`) on its moving tag
  `maszyna-reloaded-rc-<name>`, deleted with the pre-release when the pull request closes, and a
  tag pushed on main as the release on that tag (files `maszyna-reloaded-<tag>`); CI makes no other
  tag. Discord hears of the nightly, the pre-releases and the releases.

## Building

```
git submodule update --init --recursive
make compile-debug        # libreloaded with libmaszyna (vendor/) into bin/libreloaded/
godot-double --path . -e
```

During development against a local checkout of libmaszyna rather than the submodule:
`make libmaszyna-local LIBMASZYNA_LOCAL=<path>`, and `make libmaszyna-submodule` to go back.
