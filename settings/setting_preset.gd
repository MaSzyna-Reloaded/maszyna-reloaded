class_name SettingPreset
extends SettingOption

## The preset the settings match (UserSettings.preset_list()), its title a msgid, and "Custom"
## while they match none - shown then, never chosen. It stands above every section of the settings
## screen, as a preset sets options of many of them; choosing one is the screen's, which shows the
## new values on every page (preset_chosen). The row follows every change of the settings, so a
## value changed by hand shows "Custom".

## The player chose the preset of this name
signal preset_chosen(preset: String)

## The presets' names, by id - the id after the last one is "Custom"
var _presets: PackedStringArray = []


func _init() -> void:
    store = Store.PRESET


func _enter_tree() -> void:
    UserSettings.config_changed.connect(revert)


func _exit_tree() -> void:
    UserSettings.config_changed.disconnect(revert)


func _setup() -> void:
    _presets = UserSettings.preset_list()
    for id: int in _presets.size():
        %Options.add_item(UserSettings.preset_get(_presets[id])["title"], id)
    %Options.add_item("Custom", _presets.size())
    %Options.set_item_disabled(_presets.size(), true)


## No value of its own: every other row brings back its own default
func restore_default() -> void:
    pass


func _store(value: Variant) -> void:
    if _showing:
        return
    preset_chosen.emit(value)


## Left and right, and Enter, walk the presets only - "Custom" is never chosen
func _step_up() -> void:
    _choose(mini(%Options.selected + 1, _presets.size() - 1))


func _activate() -> void:
    _choose(wrapi(%Options.selected + 1, 0, _presets.size()))


func _value_of(id: int) -> Variant:
    return _presets[id]


func _id_of(value: Variant) -> int:
    var id: int = _presets.find(value)
    return id if id >= 0 else _presets.size()
