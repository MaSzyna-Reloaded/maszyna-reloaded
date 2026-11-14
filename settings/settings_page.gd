class_name SettingsPage
extends FocusSection

## The settings of one section of the settings screen, one row each, and under them a named group's
## rows folded away under its own title (UIFoldable, add_group_row()) - the settings' "Advanced",
## a plugin's own repeated instances (settings_screen.gd, "repeat_group") - shown only once it has
## a row. Up and down walk the rows - a group's title among them, and its rows while it is unfolded
## - and left leaves as navigate_left, to the sections; Enter on a group's title folds or unfolds
## it, switches a switch, and puts any other row into editing, where left and right change its
## value until Enter or Escape ends it; Tab and Shift+Tab go from a slider to its value field to
## type it and back. Down from the last item leaves as navigate_down, Escape (not editing) as
## cancelled.

## The bank this page plays from - it has to name "keystroke" and "change_focus"
@export var sounds: SfxBank = null

var _rows: Array[SettingRow] = []
## Every group's own rows, by its UIFoldable - in the order the groups were made
var _groups: Array[UIFoldable] = []
var _group_rows: Dictionary[UIFoldable, Array] = {}
var _group_by_title: Dictionary[String, UIFoldable] = {}
## The item the keyboard is on - a row or a group's title
var _selected: Control = null
## Left and right change the selected row's value instead of leaving the page
var _editing: bool = false
var _ui_sounds: SfxPlayer


func _ready() -> void:
    super()
    _ui_sounds = SfxPlayer.new()
    _ui_sounds.bank = sounds
    add_child(_ui_sounds)
    focus_taken.connect(_ui_sounds.play.bind(&"change_focus"))


## A row below the others - the screen adds them in the order the definition lists them
func add_row(row: SettingRow) -> void:
    %Rows.add_child(row)
    _rows.append(row)
    # the first row the keyboard is on is the first one shown, even after a group came first
    if not _selected or _selected is UIFoldable:
        _selected = row


## A line above the rows that the keyboard does not walk - the key sections' search and column
## titles
func add_header(header: Control) -> void:
    %Content.add_child(header)
    %Content.move_child(header, 0)


## Only the rows whose name holds `text` in any language (SettingRow.matches()) are shown, and a
## group only with one of its own; the keyboard goes to the first one shown when its row went
func filter_rows(text: String) -> void:
    for row: SettingRow in _rows:
        row.visible = row.matches(text)
    for group: UIFoldable in _groups:
        var rows: Array = _group_rows[group]
        for row: SettingRow in rows:
            row.visible = row.matches(text)
        group.visible = rows.any(func(row: SettingRow) -> bool: return row.visible)
    var items: Array[Control] = _items()
    if items and not _selected in items:
        _select(items[0])


## A row under the named group - "Advanced", or one of a plugin's own instances
## (settings_screen.gd, "repeat_group") - made the first time its title is asked for, which shows
## from its first row on
func add_group_row(title: String, row: SettingRow) -> void:
    var group: UIFoldable = _group_by_title.get(title)
    if not group:
        group = UIFoldable.new()
        group.title = title
        group.folded = true
        group.visible = false
        var rows_box: VBoxContainer = VBoxContainer.new()
        rows_box.add_theme_constant_override("separation", 6)
        group.add_child(rows_box)
        group.folding_changed.connect(_on_group_folding_changed.bind(group))
        %Content.add_child(group)
        _groups.append(group)
        _group_rows[group] = []
        _group_by_title[title] = group
        if not _selected:
            _selected = group
    row.advanced = true
    group.get_child(0).add_child(row)
    _group_rows[group].append(row)
    group.visible = true


func restore_defaults() -> void:
    for row: SettingRow in _all_rows():
        row.restore_default()


func revert() -> void:
    for row: SettingRow in _all_rows():
        row.revert()


## What the settings are opened with, for needs_restart()
func remember_values() -> void:
    for row: SettingRow in _all_rows():
        row.remember_value()


func needs_restart() -> bool:
    return _all_rows().any(func(row: SettingRow) -> bool: return row.needs_restart())


## Every row of the page, top-level and every group's
func _all_rows() -> Array[SettingRow]:
    var rows: Array[SettingRow] = _rows.duplicate()
    for group: UIFoldable in _groups:
        rows.append_array(_group_rows[group])
    return rows


## The selected item is lit only while the page has the focus, and nothing is edited without it
func _process_dirty() -> void:
    super()
    if not focused:
        _set_editing(false)
    _light(_selected, focused)


## A row is being edited - its keys are its own, Tab included, which goes between its control and
## its value field, or is bound by a row waiting for a key (the screen's Tab walks the sections only
## while no row is edited)
func is_editing() -> bool:
    return _editing or (_selected is SettingRow and (_selected as SettingRow).is_taking_keys())


func _input(event: InputEvent) -> void:
    if not is_visible_in_tree():
        return
    # a click on an item - its slider, its field, its switch - chooses it, as the keyboard would,
    # and asks for the page's focus; the control under it takes the click itself, and whatever was
    # being edited is left
    # (only inside the list's view: a row scrolled away keeps its place under what is shown there)
    var click: InputEventMouseButton = event as InputEventMouseButton
    if click and click.pressed:
        if not %Scroll.get_global_rect().has_point(click.position):
            return
        # bottom up: a group's title spans its own rows, which come after it, so a row is found
        # first
        var items: Array[Control] = _items()
        items.reverse()
        for item: Control in items:
            if item.get_global_rect().has_point(click.position):
                if not item == _selected:
                    _set_editing(false)
                    _select(item)
                focus_requested.emit()
                return
        return
    if not focused:
        return
    var row: SettingRow = _selected as SettingRow
    # a value typed into a row's field takes every key until the field is left - Tab and Shift+Tab
    # go back to the control, Escape ends the editing
    if get_viewport().gui_get_focus_owner() is LineEdit:
        if (
            event.is_action_pressed("menu_next_section", true, true)
            or event.is_action_pressed("menu_previous_section", true, true)
        ):
            row.toggle_value_typing()
        elif event.is_action_pressed("menu_back", false, true):
            row.toggle_value_typing()
            _set_editing(false)
        else:
            return
        get_viewport().set_input_as_handled()
        return
    if _editing:
        if (
            event.is_action_pressed("menu_next_section", true, true)
            or event.is_action_pressed("menu_previous_section", true, true)
        ):
            row.toggle_value_typing()
        elif event.is_action_pressed("menu_right", true, true):
            row.step_up()
        elif event.is_action_pressed("menu_left", true, true):
            row.step_down()
        elif (
            event.is_action_pressed("menu_activate", false, true)
            or event.is_action_pressed("menu_back", false, true)
        ):
            _set_editing(false)
        else:
            return
        get_viewport().set_input_as_handled()
        return
    var items: Array[Control] = _items()
    # nothing found by the search: down leaves the page, the rest is the section's
    if items.is_empty():
        if event.is_action_pressed("menu_down", true, true):
            navigate_down.emit()
            get_viewport().set_input_as_handled()
        else:
            super(event)
        return
    var at: int = items.find(_selected)
    if event.is_action_pressed("menu_down", true, true):
        if at == items.size() - 1:
            navigate_down.emit()
        else:
            _go_to(items[at + 1])
    elif event.is_action_pressed("menu_up", true, true):
        _go_to(items[maxi(at - 1, 0)])
    elif event.is_action_pressed("menu_activate", false, true):
        # a row that is not available takes nothing, editing included
        if not row:
            var group: UIFoldable = _selected as UIFoldable
            if group.folded:
                group.expand()
            else:
                group.fold()
        elif not row.available:
            pass
        elif row.is_edited_by_steps():
            _set_editing(true)
        else:
            row.activate()
    else:
        super(event)
        return
    get_viewport().set_input_as_handled()


## A click anywhere on the page asks for its focus; the control under it takes the click itself
func _gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.pressed:
        focus_requested.emit()


## What the keyboard walks, top to bottom: the rows, every group's title, its rows while unfolded -
## those the search shows (filter_rows())
func _items() -> Array[Control]:
    var items: Array[Control] = []
    for row: SettingRow in _rows:
        if row.visible:
            items.append(row)
    for group: UIFoldable in _groups:
        if group.visible:
            items.append(group)
            if not group.folded:
                for row: SettingRow in _group_rows[group]:
                    if row.visible:
                        items.append(row)
    return items


func _set_editing(editing: bool) -> void:
    if editing == _editing:
        return
    _editing = editing
    (_selected as SettingRow).set_editing(_editing)


func _go_to(item: Control) -> void:
    if item == _selected:
        return
    _ui_sounds.play(&"keystroke")
    _select(item)
    scroll_to_item(%Scroll, _selected)


## The keyboard's item moves, lit only while the page has the focus - where the list stands is the
## caller's: the keyboard brings it into view, a click is on one in view already
func _select(item: Control) -> void:
    _light(_selected, false)
    _selected = item
    _light(_selected, focused)


func _light(item: Control, lit: bool) -> void:
    if item is SettingRow:
        (item as SettingRow).set_selected(lit)
    elif item is UIFoldable:
        (item as UIFoldable).set_selected(lit)


## Every group opens folded every time the page is shown again - after another section, after the
## settings were closed
func _notification(what: int) -> void:
    if what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():
        for group: UIFoldable in _groups:
            group.fold()


## Folded under its own chosen row, the page hidden: the keyboard goes up to the title
func _on_group_folding_changed(is_folded: bool, group: UIFoldable) -> void:
    if is_folded and _selected in _group_rows[group]:
        _select(group)
