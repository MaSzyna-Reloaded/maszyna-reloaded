---
layout: page
title: "UI components"
---

Every screen, window and dialog of the game is made of the components in `ui/`. Each is a scene
or a script with a `class_name`, configured by `@export`s and answering by signals; it names
nothing of the screens that use it. A control component loads `ui/ui_theme.tres` itself, so it
looks the same wherever it stands - no screen theme carries a control's look, and the project has
no global theme (Godot's defaults stay for libmaszyna's debug HUD and the addons).

| Component | Built on | What it is |
|---|---|---|
| `UIWindow` (`ui/ui_window.tscn`) | `Window` | A window of the game: title and close button, the content under `Frame/Layout/Body`, its own backdrop over the whole game window; `close_requested` from the button and from an Escape nothing inside took |
| `UIDialog` (`ui/ui_dialog.tscn`) | `Control` | Any popup - a notice, a question: `title`, `message`, confirm / alternative / back texts and intents; `ask()`; `confirmed`, `alternative_chosen`, `dismissed`. Never Godot's `AcceptDialog` |
| `UIButton` | `Button` | A button in the colour of what it does: `intent` `DEFAULT`, `SUCCESS` (green), `WARNING` (orange), `DANGER` (reddish); takes no Godot focus |
| `UIActionButtons` | `HBoxContainer` | The button row of a window or dialog, walked by the keyboard (arrows, Tab), Enter presses the chosen one |
| `UIIconButton` | `Button` | A small button that is only its icon |
| `UISwitch` | `CheckButton` | On / off |
| `UISlider` | `HSlider` | A value in a range |
| `UISelect` | `OptionButton` | One of a few named values |
| `UITextField` | `LineEdit` | A text the player types - the only control taking Godot's focus |
| `UISearchInput` | `Control` | A search field: frame, magnifier, field, clear button |
| `UIFoldable` | `Container` | A group folding away under its title (the settings' "Advanced", a vehicle card's sections) |
| `UIChip` | `PanelContainer` | A floating tile over the game: `CARD` framed, `TEXT` a faint background (the HUD's chips) |
| `FocusSection` | `Container` | One keyboard-navigable section of a screen; the screen hands the focus between its sections |
| `SelectorList` | `FocusSection` | A list section of the selector: rows, their search, the selection |
| `TileGrid` | `Container` | Tiles of vehicle side views - a trainset in a row, the skins of a vehicle |

The keyboard focus of the game is virtual (`FocusSection`, `UIActionButtons`): a screen keeps
Godot's focus in its search field, so buttons never rely on it. Every key is an input action of
`project.godot`, tested with an exact match.

The rules of building with them - finding the existing element of the same meaning, the order and
colour of buttons, the keys a popup must take, sizes as proportions, translations into every
language - are the `game-ui` skill of this repository (`.claude/skills/game-ui/SKILL.md`).

## Themes

* `ui/ui_theme.tres` - the components, windows and dialogs
* `scenery_selector/selector_theme.tres` - the selector and the settings
* `hud/timetable_theme.tres` - the HUD's cards, chips and menus
* the loading board's own theme

Each points at the shared fonts (`ui/fonts/*.tres`) and the tooltip (`ui/ui_tooltip.tres`)
rather than holding a copy.
