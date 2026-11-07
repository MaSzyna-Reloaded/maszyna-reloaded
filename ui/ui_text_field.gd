class_name UITextField
extends LineEdit

## A text the player types, as the game draws it - framed as its search field is, the frame lit
## while it is typed in: it takes its look from ui_theme.tres itself, so no theme around it has to
## provide it.

const UI_THEME: Theme = preload("ui_theme.tres")

var _compact: bool = false


func _ready() -> void:
    theme = UI_THEME
    _apply_look()


## Smaller, for what stands below the main things (the settings' "Advanced")
func set_compact(p_compact: bool) -> void:
    _compact = p_compact
    _apply_look()


func _apply_look() -> void:
    theme_type_variation = &"UITextFieldCompact" if _compact else &"UITextField"


## `event` typed into `field` - any LineEdit - by whoever keeps the keys from the GUI: the in-game
## settings panel takes every key before the world and the GUI see it (settings_panel.gd), so it
## types into its field with the focus itself. A character (AltGr's included), Backspace, Delete,
## the arrows, Home, End and Ctrl+V, replacing a selection; Enter submits and Escape leaves, both
## giving the focus up. The field tells of a change as its own typing does (text_changed).
static func type_key(field: LineEdit, event: InputEventKey) -> void:
    if not event.pressed:
        return
    var text: String = field.text
    var caret: int = field.caret_column
    var from: int = field.get_selection_from_column() if field.has_selection() else caret
    var to: int = field.get_selection_to_column() if field.has_selection() else caret
    # Ctrl alone is a command; with Alt it is AltGr typing a character (Windows)
    var command: bool = event.is_command_or_control_pressed() and not event.alt_pressed
    var inserted: String = ""
    match event.keycode:
        KEY_ENTER, KEY_KP_ENTER:
            field.text_submitted.emit(text)
            field.release_focus()
            return
        KEY_ESCAPE:
            field.release_focus()
            return
        KEY_LEFT, KEY_RIGHT, KEY_HOME, KEY_END:
            field.deselect()
            field.caret_column = (
                maxi(caret - 1, 0) if event.keycode == KEY_LEFT
                else caret + 1 if event.keycode == KEY_RIGHT
                else 0 if event.keycode == KEY_HOME
                else text.length()
            )
            return
        KEY_BACKSPACE:
            if from == to:
                from = maxi(from - 1, 0)
        KEY_DELETE:
            if from == to:
                to = mini(to + 1, text.length())
        _:
            if command and event.keycode == KEY_V:
                inserted = DisplayServer.clipboard_get().replace("\n", " ")
            elif event.unicode >= 32 and not command:
                inserted = char(event.unicode)
            else:
                return
    if from == to and inserted.is_empty() or not field.editable:
        return
    var changed: String = text.left(from) + inserted + text.substr(to)
    if field.max_length > 0:
        changed = changed.left(field.max_length)
    field.text = changed
    field.deselect()
    field.caret_column = from + inserted.length()
    field.text_changed.emit(changed)
