---
layout: page
title: "Performance - profiling with perf"
---

How to see where the game's CPU time goes with Linux `perf`: which thread, which library, which
function, and which phase of the frame (simulation, drawing, scripts). The numbers taken this way
are in [baseline](baseline.md).

`perf` samples the CPU's call stack a few hundred times a second. A function's share of the
samples is its share of the CPU time. It shows native code - the engine and libmaszyna - by name; a
GDScript function shows as `GDScriptFunction::call`, so a script's cost is read from the native
function it calls or that calls it.

## Before the first run

1. **Allow call stacks.** At the default `kernel.perf_event_paranoid=2` only flat profiles work
   ("Failure to open any events for recording" with `-g`). In a terminal (not through `!` in an
   agent - `sudo` needs a TTY):

   ```
   sudo sysctl kernel.perf_event_paranoid=1
   ```

   It lasts until a reboot; `sudo sysctl kernel.perf_event_paranoid=2` puts it back.

2. **Build libmaszyna with optimisations and symbols:** `make compile-profiling` (RelWithDebInfo;
   it replaces the library the editor loads). `make compile-debug` builds the Mover at `-O0`, and
   its profile points at the simulation as if the code were at fault. Back with
   `make compile-debug`. After switching builds, `godot --headless --path . --import`.

3. **Get the tools** (NixOS): `nix shell nixpkgs#perf nixpkgs#gamescope`. Elsewhere `perf` comes
   with the kernel's tools (`linux-tools`).

4. **Plug the laptop in.** On battery an integrated GPU and the CPU are clocked down and every
   number is off (on Wrzosy the GPU took 94 ms on battery and 51 ms on AC). Check
   `cat /sys/class/power_supply/*/online` (1 is AC).

## Running the game to measure

A real renderer without a window, at a set resolution:

```
WAYLAND_DISPLAY= gamescope --backend headless -W 1920 -H 1080 -r 240 -- \
    godot --path . --audio-driver Dummy --log-file /tmp/godot.log -- -s wrzosy_eie8310.scn
```

* `-s <scenery>` loads the scenery and puts the player in its first trainset; `-v <vehicle_id>` in
  another.
* `-r 240`: gamescope presents at 60 Hz by default, which rounds every frame to 16.7 ms steps (a
  52 ms frame shows as 66.7 ms). The game's own VSync setting rounds the same way.
* `--log-file`: without it every run rotates the player's `logs/app.log`. Under gamescope the game
  is not headless, so its own log files (`ai.log`, `gameplay.log`, `scenario.log`) still go to the
  player's `logs/` - copy them away first if they matter.
* Plain `--headless` has no renderer and crashes a big scenery; `xvfb-run` opens a window on a
  Wayland desktop.

Wait until the scenery is loaded and has run for 20 s or so (loading Wrzosy takes 1-2 minutes)
before recording.

## Recording

Find the game's process (the newest `godot`, not `gamescope` or `gamescopereaper`) and record 20 s:

```
pid=$(pgrep -n -f "godot --path")
perf record -e cycles:u -F 499 --call-graph dwarf,16384 -o perf.data -p "$pid" -- sleep 20
```

* `-e cycles:u`: user-space cycles. The default event needs kernel access at paranoid 1.
* `-F 499`: 499 samples per second of CPU time per thread. A thread that is busy all the time gives
  about 499 x 20 = 9 980 samples in 20 s; fewer means it waited (slept) for part of the time.
* `--call-graph dwarf,16384`: full stacks from the debug info. The engine and libmaszyna are not
  built with frame pointers, so `-g` (frame pointers) gives broken stacks. Deep stacks past 16 KB
  are cut: a phase high in the stack may then be missed in some samples.
* The file is large (about 200 MB for 20 s), and reading it takes a minute or two.

## Reading

**Which thread works** - the main thread is the one with the most samples:

```
perf script -i perf.data -F tid | sort | uniq -c | sort -rn | head
```

Its count against 9 980 says how busy it is: 9 900 means the CPU limits the frame, a much lower
number means the main thread waits - for the GPU, as a rule.

**Which library** (`--tid` for the main thread only):

```
perf report -i perf.data --tid <tid> --no-children --sort dso --stdio -g none
```

**Hot functions by their own time** (self):

```
perf report -i perf.data --tid <tid> --no-children --sort sym --stdio -g none | head -40
```

**Phases by their whole time** (inclusive - the function with everything it calls). Filter the
list for the frame's phases:

```
perf report -i perf.data --tid <tid> --children --sort sym --stdio -g none \
    | grep -E "Main::iteration|SimulationServer::simulation_advance|stepping_advance|RenderingServerDefault::_draw|GDScriptFunction::call|DriverServer"
```

What the phases are in this game:

| Frame | What it is |
|---|---|
| `Main::iteration` | the whole frame of the main thread |
| `SimulationServer::simulation_advance` | everything on the simulation step: vehicles, AI drivers, events, cab logic |
| `MaszynaMoverVehicleServer::stepping_advance` | the Mover step of every vehicle |
| `DriverServer` | the AI drivers (GDScript, `ai_driver/`) |
| `RenderingServerDefault::_draw` | the engine drawing the frame (CPU side) |
| `RenderingDevice::swap_buffers` | handing the frame over; grows when the GPU is behind |
| `GDScriptFunction::call` | all GDScript, wherever it runs |

**Who calls a function** - for a function that is expensive in itself, say
`Engine::is_singleton_editor_only`:

```
perf report -i perf.data --tid <tid> --no-children --sort sym --stdio -G \
    -S "Engine::is_singleton_editor_only(StringName const&) const" | head -60
```

The `-S` name has to be written exactly as `perf report --sort sym` prints it, arguments included.

**A flame graph** - every stack at once, the width being the time:

```
nix shell nixpkgs#flamegraph --command sh -c \
    'perf script -i perf.data --tid <tid> | stackcollapse-perf.pl | flamegraph.pl > main.svg'
```

Open `main.svg` in a browser; clicking a frame zooms into it.

## Comparing two builds

* **Same scenery, same place, same settings, on AC,** and the same length of run. Godot's own
  numbers vary by a few ms between runs, so one run is not a difference.
* **Compare the shares of the same phase** in both profiles, and the main thread's sample count.
  A phase that shrinks while the frame stays as long means something else took the time - look at
  which phase grew, and at whether the main thread is still busy all the time.
* **Split CPU from GPU first.** If the main thread is not busy all the time, the GPU limits the
  frame, and making CPU code faster will not show. Pausing the simulation, or running at a lower
  resolution, tells which one limits it.
