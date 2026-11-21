extends MaszynaGutTest

## The caches' settings: the maximum size chosen from the core's sizes, and the scenery loading
## cache, which is the core's switch of every cache

const SETTING_CACHE_SIZE: PackedScene = preload("res://settings/setting_cache_size.tscn")
const DECLARATIONS_SETTING: String = "reloaded/user_settings/declarations"
## UserSettings.hpp PROJECT_SETTINGS_SECTION
const PROJECT_SETTINGS_SECTION: String = "project_settings"
const MAX_SIZE_SETTING: String = "reloaded/cache/max_size"
const CACHE_ENABLED_SETTING: String = "reloaded/cache/enabled"
## The tests' own caches: a smaller maximum size trims them at once, never the player's
const TEST_ROOT: String = "user://test_setting_cache_size/"

var _row: SettingCacheSize = null
var _original_root: String


func before_each() -> void:
    _original_root = ResourceCacheServer.root
    ResourceCacheServer.root = TEST_ROOT
    _row = SETTING_CACHE_SIZE.instantiate()
    _row.title = "Maximum cache size"
    _row.store = SettingRow.Store.PROJECT
    _row.key = MAX_SIZE_SETTING
    _row.default_value = UserSettings.get_project_value(MAX_SIZE_SETTING)
    add_child_autofree(_row)


## What the player has saved, back - nothing a test set stays
func after_each() -> void:
    UserSettings.load_config()
    ResourceCacheServer.cache_clear("")
    ResourceCacheServer.root = _original_root


func test_the_choices_are_the_core_s_sizes_and_no_limit() -> void:
    var choices: PackedInt64Array = ResourceCacheServer.max_size_get_choices()
    var options: OptionButton = _options()
    assert_eq(options.item_count, choices.size())
    assert_eq(options.get_item_text(0), "%d GB" % roundi(choices[0] / float(SettingCacheSize.BYTES_PER_GB)))
    assert_eq(options.get_item_text(options.item_count - 1), "No limit")


func test_the_row_shows_the_size_in_effect() -> void:
    var choices: PackedInt64Array = ResourceCacheServer.max_size_get_choices()
    assert_eq(_options().get_item_id(_options().selected), choices.find(ProjectSettings.get_setting(MAX_SIZE_SETTING)))


func test_a_smaller_size_chosen_is_in_effect() -> void:
    var choices: PackedInt64Array = ResourceCacheServer.max_size_get_choices()
    UserSettings.set_setting(PROJECT_SETTINGS_SECTION, MAX_SIZE_SETTING, choices[1])
    _row.revert()
    _row.step_down()
    assert_eq(ProjectSettings.get_setting(MAX_SIZE_SETTING), choices[0])


func test_the_scenery_loading_cache_is_the_switch_of_every_cache() -> void:
    var declarations: Dictionary = JSON.parse_string(
        FileAccess.get_file_as_string(ProjectSettings.get_setting(DECLARATIONS_SETTING)))
    var keys: Dictionary = {}
    for section: Dictionary in declarations["sections"]:
        for setting: Dictionary in section.get("settings", []):
            keys[setting["title"]] = setting["key"]
    assert_eq(keys.get("Scenery loading cache"), CACHE_ENABLED_SETTING)
    assert_eq(keys.get("Maximum cache size"), MAX_SIZE_SETTING)


func _options() -> OptionButton:
    return _row.get_node("%Options")
