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
