---
title: Multimonitor
---

# Multimonitor

One monitor is one window of the game, one viewport and one camera. The addon `multimonitor`
(`MultiMonitorRig`, in `world/world.tscn`) makes them; the main window is monitor 0 and keeps the HUD,
the menus and the keys.

Everything is on the Display page of the settings:

* **Monitors in use** - how many windows stand, up to the displays connected. The main window is
  always the first.
* **Angle between monitors** and **Eye distance from the screen** - the monitors are taken for a
  row of equal flat screens meeting edge to edge, each turned by the angle towards the head. The
  game works every monitor's view out of them, ordered as the displays stand on the desktop around
  the main window, and shows the result on the rows below. A shorter eye distance shows more of the
  world; the size comes from the first monitor's **Screen width** and **Screen height**.
* **Configured monitor** chooses whose rows follow. They can be tuned by hand, and a change of the
  three settings above works the layout out again.

The rows are kept in `settings.cfg`, in the sections `multimonitor` and `multimonitor_<monitor>`.

With several monitors they share one fixed exposure: Godot measures auto exposure per viewport, so
each window would settle on another brightness, seen at the seams. The cab is darker than with one
monitor for it.

A monitor's view is set by its field of view and angles, or by where the screen stands; the rows of
the other way are greyed out. With **Render the cabin** off the cab is not drawn, for a physical
cockpit; parts of the vehicle's exterior model, such as the wipers and mirrors, stay.
