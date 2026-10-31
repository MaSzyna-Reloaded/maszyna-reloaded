extends GutTest

## The environment drawn by gnd-skydome and gnd-weather (GndSkydomeMaszynaEnvironment) from the
## state of a EnvironmentNode. Each test applies the environment's configuration and then
## the sky's, as the scene's [connection] of configuration_changed and the next frame do.


func test_maps_cloudiness_and_wind_to_weather() -> void:
    var environment_node: EnvironmentNode = _create_environment_node()
    var sky: GndSkydomeMaszynaEnvironment = _create_sky(environment_node)

    environment_node.cloudiness = 0.8
    environment_node.wind_direction = 90.0
    environment_node._process(0.0)
    sky._process(0.0)

    assert_almost_eq(sky.weather.cloud_density, 0.8, 0.000001)
    assert_almost_eq(_drawn(sky).clouds_wind_direction.x, 0.0, 0.000001)
    assert_almost_eq(_drawn(sky).clouds_wind_direction.y, 1.0, 0.000001)
    assert_eq(sky.weather.skydome_path, NodePath("../../Skydome"))



func test_applies_rendering_light_settings_on_ready() -> void:
    var settings: Dictionary = {
        SkyEnvironment.SHADOW_SCENERY_ENABLED_SETTING: false,
        SkyEnvironment.SHADOW_SCENERY_MODE_SETTING: DirectionalLight3D.SHADOW_ORTHOGONAL,
        SkyEnvironment.SHADOW_SCENERY_BLUR_SETTING: 0.5,
        SkyEnvironment.SHADOW_SCENERY_BIAS_SETTING: 0.2,
        SkyEnvironment.SHADOW_SCENERY_NORMAL_BIAS_SETTING: 1.5,
        SkyEnvironment.SHADOW_SCENERY_MAX_DISTANCE_SETTING: 250.0,
        SkyEnvironment.VOLUMETRIC_FOG_ENERGY_SETTING: 12.5,
    }
    var previous: Dictionary = {}
    for setting: StringName in settings:
        previous[setting] = ProjectSettings.get_setting(setting)
        ProjectSettings.set_setting(setting, settings[setting])

    var environment_node: EnvironmentNode = _create_environment_node()
    var sky: GndSkydomeMaszynaEnvironment = _create_sky(environment_node)
    sky._process(0.0)
    var sun_light: DirectionalLight3D = sky.sun_light

    for setting: StringName in previous:
        ProjectSettings.set_setting(setting, previous[setting])

    assert_false(sun_light.shadow_enabled)
    assert_eq(sun_light.directional_shadow_mode, DirectionalLight3D.SHADOW_ORTHOGONAL)
    assert_almost_eq(sun_light.shadow_blur, 0.5, 0.000001)
    assert_almost_eq(sun_light.shadow_bias, 0.2, 0.000001)
    assert_almost_eq(sun_light.shadow_normal_bias, 1.5, 0.000001)
    assert_almost_eq(sun_light.directional_shadow_max_distance, 250.0, 0.000001)
    assert_almost_eq(sun_light.light_volumetric_fog_energy, 12.5, 0.000001)

func test_maps_rain_intensity_to_storm_overcast_and_rainbow() -> void:
    var environment_node: EnvironmentNode = _create_environment_node()
    var sky: GndSkydomeMaszynaEnvironment = _create_sky(environment_node)

    environment_node.fog_enabled = false
    environment_node.cloudiness = 0.0
    environment_node.precipitation = 0.8
    environment_node._process(0.0)
    sky._process(0.0)

    assert_almost_eq(sky.weather.precipitation_intensity, 0.8, 0.000001)
    assert_almost_eq(sky.weather.cloud_overcast_intensity, 0.8, 0.000001)
    assert_almost_eq(sky.weather.storm_intensity, 2.0 / 3.0, 0.000001)
    assert_almost_eq(sky.weather.storm_fog_intensity, 0.355, 0.000001)
    assert_almost_eq(_drawn(sky).rainbow_intensity, 0.12, 0.000001)


func test_maps_wind_strength_to_weather_global_wind() -> void:
    var environment_node: EnvironmentNode = _create_environment_node()
    var sky: GndSkydomeMaszynaEnvironment = _create_sky(environment_node)
    var weather: WeatherNode = sky.weather

    environment_node.wind_strength = 1.0
    environment_node._process(0.0)
    sky._process(0.0)

    assert_almost_eq(weather.global_wind_speed, 3.0, 0.000001)
    assert_almost_eq(weather.global_wind_strength, 5.0, 0.000001)


func test_applies_weather_project_settings() -> void:
    var environment_node: EnvironmentNode = _create_environment_node()
    var sky: GndSkydomeMaszynaEnvironment = _create_sky(environment_node)
    sky._process(0.0)

    assert_almost_eq(sky.weather.visual_intensity, 1.0, 0.000001)
    assert_almost_eq(
        sky.weather.precipitation_wind_strength, 10.0, 0.000001
    )


func test_maps_fog_controls_to_skydome_and_weather() -> void:
    var environment_node: EnvironmentNode = _create_environment_node()
    var sky: GndSkydomeMaszynaEnvironment = _create_sky(environment_node)
    var skydome: SkydomeSky = _drawn(sky)
    var weather: WeatherNode = sky.weather

    environment_node.fog_density = 0.3
    environment_node.fog_distance = 235.0
    environment_node._process(0.0)
    sky._process(0.0)

    assert_true(sky._environment.fog_enabled)
    # the day/night density is Skydome's own haze, the boost carries the rest of the opacity, and
    # their sum is what the depth fog reaches at fog_distance - over 1.0 it stops being an opacity
    assert_almost_eq(skydome.day_fog_density, 0.005, 0.000001)
    assert_almost_eq(skydome.night_fog_density, 0.02, 0.000001)
    assert_almost_eq(skydome.day_fog_distance, 235.0, 0.000001)
    # Twice the reference opacity at half the reference distance is four times the tuned
    # extinction. The volume is then stretched and the density divided by the same factor, so what
    # has to hold is their product - the optical depth - not either one on its own.
    assert_almost_eq(
        skydome.night_vol_fog_density * skydome.night_vol_fog_length,
        _skydome_look(sky, &"night_vol_fog_density") * 4.0 * _skydome_look(sky, &"night_vol_fog_length"),
        0.000001,
    )
    assert_almost_eq(
        skydome.night_fog_distance,
        235.0 * float(ProjectSettings.get_setting(
            SkyEnvironment.FOG_NIGHT_DISTANCE_FACTOR_SETTING,
            SkyEnvironment.FOG_NIGHT_DISTANCE_FACTOR_DEFAULT)),
        0.000001,
    )
    assert_eq(
        sky._environment.volumetric_fog_enabled,
        bool(UserSettings.get_setting("render", "volumetric_fog_enabled", true))
    )
    assert_almost_eq(weather.storm_fog_intensity, 0.28, 0.000001)
    # the sky is fogged as hard as geometry at fog_distance is, or distant silhouettes stay visible
    assert_almost_eq(skydome.day_fog_sky_affect, 0.3, 0.000001)
    assert_almost_eq(skydome.night_fog_sky_affect, 0.3, 0.000001)
    assert_eq(skydome.fog_mode, SkydomeSky.FogModeOverride.DEPTH)
    assert_eq(sky._environment.fog_mode, Environment.FOG_MODE_DEPTH)


func test_far_fog_leaves_the_sky() -> void:
    var environment_node: EnvironmentNode = _create_environment_node()
    var sky: GndSkydomeMaszynaEnvironment = _create_sky(environment_node)
    var skydome: SkydomeSky = _drawn(sky)

    environment_node.fog_density = 1.0
    environment_node.fog_distance = 5000.0
    environment_node._process(0.0)
    sky._process(0.0)

    # a fog of kilometres hides none of the sky
    assert_almost_eq(skydome.day_fog_sky_affect, 0.0, 0.000001)
    assert_almost_eq(skydome.night_fog_sky_affect, 0.0, 0.000001)


func test_fog_switch_disables_all_fog_layers() -> void:
    var environment_node: EnvironmentNode = _create_environment_node()
    var sky: GndSkydomeMaszynaEnvironment = _create_sky(environment_node)

    environment_node.fog_enabled = false
    environment_node._process(0.0)
    sky._process(0.0)

    assert_false(sky._environment.fog_enabled)
    assert_false(sky._environment.volumetric_fog_enabled)


func test_applies_time_and_location_as_solar_time() -> void:
    var environment_node: EnvironmentNode = _create_environment_node()
    var sky: GndSkydomeMaszynaEnvironment = _create_sky(environment_node)

    environment_node.latitude = 50.271
    environment_node.longitude = 15.0
    environment_node.timezone_offset = 2
    environment_node.current_time = 12.0
    environment_node.set_date(2026, 2, 1)
    environment_node._process(0.0)
    sky._process(0.0)

    assert_almost_eq(_drawn(sky).latitude, 50.271, 0.000001)
    assert_eq(_drawn(sky).day_of_year, 32)
    assert_almost_eq(_drawn(sky).time_of_day, 11.0, 0.000001)
    assert_eq(_drawn(sky).get_environment(), sky._environment)
    assert_eq(_drawn(sky).get_light(), sky.sun_light)


## The look of a Skydome property, as its node keeps it - what the wrapper scales from
func _skydome_look(sky: GndSkydomeMaszynaEnvironment, property: StringName) -> float:
    return float(sky.skydome.get(property))


## The sky as SkydomeServer draws it - the node's look with what the wrapper sets over it
func _drawn(sky: GndSkydomeMaszynaEnvironment) -> SkydomeSky:
    return SkydomeServer.skydome_get_sky(sky.skydome.get_rid())


func _create_environment_node() -> EnvironmentNode:
    return add_child_autofree(EnvironmentNode.new()) as EnvironmentNode


## The sky drawing `environment_node`, wired as a scene wires it
func _create_sky(environment_node: EnvironmentNode) -> GndSkydomeMaszynaEnvironment:
    var sky: GndSkydomeMaszynaEnvironment = GndSkydomeMaszynaEnvironment.new()
    # both children of the test
    sky.environment_node_path = NodePath("../%s" % environment_node.name)
    var skydome: Skydome = Skydome.new()
    skydome.name = "Skydome"
    sky.add_child(skydome)
    sky.skydome = skydome
    add_child_autofree(sky)
    environment_node.configuration_changed.connect(sky.apply_configuration)
    skydome.param_changed.connect(sky.apply_configuration.unbind(1))
    return sky
