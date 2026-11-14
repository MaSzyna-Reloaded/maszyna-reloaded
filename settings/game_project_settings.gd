extends Node

## The game's own project settings, each with its owner's default value, registered as the game
## starts - after the libraries' (ReloadedPlugins) and the plugins' servers, before the main scene
## reads them: the wind's turbulence the sky gives gnd-weather, and the sunshafts of gnd-skydome and
## the rain look of gnd-weather, which those plugins register in the editor only. A value
## project.godot gives one is kept, and the settings screen offers the project's own value as the
## default (SettingRow.get_default_value()).

## The startup, which names the world scene whose Skydome node has the game's look of the sky
const STARTUP: GDScript = preload("res://startup/startup.gd")


func _ready() -> void:
    ReloadedProjectSetting.add(
        GndSkydomeMaszynaEnvironment.WIND_TURBULENCE_SETTING, GndSkydomeMaszynaEnvironment.WIND_TURBULENCE_DEFAULT,
        TYPE_FLOAT, PROPERTY_HINT_RANGE, "0.0,4.0,0.01,or_greater"
    )
    # the plugins' own values, read off a node made for it: an exported game knows no default of a
    # script (WeatherSettings.get_value()); the sunshafts as the world scene's Skydome node has them
    var skydome: Skydome = Skydome.new()
    var world_skydome: Dictionary = _get_world_skydome_values()
    for property: StringName in GndSkydomeMaszynaEnvironment.SUNSHAFT_PROPERTIES:
        _add_plugin_setting(
            GndSkydomeMaszynaEnvironment.SUNSHAFT_SETTINGS_PREFIX + property,
            world_skydome.get(property, skydome.get(property))
        )
    skydome.free()
    var weather: WeatherNode = WeatherNode.new()
    for property: StringName in WeatherSettings.PROPERTIES:
        _add_plugin_setting(WeatherSettings.PREFIX + property, weather.get(property))
    weather.free()


static func _add_plugin_setting(name: String, default_value: Variant) -> void:
    ReloadedProjectSetting.add(name, default_value, typeof(default_value))


## The values the world scene sets on its Skydome node, by property - read from the scene, which is
## made only when a scenery is chosen
static func _get_world_skydome_values() -> Dictionary:
    var values: Dictionary = {}
    var state: SceneState = (load(STARTUP.WORLD_SCENE) as PackedScene).get_state()
    for node: int in state.get_node_count():
        var properties: Dictionary = {}
        for property: int in state.get_node_property_count(node):
            properties[state.get_node_property_name(node, property)] = state.get_node_property_value(node, property)
        if properties.get(&"script") == Skydome:
            values = properties
    return values
