class_name SettingInputHeader
extends VBoxContainer

## Above a key section's rows: the search of its actions by their names, in any language the game
## has (SettingRow.matches()), the buttons of the keyboard presets (InputBindings.KeyboardPreset),
## and the titles of the rows' keyboard and pad columns, laid out as a row is so they stand over its
## buttons. Escape or Enter in the search leaves it, the text stays.

## The text searched for changed - empty: every row
signal search_changed(text: String)
## The player chose the keyboard the keys are set for - an InputBindings.KeyboardPreset
signal keyboard_preset_chosen(preset: int)


func _ready() -> void:
    %Search.typed.connect(search_changed.emit)
    %Search.cleared.connect(search_changed.emit.bind(""))


## A preset's button - its InputBindings.KeyboardPreset bound in the scene
func choose_keyboard_preset(preset: int) -> void:
    keyboard_preset_chosen.emit(preset)


## Before the page, which would take Escape as the end of a row's editing
func _input(event: InputEvent) -> void:
    if not %Search.has_typing_focus():
        return
    if (
        event.is_action_pressed("menu_back", false, true)
        or event.is_action_pressed("menu_activate", false, true)
    ):
        get_viewport().set_input_as_handled()
        %Search.release_typing_focus()
