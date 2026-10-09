---
layout: page
title: "HUD"
---

The HUD over a running scenery is `hud/game_hud.tscn` (`hud/game_hud.gd`). It draws what
libmaszyna's servers hold - `HUDServer` (which panels are open, the vehicle card),
`PlayerServer` (the player's vehicle), `PlayerCameraServer` (the camera) - and asks them for every
change; it keeps no state of its own about the simulation.

## The top bar

`TopBar` (`hud/top_bar.gd`) - the game's menus as a brow in the middle of the top edge:

* **Simulator** - Settings, Report a problem or suggestion, Help, Exit to menu; the scene that
  holds the HUD (`game.tscn`) answers the signals `settings_requested`,
  `problem_report_requested` and `exit_to_menu_requested`.
* **View** - the HUD's panels, each opened and closed through `HUDServer.panel_toggle()`, and
  "Controls", showing all diagnostic windows at once.
* **Diagnostics** - filled by libmaszyna's `DebugHud` (`fill_menu()`): one entry per diagnostic
  window and the developer console; the game adds "Frame time statistics" (the `debug_menu`
  addon, F3) after them.

## Panels and chips

| Element | Script | What it shows |
|---|---|---|
| Driving aid | `hud/driving_aid.gd` (`DrivingAid`) | The original's driving aid as floating tiles (driveruipanels.cpp:42-205) |
| Hints | `hud/driver_hints.gd` (`DriverHints`) | The driver's hints to the player, with their keys |
| Timetable | `hud/timetable_panel.gd` (`TimetablePanel`) | The player's train: its stations, the clock, the delay, the status at the station |
| Scenario | `hud/scenario_panel.gd` | The scenario being played and the player's task (`ScenarioTask`) |
| Vehicle selector | `hud/vehicle_selector_panel.gd` | Every driven vehicle, AI or player |
| Vehicle card | `hud/vehicle_card.gd` (`VehicleCard`) | A driven vehicle's parameters and the operator's actions |
| Vehicle chips | `hud/vehicle_chip.gd` (`VehicleChip`) | The followed vehicle's and the player's vehicle's floating buttons |
| Transcripts | `hud/transcripts_panel.gd` | What the sounds heard say |
| Logs | `hud/logs_panel.gd` | The game's logs, a tab per logger of `GameLog` |
| Simulation speed | `hud/simulation_speed_panel.gd` | Slowed, paused, or the wall clock's times one to thirty |
| Script editor | `hud/script_editor_panel.gd` | A Lua editor for the scenario being played |
| Help | `hud/help_panel.gd` | Every input action of the game with its key |

The movable cards (timetable, scenario, vehicle card, selector, help, logs, script editor) are
dragged and resized with libmaszyna's `WindowMoveHandle` and `WindowResizeCorner`.

## Diagnostic windows

The diagnostic windows of the player's vehicle and of the scenery - the Mover's sections, the
mini map, scenery streaming, track and traction, scenario events, weather and time - are
libmaszyna's `DebugHud` (`addons/libmaszyna/debug_hud/debug_hud.tscn`), instanced by the game's
HUD as it is by libmaszyna's own demo. They keep their own green look; the game's themes do not
reach them.
