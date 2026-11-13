@tool
extends SkyEnvironment
class_name GndSkydomeMaszynaEnvironment

## The environment drawn by gnd-skydome (Skydome) with gnd-weather (WeatherNode) - rain, clouds,
## wind and lightning of their own.

## Skydome's sunshafts, set by the player's Graphics settings (SUNSHAFT_SETTINGS_PREFIX + property)
## over the Skydome node's own, and taken whenever they change
const SUNSHAFT_SETTINGS_PREFIX: String = "gnd_skydome/"
const SUNSHAFT_PROPERTIES: Array[StringName] = [
    &"sunshafts_enabled", &"sunshafts_intensity", &"sunshafts_density",
    &"sunshafts_bright_threshold", &"sunshafts_weight", &"sunshafts_decay", &"sunshafts_exposure",
    &"sunshafts_max_radius", &"sunshafts_cloud_occlusion", &"sunshafts_cloud_falloff",
    &"sunshafts_perf_sample_count",
]
## No rain falls inside the vehicle the player sits in: its body, as FIZ Dimensions give it, takes
## the precipitation away. Only the shown cab has one - a volume on every vehicle of a scenery was
## a quarter of the frame (libmaszyna docs/findings-archive.md, 2026-10-03 hundreds of vehicles)
const RAIN_EXCLUSION_NAME: StringName = &"RainExclusion"
const RAIN_EXCLUSION_PRECIPITATION_DELTA: float = -1.0
const SUN_LIGHT_NAME: StringName = &"SunLight"
const WEATHER_NAME: StringName = &"Weather"
const WIND_TURBULENCE_SETTING: StringName = &"reloaded/weather/wind_turbulence"
const WIND_TURBULENCE_DEFAULT: float = 1.0
# Weather response to rain and wind strength, as in forest-test-scene ui/WeatherControlsCanvas.gd.
const WIND_STRENGTH_MIN: float = 0.4
const WIND_STRENGTH_MAX: float = 5.0
const STORM_RAIN_START: float = 0.4
# Precipitation the rain starts to bring its own fog from (RAIN_FOG_DISTANCE_SETTING,
# RAIN_FOG_DENSITY_SETTING), in full at 1.0
const RAIN_FOG_START: float = 0.6
# Skydome's day/night densities are tuned for exponential fog and barely show in depth fog, so the
# visible fog comes from Skydome's fog_density boost, which is the fog opacity at the fog distance.
# The volumetric fog and the clouds and rain Skydome blends on top are tuned for this opacity
# (0.15 in forest-test-scene) and this day distance, and follow the node proportionally.
const FOG_REFERENCE_DENSITY: float = 0.15
const FOG_REFERENCE_DISTANCE_PROPERTY: StringName = &"day_fog_distance"
const FOG_DENSITY_PROPERTIES: Array[StringName] = [&"day_fog_density", &"night_fog_density"]
# Volumetric fog is an extinction per metre over a volume of Skydome's own length in front of the
# camera, not an opacity at a distance: it has to thin out as the fog distance grows, or it fills
# that volume up while the depth fog recedes. The volume length is Skydome's own, scaled by
# FOG_VOLUMETRIC_LENGTH_SCALE_SETTING with the density compensating for it.
const FOG_VOLUMETRIC_DENSITY_PROPERTIES: Array[StringName] = [&"day_vol_fog_density", &"night_vol_fog_density"]
const FOG_VOLUMETRIC_LENGTH_PROPERTIES: Array[StringName] = [&"day_vol_fog_length", &"night_vol_fog_length"]
# Skydome shortens the volume in proportion to its own fog density boost (Skydome.gd:17, :1317):
# length * (1 - VOL_FOG_LENGTH_SHRINK * boost). A scenery that declares a fog sets the density to
# 1.0, which leaves about a fifth of the length - 72 m asked for comes out as 15.5 m. Undone below
# so FOG_VOLUMETRIC_LENGTH_SCALE_SETTING means what it says.
const SKYDOME_VOL_FOG_LENGTH_SHRINK: float = 0.8
const SKYDOME_VOL_FOG_LENGTH_SHRINK_MIN: float = 0.05
const FOG_RANGE_PROPERTIES: Array[StringName] = [&"day_fog_distance_begin", &"night_fog_distance_begin"]
# How much of the depth fog reaches the sky follows the fog distance (FOG_SKY_HEIGHT_SETTING);
# Skydome's own pull of it towards 1.0 with a growing fog is switched off.
const FOG_SKY_AFFECT_PROPERTIES: Array[StringName] = [&"day_fog_sky_affect", &"night_fog_sky_affect"]
# The volumetric fog is a volume right in front of the camera, so it stands in front of the sky as
# much as in front of anything else: left out of the sky, fog lit by the headlights ends along the
# silhouette of whatever stands against it.
const FOG_VOLUMETRIC_SKY_AFFECT_PROPERTIES: Array[StringName] = [
    &"day_vol_fog_sky_affect", &"night_vol_fog_sky_affect",
]
const RAINBOW_INTENSITY_MAX: float = 0.12
const RAINBOW_RAIN_START: float = 0.2
const RAINBOW_RAIN_END: float = 0.5
const RAINBOW_CLOUD_FADE_START: float = 0.2
const RAINBOW_CLOUD_FADE_END: float = 0.5
const SECONDS_PER_DAY: int = 86400
const MAXIMUM_DAY_OF_YEAR: int = 365
# Time is pushed to Skydome at a fixed rate and Skydome interpolates in between
# (same as WorldTimer in forest-test-scene levels/test_biomes.gd:227).
const TIME_UPDATE_INTERVAL: float = 0.1
## The sun's light turns by steps of this much of the sky's time: Godot keeps the shadow cascades
## still only while the light does not turn - turned with every time pushed (TIME_UPDATE_INTERVAL)
## the shadows flickered, by a simulated minute's step (0.25 degrees) they jumped visibly
const LIGHT_UPDATE_STEP_SECONDS: float = 10.0

## The sky this environment draws with: the node keeps its look, tuned in the scene; what the
## environment sets as it goes (the time, the fog, the light) is set on its sky past it
## (SkydomeServer.skydome_set_param()), so none of it is saved with the scene. Its param_changed is
## connected to apply_configuration() in the scene.
@export var skydome: Skydome
var sun_light: DirectionalLight3D
var weather: WeatherNode

var _time_update_elapsed: float = 0.0


func create_sky() -> Sky:
    # Skydome replaces the sky with its own shader material in _init_sky() (Skydome.gd:794).
    return Sky.new()


func create_nodes(world_environment: WorldEnvironment, _sky_environment: Environment) -> void:
    # Skydome switches this single light between sun and moon by itself.
    sun_light = DirectionalLight3D.new()
    sun_light.name = SUN_LIGHT_NAME
    world_environment.add_child(sun_light, false, Node.INTERNAL_MODE_BACK)

    SkydomeServer.skydome_bind(skydome.get_rid(), world_environment, sun_light)
    _set_skydome_param(&"fog_mode", SkydomeSky.FogModeOverride.DEPTH)
    # the light turns by steps, the sky follows every time pushed (LIGHT_UPDATE_STEP_SECONDS)
    _set_skydome_param(&"light_update_mode", SkydomeSky.LightUpdateMode.STEPPED)
    _set_skydome_param(&"light_update_step_seconds", LIGHT_UPDATE_STEP_SECONDS)

    # Weather drives Skydome clouds, wind, fog density and lightning on its own - from the generated
    # WorldEnvironment it stands in, two levels under this node
    weather = WeatherNode.new()
    weather.name = WEATHER_NAME
    weather.skydome_path = NodePath("../../%s" % get_path_to(skydome))
    weather.world_environment_path = NodePath("..")
    # Rain look comes from the gnd_weather/* project settings (WeatherSettings).
    weather.apply_project_settings = true
    world_environment.add_child(weather, false, Node.INTERNAL_MODE_BACK)


func _enter_tree() -> void:
    super()
    CabinSystem.vehicle_cabin_built.connect(_on_vehicle_cabin_built)


func _exit_tree() -> void:
    super()
    CabinSystem.vehicle_cabin_built.disconnect(_on_vehicle_cabin_built)


## The cab's interior keeps the rain out of the vehicle; the vehicle's origin lies on the rail
## level, so the box is lifted by half of its height, and the cab's own turn about the vertical
## leaves the box as it is
func _on_vehicle_cabin_built(vehicle_rid: RID, cabin: Cabin3D) -> void:
    var rain_exclusion: PrecipitationVolume = PrecipitationVolume.new()
    rain_exclusion.name = RAIN_EXCLUSION_NAME
    rain_exclusion.precipitation_delta = RAIN_EXCLUSION_PRECIPITATION_DELTA
    rain_exclusion.size = VehicleServer.vehicle_get_dimensions(vehicle_rid)
    rain_exclusion.position.y = rain_exclusion.size.y * 0.5
    cabin.add_child(rain_exclusion)


func pause_weather() -> void:
    weather.process_mode = Node.PROCESS_MODE_DISABLED


func unpause_weather() -> void:
    weather.process_mode = Node.PROCESS_MODE_INHERIT


## Skydome's look value for [param property] - the node's, as tuned; what is set on its sky is
## scaled from it
func _skydome_value(property: StringName) -> float:
    return float(skydome.get(property))


func _set_skydome_param(property: StringName, value: Variant) -> void:
    SkydomeServer.skydome_set_param(skydome.get_rid(), property, value)


func apply_visual_configuration() -> void:
    if not skydome:
        return
    # only what differs: each of them makes Skydome set its effect up again
    for property: StringName in SUNSHAFT_PROPERTIES:
        var value: Variant = ProjectSettings.get_setting(SUNSHAFT_SETTINGS_PREFIX + property)
        if not value == SkydomeServer.skydome_get_param(skydome.get_rid(), property):
            _set_skydome_param(property, value)
    # the rain look of the player's Weather settings (gnd_weather/<property>) - WeatherNode reads its
    # project settings only on ready
    for property: StringName in WeatherSettings.PROPERTIES:
        var value: Variant = WeatherSettings.get_value(property, weather.get(property))
        if not value == weather.get(property):
            weather.set(property, value)

    var precipitation: float = environment_node.precipitation
    weather.cloud_density = environment_node.cloudiness
    weather.precipitation_intensity = precipitation
    weather.cloud_overcast_intensity = precipitation
    weather.storm_intensity = clampf(inverse_lerp(STORM_RAIN_START, 1.0, precipitation), 0.0, 1.0)
    var rain_fog: float = clampf(inverse_lerp(RAIN_FOG_START, 1.0, precipitation), 0.0, 1.0)
    var fog_density: float = lerpf(environment_node.fog_density, maxf(environment_node.fog_density, float(
        ProjectSettings.get_setting(RAIN_FOG_DENSITY_SETTING))), rain_fog)
    var fog_distance: float = lerpf(environment_node.fog_distance, minf(environment_node.fog_distance, float(
        ProjectSettings.get_setting(RAIN_FOG_DISTANCE_SETTING))), rain_fog)
    weather.global_wind_direction = Vector2.from_angle(deg_to_rad(environment_node.wind_direction))
    weather.global_wind_speed = environment_node.get_wind_speed()
    weather.global_wind_strength = lerpf(
        WIND_STRENGTH_MIN, WIND_STRENGTH_MAX, environment_node.wind_strength
    )
    weather.global_wind_turbulence = float(
        ProjectSettings.get_setting(WIND_TURBULENCE_SETTING)
    )
    _set_skydome_param(&"rainbow_intensity", (
        RAINBOW_INTENSITY_MAX
        * smoothstep(RAINBOW_RAIN_START, RAINBOW_RAIN_END, precipitation)
        * (1.0 - smoothstep(RAINBOW_CLOUD_FADE_START, RAINBOW_CLOUD_FADE_END, environment_node.cloudiness))
    ))

    # Skydome adds its storm fog boost on top of its own day/night fog density (Skydome.gd:1265)
    # and that sum is the opacity the depth fog reaches at fog_distance. Godot does not clamp it:
    # above 1.0 a fully fogged object comes out as opacity * fog colour - (opacity - 1) * its own
    # colour - brighter than the fogged sky and still carrying its own silhouette. So the day/night
    # density stays Skydome's own haze and the boost carries only the rest of the wanted opacity.
    var density_scale: float = fog_density / FOG_REFERENCE_DENSITY
    var base_density: float = 0.0
    for property: StringName in FOG_DENSITY_PROPERTIES:
        var density: float = _skydome_value(property)
        _set_skydome_param(property, density)
        base_density = maxf(base_density, density)
    var storm_fog_intensity: float = clampf(fog_density - base_density, 0.0, 1.0)
    weather.storm_fog_intensity = storm_fog_intensity
    var range_scale: float = (
        fog_distance / _skydome_value(FOG_REFERENCE_DISTANCE_PROPERTY))
    for property: StringName in FOG_RANGE_PROPERTIES:
        _set_skydome_param(property, _skydome_value(property) * range_scale)
    var sky_affect: float = get_fog_sky_share(fog_distance)
    # The sky takes fog_sky_affect of the fog colour whatever the density is, while geometry at
    # fog_distance takes the density itself - a sky fogged harder than the terrain in front of it
    # cuts every distant silhouette back out of the fog, so the height share carries the opacity.
    sky_affect = lerpf(sky_affect, 1.0, rain_fog) * clampf(fog_density, 0.0, 1.0)
    for property: StringName in FOG_SKY_AFFECT_PROPERTIES:
        _set_skydome_param(property, sky_affect)
    _set_skydome_param(&"fog_sky_affect_intensity", 0.0)
    for property: StringName in FOG_VOLUMETRIC_SKY_AFFECT_PROPERTIES:
        _set_skydome_param(property, 1.0)
    # closer than the reference distance the volumetric fog thickens in proportion; further away
    # it dies out faster (FOG_VOLUMETRIC_FAR_FALLOFF_SETTING). Skydome scales its own boost of that
    # fog by the plain proportion, so the boost gets the rest of the falloff.
    var distance_ratio: float = 1.0 / range_scale
    var volumetric_scale: float = distance_ratio
    if distance_ratio < 1.0:
        volumetric_scale = pow(distance_ratio, float(ProjectSettings.get_setting(FOG_VOLUMETRIC_FAR_FALLOFF_SETTING)))
        # ...but never all the way to nothing, or a scenery declaring a fog of kilometres leaves
        # the lamps with no haze to light (see FOG_VOLUMETRIC_MINIMUM_SETTING)
        volumetric_scale = maxf(volumetric_scale, clampf(float(ProjectSettings.get_setting(FOG_VOLUMETRIC_MINIMUM_SETTING)), 0.0, 1.0))
    # Stretching the volume and thinning the fog by the same factor keeps the optical depth, so the
    # fog reaches out to where the lamps hang without looking any thicker (see the constant).
    var length_scale: float = maxf(0.1, float(ProjectSettings.get_setting(FOG_VOLUMETRIC_LENGTH_SCALE_SETTING)))
    # What the length property ends up multiplied by, Skydome's own shrink included. The optical
    # depth is the density times the length, so the density has to be divided by this whole factor
    # and not by length_scale alone, or undoing the shrink thickens the fog by the shrink again.
    # A scale of exactly 1.0 leaves the volume, and with it the shrink, entirely to Skydome.
    var length_shrink: float = maxf(
        1.0 - SKYDOME_VOL_FOG_LENGTH_SHRINK * storm_fog_intensity, SKYDOME_VOL_FOG_LENGTH_SHRINK_MIN)
    var volume_scale: float = 1.0
    if not is_equal_approx(length_scale, 1.0):
        volume_scale = length_scale / length_shrink
    var fog_ends: Array[float] = [
        fog_distance * float(ProjectSettings.get_setting(FOG_DAY_DISTANCE_FACTOR_SETTING)),
        fog_distance * float(ProjectSettings.get_setting(FOG_NIGHT_DISTANCE_FACTOR_SETTING)),
    ]
    # The volume reaches no further than the depth fog: the volumetric fog is darker than the depth
    # fog's colour, and past the depth fog's end, where everything is that colour, an object in the
    # volume had less of it in front than the sky behind it, which has all of it - drawn brighter
    # than the fog around it (+3 of 255 at 100 m in a 103 m fog with a 192 m volume). Shortened,
    # it is as much thicker, keeping the darkening the sky gets.
    var reach_scales: Array[float] = []
    for period: int in FOG_VOLUMETRIC_LENGTH_PROPERTIES.size():
        var length_property: StringName = FOG_VOLUMETRIC_LENGTH_PROPERTIES[period]
        var length: float = _skydome_value(length_property) * volume_scale
        var reach_scale: float = minf(1.0, fog_ends[period] / maxf(length * length_shrink, 0.001))
        reach_scales.append(reach_scale)
        _set_skydome_param(length_property, length * reach_scale)
        var density_property: StringName = FOG_VOLUMETRIC_DENSITY_PROPERTIES[period]
        _set_skydome_param(density_property, _skydome_value(density_property) * density_scale
            * volumetric_scale / volume_scale / reach_scale)
    # Skydome adds this as a second extinction per metre on top of the day/night density
    # (Skydome.gd:1305), so the stretched volume has to thin it by the same factor as that one,
    # and the shortened one thicken it - by the day's or the night's, whichever it is
    _set_skydome_param(&"vol_fog_density_boost", (
        _skydome_value(&"vol_fog_density_boost")
        * volumetric_scale / distance_ratio / volume_scale
        / lerpf(reach_scales[1], reach_scales[0], get_day_share())))
    _set_skydome_param(&"day_fog_distance", fog_ends[0])
    _set_skydome_param(&"night_fog_distance", fog_ends[1])


## Skydome later overrides shadow opacity from cloud coverage.
## Skydome's day light - its sun - times the sky's sun_energy, its night light - the moon
## (Skydome.gd:1191) - times moon_energy; its day's and night's ambient light and fog colour the sky's,
## which Skydome draws itself (Skydome.gd:1211-1214) - the share the sky gives of the ambient light is
## SkyEnvironment's to set
func apply_light_configuration() -> void:
    _apply_sun_settings(sun_light)
    _set_skydome_param(&"day_light_energy", _skydome_value(&"day_light_energy") * sun_energy)
    _set_skydome_param(&"night_light_energy", _skydome_value(&"night_light_energy") * moon_energy)
    _set_skydome_param(&"day_ambient_color", day_ambient_color)
    _set_skydome_param(&"day_ambient_energy", day_ambient_energy)
    _set_skydome_param(&"night_ambient_color", night_ambient_color)
    _set_skydome_param(&"night_ambient_energy", night_ambient_energy)
    _set_skydome_param(&"day_fog_color", day_fog_color)
    _set_skydome_param(&"night_fog_color", night_fog_color)


func apply_time_configuration() -> void:
    _push_time(true)


## The environment's running time, pushed to Skydome at TIME_UPDATE_INTERVAL
func process_time(delta: float) -> void:
    if Engine.is_editor_hint():
        return
    _time_update_elapsed += delta
    if _time_update_elapsed < TIME_UPDATE_INTERVAL:
        return
    _time_update_elapsed = 0.0
    _push_time(false)


# Configuration changes snap immediately; only running time uses Skydome's transition.
func _push_time(snap: bool) -> void:
    if not skydome:
        return

    var transition_duration: float = SkydomeServer.skydome_get_param(skydome.get_rid(), &"time_transition_duration")
    if snap:
        _set_skydome_param(&"time_transition_duration", 0.0)

    var year_start: int = Time.get_unix_time_from_datetime_dict(
        {"year": environment_node.year, "month": 1, "day": 1}
    )
    var date_time: int = Time.get_unix_time_from_datetime_dict(
        {"year": environment_node.year, "month": environment_node.month, "day": environment_node.day}
    )
    var day_of_year: int = (date_time - year_start) / SECONDS_PER_DAY + 1

    _set_skydome_param(&"latitude", environment_node.latitude)
    _set_skydome_param(&"day_of_year", mini(day_of_year, MAXIMUM_DAY_OF_YEAR))
    # Skydome treats time_of_day as local solar time (Skydome.gd:1052) and has no longitude
    # nor timezone, so the local clock time is converted here.
    _set_skydome_param(&"time_of_day", wrapf(
        environment_node.current_time - environment_node.timezone_offset + environment_node.longitude / 15.0,
        0.0,
        24.0
    ))
    _set_skydome_param(&"time_transition_duration", transition_duration)
