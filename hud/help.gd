extends ScrollContainer
class_name Help

## Lists the input actions as "Action [Shortcut]" rows, grouped as InputBindings groups them, with
## the bindings in effect of the device in use - the player's own included; the keys of an action
## the pad does not take while a pad is (InputBindings.get_shown_events()) - and a pad's drawn as on
## the pad last used, shown again whenever any of them changes.

const KEY_CAP: PackedScene = preload("key_cap.tscn")


func _ready() -> void:
    InputBindings.bindings_changed.connect(_show_bindings)
    InputBindings.pad_layout_changed.connect(_show_bindings)
    InputBindings.device_changed.connect(_show_bindings)
    _show_bindings()


func _show_bindings() -> void:
    for group_node: Node in %Bindings.get_children():
        group_node.queue_free()
    for group: String in InputBindings.GROUPS:
        var actions: PackedStringArray = InputBindings.get_actions(group)
        if not actions:
            continue
        var foldable: UIFoldable = UIFoldable.new()
        foldable.title = group
        # Tab and Space belong to the game, not to the focus of a HUD widget
        foldable.focus_mode = Control.FOCUS_NONE
        var rows: VBoxContainer = VBoxContainer.new()
        for action: String in actions:
            rows.add_child(_make_row(action))
        foldable.add_child(rows)
        %Bindings.add_child(foldable)


func _make_row(action: String) -> HBoxContainer:
    var row: HBoxContainer = HBoxContainer.new()
    var label: Label = Label.new()
    label.text = action.capitalize()
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    label.custom_minimum_size.x = 80.0
    label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(label)
    for event: InputEvent in InputBindings.get_shown_events(action):
        var key_cap: KeyCap = KEY_CAP.instantiate()
        row.add_child(key_cap)
        key_cap.show_event(event)
    return row

