# TODO

## HUD

* The HUD keeps copies of the player's state: `DrivingAid.vehicle`, `FollowedVehicleChip.vehicle`,
  `PlayerVehicleChip.vehicle` (set from `PlayerServer`/`PlayerCameraServer` signals).

### Scenario panel (Shift+F2, `hud/scenario_panel.gd`)
* A scenery started with `-s` shows the file name as the title and an empty "Scenario
  description" tab, although its header has `//$n`, `//$d` and `//$i` (seen on
  `$zwierzyniec_tlk.scn`; the same before the "Scenario progress" tab was added).
* "Scenario progress" (`ScenarioTask`) tells only what the driver already has - its timetable and
  the order the scenario's events gave it so far; an order an event will give later cannot be
  known ahead, events being tied to tracks, not to vehicles.
* The trainset's `assignment <lang> "<text>" ... endassignment` block
  (simulationstateserializer.cpp:197-205, the original's "Assignment" in the scenario window) is
  not parsed.

### Problem reports (`bug_report/`)
* The reporting endpoint (`maszyna/bugtracking/endpoint`, the Cloudflare Worker in
  `MaSzyna-Reloaded/reports`, `worker/`) is on a personal `workers.dev` account; moving it to the
  project's account or domain changes that address.
* A command carries no sender (`VehicleServer.vehicle_command_received`), so the report's command
  audit cannot tell the player's commands from the scenario's or the console's.

### Settings screen (`settings/`)
* A light a caller makes by hand (`E3DRenderingServer.spot_light_create()`/`omni_light_create()`)
  keeps the `scenery/lights/size` it was made with.
* In a scenery the panel pauses nothing, and the world takes keys before the panel swallows them -
  the cab may react to keys meant for the settings.
* Not on the screen, editor-only: `import/*`, `python/home`, `locale/translations`,
  `smoke/modern/atlas`, `smoke/modern/atlas_frames`.
* `settings.json` repeats the readers' defaults: the registration in `libmaszyna.gd` runs only in
  the editor. One registrar that runs in the game too would let the screen take hints and defaults
  from `ProjectSettings`.
* A drop-down's popup is mouse-only; the keyboard walks its choices with left and right.
* Weather > Advanced lacks `near_rain_color`, `mid_rain_color`: the screen has no row for a
  `Color`.
* `hud/user_settings_panel.gd` (demo_3d) and the editor dock keep their own widgets; the
  dock's `render/fxaa_enabled` is read by nothing (the game reads `render/screen_space_aa`).

### Game directory (`GameDirWindow`)
* The warning chip's "Configure" is mouse-only; from the keyboard the window is reached only
  through the dialog shown at launch.

### Driving aid (`hud/driving_aid.gd`)

* Left out (`driveruipanels.cpp:42-205`): the reverser letter, the grade, the slipping `!`, the
  brake cylinder pressure, the load exchange / vehicle ahead line, the alerter/SHP line.
* An EIM vehicle shows `MainCtrlPos + ScndCtrlPos`; the original `eimic_real` % plus `MainCtrlPos`
  and the integrated brake's `eimic` (`EIMCtrlType` not exposed).
* The nearest signal and its lights (postponed): a memcell -> signal head link recorded from the
  scenery's `multiple`; the lights' colours have no getter in `E3DRenderingServer`.

## Translations

* The HUD's help (`hud/help.gd`) shows `action.capitalize()` as a msgid, so a new input
  action needs its capitalised name added to `translations/*.po` by hand.

## Linux release built on an old glibc

* `release-linux-symbols` (`compile-release-symbols`) still builds on the host; needs the
  `release-linux` container.
* A local install holds the host-built debug export template until `ci/fetch-godot.sh` replaces it.

## CI

* A pull request from a fork has a read-only token: after a `GODOT_VERSION` bump it cannot
  publish the engine release, and it publishes no prerelease.
* Android: only `arm64`; the `android_x86_64` preset has no template.
* The `maszyna-reloaded-<branch>` prerelease of a pull request stays after it is merged or closed.
* The Windows installer and the exe are unsigned: SmartScreen asks "Run anyway". Candidates:
  SignPath Foundation (free for open source, signs in GitHub Actions), Certum Open Source Code
  Signing (cloud key, awkward in CI), Azure Trusted Signing (eligibility for individuals limited).
* The game is a new repository: the workflow (`.github/workflows/build.yaml`) and the build
  through the submodule (`ci/docker/entrypoint.sh`, `make release-*`) have not run yet.
* `tests/fixtures/` is a copy of libmaszyna's fixtures as they were at the split - only what the
  game's tests need should stay.

## The original's driver (ai_driver/, libmaszyna #297)

* **`universal_brake_button` 0, 1, 2 sent on every driver update** while coupling, standing
  (calkowo SN61 log 2026-10-09, `shunt_sn61_couple.scn`): check against the original's
  `universal` handling before treating it as a bug.

* **The AI stops at a Tm at Ms1, not 7-12 m before it** (shunting, SN61-02 + a wagon,
  calkowo_sn61_zima.scn, Paszki Tm7, 2026-10-07): at "0.0 km" to the stop point it still ran
  11 km/h and stood with its buffers past the mast, braking hard (pipe 2.8 bar). The original's
  shunting range is 5-25 m (`Driver.cpp:6715-6716`, ported the same). Measure with a probe - speed,
  distance of the front, `brake_distance`, when braking starts - against the original's.
* **Preparing and releasing the engine** (`Driver.cpp:2759-3012`): diesel heating
  (`PrepareHeating()`), pantograph air (`bPantKurek3`, `PantsValve`) and the speed a pantograph
  counts as up at, ground and motor overload relay resets, SN61's idle position,
  `mastercontrollersetreverserunlock`, motor blowers, spring brake, doors, releaser and brakes on
  putting away; compressor presence not asked; the brake handle's driving position cued, not
  checked; `Activation()`'s move to another vehicle (EN57, ET41); `ShuntModeAllow`. On Stary Jawor
  sa134-014 and WMB10-819 report their line breaker open after being prepared.
  `PrepareEngine()`'s readiness compares the main reservoir, the original the feed pipe
  (`ScndPipePress`, Driver.cpp:2843-2851).
* **Orders**: `engine_active` lost on a breakdown while driving; the trainset's timetable and
  velocity from the `.scn` (`OrdersInit`); a push-pull set turning only at `@` (`movePushPull`);
  `OrderCheck()`'s doors; lights - lamp inventory (`iInventory`), the far end put out on
  `Disconnect` (`Driver.cpp:2510-2525`), the player's vehicle on taking over (`Driver.cpp:5662`),
  `Global.AITrainman`'s Pc5; `SetSignal`; station announcements and guard signals of `Timetable:`.
* **Trainset reading**: stretched couplers, doors, light, relays of the other vehicles, the
  individual release of an overcharged vehicle, the parking brake of a speed control unit, EP
  brakes in `IsConsistBraked`, `BrakePressureActual.PipePressureVal` (taken as 3.9).
* **Speed**: obstacles, an aggressive driver, EMU/DMU thresholds, cargo trains' and couplers'
  acceleration limits, the braking test.
* **Traction**: EN57 does not prepare (`Activation()` not ported); doors closed and departure
  signal off before power (`Doors()`, `DepartureSignal` not published); no-current sections
  (`fOverhead2`, `iOverheadZero`); shunting mode of a 2Ls150 and of an induction motor; SN61's idle
  position after the reverser (Driver.cpp:5778); the input action for `maxcurrent_sw` (Ctrl+F);
  `Engine:EngineMaxTemperature` (Mover.cpp:8306, not in the vendored Mover); the radio off after a
  Radio-Stop.
* **Braking**: the braking test (`ForcePNBrake`, `DynamicBrakeTest`), unlocking the pipe before
  the releaser (`control_main_pipe()`), individual release of an overcharged wagon, `manualbrakon`
  on putting away, the weather's friction; why the eszelon almost stopped on n226 before E4 (x20).
* **Speed table**: passenger stop points, section and road speeds, stopping at an SBL, crossings,
  the switch branch of an event on a switch, the cargo train's distances; vehicles ahead - the scan
  from the rear end (Driver.cpp:6642), a signal beyond a vehicle ahead (`isforsomeoneelse`,
  Driver.cpp:1566, 1709), coupler adapters in the gap, `braking_distance_multiplier()` in the
  target speed. `VelLimitLastDist` ported, `SwitchClearDist` only as far as it extends it,
  `moveSwitchFound`/`moveStopPointFound` (Driver.cpp:1043) not.
* **Timetable**: the departure signal before the doors close (Driver.cpp:4305-4320) and the wait
  after (`Random(-3.5, -1.0)`, Driver.cpp:4351); `moveGuardOpenDoor`; car load weights
  (`load_weights.txt`) and visible load (`update_load_visibility()`, `update_load_sections()`);
  passenger announcements; the load unit `"tons"` vs the original's `"tonns"` (Mover.cpp:4464);
  the guard's message beside the train (`<timetable>.ogg`, Driver.cpp:4466-4472, 6862-6870); the
  radio channel hint (Driver.cpp:1113); `UpdateDelayFlag()`; a player's stop left far behind
  (Driver.cpp:1190-1200); `VelSignalLast` reset by a stop (`eSignNext`); a player leaving a stop
  early keeps counting the delay from it.
* **Timetable panel** (`hud/timetable_panel.gd`): the list from `StationStart`
  (driveruipanels.cpp:392), the expanded mode's weight and length (:360-386), re-resolving the
  followed driver on coupling.
* **The driver's hints**: the compartment lights go by the scenery's light level alone - the
  consist's shade (`ConsistShade`) is not published.
* **The Hints chip** (`hud/driver_hints.tscn`): its place under the driving aid not seen in the
  running game yet.
* **Coupling and uncoupling - not checked on a scenery** (linia61, calkowo too heavy for a headless
  probe so far). Left: high voltage and power lines of a coupler number; `coupler_connect` joins in
  a fixed order; lights after the trainset changed (`CheckVehicles()`); `bh_EPB`; a coupling a
  player left half done; margins of modern vehicles, the weather and a late train (`moveLate`).
* **`movePrimary` is not ported** (`TController::primary()`, Driver.h:226-231): the others defer
  to it (Driver.cpp:2410-2430), only it runs the dynamic brake test (Driver.cpp:7856), and one
  moving through a gangway takes over (Driver.cpp:5870).
* **To drive again in game**: Stary Jawor Osobowy 1, the AI's n323m ran past a signal at stop
  while the player shunted in SM42-329 (two likely causes fixed on krzyzowa2).
