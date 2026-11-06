extends "settings_screen.gd"

## The settings as a panel beside the game, a third of the screen wide, so what a change does stays
## in sight: the sections first, and the settings of one in their place once it is opened; back -
## the arrow - shows the sections again. It is played with the mouse, and while it is open no key
## and no pad's button or axis pressed reaches the game - a key row waiting for one takes it first,
## and nothing else in the game acts on it (game.gd puts the world before the panel, so the panel's
## input comes first). A key or a button let go still does, so nothing held as the panel opens
## stays held. Escape asks about the settings, as the close button does, and the key that opened
## the panel closes it the same way. A field of the panel with the focus is typed into by the panel
## itself (UITextField.type_key()), the world seeing nothing of it.

## Another game directory, confirmed in a game - the game ends and the directory is set in the
## menu, once the scenery read from the old one is gone
signal game_dir_change_requested(path: String)

## The sections' own title, shown while no section is open
const SECTIONS_TITLE: String = "Settings"

## A section's settings stand in the place of the sections
var _page_open: bool = false
## The directory chosen on its page, waiting for the player to confirm the game ends
var _chosen_game_dir: String = ""


func focus_section_list() -> void:
    _page_open = false
    _pages[_page].visible = false
    %SectionList.visible = true
    %BackButton.visible = false
    %Title.text = SECTIONS_TITLE


func focus_page() -> void:
    _page_open = true
    %SectionList.visible = false
    _pages[_page].visible = true
    %BackButton.visible = true
    %Title.text = _titles[_page]


## F11 and the "Simulator" menu's entry: open, or - open already - closed as by its close button
func toggle() -> void:
    if visible:
        ask_save_or_discard()
        return
    open()


## Up from the buttons: back to whichever of the two is shown
func focus_content() -> void:
    if _page_open:
        focus_page()
        return
    focus_section_list()


## Before the game sees the key: its menu shortcuts come after the input, and the world's own
## input after the panel's (game.gd); the key rows, children of the panel, have had it before
func _input(event: InputEvent) -> void:
    if not visible:
        return
    # a field of the panel with the focus - a key section's search, a slider's value - is typed into
    # here: the GUI would see the key only after the world
    var field: LineEdit = get_viewport().gui_get_focus_owner() as LineEdit
    if field and is_ancestor_of(field) and event is InputEventKey:
        get_viewport().set_input_as_handled()
        UITextField.type_key(field, event)
        return
    if (
        event.is_action_pressed("menu_back", false, true)
        or event.is_action_pressed("settings_open", false, true)
    ):
        get_viewport().set_input_as_handled()
        ask_save_or_discard()
        return
    # the pad's actions come as actions (InputBindings turns its input into them)
    var pressed_input: bool = (
        event is InputEventKey or event is InputEventAction or InputBindings.is_pad_event(event)
    ) and event.is_pressed()
    if pressed_input:
        get_viewport().set_input_as_handled()


## The section is only chosen here; it is shown when it is opened
func _on_section_list_item_selected(index: int) -> void:
    if index < 0:
        return
    _page = index


## In a game another directory ends it: the scenery was read from the old one. The player is asked.
func choose_game_dir(path: String, _row: SettingGameDir) -> void:
    _chosen_game_dir = path
    %GameDirQuestion.ask()


## The panel goes and the game ends; the directory is set in the menu (game.gd)
func change_game_dir() -> void:
    _close()
    game_dir_change_requested.emit(_chosen_game_dir)
