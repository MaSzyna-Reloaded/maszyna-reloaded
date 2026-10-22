---
layout: page
title: "Performance - baseline"
---

Measurements of the game as it runs, taken before any optimisation and used to decide what to
change. The rule of the work is **no change to the picture**: no setting is lowered, a change counts
only if the image stays the same. What would change the image is listed in
[out of scope](out-of-scope.md). Changes are in [changes](changes.md). libmaszyna keeps its own
part in its `docs/performance/`.

## How it is measured

* **Machine:** a laptop, AMD Ryzen with Radeon "Renoir" integrated graphics (PCI `1002:1636`),
  8 threads. Godot 4.7.2 double (nixpkgs), libmaszyna built with `make compile-profiling`
  (RelWithDebInfo). A `compile-debug` build runs the Mover at `-O0` and misleads. The engine is
  nixpkgs' editor binary (`godot.linuxbsd.editor.double`) and the extension a `template_debug`
  library, so an exported release runs somewhat faster than these numbers.
* **Real renderer, no window:** `gamescope --backend headless -W 1920 -H 1080 -r 240 -- godot
  --path . --audio-driver Dummy -- -s <scenery>.scn`, with `WAYLAND_DISPLAY` unset.
* **Recorder:** a throwaway autoload, never committed, hooked through an untracked `override.cfg`.
  Per second it logs FPS, the frame's median and maximum, `viewport_get_measured_render_time_cpu`/
  `_gpu`, draw calls and primitives. It takes one screenshot for A/B comparisons. It pauses the
  simulation on request, and it sends the game's log files beside the run, not over the player's.
* **CPU profile:** `perf record -e cycles:u -F 499 --call-graph dwarf,16384 -p <pid> -- sleep 20`
  on the profiling build. The share of a phase is the share of the main thread's samples whose
  stack holds it. How to record and read it: [profiling with perf](profiling.md).
* **The player's settings** (`settings.cfg`): TAA off, SSIL on, SDFGI, SSAO, SSR, volumetric fog
  and glow off. VSync is on by default.
* **The second machine** (from 2026-10-19): a desktop, AMD Ryzen 9 5950X (16 cores, 32 threads)
  with a Radeon RX 9060 XT, Fedora 44 (KDE), Godot 4.7.2 double from `/usr/bin/godot` (a stripped
  editor build). The same settings and resolution as above, VSync off; the recorder warms up for
  120 s after the scenery has loaded before it measures 60 s. How it differs from the laptop's
  method: [profiling with perf](profiling.md), "On Fedora".

### Traps that cost runs

* **On battery the GPU stays at 400-635 MHz instead of 1600 MHz** while 100% busy. The same frame
  took 94 ms of GPU on battery and 51 ms on AC, and scenery loading took twice as long. Every
  measurement is taken on AC; `/sys/class/power_supply/*/online` is checked before a run.
* **VSync and gamescope quantise the frame** to multiples of 16.7 ms: a 52 ms frame shows as
  66.7 ms (15 FPS). Turning VSync off in the game is not enough, because gamescope still presents
  at 60 Hz. Runs use `gamescope -r 240`.
* **`Performance.TIME_PROCESS` does not read as a frame's share** (it showed 200-2400 "ms" in a
  67 ms frame). The phases come from `perf`.
* **perf needs `kernel.perf_event_paranoid` <= 1** for call graphs; at 2 only flat profiles work.
* **Under gamescope the game is not headless,** so it writes its log files (`ai.log`, ...) into
  the player's `logs/`. The recorder redirects `debug/file_logging/log_path`.

## Wrzosy (`wrzosy_eie8310.scn`)

The player in the cab of EP07-1024 standing at Wolica: about 300 vehicles, about 8 500 draw calls
and 3.7 M triangles in view, video memory 1.8 GB.

| State | FPS | Frame (median) | Render GPU | Render CPU |
|---|---|---|---|---|
| on battery (invalid) | 15 | 66.7 ms | 94 ms | 12 ms |
| on AC | ~15 | 64-68 ms | 51-52 ms | 11-12 ms |
| on AC, simulation paused | **18.5-20** | **52-55 ms** | 52 ms | 21 ms |

* **The main thread is busy 99% of the time** (about 9 900 samples of 9 980 possible in 20 s).
  The frame is longer than the GPU's work, so the CPU limits it.
* **With the simulation paused the frame falls to the GPU's time.** The simulation adds about
  15 ms to the frame; without it Wrzosy on this GPU is GPU-bound at about 19 FPS.
* **Phases of the main thread** (after the log panel fix, `changes.md`):

| Phase | Share |
|---|---|
| `SimulationServer.simulation_advance` (everything on the simulation step) | 70% |
| of it: the Mover step (`MaszynaMoverVehicleServer::stepping_advance`) | 54% |
| of it: GDScript on the step (AI drivers, cab logic, sound) | about 25% |
| `RenderingServer` drawing (CPU side) | 15% |

* **The simulation runs on the frame's real time:** the Mover integrates `ceil(delta / 10 ms)`
  sub-steps every frame for every vehicle (as the original, `drivermode.cpp:193-206`). A longer
  frame means more sub-steps in the next one, so the cost of one sub-step counts twice. libmaszyna's
  `docs/performance/` holds the split of the Mover step.

### The GPU by system

The recorder's ablation: the simulation paused, one system switched off at a time for 6 s, the GPU
time averaged over the last 4 s, then restored (1920x1080, on AC, GPU at 1600 MHz, day).

| Switched off | GPU | Saved | Render CPU |
|---|---|---|---|
| nothing | 53.5 ms | - | 20.7 ms |
| sun shadows (4 cascades) | 40.8 ms | **12.7 ms** | 15.7 ms |
| SSIL (the player's setting) | 39.4 ms | **14.2 ms** | 16.9 ms |
| node lights (vehicles, cab) | 50.6 ms | 2.9 ms | 21.0 ms |
| sky (background, ambient and reflections) | 51.5 ms | 2.0 ms | 21.0 ms |
| lamp shadows (positional atlas) | 53.1 ms | 0.4 ms | 21.1 ms |

The geometry itself - the opaque pass and the depth prepass - is the remaining ~21 ms; the sun's
shadow cascades draw the same geometry four more times, and cost the renderer 5 ms of CPU.

### The AI drivers

`DriverImplementation::update` (the game's `ai_driver/`, GDScript) is 16.8% of the main thread at
1280x720, after the libmaszyna changes. Of it:

* 7.6% is the GDScript interpreter itself, and most of the rest `Variant` work and property reads
  by name (`Variant::get_named`) - the cost of interpreting about 7 400 lines at 10 Hz for every
  moving train;
* **commands sent to vehicles: 5.9% of the thread** (`VehicleServer.vehicle_send_command`). A
  command renews the vehicle's whole state (`VehicleController::command_executed` >
  `update_state`) and is announced: `VehicleServer.vehicle_command_received` runs the AI's own
  listener and `GamePlayLogRecorder`'s, which formats a line for `ai.log` and the Logs panel.

In one run (about 75 s of loading and 65 s running) the AI wrote 68 000 lines to `ai.log`. The
commands that make them:

| Command | Count | Why |
|---|---|---|
| `universal_brake_button` | 27 888 | the three buttons sent on every braking update, as the original does (`Driver.cpp:4248-4258`); `TMoverParameters::UniversalBrakeButton()` recomputes its flag from the power supply on each call, so a repeated one is not a no-op |
| `converter` | 20 784 | road cars (`auto_a#510` ... `auto_n#523`, about 124 each) switched on and off in turn: `_prepare_engine()` cues `CONVERTER_OFF` while `converter_overload` and `CONVERTER_ON` otherwise, so the overload flips on every update |
| `oil_pump`, `oil_pump_switch_off` | 4 147, 4 142 | the same on and off in turn |
| `compressor` | 2 256 | |

The flipping converter and oil pump and the brake buttons are in [findings](findings.md).

## Wrzosy on the Fedora desktop (`wrzosy_eie8310.scn`)

The same place and settings as above, 1920x1080, before the second round of changes (the game at
`ebe87bf`, libmaszyna at `7f7c833e`). About 743 vehicles, 264 of them driven by the AI, about
9 200 draw calls and 3.9 M triangles in view.

| Build | FPS | Frame (median, p95, p99) | Render GPU | Render CPU |
|---|---|---|---|---|
| `/usr/bin/godot`, single-threaded rendering | **22.1** | 44.4, 55.6, 64.4 ms | 7.6 ms | 7.5 ms |

* **The GPU is idle most of the frame** (7.6 ms of 44): this machine is held by the CPU alone.
* **The main thread is busy 99%** (9 848 samples of 9 980 in 20 s, the symbol build below):

| Phase | Share of the main thread |
|---|---|
| `SimulationServer.simulation_advance` | 48.4% |
| of it: the Mover step (`MaszynaMoverVehicleServer::stepping_advance`) | 24.2% |
| of it: the AI drivers (`DriverImplementation::update`, the game's GDScript) | 17.6% |
| of it: the rest of its listeners (the cab logic of every driven cab, sound's sweep) | 7.7% |
| `RenderingServerDefault::_draw` (drawing, CPU side) | 31.4% |
| `SceneTree::_process` (scripts' `_process`, sound's update) | 5.6% |

* **Drawing ran on the main thread** (the project's default `thread_model`), so the frame was the
  simulation's time plus the drawing's. Moving it to a thread of its own is the largest change of
  this round ([changes](changes.md)).
* **What the GDScript on the step is**, from probes put into the scripts for one run (never
  committed; shares of the main thread's wall time with the rendering thread already separate):

| Probe | Share | Calls a minute |
|---|---|---|
| cab lights of every driven cab (`LegacyCabinCabLights`, every step) | 8.5% | 947 000 |
| main switch of every driven cab (`LegacyCabinMainSwitch`, every step) | 7.8% | 947 000 |
| AI: traction and braking control | 6.4% | 45 500 |
| AI: route table | 2.7% | 45 500 |
| sound's `_process` (59 banks in earshot of 87) | 2.7% | 3 600 |
| AI: speed pick and the scan behind | 2.5% | 45 500 |
| door permits of every driven cab | 2.3% | 947 000 |
| AI: everything else of `_update()` | 6.4% | |
| `GamePlayLogRecorder` on commands | 0.5% | 16 300 |

* 264 cabs run three cab-logic callables each on every simulation step - the cab of every AI
  driver, nobody sitting in it.

### After the round

| State | FPS | Frame (median, p95, p99) |
|---|---|---|
| before | 22.1 | 44.4, 55.6, 64.4 ms |
| rendering on its own thread | 56.8 | 16.7, 19.1, 26.7 ms |
| + libmaszyna's changes of the round | 55.7-56.0 | 17.8-18.2, 20.0, 23.9-30.9 ms |
| + the Mover on worker threads | 56.1-58.9 | 16.7-17.8, 18.2-20.0, 23.3-25.5 ms |
| + materials without RenderingServer waits | **79.0** | 12.5, 13.3, 16.7 ms |
| the operator's settings (2560x1440, MSAA 8x, TAA, SSR, SSAO, SSIL, SDFGI), before the Mover's threads | 56.5 | 17.2, 19.1, 24.7 ms |

* With the rendering thread **two threads hold the frame**: the rendering thread is busy 83%
  (recording the commands of about 9 200 draw calls: `_render_list` 34%, the rendering graph 32%,
  binding vertex buffers about 12%, the sun's cascades about 15%), the main thread 77% (the
  simulation 80% of it: the Mover 44%, the AI 23.5%; scripts' `_process` 13%).
* The changes on the main thread after the first one show little in FPS: the rendering thread is
  the limit now (91% busy once the Mover runs on worker threads, the main thread 69%). Even on the
  operator's settings at 2560x1440 the GPU needs about 8 ms of an 18 ms frame. They leave the main thread more room, which is what a scene with more
  trains, or a slower CPU, runs into first.

## calkowo_v2, forest, day (`calkowo_v2_osoba_wil_dzien1.scn`)

The player's cab at the scenery's start, 1920x1080, on AC, with the libmaszyna changes and the
material variants (libmaszyna `docs/performance/changes.md`). Loading takes 165 s under gamescope.
About 7 900-8 100 draw calls and 2.4 M triangles in view, video memory 1.5 GB, 6 400 nodes.

| FPS | Frame (median, p95, p99) | Render GPU | Render CPU |
|---|---|---|---|
| 15.0 | 66.7, 79.4, 85.9 ms | 62-69 ms | 20-23 ms |

* **The GPU limits the frame here, unlike on Wrzosy.** The main thread is busy 92%. The CPU model
  R / (1 - k) gives 56 ms (k = 0.435, R = 31.7 ms, of which 22.8 ms drawing). The GPU needs
  62-69 ms.
* **The simulation is lighter than on Wrzosy:** k = 0.435 (Mover 0.300, AI 0.096) against 0.63.

The GPU by system (the ablation run, the simulation paused). The draw calls rose from 7 060 to
8 670 during the run, as the scenery around the player was still streaming in, so the
differences are approximate:

| Switched off | GPU | Saved | Draw calls |
|---|---|---|---|
| nothing (start / end) | 63.6 / 63.3 ms | - | 7 060 / 8 671 |
| sun shadows (4 cascades) | 50.1 ms | **13.5 ms** | 5 260 |
| SSIL (the player's setting) | 53.8 ms | **~10 ms** | 7 930 |
| sky | 60.6 ms | ~3 ms | 8 220 |
| node lights | 63.4 ms | ~0 | 8 502 |
| lamp shadows | 63.7 ms | 0 | 7 653 |

The sun's cascades over the trees are the largest system cost that is not a setting. The trees
are cut out, so they keep their `discard` and draw with their own shader in every cascade.

## calkowo_v2, forest, night (`calkowo_v2_osoba_wil_noc.scn`)

The same conditions as the day. About 9 100-9 600 draw calls, 2.4 M triangles, 1.3 GB of video
memory.

| Build | FPS | Frame (median, p99) | Render GPU | Render CPU |
|---|---|---|---|---|
| as measured first | 17.3 | 57.6, 81.7 ms | 54.4 ms | 18.6 ms |
| the dark light casting no shadow (libmaszyna `changes.md`) | **18.9** | **52.8, 68.1 ms** | **42.9 ms** | 17.6 ms |

* **The sun's shadows cost 9-11 ms at night with nothing to light:** the sky's one directional
  light had zero energy (neither sun nor moon up) and its four cascades still drew the scenery.
  Fixed in libmaszyna; the picture is the same.
* Main thread busy 90%, k = 0.366 (Mover 0.222, AI 0.093), R = 31.1 ms. The CPU model gives
  49 ms, so after the fix the frame is close to both limits.
* The street lamps: their shadow atlas costs about 2 ms, node lights about 1 ms.
* SSIL (the player's setting) costs 11-12 ms here as well.

## Still to measure

* `braniewo_szeroki.scn`; the cab driving (an AI-driven player's trainset); rain on Wrzosy and on
  calkowo_v2
