extends MaszynaGutTest

## Every project setting of the settings screen has its default once, where its owner keeps it - a
## library's or the game's registration, or project.godot - and that is the project's own value,
## whatever the player set (SettingRow.get_default_value())

const DECLARATIONS_SETTING: String = "reloaded/user_settings/declarations"
## UserSettings.hpp PROJECT_SETTINGS_SECTION
const PROJECT_SETTINGS_SECTION: String = "project_settings"
const WIND_TURBULENCE_PLAYER_VALUE: float = 2.5


func after_each() -> void:
    UserSettings.erase_setting(PROJECT_SETTINGS_SECTION, GndSkydomeMaszynaEnvironment.WIND_TURBULENCE_SETTING)


func test_every_project_setting_of_the_screen_has_a_default() -> void:
    var declarations: Dictionary = JSON.parse_string(
        FileAccess.get_file_as_string(ProjectSettings.get_setting(DECLARATIONS_SETTING)))
    for section: Dictionary in declarations["sections"]:
        for setting: Dictionary in section.get("settings", []):
            if not SettingRow.STORES[setting["store"]] == SettingRow.Store.PROJECT:
                continue
            assert_false(setting.has("default"), "%s keeps no default of its own" % setting["key"])
            assert_ne(SettingRow.get_default_value(setting), null, "%s has a default" % setting["key"])


func test_the_default_is_the_project_s_own_value_whatever_the_player_set() -> void:
    var setting: Dictionary = {"store": "project", "key": GndSkydomeMaszynaEnvironment.WIND_TURBULENCE_SETTING}
    UserSettings.set_setting(PROJECT_SETTINGS_SECTION, setting["key"], WIND_TURBULENCE_PLAYER_VALUE)

    assert_eq(ProjectSettings.get_setting(setting["key"]), WIND_TURBULENCE_PLAYER_VALUE, "the player's value applied")
    assert_eq(SettingRow.get_default_value(setting), GndSkydomeMaszynaEnvironment.WIND_TURBULENCE_DEFAULT)
