extends MaszynaGutTest

## The rain kept out of the vehicle the player sits in: the Skydome sky
## (GndSkydomeMaszynaEnvironment) gives the shown cab a PrecipitationVolume
## (CabinSystem.vehicle_cabin_built)

const FIXTURES_GAME_DIR: String = "res://tests/fixtures"

var _previous_game_dir: String


func before_each() -> void:
    _previous_game_dir = MaszynaGameDirectory.get_game_dir()
    MaszynaGameDirectory.save_game_dir(FIXTURES_GAME_DIR)
    var environment_node: EnvironmentNode = add_child_autofree(EnvironmentNode.new())
    var sky: GndSkydomeMaszynaEnvironment = GndSkydomeMaszynaEnvironment.new()
    # both children of the test
    sky.environment_node_path = NodePath("../%s" % environment_node.name)
    # its sky, as the world's scene gives it (world/world.tscn)
    var skydome: Skydome = Skydome.new()
    skydome.name = "Skydome"
    sky.add_child(skydome)
    sky.skydome = skydome
    add_child_autofree(sky)


func after_each() -> void:
    MaszynaGameDirectory.save_game_dir(_previous_game_dir)


func test_vehicle_keeps_no_rain_volume_of_its_own() -> void:
    var vehicle: MaszynaRailVehicle3D = await spawn_maszyna_vehicle(
            "dynamic/test/synthetic_v1", "synthetic", "", "test_vehicle_rain")
    if not await wait_detailed(vehicle):
        return
    autofree(vehicle)

    assert_eq(_rain_volumes(self).size(), 0)


func test_shown_cab_excludes_rain_over_the_vehicle_body() -> void:
    var vehicle: MaszynaRailVehicle3D = await spawn_maszyna_vehicle(
            "dynamic/test/synthetic_v1", "synthetic", "", "test_vehicle_rain")
    if not await wait_detailed(vehicle):
        return
    autofree(vehicle)

    var cabin: Cabin3D = CabinSystem.cabin_show(RailVehicleServer.vehicle_get_front_cabin(vehicle.get_rid()), self)
    var volumes: Array[PrecipitationVolume] = _rain_volumes(cabin)
    var controller: VehicleController = vehicle.get_controller()
    CabinSystem.vehicle_hide_cabin(vehicle.get_rid())

    assert_eq(volumes.size(), 1)
    assert_eq(
        volumes[0].size,
        Vector3(controller.dimensions_width, controller.dimensions_height, controller.dimensions_length)
    )
    assert_almost_eq(volumes[0].position.y, controller.dimensions_height * 0.5, 0.000001)
    assert_almost_eq(volumes[0].precipitation_delta, -1.0, 0.000001)
    assert_true(volumes[0].enclosed)


## The cab's box its models' bounds in its frame, not the vehicle's whole body: sized to the body it
## hid the snow about the vehicle and over its bonnet
func test_the_cabs_box_its_models_bounds() -> void:
    var sky: GndSkydomeMaszynaEnvironment = autofree(GndSkydomeMaszynaEnvironment.new())
    var mount: Node3D = add_child_autofree(Node3D.new())
    mount.rotation.y = 0.7
    mount.position = Vector3(100.0, 2.0, -40.0)
    var cabin: Node3D = Node3D.new()
    mount.add_child(cabin)
    var shell: MeshInstance3D = MeshInstance3D.new()
    var box: BoxMesh = BoxMesh.new()
    box.size = Vector3(2.8, 2.2, 2.5)
    shell.mesh = box
    shell.position = Vector3(0.0, 2.6, 4.0)
    # internal, as a generated interior is
    cabin.add_child(shell, false, Node.INTERNAL_MODE_BACK)
    var volume: PrecipitationVolume = PrecipitationVolume.new()
    cabin.add_child(volume)

    sky._fit_rain_exclusion(volume, RID())

    assert_true(volume.size.is_equal_approx(Vector3(2.8, 2.2, 2.5)), str(volume.size))
    assert_true(volume.position.is_equal_approx(Vector3(0.0, 2.6, 4.0)), str(volume.position))


## Internal children too: the vehicle's parts and the cab's generated interior are internal
func _rain_volumes(node: Node) -> Array[PrecipitationVolume]:
    var found: Array[PrecipitationVolume] = []
    for child: Node in node.get_children(true):
        if child is PrecipitationVolume:
            found.append(child)
        found.append_array(_rain_volumes(child))
    return found


func test_rain_volumes_beyond_active_distance_are_ignored() -> void:
    var near_volume: PrecipitationVolume = add_child_autofree(PrecipitationVolume.new())
    var far_volume: PrecipitationVolume = add_child_autofree(PrecipitationVolume.new())
    var world_3d: World3D = near_volume.get_world_3d()
    far_volume.position = Vector3(0.0, 0.0, 100.0)

    WeatherServer.set_weather_observer_sample(world_3d, Vector3.ZERO)
    WeatherServer.set_precipitation_volume_active_distance(world_3d, 10.0)
    var active_volumes: Array = WeatherServer._get_active_precipitation_volumes(world_3d)
    WeatherServer.clear_weather_state(world_3d)

    assert_true(active_volumes.has(near_volume))
    assert_false(active_volumes.has(far_volume))
