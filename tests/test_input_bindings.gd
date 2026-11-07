extends MaszynaGutTest

## The player's keys (input_bindings.gd, settings/setting_input.gd): a binding kept in the player's
## settings is on the InputMap at once, the project's own is back when it is restored to default or
## discarded, and a key row's keyboard button binds the next key pressed and its pad button the next
## pad button or axis, each in place of the event of its kind, showing a pad's button or axis as an
## icon drawn as on the pad last used (PadIcon). What is shown to the player follows the device in
## use. The player's settings are set here and loaded back after each test, never saved.

const SETTING_INPUT: PackedScene = preload("res://settings/setting_input.tscn")
const CABIN_CONTROL_TOOLTIP: PackedScene = preload(
    "res://addons/libreloaded/cabin/cabin_control_tooltip.tscn"
)
## An action project.godot binds to a key (Up) and a pad's button (the d-pad's up)
const ACTION: String = "menu_up"
## An icon's height in the tests [px]
const ICON_HEIGHT: int = 24

var _row: SettingInput = null


func before_each() -> void:
    _row = SETTING_INPUT.instantiate()
    _row.title = ACTION.capitalize()
    _row.store = SettingRow.Store.USER
    _row.section = InputBindings.SETTINGS_SECTION
    _row.key = ACTION
    _row.default_value = InputBindings.get_default_events(ACTION)
    add_child_autofree(_row)


## What the player has saved, back - nothing a test set stays; the keyboard in use again
func after_each() -> void:
    UserSettings.load_config()
    InputBindings._set_device(InputBindings.Device.KEYBOARD)


func test_a_binding_set_is_on_the_input_map_and_restored_to_the_project_s() -> void:
    var events: Array = [_key(KEY_F, true)]
    UserSettings.set_setting(InputBindings.SETTINGS_SECTION, ACTION, events)
    assert_eq(InputMap.action_get_events(ACTION).size(), 1)
    assert_true(_key(KEY_F, true).is_action_pressed(ACTION, false, true))
    assert_false(_key(KEY_UP, false).is_action_pressed(ACTION, false, true))
    UserSettings.erase_setting(InputBindings.SETTINGS_SECTION, ACTION)
    assert_true(_key(KEY_UP, false).is_action_pressed(ACTION, false, true))
    assert_false(_key(KEY_F, true).is_action_pressed(ACTION, false, true))


func test_a_binding_discarded_is_the_project_s_again() -> void:
    UserSettings.set_setting(InputBindings.SETTINGS_SECTION, ACTION, [_key(KEY_F, false)])
    UserSettings.load_config()
    assert_true(_key(KEY_UP, false).is_action_pressed(ACTION, false, true))
    assert_false(_key(KEY_F, false).is_action_pressed(ACTION, false, true))


func test_a_key_with_its_modifier_takes_the_place_of_the_key_alone() -> void:
    _row.wait_for_key()
    assert_true(_row.is_taking_keys())
    _press(_key(KEY_CTRL, true))
    _press(_key(KEY_F, true))
    assert_false(_row.is_taking_keys())
    assert_true(_key(KEY_F, true).is_action_pressed(ACTION, false, true))
    assert_false(_key(KEY_F, false).is_action_pressed(ACTION, false, true))
    assert_false(_key(KEY_UP, false).is_action_pressed(ACTION, false, true))
    # the pad's button stays
    assert_true(_has_pad(ACTION, _button(JOY_BUTTON_DPAD_UP)))


func test_a_modifier_alone_is_no_binding() -> void:
    _row.activate()
    _press(_key(KEY_SHIFT, false))
    var released: InputEventKey = _key(KEY_SHIFT, false)
    released.pressed = false
    _press(released)
    assert_true(_row.is_taking_keys())
    assert_false(UserSettings.is_config_changed())


func test_a_pad_button_takes_the_place_of_the_pad_button_only() -> void:
    _row.wait_for_pad()
    _press(_button(JOY_BUTTON_A))
    assert_true(_has_pad(ACTION, _button(JOY_BUTTON_A)))
    assert_false(_has_pad(ACTION, _button(JOY_BUTTON_DPAD_UP)))
    assert_true(_key(KEY_UP, false).is_action_pressed(ACTION, false, true))


## A trigger is a modifier: it is bound alone once it is let go with nothing pressed
func test_a_trigger_pulled_takes_the_place_of_the_pad_button_and_shows_by_its_label() -> void:
    _row.wait_for_pad()
    var pulled: InputEventJoypadMotion = InputEventJoypadMotion.new()
    pulled.axis = JOY_AXIS_TRIGGER_RIGHT
    pulled.axis_value = 0.9
    _press(pulled)
    assert_true(_row.is_taking_keys())
    var let_go: InputEventJoypadMotion = InputEventJoypadMotion.new()
    let_go.axis = JOY_AXIS_TRIGGER_RIGHT
    let_go.axis_value = 0.0
    _press(let_go)
    assert_false(_row.is_taking_keys())
    var events: Array[InputEvent] = InputBindings.get_events(ACTION)
    assert_eq(events.size(), 2)
    assert_false(_has_pad(ACTION, _button(JOY_BUTTON_DPAD_UP)))
    assert_true(_key(KEY_UP, false).is_action_pressed(ACTION, false, true))
    var motion: InputEventJoypadMotion = events[1] as InputEventJoypadMotion
    assert_not_null(motion)
    assert_eq(motion.axis_value, 1.0)
    assert_eq(InputEventNames.event_name(motion), "Pad RT")


func test_the_row_shows_its_key_by_name_and_its_pad_button_as_an_icon() -> void:
    var binding: Button = _row.find_child("Binding") as Button
    assert_eq(binding.text, "Up")
    assert_null(binding.icon)
    assert_eq(binding.tooltip_text, "Up")
    var pad_binding: Button = _row.find_child("PadBinding") as Button
    var icon: PadIcon = pad_binding.icon as PadIcon
    assert_not_null(icon)
    assert_eq(icon.get_height(), SettingInput.ICON_HEIGHT)
    assert_eq(pad_binding.text, "")
    # the driving preset's direction takes the d-pad's up as well: a conflict's line follows
    assert_eq(pad_binding.tooltip_text.get_slice("\n", 0), "Pad Up")


func test_the_keyboard_button_waits_for_a_key_only() -> void:
    _row.wait_for_key()
    _press(_button(JOY_BUTTON_A))
    assert_true(_row.is_taking_keys())
    assert_false(UserSettings.is_config_changed())


func test_the_pad_button_waits_for_a_pad_only() -> void:
    _row.wait_for_pad()
    _press(_key(KEY_F, false))
    assert_true(_row.is_taking_keys())
    assert_false(UserSettings.is_config_changed())


func test_enter_waits_on_the_button_of_the_device_in_use() -> void:
    InputBindings._set_device(InputBindings.Device.PAD)
    _row.activate()
    _press(_button(JOY_BUTTON_B))
    assert_false(_row.is_taking_keys())
    assert_true(_has_pad(ACTION, _button(JOY_BUTTON_B)))
    assert_true(_key(KEY_UP, false).is_action_pressed(ACTION, false, true))


func test_the_bindings_shown_are_the_device_in_use_s_or_the_other_s() -> void:
    var shown: Array[InputEvent] = InputBindings.get_shown_events(ACTION)
    assert_eq(shown.size(), 1)
    assert_true(shown[0] is InputEventKey)
    InputBindings._set_device(InputBindings.Device.PAD)
    shown = InputBindings.get_shown_events(ACTION)
    assert_eq(shown.size(), 1)
    assert_true(shown[0] is InputEventJoypadButton)
    # no pad's binding: its key is shown
    UserSettings.set_setting(InputBindings.SETTINGS_SECTION, ACTION, [_key(KEY_F, false)])
    shown = InputBindings.get_shown_events(ACTION)
    assert_eq(shown.size(), 1)
    assert_true(shown[0] is InputEventKey)


## Two actions of one group are always in effect together
func test_a_key_another_action_takes_is_a_conflict_of_the_keyboard_s_column() -> void:
    var action: String = InputBindings.get_actions("UI")[0]
    var other: String = InputBindings.get_actions("UI")[1]
    UserSettings.set_setting(
        InputBindings.SETTINGS_SECTION, action, [_key(KEY_F, true), _button(JOY_BUTTON_A)]
    )
    UserSettings.set_setting(InputBindings.SETTINGS_SECTION, other, [_key(KEY_F, true)])
    assert_eq(InputBindings.get_conflicts(action, false), PackedStringArray([other]))
    # the pad's button is the vehicle's too (whistle), never the other's
    assert_does_not_have(InputBindings.get_conflicts(action, true), other)


## The line under the keyboard's button names the other action with its section's title
func test_a_conflict_is_named_under_the_button_with_its_section() -> void:
    var group_titles: Dictionary[String, String] = {"Vehicle": "Vehicle keys"}
    _row.group_titles = group_titles
    var line: Label = _row.find_child("KeyConflict") as Label
    UserSettings.set_setting(InputBindings.SETTINGS_SECTION, "horn_low", [_key(KEY_UP, false)])
    assert_true(line.visible)
    assert_eq(line.text, "Conflict with: Vehicle keys, Horn Low")
    assert_eq((_row.find_child("Binding") as UIButton).intent, UIButton.Intent.WARNING)
    UserSettings.erase_setting(InputBindings.SETTINGS_SECTION, "horn_low")
    assert_false(line.visible)


## The 60% keyboard binds the numpad's keys under Left Alt, the full one project.godot's again; the
## pad's binding stays either way
func test_a_keyboard_preset_sets_the_keys_and_keeps_the_pad_s_binding() -> void:
    var action: String = "brake_level_increase"
    var row: SettingInput = SETTING_INPUT.instantiate()
    row.store = SettingRow.Store.USER
    row.section = InputBindings.SETTINGS_SECTION
    row.key = action
    row.default_value = InputBindings.get_default_events(action)
    add_child_autofree(row)
    UserSettings.set_setting(
        InputBindings.SETTINGS_SECTION, action, [_key(KEY_F, false), _button(JOY_BUTTON_A)]
    )
    row.apply_keyboard_preset(InputBindings.KeyboardPreset.COMPACT)
    var alt_l: InputEventKey = _key(KEY_L, false)
    alt_l.alt_pressed = true
    assert_true(alt_l.is_action_pressed(action, false, true))
    assert_false(_key(KEY_F, false).is_action_pressed(action, false, true))
    assert_true(_has_pad(action, _button(JOY_BUTTON_A)))
    row.apply_keyboard_preset(InputBindings.KeyboardPreset.FULL)
    assert_true(_key(KEY_KP_3, false).is_action_pressed(action, false, true))
    assert_false(alt_l.is_action_pressed(action, false, true))
    assert_true(_has_pad(action, _button(JOY_BUTTON_A)))


## Bindings changed at once (a keyboard preset on every row) are applied, and bindings_changed sent,
## once after the last - each sent on its own drew every row again for each
func test_bindings_changed_at_once_are_applied_once() -> void:
    watch_signals(InputBindings)
    InputBindings.change_at_once(
        func() -> void:
            for action: String in InputBindings.COMPACT_KEYS:
                UserSettings.set_setting(
                    InputBindings.SETTINGS_SECTION, action,
                    InputBindings.get_preset_keys(action, InputBindings.KeyboardPreset.COMPACT)
                )
            assert_signal_not_emitted(InputBindings, "bindings_changed")
    )
    assert_signal_emit_count(InputBindings, "bindings_changed", 1)
    var alt_l: InputEventKey = _key(KEY_L, false)
    alt_l.alt_pressed = true
    assert_true(alt_l.is_action_pressed("brake_level_increase", false, true))
    for action: String in InputBindings.COMPACT_KEYS:
        UserSettings.erase_setting(InputBindings.SETTINGS_SECTION, action)


## Every key the 60% keyboard moves is an action's, and no other action takes the key it moves to
func test_the_compact_preset_adds_no_conflict() -> void:
    for action: String in InputBindings.COMPACT_KEYS:
        assert_true(InputMap.has_action(action), action)
    var taken: Dictionary[String, String] = {}
    for group: String in InputBindings.GROUPS:
        for action: String in InputBindings.get_actions(group):
            for event: InputEvent in InputBindings.get_preset_keys(
                action, InputBindings.KeyboardPreset.COMPACT
            ):
                var id: String = event.as_text()
                var other: String = taken.get(id, "")
                if other and (action in InputBindings.COMPACT_KEYS or other in InputBindings.COMPACT_KEYS):
                    fail_test("%s and %s take %s" % [action, other, id])
                taken[id] = action


## Whatever the language shown: English, Polish, Chinese, Hungarian - case aside
func test_a_row_is_found_by_its_name_in_any_language() -> void:
    assert_true(_row.matches(""))
    assert_true(_row.matches("menu up"))
    assert_true(_row.matches("W GÓRĘ"))
    assert_true(_row.matches("菜单"))
    assert_true(_row.matches("fel"))
    assert_false(_row.matches("hamulec"))


func test_the_search_shows_only_the_rows_found_and_the_keyboard_walks_them() -> void:
    var page: SettingsPage = preload("res://settings/settings_page.tscn").instantiate()
    remove_child(_row)
    page.add_row(_row)
    var other: SettingInput = SETTING_INPUT.instantiate()
    other.title = "Menu Down"
    other.store = SettingRow.Store.USER
    other.section = InputBindings.SETTINGS_SECTION
    other.key = "menu_down"
    other.default_value = InputBindings.get_default_events("menu_down")
    page.add_row(other)
    add_child_autofree(page)
    page.filter_rows("dół")
    assert_false(_row.visible)
    assert_true(other.visible)
    assert_eq(page._items(), [other] as Array[Control])
    page.filter_rows("")
    assert_true(_row.visible)


## The in-game panel types into its field itself: a character, AltGr's, Backspace, a selection
## replaced
func test_a_key_typed_into_a_field_as_the_field_would_take_it() -> void:
    var field: LineEdit = LineEdit.new()
    add_child_autofree(field)
    var changes: Array[String] = []
    field.text_changed.connect(changes.append)
    UITextField.type_key(field, _typed(KEY_H, "h", false))
    UITextField.type_key(field, _typed(KEY_A, "ą", true))
    assert_eq(field.text, "hą")
    UITextField.type_key(field, _typed(KEY_BACKSPACE, "", false))
    assert_eq(field.text, "h")
    field.select_all()
    UITextField.type_key(field, _typed(KEY_X, "x", false))
    assert_eq(field.text, "x")
    assert_eq(changes, ["h", "hą", "h", "x"] as Array[String])


func test_a_shoulder_held_and_a_button_make_a_combination() -> void:
    _row.wait_for_pad()
    _press(_button(JOY_BUTTON_LEFT_SHOULDER))
    assert_true(_row.is_taking_keys())
    _press(_button(JOY_BUTTON_A))
    assert_false(_row.is_taking_keys())
    var combination: InputEvent = InputBindings.get_events(ACTION)[-1]
    assert_eq(InputBindings.get_pad_modifier(combination), InputBindings.PadModifier.LB)
    assert_eq(InputBindings.event_name(combination, InputEventNames.PadLayout.XBOX), "Pad LB + Pad A")
    # drawn as the shoulder, a plus and the button: wider than the button alone
    var icon: PadIcon = PadIcon.for_event(combination, InputEventNames.PadLayout.XBOX, ICON_HEIGHT)
    assert_gt(icon.get_width(), 2 * ICON_HEIGHT)


func test_a_shoulder_let_go_alone_is_bound_alone() -> void:
    _row.wait_for_pad()
    _press(_button(JOY_BUTTON_LEFT_SHOULDER))
    _press(_released(JOY_BUTTON_LEFT_SHOULDER))
    assert_false(_row.is_taking_keys())
    var bound: InputEvent = InputBindings.get_events(ACTION)[-1]
    assert_eq(InputBindings.get_pad_modifier(bound), InputBindings.PadModifier.NONE)
    assert_true(_has_pad(ACTION, _button(JOY_BUTTON_LEFT_SHOULDER)))


func test_the_trash_buttons_take_a_binding_of_their_kind_away() -> void:
    _row.clear_pad()
    assert_false(_has_pad(ACTION, _button(JOY_BUTTON_DPAD_UP)))
    assert_true(_key(KEY_UP, false).is_action_pressed(ACTION, false, true))
    assert_true((_row.find_child("ClearPad") as Button).disabled)
    _row.clear_keys()
    assert_true(InputBindings.get_events(ACTION).is_empty())
    assert_eq((_row.find_child("Binding") as Button).text, SettingInput.UNBOUND_TEXT)


## LB+A acts on its own action, not on A's; LB tapped alone presses its own for TAP_SECONDS -
## long enough for the simulation to see it - unless a combination was pressed while it was held
func test_the_pad_acts_on_a_combination_before_its_button_alone() -> void:
    var combined: String = InputBindings.get_actions("UI")[0]
    var alone: String = InputBindings.get_actions("UI")[1]
    var shoulder: String = InputBindings.get_actions("UI")[2]
    var combination: InputEventJoypadButton = _button(JOY_BUTTON_A)
    combination.set_meta(InputBindings.PAD_MODIFIER_META, InputBindings.PadModifier.LB)
    UserSettings.set_setting(InputBindings.SETTINGS_SECTION, combined, [combination])
    UserSettings.set_setting(InputBindings.SETTINGS_SECTION, alone, [_button(JOY_BUTTON_A)])
    UserSettings.set_setting(
        InputBindings.SETTINGS_SECTION, shoulder, [_button(JOY_BUTTON_LEFT_SHOULDER)]
    )
    # the player's own settings may bind A to more actions: only these three are looked at
    var sent: Array[String] = []
    var record: Callable = func(action: String, pressed: bool) -> void:
        if action in [combined, alone, shoulder]:
            sent.append("%s %s" % [action, "down" if pressed else "up"])
    InputBindings.pad_action_sent.connect(record)
    InputBindings._dispatch_pad_event(_button(JOY_BUTTON_LEFT_SHOULDER))
    InputBindings._dispatch_pad_event(_button(JOY_BUTTON_A))
    InputBindings._dispatch_pad_event(_released(JOY_BUTTON_A))
    InputBindings._dispatch_pad_event(_released(JOY_BUTTON_LEFT_SHOULDER))
    assert_eq(sent, ["%s down" % combined, "%s up" % combined] as Array[String])
    sent.clear()
    InputBindings._dispatch_pad_event(_button(JOY_BUTTON_LEFT_SHOULDER))
    InputBindings._dispatch_pad_event(_released(JOY_BUTTON_LEFT_SHOULDER))
    assert_eq(sent, ["%s down" % shoulder] as Array[String])
    await wait_seconds(InputBindings.TAP_SECONDS + 0.1)
    assert_eq(sent, ["%s down" % shoulder, "%s up" % shoulder] as Array[String])
    sent.clear()
    InputBindings._dispatch_pad_event(_button(JOY_BUTTON_A))
    InputBindings._dispatch_pad_event(_released(JOY_BUTTON_A))
    assert_eq(sent, ["%s down" % alone, "%s up" % alone] as Array[String])
    sent.clear()
    # held alone past MODIFIER_HOLD_SECONDS it holds its own action until let go
    InputBindings._dispatch_pad_event(_button(JOY_BUTTON_LEFT_SHOULDER))
    await wait_seconds(InputBindings.MODIFIER_HOLD_SECONDS + 0.1)
    assert_eq(sent, ["%s down" % shoulder] as Array[String])
    InputBindings._dispatch_pad_event(_released(JOY_BUTTON_LEFT_SHOULDER))
    assert_eq(sent, ["%s down" % shoulder, "%s up" % shoulder] as Array[String])
    InputBindings.pad_action_sent.disconnect(record)


## The default pad's preset for driving: project.godot's combinations keep their modifier, and a cab
## control's caption names them while a pad is in use
func test_the_driving_preset_s_combinations_are_named_under_a_cab_control() -> void:
    UserSettings.erase_setting(InputBindings.SETTINGS_SECTION, "battery_toggle")
    var battery: Array[InputEvent] = InputBindings.get_events("battery_toggle")
    var combination: InputEvent = battery[-1]
    assert_eq(InputBindings.get_pad_modifier(combination), InputBindings.PadModifier.LB)
    InputBindings._set_device(InputBindings.Device.PAD)
    assert_eq(
        BaseCabinTool3D.action_hints.call("battery_toggle"), PackedStringArray(["Pad LB + Pad A"])
    )
    InputBindings._set_device(InputBindings.Device.KEYBOARD)
    assert_eq(BaseCabinTool3D.action_hints.call("battery_toggle"), PackedStringArray(["J"]))


## A cab control's caption draws a pad's binding as on the pad (PadIcon), a key's name as text
func test_a_cab_control_s_caption_draws_the_pad_s_binding_as_its_icon() -> void:
    UserSettings.erase_setting(InputBindings.SETTINGS_SECTION, "battery_toggle")
    var tooltip: CabinControlTooltip = CABIN_CONTROL_TOOLTIP.instantiate()
    add_child_autofree(tooltip)
    InputBindings._set_device(InputBindings.Device.PAD)
    var hints: String = BaseCabinTool3D.HINTS_SEPARATOR.join(
        BaseCabinTool3D.action_hints.call("battery_toggle")
    )
    CabinHUDMouseSystem.control_hovered.emit("Battery", hints, "")
    var icons: HBoxContainer = tooltip.find_child("HintIcons")
    assert_true(icons.visible)
    assert_false((tooltip.find_child("Hints") as Label).visible)
    assert_true((icons.get_child(0) as TextureRect).texture is PadIcon)
    InputBindings._set_device(InputBindings.Device.KEYBOARD)
    hints = BaseCabinTool3D.HINTS_SEPARATOR.join(
        BaseCabinTool3D.action_hints.call("battery_toggle")
    )
    CabinHUDMouseSystem.control_hovered.emit("Battery", hints, "")
    assert_false(icons.visible)
    assert_eq((tooltip.find_child("Hints") as Label).text, "J")


func test_a_pad_icon_is_only_a_pad_s() -> void:
    var layout: InputEventNames.PadLayout = InputEventNames.PadLayout.PLAYSTATION
    assert_null(PadIcon.for_event(_key(KEY_F, false), layout, ICON_HEIGHT))
    var face: PadIcon = PadIcon.for_event(_button(JOY_BUTTON_A), layout, ICON_HEIGHT)
    assert_eq(face.get_size(), Vector2(ICON_HEIGHT, ICON_HEIGHT))
    # a labelled button is as wide as its label needs, never narrower than it is high
    var options: PadIcon = PadIcon.for_event(_button(JOY_BUTTON_START), layout, ICON_HEIGHT)
    assert_gt(options.get_width(), ICON_HEIGHT)
    var pulled: InputEventJoypadMotion = InputEventJoypadMotion.new()
    pulled.axis = JOY_AXIS_TRIGGER_LEFT
    pulled.axis_value = 1.0
    assert_not_null(PadIcon.for_event(pulled, layout, ICON_HEIGHT))


func test_without_a_pad_the_buttons_are_shown_as_on_an_xbox_pad() -> void:
    assert_eq(InputBindings.get_pad_layout(), InputEventNames.PadLayout.XBOX)


func test_escape_stops_waiting_with_the_binding_as_it_was() -> void:
    _row.activate()
    _press(_key(KEY_ESCAPE, false))
    assert_false(_row.is_taking_keys())
    assert_false(UserSettings.is_config_changed())
    assert_true(_key(KEY_UP, false).is_action_pressed(ACTION, false, true))


func _press(event: InputEvent) -> void:
    get_viewport().push_input(event)


## A key pressed - with Ctrl held, or not
func _key(keycode: Key, ctrl: bool) -> InputEventKey:
    var event: InputEventKey = InputEventKey.new()
    event.keycode = keycode
    event.ctrl_pressed = ctrl or keycode == KEY_CTRL
    event.shift_pressed = keycode == KEY_SHIFT
    event.pressed = true
    return event


## A key typing `character` - with AltGr (Ctrl and Alt) held, or not
func _typed(keycode: Key, character: String, alt_gr: bool) -> InputEventKey:
    var event: InputEventKey = InputEventKey.new()
    event.keycode = keycode
    event.unicode = character.unicode_at(0) if character else 0
    event.ctrl_pressed = alt_gr
    event.alt_pressed = alt_gr
    event.pressed = true
    return event


## Whether `action` takes the pad's `event` - the pad's bindings are InputBindings', not the
## InputMap's
func _has_pad(action: String, event: InputEvent) -> bool:
    var id: String = InputBindings._input_id(event)
    return InputBindings.get_events(action).any(
        func(bound: InputEvent) -> bool: return InputBindings._input_id(bound) == id
    )


func _released(index: JoyButton) -> InputEventJoypadButton:
    var event: InputEventJoypadButton = _button(index)
    event.pressed = false
    return event


func _button(index: JoyButton) -> InputEventJoypadButton:
    var event: InputEventJoypadButton = InputEventJoypadButton.new()
    event.button_index = index
    event.pressed = true
    return event
