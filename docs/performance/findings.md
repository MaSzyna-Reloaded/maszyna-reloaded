---
layout: page
title: "Performance - findings"
---

Faults and traps found while measuring that cost frame time but are not a matter of faster code:
behaviour of the AI or of the data that makes work, or a choice the original makes that is
expensive here. Each one says what was measured, what it costs, and what was decided. The numbers
come from [baseline](baseline.md).

## Road cars switch their converter and oil pump on and off on every AI update

* **Seen:** Wrzosy (`wrzosy_eie8310.scn`), one run of about 75 s loading and 65 s running.
  `ai.log` had 20 784 `converter` commands, true and false in turn, from the road cars
  (`auto_a#510` ... `auto_n#523`, about 124 each), and 4 147 `oil_pump` / 4 142
  `oil_pump_switch_off` in turn.
* **Where:** `MaszynaLegacyAIDriver._prepare_engine()` (`ai_driver/maszyna_legacy_ai_driver.gd`),
  which cues `CONVERTER_ON` on every update until the converter counts as on. A flipping overload
  was the first guess; the probe below disproved it.
* **Cost:** every command renews the vehicle's whole state and is announced
  (`VehicleServer.vehicle_command_received`), running the AI's listener and
  `GamePlayLogRecorder`'s, which writes a line to `ai.log` and the Logs panel. All commands
  together were 5.9% of the main thread.
* **Decided:** investigate and fix (operator, 2026-10-18).
* **Measured** (a probe printing the AI's state at every command of `auto_a`): the car stands on
  "Start the engine" for good, `engine_active=false`, `engine_missing=24` (`CONVERTER` + `AIR`),
  its converter never running. Every 0.54 s the AI cues `CONVERTER_ON` again, through the cab's
  `converter_sw`, which flips - hence true and false in turn. **The road cars on Wrzosy never
  drive at all.** The car (`dynamic/road/clio/clio.fiz`: `EngineType=Dumb`, hydraulic brakes) has
  no converter section (so the Mover's default `ConverterStart=manual`) and no main reservoir.
* **Cause:** the port diverged from the original in what it reads.
  * The original's "converter enabled" is its switch: `IsAnyConverterEnabled = ConverterAllow ||
    ConverterStart == automatic` (`Driver.cpp:6141-6144`). The port read `ConverterFlag` - whether
    it runs (`RailVehiclePowerSupply.get_converter_enabled()`), in the readiness, in the consist's
    check and in the hint's "done". A road car's converter is switched on and never runs.
  * The original cues `converteron` only where a converter is (`IsAnyConverterPresent`,
    `Driver.cpp:2853`) and asks for air only with a main reservoir (`VeselVolume == 0.0`,
    `Driver.cpp:2897`). The port asked every vehicle for both.
* **Fix** (`ai_driver/`): `MaszynaLegacyDriverTrainset` reads `converter_present`,
  `converter_enabled` and `converter_explicitly_enabled` over the vehicles under control as the
  original does; `_prepare_engine()` cues the converter (and then the compressor) only where there
  is one, and wants air only with a main reservoir; the consist's check and the hints' "done" of
  `CONVERTER_ON`/`CONVERTER_OFF` read the switch (`driverhints.cpp:315-335`).
* **Not done here:** the original's readiness also wants an enabled compressor where there is one
  (`IsAnyCompressorPresent`, `Driver.cpp:2896, 6199`) and the feed pipe's pressure
  (`ScndPipePress`), not the main reservoir's - both already in `TODO.md`'s list for the driver.
* **After the fix** (Wrzosy, 1280x720): `auto_a` gets to "Shunt according to signals"
  (`engine_active=true`, `missing=0`) and drives; one `converter` command instead of 20 784. The
  AI's cost per simulated second rose from 0.167 to 0.263 s and the FPS fell from 16.0 to 15.0: a
  dozen cars now drive, updated every 0.1 s as a moving vehicle is. That is the original's work too.

## Diesel road cars cue the oil pump forever and never start their engine

* **Seen** (`ai.log` after the converter fix): about 1 850 `oil_pump` and as many
  `oil_pump_switch_off` - not on and off, but the cab's two-state switch, which sends both on each
  press (`LegacyCabinPump`) - from road cars with a diesel engine (`auto_75`, `auto_49`, ..., 124
  each), every 0.55 s, with `main_controller_increase` and `main_controller_decrease` in turn.
* **Measured** (the probe on `auto_75`): `MoverRailVehicleDieselEngine`, the oil pump's
  `start_mode=2` (`START_MODE_AUTOMATIC`), never enabled; order "Start the engine",
  `engine_missing=10` (`LINE_BREAKER` + `CONVERTER`); no `main_switch` command at all.
* **Cause of the oil pump:** the original takes `oilpumpon` as done when the pump does not start by
  hand (`start_type != manual`, `driverhints.cpp:171`). The AI's override in
  `MaszynaLegacyDriverHints.cue()` asked for `get_oil_pump_enabled()` alone, which an automatic pump
  never is.
* **Fix:** the override takes a pump that is not started by hand as done, as the original.
* **Still open - the engine never starts:** the line breaker is never closed (no `main_switch`),
  while the master controller is set to zero and to idle on every update
  (`MASTER_CONTROLLER_SET_ZERO_SPEED`, then `MASTER_CONTROLLER_SET_IDLE` for a diesel,
  `Driver.cpp:2836-2843`). The port closes the breaker through the cab's `main_on_bt`
  (`LINE_BREAKER_CLOSE`), the original by `MainSwitch(true)`. Not investigated further yet.

## The universal brake buttons are sent on every braking update

* **Seen:** 27 888 `universal_brake_button` commands in the same run - the three buttons, each
  pressed or released, on every update of `MaszynaLegacyDriverBraking`
  (`ai_driver/maszyna_legacy_driver_braking.gd`, the end of the braking control).
* **Why it is so:** the original does the same (`Driver.cpp:4248-4258`), and
  `TMoverParameters::UniversalBrakeButton()` (`Mover.cpp:3670`) is no plain setter: on each call it
  recomputes the brake's universal flag from whether 24 V or 110 V power is there, and may work the
  releaser. Leaving out a repeated press could keep a stale flag after the power changed.
* **Cost:** part of the 5.9% of all commands; each one renews the vehicle's state and is logged.
* **Decided:** recorded only (operator, 2026-10-18). Sending a button only when it changes would
  need the brake to recompute its flag when the power changes by itself.
* **After the converter fix** the driving road cars made it 71 953 commands in a run.
* **Fix where it is a no-op (operator, 2026-10-18):** only 72 of the game directory's 1 466 `.fiz`
  give a vehicle any universal button (`UBB1`-`UBB3`). With all three flags 0 the Mover's flag stays
  0 and the releaser untouched whatever is pressed (`Mover.cpp:3670-3689`), so
  `MaszynaLegacyDriverBraking` no longer sends the buttons to such a vehicle. Vehicles with buttons
  get them on every update, as before.

## Road cars derail at crossings in every run

* **Seen:** 52 to 75 `derailed cause=collision` a run in `ai.log` on Wrzosy, in builds before and
  after the AI fixes and the libmaszyna changes - road cars (`auto_71x`, `auto_131`, ...) on road
  tracks such as `wolica_przejazd014`, `wol_z_rd005`, `rd_las014`, mostly in the first 20 s.
* **Not investigated:** recorded only; it is not a cost of this work's changes.

## A run of the same build is not the same run twice

* **Seen** (Wrzosy, the Fedora desktop): the simulation paused when the scenery had loaded, then
  stepped by hand by 1/30 s 900 times. Two runs of the same build ended with 474 of the 743
  vehicles at other speeds or places, and with 36 162 against 37 309 commands.
* **Why:** before the first step the AI and the cab logic already send about 20 000 commands while
  the scenery streams in, in an order that follows the real time of the loading; and the Mover
  draws from one random engine for every vehicle (`Random()`, `utilities.cpp`: adhesion, track
  irregularities, brake delays), so the order the vehicles draw in moves every value after.
* **What it means:** a change cannot be proven to keep the behaviour by comparing two runs bit by
  bit. This round's changes keep it by construction (each says why in libmaszyna's `changes.md`),
  and by the tests of the code they touch.
* **For later:** a Mover stepped on several threads would change the order of the draws as well -
  the behaviour the same in distribution, not bit by bit. Not done; for the operator to decide.

## The cab of every AI driver ran its logic on every step

* **Seen:** 264 cabs on Wrzosy - one per AI driver - each ran the cab lights, the main switch and
  the door permits on every simulation step (`CabinSystem.register_process()`): 2.8 million
  script calls a minute, 18.5% of the main thread, for cabs nobody sits in.
* **Decided:** the lights work out what a cab shows - they run for a cab while it is shown, and
  for a cab not shown when they are read. The main switch and the door permits send commands, so
  they keep running on every step, cheaper (libmaszyna `changes.md`).

## Traps of the Fedora runs

* **`/usr/bin/godot` is stripped:** `perf` shows the engine as addresses and cannot follow the
  stacks through it, so a phase of the frame cannot be read. A build of the same version with
  symbols (`scons platform=linuxbsd target=editor precision=double debug_symbols=yes lto=none`
  on the `4.7.2-stable` tag) gives the phases; it runs about 20% slower, so FPS is measured on
  `/usr/bin/godot` and the shares on the symbol build.
* **The process is `gamescope-wl`**, not `gamescope`: `pgrep -x gamescope` finds nothing, and two
  runs ran at once until the run script took a lock (`flock`).
* **The scenery warms up for 30-40 s after it has loaded** (streaming, shader compilation): with
  30 s of warm-up the first half of a minute measured 5-20 FPS. Runs warm up 120 s.
* **A recorder that reads the render times on every frame** (`viewport_get_measured_render_time_*`)
  waits for the rendering thread when it runs on its own; it reads them once a second.
* **Godot's own script profiler** (`-d` and `EngineDebugger.profiler_enable("scripts", true)`)
  hung the game while the scenery loaded on worker threads, also with `--ignore-error-breaks`.
  The scripts' shares came from probes put into the scripts for one run instead.
* **A material type changed in memory is saved by the editor:** a first version of the material
  defaults set them on the type's base material, loaded from its `.tres`; an editor open on the
  project wrote all 13 type files back. The change works on a copy now.
