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
| `PadIcon` | `Texture2D` | A pad's button or axis drawn as on the pad last used - Xbox, PlayStation or Nintendo (`InputBindings.get_pad_layout()`): `PadIcon.for_event(event, layout, height)`, null for a key; a Button's icon, a `TextureRect` |
| `FocusSection` | `Container` | One keyboard-navigable section of a screen; the screen hands the focus between its sections |
| `SelectorList` | `FocusSection` | A list section of the selector: rows, their search, the selection |
| `TileGrid` | `Container` | Tiles of vehicle side views - a trainset in a row, the skins of a vehicle |

The keyboard focus of the game is virtual (`FocusSection`, `UIActionButtons`): a screen keeps
Godot's focus in its search field, so buttons never rely on it. Every key is an input action of
`project.godot`, tested with an exact match.

A binding shown to the player - the help, the driving hints - is
`InputBindings.get_shown_events(action)`: the pad's while a pad is in use (connected, or its button
pressed last), the keyboard's while a key or a mouse button was pressed last, and the other device's
when the action has none on that one; `device_changed` tells when to show them again. The settings
bind the keyboard and the pad in two columns of a key row, and point out a binding another action
takes as well (`InputBindings.get_conflicts()`) in orange, with a line under it naming the other
action and its section ("Conflict with: Vehicle keys, Horn High"), and a trash button beside each
takes its binding away. The buttons above every key section set the keyboard's bindings of all of
them at once for a keyboard (`InputBindings.KeyboardPreset`, `get_preset_keys()`): 100% -
`project.godot`'s keys - or 60%, a laptop's, whose F keys, arrows and Insert, Delete, Home and End
come from its Fn layer: only the numpad's keys move (`COMPACT_KEYS`), under Left Alt, where a
laptop's built-in keypad has them (7 8 9 0, U I O P, J K L ;, . and /). The pad's bindings stay. A pad's binding can be a combination - LB, RB, LT or RT held with another button
or axis (`InputBindings.PAD_MODIFIER_META`) - so the pad's bindings are not on the `InputMap`:
`InputBindings` turns the pad's input into `InputEventAction`s itself, a combination before the
button alone, and a shoulder or trigger used in a combination acts alone only as it is let go.
`InputBindings.get_events()` lists an action's bindings, keys and pad's. A shoulder or trigger
tapped presses its own actions for `TAP_SECONDS`, held alone past `MODIFIER_HOLD_SECONDS` it holds
them. A cab control's caption names the bindings of the device in use too: `InputBindings` sets
libreloaded's `BaseCabinTool3D.action_hints` and calls `update_mouse_hints()` on its
`MOUSE_HINTS_GROUP` when they change, and a pad's binding there is drawn as on the pad
(`PadIcon`, through `CabinControlTooltip.hint_icon`).

The default pad preset is for driving (`project.godot`): the triggers step the main controller,
the right stick the train brake (back: more) and the local brake, A acknowledges the vigilance
device, X and Y are the horn, the d-pad the direction and the lights; LB with A, B, X, Y and the
d-pad the battery, main switch, pantographs, converter, compressor and doors; RB with them the cab
signal acknowledgement, fuse reset, departure announcement, cab activation, the shunt controller
and the wipers. B alone stays `menu_back` - in a game the exit to the menu.

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
