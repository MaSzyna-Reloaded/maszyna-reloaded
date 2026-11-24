extends MaszynaGutTest

## The graphics quality presets of settings.json: each sets the same settings of the screen, within
## their choices, none that waits for a restart and none experimental turned on; High is the
## settings' own defaults, Filmic Ultra with the film grain, the scenery lights of high quality and
## the maximum shadow texture quality.
## The choice stands above every section, shows the preset the settings match, "Custom" while they
## match none, and a choice of it sets the whole preset.

const SETTING_PRESET: PackedScene = preload("res://settings/setting_preset.tscn")
const SETTINGS_SCREEN: PackedScene = preload("res://settings/settings_screen.tscn")
## The settings beside a game (F11)
const SETTINGS_PANEL: PackedScene = preload("res://settings/settings_panel.tscn")
const DECLARATIONS_SETTING: String = "reloaded/user_settings/declarations"
## UserSettings.hpp PROJECT_SETTINGS_SECTION
const PROJECT_SETTINGS_SECTION: String = "project_settings"
const PRESETS: PackedStringArray = ["low", "mid", "high", "ultra", "filmic"]
const DEFAULTS_PRESET: String = "high"
## Experimental settings, as "<section>/<key>": off in every preset, High's defaults aside
const EXPERIMENTAL: PackedStringArray = [
    "project_settings/maszyna/rendering/real_mirrors",
]
const ULTRA: String = "ultra"
const FILMIC: String = "filmic"
## What Filmic sets apart from Ultra, as "<section>/<key>"
const FILMIC_OWN: PackedStringArray = [
    "render/film_grain_enabled",
    "project_settings/reloaded/shadows/texture_quality",
    "project_settings/maszyna/scenery/lights/mode",
]
## A value of a range hint_string may pass its maximum
const OR_GREATER: String = "or_greater"
## A row that never matches any preset - lower than any preset's range
const NO_PRESET_TRACKS_DISTANCE: float = 123.0
const TRACKS_DISTANCE_SETTING: String = "reloaded/scenery/tracks/distance"

var _declarations: Dictionary = {}
## Every declared setting by its section and key - a "project" one's section is
## PROJECT_SETTINGS_SECTION, as a preset's values have it
var _declared: Dictionary = {}
var _row: SettingPreset = null


func before_all() -> void:
    _declarations = JSON.parse_string(
        FileAccess.get_file_as_string(ProjectSettings.get_setting(DECLARATIONS_SETTING)))
    for section: Dictionary in _declarations["sections"]:
        for setting: Dictionary in section.get("settings", []):
            var setting_section: String = (
                PROJECT_SETTINGS_SECTION if setting["store"] == "project" else setting.get("section", ""))
            if not _declared.has(setting_section):
                _declared[setting_section] = {}
            _declared[setting_section][setting.get("key", "")] = setting


func before_each() -> void:
    _row = SETTING_PRESET.instantiate()
    _row.title = "Graphics quality"
    add_child_autofree(_row)


## What the player has saved, back - nothing a test set stays
func after_each() -> void:
    UserSettings.load_config()


func test_the_game_s_presets_in_their_order() -> void:
    assert_eq(UserSettings.preset_list(), PRESETS)


func test_the_choice_stands_above_every_section() -> void:
    for scene: PackedScene in [SETTINGS_SCREEN, SETTINGS_PANEL]:
        var screen: Control = scene.instantiate()
        add_child_autofree(screen)

        var presets: Array[Node] = screen.find_children("*", "SettingPreset", true, false)
        assert_eq(presets.size(), 1, "one choice of the preset in %s" % screen.name)
        assert_eq(presets[0].get_parent(), screen.get_node("%PresetSection"), "above the sections")


func test_the_panel_beside_a_game_opens_with_the_preset_in_effect() -> void:
    var panel: Control = SETTINGS_PANEL.instantiate()
    add_child_autofree(panel)
    UserSettings.preset_set(ULTRA)

    panel.open()

    assert_true(panel.visible, "open")
    var options: OptionButton = panel.get_node("%Preset").get_node("%Options")
    assert_eq(options.get_item_text(options.selected), "Ultra")


func test_every_value_is_a_declared_setting_within_its_choices() -> void:
    for preset: Dictionary in _declarations["presets"]:
        for key: String in _keys(preset):
            var setting: Dictionary = _setting(key)
            assert_false(setting.is_empty(), "%s of %s is declared" % [key, preset["name"]])
            if setting.is_empty():
                continue
            assert_false(setting.get("restart_required", false), "%s takes effect at once" % key)
            var value: Variant = _value(preset, key)
            match setting.get("hint", ""):
                "enum":
                    var choices: Array[int] = []
                    for choice: String in setting["hint_string"].split(","):
                        choices.append(int(choice.get_slice(":", 1)))
                    assert_has(choices, int(value), "%s of %s is a choice" % [key, preset["name"]])
                "range":
                    var range_hint: PackedStringArray = setting["hint_string"].split(",")
                    assert_gte(float(value), float(range_hint[0]), "%s of %s within its range" % [key, preset["name"]])
                    if not range_hint.has(OR_GREATER):
                        assert_lte(float(value), float(range_hint[1]), "%s of %s within its range" % [key, preset["name"]])
            if setting["type"] == "bool":
                assert_typeof(value, TYPE_BOOL, "%s of %s is a switch" % [key, preset["name"]])


func test_every_preset_sets_the_same_settings() -> void:
    var keys: PackedStringArray = _keys(_declarations["presets"][0])
    for preset: Dictionary in _declarations["presets"]:
        assert_eq(_keys(preset), keys, "%s sets the same settings" % preset["name"])


func test_no_preset_turns_an_experimental_setting_on() -> void:
    for preset: Dictionary in _declarations["presets"]:
        for key: String in EXPERIMENTAL:
            assert_eq(_value(preset, key), false, "%s off in %s" % [key, preset["name"]])


func test_high_is_the_settings_own_defaults() -> void:
    var preset: Dictionary = _preset(DEFAULTS_PRESET)
    for key: String in _keys(preset):
        if key in EXPERIMENTAL:
            continue
        var default_value: Variant = SettingRow.get_default_value(_setting(key))
        assert_almost_eq(float(_value(preset, key)), float(default_value), 0.0001, "%s is its default" % key)


func test_filmic_is_ultra_with_film_grain_and_high_quality_scenery_lights() -> void:
    var ultra: Dictionary = _preset(ULTRA)
    var filmic: Dictionary = _preset(FILMIC)
    var own: PackedStringArray = []
    for key: String in _keys(filmic):
        if not _value(filmic, key) == _value(ultra, key):
            own.append(key)
    assert_eq(own, FILMIC_OWN)


func test_the_row_shows_the_preset_set() -> void:
    UserSettings.preset_set(ULTRA)

    assert_eq(_options().get_item_text(_options().selected), "Ultra")


func test_the_row_shows_custom_while_the_settings_match_no_preset() -> void:
    UserSettings.preset_set(ULTRA)

    UserSettings.set_setting(PROJECT_SETTINGS_SECTION, TRACKS_DISTANCE_SETTING, NO_PRESET_TRACKS_DISTANCE)

    assert_eq(_options().get_item_text(_options().selected), "Custom")


func test_a_preset_chosen_asks_for_the_whole_preset() -> void:
    UserSettings.preset_set(ULTRA)
    watch_signals(_row)

    _row.step_down()

    assert_signal_emitted_with_parameters(_row, "preset_chosen", ["high"])


func test_custom_is_never_chosen() -> void:
    UserSettings.preset_set(FILMIC)
    watch_signals(_row)

    _row.step_up()

    assert_signal_not_emitted(_row, "preset_chosen", "Filmic is the last preset")


func _options() -> OptionButton:
    return _row.get_node("%Options")


func _preset(preset_name: String) -> Dictionary:
    for preset: Dictionary in _declarations["presets"]:
        if preset["name"] == preset_name:
            return preset
    return {}


## A preset's settings as "<section>/<key>"
func _keys(preset: Dictionary) -> PackedStringArray:
    var keys: PackedStringArray = []
    for section: String in preset["values"]:
        for key: String in preset["values"][section]:
            keys.append(section.path_join(key))
    return keys


func _value(preset: Dictionary, key: String) -> Variant:
    var section: String = key.get_slice("/", 0)
    return preset["values"][section][key.trim_prefix(section + "/")]


func _setting(key: String) -> Dictionary:
    var section: String = key.get_slice("/", 0)
    return _declared.get(section, {}).get(key.trim_prefix(section + "/"), {})
