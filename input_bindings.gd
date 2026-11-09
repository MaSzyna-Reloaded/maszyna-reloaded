extends Node

## The player's keys, for as long as the game runs, and the only writer of the InputMap after
## Godot's start: the input map is project.godot's, and a binding the player sets (the settings'
## key sections, setting_input.gd) is kept by UserSettings in SETTINGS_SECTION under the action's
## name - its events, in place of the project's. Every action of the project takes the events in
## effect - the player's or the project's own - at the start and whenever the settings change: set,
## restored to default, discarded.
##
## The actions are grouped for the player - the help and the settings' key sections list them by
## group; an action of no group is in DEFAULT_GROUP. Godot's own ui_* actions are no group's: they
## belong to its controls.
##
## A pad's buttons are shown as on the pad last used - its maker's layout (PadIcon,
## InputEventNames.PadLayout) - or on the first one connected before any is used; an Xbox pad's
## without a pad.
##
## An action is bound to a key and to a pad's button or axis apart (the settings' two columns). The
## help and the hints show the binding of the device in use (get_shown_events()): the pad once one
## is connected or used, the keyboard once a key or a mouse button is pressed; an action with no
## binding on that device shows its other one.
##
## A key, pad button or pad axis that two actions take is a conflict when their groups are in
## effect at once (_groups_compete()): the settings' key rows point it out (get_conflicts()).
##
## The keyboard's bindings of every action can be set at once for a keyboard (KeyboardPreset,
## get_preset_keys()): a full one, or a 60% or a laptop's without the numpad.
##
## A pad's binding can be a combination: a shoulder (LB, RB) or a trigger (LT, RT) held - its
## PadModifier in the event's PAD_MODIFIER_META - and another button or axis pressed. Godot matches
## an action by one event, so the pad's bindings are not on the InputMap: this node turns the pad's
## input into the actions itself (InputEventAction, pad_action_sent), a combination before the
## binding of its button alone. A shoulder or a trigger that some combination holds acts on its own
## binding only when no combination is pressed while it is held: held longer than
## MODIFIER_HOLD_SECONDS it holds its actions until it is let go, let go sooner it presses them for
## TAP_SECONDS - a cab's monostable button or knob has to be seen held by the simulation.

## The bindings in effect changed, and the InputMap has them
signal bindings_changed
## Another maker's pad was used: its buttons are shown as on it
signal pad_layout_changed
## The player went over to the keyboard or to a pad: the bindings of that one are shown
signal device_changed
## A pad's input pressed or let go `action` (an InputEventAction is parsed for it)
signal pad_action_sent(action: String, pressed: bool)

## The device whose bindings are shown - the keyboard with the mouse, or a pad
enum Device {
    KEYBOARD,
    PAD,
}

## UserSettings section of the player's bindings
const SETTINGS_SECTION: String = "input"
## Project settings of the input map, "input/<action>"
const PROJECT_PREFIX: String = "input/"
## Godot's own actions, for its controls
const BUILT_IN_PREFIX: String = "ui_"
const DEFAULT_GROUP: String = "Vehicle"
const GROUPS: Dictionary = {
    "Vehicle": [],
    "Player": [
        "change_vehicle",
        "cabin_mode_toggle",
        "cabin_sit_down",
        "cabin_next",
        "cabin_previous",
        "external_view_cycle",
        "ai_driver_enable",
        "ai_driver_disable",
        "flashlight_toggle",
        "coupler_connect",
        "coupler_disconnect",
        "coupler_disconnect_occupied",
        "coupler_adapter_attach",
        "coupler_adapter_remove",
    ],
    "UI": [
        "hud_toggle",
        "hud_visibility_toggle",
        "minimap_toggle",
        "toggle_weather_controls",
        "timetable_toggle",
        "scenario_toggle",
        "hints_toggle",
        "trainsets_toggle",
        "vehicle_card_toggle",
        "cycle_debug_menu",
        "console_toggle",
        "driving_aid_toggle",
        "settings_open",
        "toggle_fullscreen",
    ],
    # the keys the menus and the settings themselves are walked with
    "Menu": [
        "menu_up",
        "menu_down",
        "menu_left",
        "menu_right",
        "menu_move_left",
        "menu_move_right",
        "menu_reverse",
        "menu_page_up",
        "menu_page_down",
        "menu_home",
        "menu_end",
        "menu_activate",
        "menu_back",
        "menu_next_section",
        "menu_previous_section",
    ],
}

## The keyboard the player's keys are set for at once (the settings' key sections): a full one with
## the numpad - project.godot's keys - or a 60% one, a laptop's, whose F keys, arrows and Insert,
## Delete, Home and End come from its Fn layer and only the numpad is missing
enum KeyboardPreset {
    FULL,
    COMPACT,
}

## The keys of the COMPACT preset in place of the numpad's - the rest are project.godot's. Left Alt
## held is the Fn of a laptop's built-in keypad, its keys where they are on one: 7 8 9 0 is the
## numpad's 7 8 9 /, U I O P its 4 5 6 *, J K L ; its 1 2 3 -, . its . and / its +; a key with Ctrl on
## the numpad has Ctrl and Alt. The numpad's Enter is the keypad's + key (/), Pause is Backspace -
## the radio's call - with its modifiers
const COMPACT_KEYS: Dictionary[String, Dictionary] = {
    "local_brake_decrease": {"keycode": KEY_7, "alt": true},
    "manual_brake_decrease": {"keycode": KEY_7, "alt": true, "ctrl": true},
    "brake_operation_mode_decrease": {"keycode": KEY_8, "alt": true, "ctrl": true},
    "brake_level_decrease": {"keycode": KEY_9, "alt": true},
    "second_controller_increase": {"keycode": KEY_0, "alt": true},
    "brake_release": {"keycode": KEY_U, "alt": true},
    "brake_level_drive": {"keycode": KEY_O, "alt": true},
    "second_controller_decrease": {"keycode": KEY_P, "alt": true},
    "local_brake_increase": {"keycode": KEY_J, "alt": true},
    "manual_brake_increase": {"keycode": KEY_J, "alt": true, "ctrl": true},
    "brake_operation_mode_increase": {"keycode": KEY_K, "alt": true, "ctrl": true},
    "brake_level_increase": {"keycode": KEY_L, "alt": true},
    "main_controller_decrease": {"keycode": KEY_SEMICOLON, "alt": true},
    "brake_level_charging": {"keycode": KEY_PERIOD, "alt": true},
    "main_controller_increase": {"keycode": KEY_SLASH, "alt": true},
    "spring_brake_toggle": {"keycode": KEY_SLASH, "alt": true, "shift": true},
    "radio_stop_send": {"keycode": KEY_BACKSPACE, "ctrl": true, "shift": true},
}
## An event of every device, as project.godot's events are (input_map.h, InputMap::ALL_DEVICES)
const ALL_DEVICES: int = -1

## What a pad's binding holds with its button or axis to be a combination
enum PadModifier {
    NONE,
    LB,
    RB,
    LT,
    RT,
}

## The meta of a pad's event naming its PadModifier - none: the button or axis alone
const PAD_MODIFIER_META: StringName = &"pad_modifier"
## The pad's inputs that are held as a modifier
const MODIFIER_BUTTONS: Dictionary[JoyButton, PadModifier] = {
    JOY_BUTTON_LEFT_SHOULDER: PadModifier.LB,
    JOY_BUTTON_RIGHT_SHOULDER: PadModifier.RB,
}
const MODIFIER_AXES: Dictionary[JoyAxis, PadModifier] = {
    JOY_AXIS_TRIGGER_LEFT: PadModifier.LT,
    JOY_AXIS_TRIGGER_RIGHT: PadModifier.RT,
}
## Between a modifier's name and its button's or axis's
const COMBINATION_SEPARATOR: String = " + "
## A modifier held this long with no combination pressed holds its own actions [s]
const MODIFIER_HOLD_SECONDS: float = 0.3
## A modifier tapped presses its own actions this long - a few of the simulation's steps [s]
const TAP_SECONDS: float = 0.15

## DisplayServer.get_name() of a run without a window
const HEADLESS_DISPLAY_SERVER: String = "headless"
## How far a stick is pushed or a trigger pulled to count as the pad used - past the drift of one
## at rest
const PAD_AXIS_USED: float = 0.5

## Every action of the project, by group, sorted by name
var _actions: Dictionary[String, PackedStringArray] = {}
## The group of every action
var _action_groups: Dictionary[String, String] = {}
## The actions taking each input in effect, by _input_id() - made again whenever the bindings change
var _actions_by_input: Dictionary[String, PackedStringArray] = {}
var _pad_layout: InputEventNames.PadLayout = InputEventNames.PadLayout.XBOX
## The pad last used - its layout is looked up only when another one is
var _pad_device: int = -1
var _device: Device = Device.KEYBOARD
## The pad's events in effect of every action - the InputMap has its keys only
var _pad_events: Dictionary[String, Array] = {}
## The modifiers some combination holds - their own binding waits for them let go
var _combination_modifiers: Dictionary[PadModifier, bool] = {}
## A key row waits for a pad's input to bind: the pad acts on no action
var _pad_capture: bool = false
## The pad's events named under the cab controls' captions, by their names - drawn as icons there
## (_cab_hint_icon())
var _cab_hint_events: Dictionary[String, InputEvent] = {}
## Many bindings are being changed at once (change_at_once()): they are applied after the last
var _changing_at_once: bool = false
## What the pad holds now, by "<device>|<input>" (_base_id()): the actions its input pressed, a
## modifier's own actions waiting for it let go, the modifiers held and used, the axes pushed
var _pressed_by_input: Dictionary[String, PackedStringArray] = {}
var _pending_taps: Dictionary[String, PackedStringArray] = {}
## Which press of a modifier its hold timer is for - a timer of an earlier press does nothing
var _pending_presses: Dictionary[String, int] = {}
var _press_count: int = 0
var _modifiers_held: Dictionary[String, bool] = {}
var _modifiers_used: Dictionary[String, bool] = {}
var _axes_pushed: Dictionary[String, bool] = {}


func _ready() -> void:
    for group: String in GROUPS:
        _actions[group] = PackedStringArray()
    for property: Dictionary in ProjectSettings.get_property_list():
        var property_name: String = property["name"]
        if not property_name.begins_with(PROJECT_PREFIX):
            continue
        var action: String = property_name.trim_prefix(PROJECT_PREFIX)
        if action.begins_with(BUILT_IN_PREFIX):
            continue
        var action_group: String = DEFAULT_GROUP
        for group: String in GROUPS:
            if action in GROUPS[group]:
                action_group = group
        _actions[action_group].append(action)
        _action_groups[action] = action_group
    for group: String in _actions:
        _actions[group].sort()
    UserSettings.config_changed.connect(_apply_bindings)
    _apply_bindings()
    _index_inputs()
    var pads: Array[int] = Input.get_connected_joypads()
    if pads:
        _pad_device = pads[0]
        _pad_layout = InputEventNames.pad_layout(_pad_device)
        _device = Device.PAD
    Input.joy_connection_changed.connect(_on_joy_connection_changed)
    # a cab control's caption names the bindings of the device in use, a pad's combinations among
    # them, and is made again whenever they change
    BaseCabinTool3D.action_hints = _cab_control_hints
    CabinControlTooltip.hint_icon = _cab_hint_icon
    bindings_changed.connect(_update_cab_control_hints)
    device_changed.connect(_update_cab_control_hints)
    pad_layout_changed.connect(_update_cab_control_hints)
    # the game window's input comes before anything in it takes the event - a key row binding the
    # pad's button among them
    get_window().window_input.connect(_on_window_input)


## A pad's button pressed, a stick pushed or a trigger pulled: the pad is in use, and the one used
## last is that one; a key or a mouse button pressed: the keyboard is
func _on_window_input(event: InputEvent) -> void:
    if (event is InputEventKey or event is InputEventMouseButton) and event.pressed:
        _set_device(Device.KEYBOARD)
        return
    var used: bool = (
        (event is InputEventJoypadButton and event.pressed)
        or (event is InputEventJoypadMotion and absf(event.axis_value) >= PAD_AXIS_USED)
    )
    if is_pad_event(event):
        _dispatch_pad_event(event)
    if not used:
        return
    _use_pad(event.device)
    _set_device(Device.PAD)


## While a key row binds a pad's input, the pad acts on nothing - its button of menu_back is bound,
## not taken as Escape
func set_pad_capture(capture: bool) -> void:
    _pad_capture = capture
    if capture:
        for input: String in _pressed_by_input.keys():
            _release_input(input)
        _pending_taps.clear()


## A pad's button pressed or let go, an axis pushed past PAD_AXIS_USED or back: its actions
func _dispatch_pad_event(event: InputEvent) -> void:
    var button: InputEventJoypadButton = event as InputEventJoypadButton
    if button:
        var button_modifier: PadModifier = MODIFIER_BUTTONS.get(button.button_index, PadModifier.NONE)
        _pad_input_changed(event.device, _base_id(event), button_modifier, button.pressed)
        return
    var motion: InputEventJoypadMotion = event as InputEventJoypadMotion
    for side: int in [-1, 1]:
        var id: String = "axis:%d:%d" % [motion.axis, side]
        var pushed: bool = motion.axis_value * side >= PAD_AXIS_USED
        var key: String = "%d|%s" % [motion.device, id]
        if pushed == _axes_pushed.get(key, false):
            continue
        _axes_pushed[key] = pushed
        var modifier: PadModifier = PadModifier.NONE
        if side > 0:
            modifier = MODIFIER_AXES.get(motion.axis, PadModifier.NONE)
        _pad_input_changed(motion.device, id, modifier, pushed)


## `id` (_base_id()) of `device` went down or up; `modifier` is the one it is itself, if any
func _pad_input_changed(device: int, id: String, modifier: PadModifier, down: bool) -> void:
    var key: String = "%d|%s" % [device, id]
    var modifier_key: String = "%d|%d" % [device, modifier]
    if not down:
        _release_input(key)
        if _pending_taps.has(key):
            var tapped: PackedStringArray = _pending_taps[key]
            _pending_taps.erase(key)
            if not _modifiers_used.get(modifier_key, false) and not _pad_capture:
                for action: String in tapped:
                    _send(action, true, device)
                get_tree().create_timer(TAP_SECONDS, true, false, true).timeout.connect(
                    _send_all.bind(tapped, false, device)
                )
        if modifier != PadModifier.NONE:
            _modifiers_held.erase(modifier_key)
            _modifiers_used.erase(modifier_key)
        return
    if modifier != PadModifier.NONE:
        _modifiers_held[modifier_key] = true
        _modifiers_used.erase(modifier_key)
    if _pad_capture:
        return
    # a combination with a modifier held first, then the input alone
    var actions: PackedStringArray = []
    for held: PadModifier in PadModifier.values():
        if held == PadModifier.NONE or held == modifier:
            continue
        var held_key: String = "%d|%d" % [device, held]
        if not _modifiers_held.get(held_key, false):
            continue
        var combined: PackedStringArray = _actions_by_input.get(
            _combination_id(id, held), PackedStringArray()
        )
        if combined:
            actions.append_array(combined)
            _modifiers_used[held_key] = true
            # held past MODIFIER_HOLD_SECONDS, its own actions were held: a combination lets them go
            _release_input("%d|%s" % [device, _base_id(get_modifier_event(held))])
    if actions.is_empty():
        actions = _actions_by_input.get(id, PackedStringArray())
        if actions and _combination_modifiers.has(modifier):
            _pending_taps[key] = actions
            _press_count += 1
            _pending_presses[key] = _press_count
            get_tree().create_timer(MODIFIER_HOLD_SECONDS, true, false, true).timeout.connect(
                _on_modifier_held.bind(key, _press_count, modifier_key, device)
            )
            return
    if actions.is_empty():
        return
    _pressed_by_input[key] = actions
    for action: String in actions:
        _send(action, true, device)


## A modifier still held, alone, MODIFIER_HOLD_SECONDS after its press `press`: it holds its actions
func _on_modifier_held(key: String, press: int, modifier_key: String, device: int) -> void:
    if not _pending_taps.has(key) or _pending_presses.get(key, 0) != press:
        return
    if _modifiers_used.get(modifier_key, false) or _pad_capture:
        return
    var actions: PackedStringArray = _pending_taps[key]
    _pending_taps.erase(key)
    _pressed_by_input[key] = actions
    _send_all(actions, true, device)


func _send_all(actions: PackedStringArray, pressed: bool, device: int) -> void:
    for action: String in actions:
        _send(action, pressed, device)


func _release_input(key: String) -> void:
    if not _pressed_by_input.has(key):
        return
    var device: int = key.get_slice("|", 0).to_int()
    for action: String in _pressed_by_input[key]:
        _send(action, false, device)
    _pressed_by_input.erase(key)


func _send(action: String, pressed: bool, device: int) -> void:
    var event: InputEventAction = InputEventAction.new()
    event.action = action
    event.pressed = pressed
    event.strength = 1.0 if pressed else 0.0
    event.device = device
    pad_action_sent.emit(action, pressed)
    Input.parse_input_event(event)


## A pad connected is the one in use; the last one gone leaves the keyboard
func _on_joy_connection_changed(device: int, connected: bool) -> void:
    if connected:
        _use_pad(device)
        _set_device(Device.PAD)
    elif not Input.get_connected_joypads():
        _set_device(Device.KEYBOARD)


func _use_pad(device: int) -> void:
    if device == _pad_device:
        return
    _pad_device = device
    var layout: InputEventNames.PadLayout = InputEventNames.pad_layout(device)
    if layout == _pad_layout:
        return
    _pad_layout = layout
    pad_layout_changed.emit()


func _set_device(device: Device) -> void:
    if device == _device:
        return
    _device = device
    device_changed.emit()


## The layout of the pad last used, its buttons are shown as on it
func get_pad_layout() -> InputEventNames.PadLayout:
    return _pad_layout


## The device in use, whose bindings are shown
func get_device() -> Device:
    return _device


## A pad's button or axis - not a key or the mouse
static func is_pad_event(event: InputEvent) -> bool:
    return event is InputEventJoypadButton or event is InputEventJoypadMotion


## The modifier a pad's binding holds with its button or axis - none for a button or axis alone
static func get_pad_modifier(event: InputEvent) -> PadModifier:
    if not is_pad_event(event):
        return PadModifier.NONE
    return event.get_meta(PAD_MODIFIER_META, PadModifier.NONE)


## The modifier a pad's input is itself, when it is held - a shoulder, or a trigger pulled
static func get_modifier_of_input(event: InputEvent) -> PadModifier:
    var button: InputEventJoypadButton = event as InputEventJoypadButton
    if button:
        return MODIFIER_BUTTONS.get(button.button_index, PadModifier.NONE)
    var motion: InputEventJoypadMotion = event as InputEventJoypadMotion
    if motion and motion.axis_value > 0.0:
        return MODIFIER_AXES.get(motion.axis, PadModifier.NONE)
    return PadModifier.NONE


## The pad's input of `modifier` - a shoulder's button, or a trigger pulled
static func get_modifier_event(modifier: PadModifier) -> InputEvent:
    for button: JoyButton in MODIFIER_BUTTONS:
        if MODIFIER_BUTTONS[button] == modifier:
            var button_event: InputEventJoypadButton = InputEventJoypadButton.new()
            button_event.button_index = button
            return button_event
    for axis: JoyAxis in MODIFIER_AXES:
        if MODIFIER_AXES[axis] == modifier:
            var motion: InputEventJoypadMotion = InputEventJoypadMotion.new()
            motion.axis = axis
            motion.axis_value = 1.0
            return motion
    return null


## `event` named as InputEventNames names it - a combination's modifier first ("Pad LB + Pad A")
static func event_name(event: InputEvent, layout: InputEventNames.PadLayout) -> String:
    var name: String = InputEventNames.event_name(event, layout)
    var modifier: PadModifier = get_pad_modifier(event)
    if modifier == PadModifier.NONE:
        return name
    var modifier_name: String = InputEventNames.event_name(get_modifier_event(modifier), layout)
    return modifier_name + COMBINATION_SEPARATOR + name


## The events of `action` in effect: its keys (the InputMap's) and its pad's
func get_events(action: String) -> Array[InputEvent]:
    var events: Array[InputEvent] = InputMap.action_get_events(action)
    for event: InputEvent in _pad_events.get(action, []):
        events.append(event)
    return events


## The events of `action` in effect to show the player: those of the device in use, or - none
## bound there - the others
func get_shown_events(action: String) -> Array[InputEvent]:
    var events: Array[InputEvent] = get_events(action)
    var pad: bool = _device == Device.PAD
    var shown: Array[InputEvent] = []
    for event: InputEvent in events:
        if is_pad_event(event) == pad:
            shown.append(event)
    return shown if shown else events


## The names of `action`'s bindings under a cab control's caption (BaseCabinTool3D.action_hints)
func _cab_control_hints(action: String) -> PackedStringArray:
    var hints: PackedStringArray = []
    if not InputMap.has_action(action):
        return hints
    for event: InputEvent in get_shown_events(action):
        var hint: String = event_name(event, _pad_layout)
        hints.append(hint)
        if is_pad_event(event):
            _cab_hint_events[hint] = event
    return hints


## A pad's binding under a cab control's caption drawn as on the pad last used (PadIcon) - a key's
## name stays text (CabinControlTooltip.hint_icon)
func _cab_hint_icon(hint: String, height: int) -> Texture2D:
    var event: InputEvent = _cab_hint_events.get(hint)
    if not event:
        return null
    return PadIcon.for_event(event, _pad_layout, height)


## Every caption named again - the pad's events named are only those of the captions made now
func _update_cab_control_hints() -> void:
    _cab_hint_events.clear()
    get_tree().call_group(BaseCabinTool3D.MOUSE_HINTS_GROUP, &"update_mouse_hints")


## The actions of `group` (a key of GROUPS), sorted by name
func get_actions(group: String) -> PackedStringArray:
    return _actions[group]


## The group of `action` (a key of GROUPS)
func get_group(action: String) -> String:
    return _action_groups[action]


## The events project.godot binds `action` to - what the player's binding replaces
func get_default_events(action: String) -> Array:
    return ProjectSettings.get_setting(PROJECT_PREFIX + action)["events"]


## The keys `preset` binds `action` to: project.godot's, or COMPACT's in place of the numpad's
func get_preset_keys(action: String, preset: KeyboardPreset) -> Array[InputEvent]:
    var keys: Array[InputEvent] = []
    if preset == KeyboardPreset.COMPACT and COMPACT_KEYS.has(action):
        var compact: Dictionary = COMPACT_KEYS[action]
        var key: InputEventKey = InputEventKey.new()
        key.device = ALL_DEVICES
        key.keycode = compact["keycode"]
        key.alt_pressed = compact.get("alt", false)
        key.ctrl_pressed = compact.get("ctrl", false)
        key.shift_pressed = compact.get("shift", false)
        keys.append(key)
        return keys
    for event: InputEvent in get_default_events(action):
        if event is InputEventKey:
            keys.append(event)
    return keys


## Many bindings changed at once - a keyboard preset on every key row: `change` sets them, and they
## are applied, with bindings_changed sent, once after it - not once for each, which drew every row
## again for each binding changed (150-200 ms with the 147 rows of the settings)
func change_at_once(change: Callable) -> void:
    _changing_at_once = true
    change.call()
    _changing_at_once = false
    _apply_bindings()


## An action whose events in effect are not the ones it has - the same events, not equal ones: a
## setting of another section changes none, the settings read again (discarded) all of them. Its
## keys go onto the InputMap, its pad's stay here (_dispatch_pad_event())
func _apply_bindings() -> void:
    if _changing_at_once:
        return
    var changed: bool = false
    for group: String in _actions:
        for action: String in _actions[group]:
            var events: Array = UserSettings.get_setting(
                SETTINGS_SECTION, action, get_default_events(action)
            )
            var keys: Array[InputEvent] = []
            var pads: Array = []
            for event: InputEvent in events:
                if is_pad_event(event):
                    pads.append(event)
                else:
                    keys.append(event)
            if InputMap.action_get_events(action) == keys and _pad_events.get(action, []) == pads:
                continue
            changed = true
            InputMap.action_erase_events(action)
            for event: InputEvent in keys:
                InputMap.action_add_event(action, event)
            _pad_events[action] = pads
    if changed:
        _index_inputs()
        bindings_changed.emit()


## The other actions taking one of `action`'s inputs in effect - its pad's (`pad`) or its keys -
## while it is in effect itself: their groups compete (_groups_compete()). Sorted by name
func get_conflicts(action: String, pad: bool) -> PackedStringArray:
    var conflicts: PackedStringArray = []
    if not _action_groups.has(action):
        return conflicts
    var group: String = _action_groups[action]
    for event: InputEvent in get_events(action):
        if is_pad_event(event) != pad:
            continue
        for other: String in _actions_by_input.get(_input_id(event), PackedStringArray()):
            if other == action or other in conflicts:
                continue
            if _groups_compete(group, _action_groups[other]):
                conflicts.append(other)
    conflicts.sort()
    return conflicts


## Whether the actions of `group` and of `other_group` (keys of GROUPS) are in effect at the same
## time, so one input taken by both is a conflict
func _groups_compete(group: String, other_group: String) -> bool:
    # TODO(operator): the rule of which groups are in effect together
    return true


func _index_inputs() -> void:
    _actions_by_input.clear()
    _combination_modifiers.clear()
    for action: String in _action_groups:
        for event: InputEvent in get_events(action):
            var id: String = _input_id(event)
            if not id:
                continue
            if not _actions_by_input.has(id):
                _actions_by_input[id] = PackedStringArray()
            _actions_by_input[id].append(action)
            var modifier: PadModifier = get_pad_modifier(event)
            if modifier != PadModifier.NONE:
                _combination_modifiers[modifier] = true


## One text for every event of the same input: a key by its keycode - project.godot's physical
## ones too, as the keyboard's layout makes them - with its modifiers; a pad's button or axis
## (_base_id()) with the modifier of its combination. Empty for anything else (the mouse)
func _input_id(event: InputEvent) -> String:
    if is_pad_event(event):
        var modifier: PadModifier = get_pad_modifier(event)
        if modifier == PadModifier.NONE:
            return _base_id(event)
        return _combination_id(_base_id(event), modifier)
    return _key_id(event)


func _combination_id(base_id: String, modifier: PadModifier) -> String:
    return "%s+%d" % [base_id, modifier]


## A pad's button by its index, a pad's axis by the axis and the side it is pushed to
func _base_id(event: InputEvent) -> String:
    var button: InputEventJoypadButton = event as InputEventJoypadButton
    if button:
        return "button:%d" % button.button_index
    var motion: InputEventJoypadMotion = event as InputEventJoypadMotion
    if motion:
        return "axis:%d:%d" % [motion.axis, int(signf(motion.axis_value))]
    return ""


func _key_id(event: InputEvent) -> String:
    var key: InputEventKey = event as InputEventKey
    if key:
        var keycode: Key = key.keycode
        if keycode == KEY_NONE:
            keycode = key.physical_keycode
            # a headless display server has no keyboard layout (tests): a QWERTY key's two codes
            # are the same
            if DisplayServer.get_name() != HEADLESS_DISPLAY_SERVER:
                keycode = DisplayServer.keyboard_get_keycode_from_physical(keycode)
        return "key:%d:%d%d%d%d" % [
            keycode, int(key.shift_pressed), int(key.ctrl_pressed), int(key.alt_pressed),
            int(key.meta_pressed),
        ]
    return ""
