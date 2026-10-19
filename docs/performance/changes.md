---
layout: page
title: "Performance - changes"
---

Changes made to the game for performance, each measured before and after on the same scenery.
None changes the picture. The baseline and the method are in [baseline](baseline.md).

## The Logs panel dropped its oldest line on every new one

`hud/log_lines.gd` (each tab of the HUD's Logs panel) kept at most 5 000 lines and, past that,
called `RichTextLabel.remove_paragraph(0)` for every line added. `remove_paragraph()` walks every
item of the text, so each line cost a walk through 5 000 lines. The panel is a `GameLog` handler of
every logger and the engine's own log, so it takes every line even while it is closed. On Wrzosy
the AI drivers alone wrote about 39 000 lines in one run.

* **Measured:** 71% of the main thread's samples in `RichTextLabel::remove_paragraph`, called from
  `LogLines.add_line()` (Wrzosy, perf, on AC).
* **Change:** the lines are kept beside the text, and the oldest go `TRIM_BATCH` (1 000) at a time;
  the text is then drawn again from the lines kept. The panel shows the same - at least the last
  5 000 lines. A test of the trimming is in `tests/test_logs_panel.gd`.
* **After:** `remove_paragraph` is gone from the profile (0 samples).
* **Not proven:** the frame time before the change cannot be compared. In that run the simulation
  did not advance at all (0 samples in `simulation_advance`), so the main thread's time went to
  the panel alone.

## A hidden log tab draws nothing

After the trimming above the Logs panel still cost about 3% of the main thread on Wrzosy at
1280x720 (`GameLogger` 3.0%, `RichTextLabel` 2.3%): every line of the AI went into a
`RichTextLabel`, even in a tab in the back or with the panel closed - which it is by default.

* **Change:** `LogLines` keeps its lines and puts them into its text only while it is visible in the
  tree; when it is shown (`NOTIFICATION_VISIBILITY_CHANGED`) it draws what it has not drawn yet. A
  closed panel or a tab in the back takes a line for the price of an append.
* **Test changed with the operator's consent (2026-10-18):** `tests/test_logs_panel.gd` read the text
  of a tab in the back; it now shows the panel and the tab before it reads
  (`_shown_text()`), and a new test checks that a tab in the back draws nothing until it is shown.
* **After:** being measured.

## The AI's commands: road cars, the oil pump, the brake buttons

The causes are in [findings](findings.md); here the cost. Wrzosy, 1280x720, on AC.

| Build | Commands (share of main thread) | AI per simulated s | `ai.log` lines per run | FPS |
|---|---|---|---|---|
| before | 5.9% | 0.167 s | 68 000 | 16.0 |
| converter read as the original (road cars drive) | 5.6% | 0.263 s | 95 000 | 15.0 |
| + no brake buttons to vehicles without them, automatic oil pump taken as done | **0.6%** | **0.221 s** | **20 500** | 15.0 |

* `universal_brake_button` fell from 71 953 to 1 178 commands, `oil_pump` / `oil_pump_switch_off`
  from about 1 850 each to none.
* The road cars driving is the fix of a fault (they never moved), and costs what the original's
  driving costs; the two changes after it took the commands' cost back below what it was before.
* The FPS stays at 15: the Mover step measured 0.444 s per simulated second in this run against
  0.407 in the one before - more vehicles moving by then - and the frame is bound by the
  simulation as a whole (baseline).
* Tests: 56 of the driver's, braking's, hints' and the Logs panel's tests pass.

## Rendering on a thread of its own

On the Fedora desktop the GPU needed 7.6 ms of a 44 ms frame on Wrzosy, and drawing took 31% of
the main thread: the frame was the simulation's time and the drawing's one after the other.

* **Change:** `rendering/driver/threads/thread_model=2` in `project.godot` - the RenderingServer
  records the frame on a thread of its own while the main thread runs the simulation.
* **Measured** (Wrzosy, 1920x1080, `/usr/bin/godot`, 60 s after 120 s of warm-up):

| Build | FPS | Frame (median, p95, p99) |
|---|---|---|
| before | 22.1 | 44.4, 55.6, 64.4 ms |
| after | **56.8** | 16.7, 19.1, 26.7 ms |

* The picture is the same: the screenshots of the two runs show the same cab and scene.
* Godot calls the mode experimental. What it showed: the font atlas reports
  `p_image.is_null() || p_image->is_empty()` about 20 times while its glyph cache grows at start
  (Godot's own `TextServerAdvanced::_font_draw_glyph`, not the game's code), and every read of the
  RenderingServer that returns a value waits for the rendering thread - which found the material
  defaults of libmaszyna (its `docs/performance/changes.md`).
* A player's VSync off still holds: the operator saw up to 78 FPS on a 75 Hz monitor. Under
  headless gamescope the frames come out on a 60 Hz step (16.7 ms medians) whatever the setting;
  with VSync forced off in the project the run gives the same average (56.0 FPS).

## The log of commands starts its timer once

`GamePlayLogRecorder` counts a repeated command into one line and writes it once the command has
not come again for a second. It restarted its `Timer` on every command - 16 300 commands a minute
from the AI on Wrzosy - and made the vehicle's `name#rid` twice.

* **Change:** the timer starts with the first command of a line; when it fires, it waits out the
  rest of the gap since the last command before it writes. The line comes out at the same moment.
* **Measured:** the recorder was 0.5% of the main thread (a probe, one run); not measured
  separately after, under the noise of the frame. Tests: `test_game_play_log_recorder.gd` and the
  AI's and Logs panel's tests (42) pass.

## The round on the Fedora desktop

| State | FPS | Frame (median, p95, p99) |
|---|---|---|
| before (game `ebe87bf`, libmaszyna `7f7c833e`) | 22.1 | 44.4, 55.6, 64.4 ms |
| rendering thread | 56.8 | 16.7, 19.1, 26.7 ms |
| + libmaszyna's changes (`57b57141`) | 55.7-56.0 | 17.8-18.2, 20.0, 23.9-30.9 ms |

libmaszyna's changes of the round - the cab logic of unseen cabs, the material defaults, the Mover's
controller and component lookups - are in its `docs/performance/changes.md`. They take main-thread
time off, but the rendering thread is the limit after the first change ([baseline](baseline.md)).
