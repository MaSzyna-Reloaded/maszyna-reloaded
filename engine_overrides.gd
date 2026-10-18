extends Node

## The engine's settings the player sets that the engine reads only at its own start, before the game
## can set anything - the file logging, and multi-bounce ambient occlusion and texture streaming,
## both compiled into the shaders: kept in override.cfg, which Godot reads then (beside
## project.godot, beside the executable of a release; application/config/
## disable_project_settings_override is off). The only writer of that file. The player's value lives
## in UserSettings like any other, so Save and Discard changes hold for it; the file holds what
## differs from the project's own and is gone when nothing is left in it.

## A player's switch (settings.json, "restart_required") and the engine's settings it stands for:
## on, they are the project's own; off, they take the values of `off`
class Override:
    var section: String
    var key: String
    var default: bool
    var off: Dictionary[String, bool]

    func _init(p_section: String, p_key: String, p_default: bool, p_off: Dictionary[String, bool]) -> void:
        section = p_section
        key = p_key
        default = p_default
        off = p_off


## Logging is the project's own (project.godot): to the file, the prints and the errors of a release
## with it - which the file has nothing of otherwise - each written out at once, a line whole as
## it comes (flush_stdout_on_print). Switched off, all of it goes quiet.
const LOGGING_OFF: Dictionary[String, bool] = {
    "debug/file_logging/enable_file_logging": false,
    "application/run/disable_stdout.release": true,
    "application/run/disable_stderr.release": true,
}
## Both on in project.godot; the engine reads them when it compiles its shaders
## (render_forward_clustered.cpp), the streaming also when a StreamedTexture2D is made
const MULTI_BOUNCE_OCCLUSION_OFF: Dictionary[String, bool] = {
    "rendering/lights_and_shadows/multi_bounce_occlusion/enabled": false,
}
const TEXTURE_STREAMING_OFF: Dictionary[String, bool] = {
    "rendering/textures/streaming/enabled": false,
}
const OVERRIDE_FILE: String = "override.cfg"

## The player's switches (settings.json: Debug, Graphics)
var _overrides: Array[Override] = [
    Override.new("debug", "file_logging", true, LOGGING_OFF),
    Override.new("render", "multi_bounce_occlusion_enabled", true, MULTI_BOUNCE_OCCLUSION_OFF),
    Override.new("render", "texture_streaming_enabled", true, TEXTURE_STREAMING_OFF),
]


func _ready() -> void:
    UserSettings.config_changed.connect(_write_overrides)
    _write_overrides()


func _write_overrides() -> void:
    # beside the executable of a release, beside project.godot otherwise
    var directory: String = (
        OS.get_executable_path().get_base_dir() if OS.has_feature("template")
        else ProjectSettings.globalize_path("res://")
    )
    var path: String = directory.path_join(OVERRIDE_FILE)
    var overrides: ConfigFile = ConfigFile.new()
    overrides.load(path)
    var changed: bool = false
    for override: Override in _overrides:
        var on: bool = bool(UserSettings.get_setting(override.section, override.key, override.default))
        for setting: String in override.off:
            var section: String = setting.get_slice("/", 0)
            var key: String = setting.trim_prefix(section + "/")
            var stored: bool = overrides.has_section_key(section, key)
            if on and stored:
                overrides.erase_section_key(section, key)
                changed = true
            elif not on and not (stored and overrides.get_value(section, key) == override.off[setting]):
                overrides.set_value(section, key, override.off[setting])
                changed = true
    if not changed:
        return
    if overrides.get_sections():
        overrides.save(path)
    else:
        DirAccess.remove_absolute(path)
