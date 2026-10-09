This repository is the game - MaSzyna Reloaded's screens, HUD, settings, problem reports and
releases - built on **libmaszyna**, the `vendor/libmaszyna` submodule whose addon stands in
`addons/libmaszyna`. Everything in `vendor/libmaszyna/AGENTS.md` and
`vendor/libmaszyna/CODE_STYLE.md` binds here as written, with these substitutions and additions.

Where the game is not libmaszyna:

* the Godot project is the repository's root: `--path .`, `res://` is this directory; libmaszyna's
  `demo/...` paths read as the root here (`project.godot`, `tests/`, `tests/fixtures/`)
* REQUIRED: **the game never changes libmaszyna from here.** `vendor/libmaszyna` and
  `addons/libmaszyna` are libmaszyna's; a change the game needs there is made in libmaszyna's own
  repository (a local checkout: `make libmaszyna-local LIBMASZYNA_LOCAL=<path>`), and the
  submodule is moved to it once it is pushed
* REQUIRED, ALARM: **separation of concerns between the two repositories.** libmaszyna knows
  nothing of the game: no game class, path, setting or input action is named in it. What the game
  needs from libmaszyna is a public API, a signal or a base class there (`MaszynaSkyEnvironment`,
  `DebugHud`, `CabinSystem.vehicle_cabin_built`); a breach is reported to the operator
* the game's sky is a backend extending libmaszyna's `MaszynaSkyEnvironment` (`world/sky/`),
  placed beside the `MaszynaEnvironmentNode` it draws, with the node's `configuration_changed`
  connected to its `apply_configuration()` in the scene
* the original's AI driver is the game's (`ai_driver/`, `MaszynaLegacyAIDriver`): a
  `DriverImplementation` registered with libmaszyna's `DriverServer` under
  `SceneryInstancer.DRIVER_IMPLEMENTATION` - by `game.gd` and by the tests' hook - and thinking for
  the drivers a scenery declares; libmaszyna knows the name, never the class
* addons from outside (`gnd-*`, `gut`) are submodules in `vendor/` with a versioned relative link
  in `addons/`; an addon taken as a copy (`debug_menu`) stands in `addons/` as it came,
  never moved into another addon; `vendor/` carries a `.gdignore`, so Godot sees an addon only
  through its link
* player-facing UI follows the `game-ui` skill (`.claude/skills/game-ui/SKILL.md`)
* every key is an action of this `project.godot`; the input map holds libmaszyna's actions as
  well, as Godot keeps no input map per addon
* the game's tests are in `tests/` with their own harness (`tests/maszyna_gut_test.gd`) and
  fixtures (`tests/fixtures/`); libmaszyna's tests stay in libmaszyna. Run as libmaszyna's rules
  say, with `--path .`
* a headless run's game log files go to `logs/headless/` (`game.gd`, `HEADLESS_LOG_DIRECTORY`)
* releases are cut here: `make build-number`, `make release-linux` / `release-windows` /
  `release-android`; the CI workflow builds libmaszyna from the submodule, exports and publishes
  the branch's prerelease
* documentation of the game is the Jekyll site in `docs/` (UI components, HUD, problem reports);
  libmaszyna documents itself
* `make install-git-hooks` once per clone: the pre-commit hook runs libmaszyna's
  `scripts/check-staged-uids` on this repository
