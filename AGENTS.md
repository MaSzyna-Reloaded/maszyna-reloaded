This repository is the game - MaSzyna Reloaded's screens, HUD, settings, problem reports and
releases - built on **libreloaded**, the `vendor/libreloaded` submodule whose addon stands in
`addons/libreloaded`, with its plugin **libmaszyna** (`vendor/libmaszyna`, `addons/libmaszyna`).
Everything in `vendor/libreloaded/AGENTS.md` and `vendor/libreloaded/CODE_STYLE.md` binds here as
written, with these substitutions and additions.

Where the game is not libmaszyna:

* the Godot project is the repository's root: `--path .`, `res://` is this directory; libmaszyna's
  `demo/...` paths read as the root here (`project.godot`, `tests/`, `tests/fixtures/`)
* REQUIRED: **the game never changes libmaszyna from here.** `vendor/libmaszyna` and
  `addons/libmaszyna` are libmaszyna's; a change the game needs there is made in libmaszyna's own
  repository (a local checkout: `make libmaszyna-local LIBMASZYNA_LOCAL=<path>`), and the
  submodule is moved to it once it is pushed
* REQUIRED, ALARM: **separation of concerns between the two repositories.** libmaszyna knows
  nothing of the game: no game class, path, setting or input action is named in it. What the game
  needs from libmaszyna is a public API, a signal or a base class there (`SkyEnvironment`,
  `DebugHud`, `CabinSystem.vehicle_cabin_built`); a breach is reported to the operator
* the game's sky is a backend extending libmaszyna's `SkyEnvironment` (`world/sky/`),
  placed beside the `EnvironmentNode` it draws, with the node's `configuration_changed`
  connected to its `apply_configuration()` in the scene
* the original's AI driver is the game's (`ai_driver/`, `MaszynaAIDriver`): a
  `DriverImplementation` registered with libmaszyna's `DriverServer` under
  `SceneryInstancer.DRIVER_IMPLEMENTATION` - by `game.gd` and by the tests' hook - and thinking for
  the drivers a scenery declares; libmaszyna knows the name, never the class
* addons from outside (`gnd-*`, `gut`) are submodules in `vendor/` with a versioned relative link
  in `addons/`; an addon taken as a copy (`debug_menu`) stands in `addons/` as it came,
  never moved into another addon; `vendor/` carries a `.gdignore`, so Godot sees an addon only
  through its link
* `addons/libreloaded` and `addons/libmaszyna` are links to the checkout in use - the submodule or
  a local one (`make libreloaded-local`, `make plugin-local`) - and are not versioned: `make links`
  makes them, after a clone too, and libreloaded's build makes only a missing one
* REQUIRED, ALARM: **the game speaks only libreloaded's core data and servers** (`VehicleData`,
  `VehicleLivery`, `VehicleInfo`, `VehicleCatalogServer`, ...); its plugins (libmaszyna) only
  supply backends and their own classes behind them - no cast to `MaszynaVehicleData`, no
  `MaszynaVehiclesBank` or `MaszynaRailVehicle3DInstancer` in a screen (libreloaded's
  `.claude/skills/maszyna-architecture/SKILL.md`, "The core's data is the interface")
* player-facing UI follows the `game-ui` skill (`.claude/skills/game-ui/SKILL.md`)
* every key is an action of this `project.godot`; the input map holds libmaszyna's actions as
  well, as Godot keeps no input map per addon
* the game's tests are in `tests/` with their own harness (`tests/maszyna_gut_test.gd`) and
  fixtures (`tests/fixtures/`); libmaszyna's tests stay in libmaszyna. Run as libmaszyna's rules
  say, with `--path .`
* a headless run's game log files go to `logs/headless/` (`game.gd`, `HEADLESS_LOG_DIRECTORY`)
* `--check-only -s` checks nearly nothing here: almost every game script reaches an autoload
  (libmaszyna's `CabinSystem`, `SceneryInstancer`, ..., or the game's own), and without them it
  only reports `Identifier not found` - a game script is checked by `--import` and by its tests'
  GUT run, as libmaszyna's rules say
* releases are cut here: `make build-number`, `make release-linux` / `release-windows` /
  `release-android`; the CI workflow builds libmaszyna from the submodule, exports and publishes
  a pull request's prerelease, main's nightly, a `release/<name>` branch's candidate and a tag's
  release (`.github/workflows/build.yaml`)
* a log view of many lines is `LogLines` (`hud/log_lines.gd`, `add_line()`): it draws only while
  it is visible and drops the oldest lines in batches. Never `RichTextLabel.remove_paragraph()`
  per line - it walks the whole text, and the Logs panel took 71% of the main thread on Wrzosy
  that way
* documentation of the game is the Jekyll site in `docs/` (UI components, HUD, problem reports);
  libmaszyna documents itself
* `make install-git-hooks` once per clone: the pre-commit hook runs libmaszyna's
  `scripts/check-staged-uids` on this repository
