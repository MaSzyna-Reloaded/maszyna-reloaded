class_name SettingInput
extends SettingRow

## The bindings of one input action (InputBindings) on two buttons, the keyboard's and the pad's:
## its keys by their names on the first, its pad's button or axis drawn as on the pad last used
## (PadIcon) on the second, each named under the mouse. A click on one waits for the next input of
## its kind - a key on the keyboard's, a pad button or axis on the pad's (a stick pushed, a trigger
## pulled) - which takes the place of the action's binding of that kind; the other stays. Enter -
## or the pad's button of menu_activate - waits on the button of the device in use
## (InputBindings.get_device()). The trash button beside each takes its binding away.
##
## A key is taken with the modifiers held with it; a modifier alone is no binding - an exact match
## cannot tell it pressed on every platform (X11 sets its own flag only as it is let go). A pad's
## shoulder or trigger (InputBindings.PadModifier) held while another button or axis is pressed makes
## a combination of the two; let go with nothing pressed, it is bound alone. Escape, or a click
## anywhere, stops waiting with the binding as it was; an input of the other kind is taken by the
## row and does nothing. The value is the action's events, "default" the project's. A binding
## another action takes as well while this one is in effect (InputBindings.get_conflicts()) turns
## its button orange, and the line under it names the other actions with their sections. A keyboard
## preset (InputBindings.KeyboardPreset) puts its keys in place of the action's, the pad's stay.

## The kind of input each button binds
enum Slot {
    NONE,
    KEY,
    PAD,
}

## The buttons' texts while they wait - msgids
const KEY_WAITING_TEXT: String = "Press a key"
const PAD_WAITING_TEXT: String = "Press a pad button"
## The button's text of an action bound to nothing of its kind - a msgid
const UNBOUND_TEXT: String = "Not bound"
## Under the button, the actions taking one of its bindings as well - a msgid
const CONFLICT_TEXT: String = "Conflict with: %s"
## An action in conflict: its section's title, its name
const CONFLICT_ACTION: String = "%s, %s"
## Between the actions in conflict
const CONFLICT_SEPARATOR: String = "; "
## Between the names of the action's events
const SEPARATOR: String = " / "
## The keys only taken with another one
const MODIFIERS: Array[Key] = [KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META]
## How far a stick is pushed or a trigger pulled to be taken - past the drift of one at rest
const AXIS_PRESSED: float = 0.5
## Height of the pad's icon [px] - of a main row, and of an advanced one
const ICON_HEIGHT: int = 24
const COMPACT_ICON_HEIGHT: int = 20

## The titles of the sections holding each group's actions (msgids) - a conflict names the other
## action's section by it, a group of no section by the group's own name
var group_titles: Dictionary[String, String] = {}

## The button waiting: the next input of its kind pressed becomes the binding
var _waiting: Slot = Slot.NONE
var _icon_height: int = ICON_HEIGHT
## A shoulder or a trigger held while the pad's button waits (an InputBindings.PadModifier) - a
## combination's modifier, or the binding itself once it is let go alone - and its event to bind then
var _held_modifier: int = InputBindings.PadModifier.NONE
var _held_modifier_event: InputEvent = null


func is_edited_by_steps() -> bool:
    return false


## Waiting, it takes every key - Tab included, which the page and the screen walk with otherwise
func is_taking_keys() -> bool:
    return _waiting != Slot.NONE


## The keyboard's button waits for a key - a click on it
func wait_for_key() -> void:
    if available:
        _wait(Slot.KEY)


## The pad's button waits for a pad's button or axis - a click on it
func wait_for_pad() -> void:
    if available:
        _wait(Slot.PAD)


## The action's keys taken away - the keyboard's trash button
func clear_keys() -> void:
    if available:
        _clear(false)


## The action's pad's binding taken away - the pad's trash button
func clear_pad() -> void:
    if available:
        _clear(true)


## The keys of `preset` (an InputBindings.KeyboardPreset) in place of the action's keys - its pad's
## binding stays
func apply_keyboard_preset(preset: int) -> void:
    if _waiting != Slot.NONE:
        _stop_waiting()
    var events: Array = _without_kind(false)
    events.append_array(InputBindings.get_preset_keys(key, preset))
    # shown again by bindings_changed, when the keys are others - the same keys look the same
    _store(events)


## Drawn again when another maker's pad is used, and when any binding changes - a conflict comes
## or goes with another row's
func _setup() -> void:
    InputBindings.pad_layout_changed.connect(_on_pad_layout_changed)
    InputBindings.bindings_changed.connect(_on_bindings_changed)


func _make_compact() -> void:
    %Binding.add_theme_font_size_override(&"font_size", ADVANCED_TITLE_FONT_SIZE)
    %PadBinding.add_theme_font_size_override(&"font_size", ADVANCED_TITLE_FONT_SIZE)
    _icon_height = COMPACT_ICON_HEIGHT


func _enable_control(enabled: bool) -> void:
    for button: Button in [%Binding, %PadBinding]:
        button.disabled = not enabled
        button.modulate.a = 1.0 if enabled else UNAVAILABLE_ALPHA
    _update_clear_buttons()


## The keys as text on the keyboard's button, the first pad's button or axis as the icon on the
## pad's - a row binds one of each
func _show(value: Variant) -> void:
    var layout: InputEventNames.PadLayout = InputBindings.get_pad_layout()
    var keys: PackedStringArray = []
    var pad_names: PackedStringArray = []
    var icon: PadIcon = null
    for event: InputEvent in value:
        var event_name: String = InputBindings.event_name(event, layout)
        if not InputBindings.is_pad_event(event):
            keys.append(event_name)
            continue
        pad_names.append(event_name)
        if not icon:
            icon = PadIcon.for_event(event, layout, _icon_height)
    %Binding.text = SEPARATOR.join(keys) if keys else UNBOUND_TEXT
    %Binding.tooltip_text = SEPARATOR.join(keys)
    %PadBinding.text = "" if icon else UNBOUND_TEXT
    %PadBinding.icon = icon
    %PadBinding.tooltip_text = SEPARATOR.join(pad_names)
    _show_conflicts(%Binding, %KeyConflict, InputBindings.get_conflicts(key, false))
    _show_conflicts(%PadBinding, %PadConflict, InputBindings.get_conflicts(key, true))
    _update_clear_buttons()


## Enter on the row: the button of the device in use waits
func _activate() -> void:
    _wait(Slot.PAD if InputBindings.get_device() == InputBindings.Device.PAD else Slot.KEY)


func _wait(slot: Slot) -> void:
    _stop_waiting()
    _waiting = slot
    var button: Button = %PadBinding if slot == Slot.PAD else %Binding
    button.text = PAD_WAITING_TEXT if slot == Slot.PAD else KEY_WAITING_TEXT
    button.icon = null
    # the pad's button of menu_back is bound, not taken as Escape
    InputBindings.set_pad_capture(slot == Slot.PAD)


## Before the page and the screen: the rows are their children
func _input(event: InputEvent) -> void:
    if _waiting == Slot.NONE:
        return
    # the click is left to whatever it is on - a button itself starts waiting again
    if event is InputEventMouseButton and event.pressed:
        _stop_waiting()
        return
    # the key of menu_back only - its pad button is bound like any other
    if event is InputEventKey and event.is_action_pressed("menu_back", false, true):
        get_viewport().set_input_as_handled()
        _stop_waiting()
        return
    var key_event: InputEventKey = event as InputEventKey
    if key_event:
        get_viewport().set_input_as_handled()
        if _waiting == Slot.KEY:
            _take_key(key_event)
        return
    if InputBindings.is_pad_event(event):
        get_viewport().set_input_as_handled()
        if _waiting == Slot.PAD:
            _take_pad_input(event)


func _take_key(key_event: InputEventKey) -> void:
    if (
        not key_event.pressed or key_event.echo or key_event.keycode == KEY_NONE
        or key_event.keycode in MODIFIERS
    ):
        return
    var bound_key: InputEventKey = InputEventKey.new()
    bound_key.device = InputBindings.ALL_DEVICES
    bound_key.keycode = key_event.keycode
    bound_key.shift_pressed = key_event.shift_pressed
    bound_key.ctrl_pressed = key_event.ctrl_pressed
    bound_key.alt_pressed = key_event.alt_pressed
    bound_key.meta_pressed = key_event.meta_pressed
    _bind(bound_key)


## A button pressed or a stick pushed binds itself - with the shoulder or trigger held, if any; a
## shoulder or trigger pressed first waits: for another input, or for it let go alone
func _take_pad_input(event: InputEvent) -> void:
    var bound: InputEvent = _bound_pad_event(event)
    var modifier: int = InputBindings.PadModifier.NONE
    if bound:
        modifier = InputBindings.get_modifier_of_input(bound)
    if not _is_pad_pressed(event):
        # the modifier let go with nothing pressed while it was held: it alone is the binding
        var released: InputEvent = _released_pad_event(event)
        if released and _held_modifier != InputBindings.PadModifier.NONE and (
            InputBindings.get_modifier_of_input(released) == _held_modifier
        ):
            _bind(_held_modifier_event)
        return
    # a trigger held tells its every move: still the modifier held, not a second input
    if not bound or (modifier != InputBindings.PadModifier.NONE and modifier == _held_modifier):
        return
    if modifier != InputBindings.PadModifier.NONE and _held_modifier == InputBindings.PadModifier.NONE:
        _held_modifier = modifier
        _held_modifier_event = bound
        return
    if _held_modifier != InputBindings.PadModifier.NONE:
        bound.set_meta(InputBindings.PAD_MODIFIER_META, _held_modifier)
    _bind(bound)


## A pad's button pressed, or an axis pushed past AXIS_PRESSED
func _is_pad_pressed(event: InputEvent) -> bool:
    var button: InputEventJoypadButton = event as InputEventJoypadButton
    if button:
        return button.pressed
    return absf((event as InputEventJoypadMotion).axis_value) >= AXIS_PRESSED


## The binding a pad's input pressed makes - every device's, a pushed axis by its side
func _bound_pad_event(event: InputEvent) -> InputEvent:
    if not _is_pad_pressed(event):
        return null
    return _pad_event_of(event)


## A trigger let go or a button released, as the binding it made when it was pressed
func _released_pad_event(event: InputEvent) -> InputEvent:
    var motion: InputEventJoypadMotion = event as InputEventJoypadMotion
    if motion:
        # a trigger is let go towards its rest; only its pulled side is a modifier
        var pulled: InputEventJoypadMotion = InputEventJoypadMotion.new()
        pulled.device = InputBindings.ALL_DEVICES
        pulled.axis = motion.axis
        pulled.axis_value = 1.0
        return pulled
    return _pad_event_of(event)


func _pad_event_of(event: InputEvent) -> InputEvent:
    var button: InputEventJoypadButton = event as InputEventJoypadButton
    if button:
        var bound_button: InputEventJoypadButton = InputEventJoypadButton.new()
        bound_button.device = InputBindings.ALL_DEVICES
        bound_button.button_index = button.button_index
        return bound_button
    var motion: InputEventJoypadMotion = event as InputEventJoypadMotion
    var bound_motion: InputEventJoypadMotion = InputEventJoypadMotion.new()
    bound_motion.device = InputBindings.ALL_DEVICES
    bound_motion.axis = motion.axis
    bound_motion.axis_value = signf(motion.axis_value)
    return bound_motion


## `event` in place of the action's event of its kind - a key's, or a pad's button or axis
func _bind(event: InputEvent) -> void:
    var events: Array = _without_kind(InputBindings.is_pad_event(event))
    events.append(event)
    _store(events)
    _stop_waiting()


func _clear(pad: bool) -> void:
    _stop_waiting()
    _store(_without_kind(pad))
    _show(_read())


## The action's events but those of a pad (`pad`) or the keys
func _without_kind(pad: bool) -> Array:
    return (_read() as Array).filter(
        func(kept: InputEvent) -> bool:
            if pad:
                return not InputBindings.is_pad_event(kept)
            return not kept is InputEventKey
    )


func _stop_waiting() -> void:
    if _waiting == Slot.PAD:
        InputBindings.set_pad_capture(false)
    _waiting = Slot.NONE
    _held_modifier = InputBindings.PadModifier.NONE
    _held_modifier_event = null
    _show(_read())


## A trash button can be pressed while the row is available and its slot holds a binding
func _update_clear_buttons() -> void:
    if not is_node_ready():
        return
    var events: Array = _read()
    %ClearKeys.disabled = not available or not events.any(
        func(event: InputEvent) -> bool: return event is InputEventKey
    )
    %ClearPad.disabled = not available or not events.any(InputBindings.is_pad_event)


## The button orange while other actions take its binding too, and the line under it naming them,
## each with its section
func _show_conflicts(button: UIButton, line: Label, conflicts: PackedStringArray) -> void:
    button.intent = UIButton.Intent.WARNING if conflicts else UIButton.Intent.DEFAULT
    line.visible = conflicts.size() > 0
    if not conflicts:
        return
    var names: PackedStringArray = []
    for action: String in conflicts:
        var group: String = InputBindings.get_group(action)
        names.append(CONFLICT_ACTION % [
            tr(group_titles.get(group, group)), tr(action.capitalize())
        ])
    line.text = tr(CONFLICT_TEXT) % CONFLICT_SEPARATOR.join(names)


func _on_pad_layout_changed() -> void:
    if _waiting == Slot.NONE:
        _show(_read())


func _on_bindings_changed() -> void:
    if _waiting == Slot.NONE:
        _show(_read())


## Hidden - another section, the settings closed - it waits no more
func _notification(what: int) -> void:
    if what != NOTIFICATION_VISIBILITY_CHANGED or is_visible_in_tree():
        return
    if _waiting != Slot.NONE:
        _stop_waiting()
