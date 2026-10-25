extends MaszynaGutTest

const PLAYER_SCENE:PackedScene = preload("res://addons/libreloaded/player/player.tscn")
const WORLD_SCENE:PackedScene = preload("res://world/world.tscn")
const STREAMER_SCRIPT:Script = preload("res://addons/libreloaded/scenery/scenery_streamer.gd")
const TRACK_NAME:String = "initialization_track"
const TRACK_LENGTH:float = 200.0
const VEHICLE_OFFSET:float = 100.0
const PLAYER_POSITION:Vector3 = Vector3(30.0, 3.0, 615.0)

var _player:Player
var _streamer:Node
var _world:SceneryWorld
var _vehicle:RailVehicle3D
var _track:RID
var _previous_game_dir:String


func before_each() -> void:
    _previous_game_dir = MaszynaGameDirectory.get_game_dir()
    UserSettings.set_setting("maszyna", "game_dir", "res://tests/fixtures")
    _streamer = STREAMER_SCRIPT.new()
    add_child(_streamer)


func after_each() -> void:
    PlayerServer.player_stop()
    if is_instance_valid(_world):
        await _world.unload_scenery()
        _world.free()
    if is_instance_valid(_player):
        _player.free()
    _streamer.free()
    if is_instance_valid(_vehicle):
        free_rail_vehicle(_vehicle)
    if _track.is_valid():
        TrackServer.track_free(_track)
        TrackServer.topology_rebuild()
    UserSettings.set_setting("maszyna", "game_dir", _previous_game_dir)


func test_streaming_does_not_start_before_scenery_loaded() -> void:
    _player = PLAYER_SCENE.instantiate()
    _player.camera_changed.connect(_streamer.set_camera)
    watch_signals(_player)
    add_child(_player)
    assert_false(SceneryStreamingServer.streaming_has_camera())
    assert_null(_player.camera, "no camera of the player's before it has started")
    assert_signal_emit_count(_player, "camera_changed", 0)
    PlayerServer.player_start(RID())
    assert_true(SceneryStreamingServer.streaming_has_camera())
    assert_eq(get_viewport().get_camera_3d(), _player.camera, "the player's one camera, current once it has started")
    assert_eq(_player.camera.get_parent(), _player.free_view, "started outside, it looks through the free view")
    assert_signal_emit_count(_player, "camera_changed", 1)


func test_streamer_uses_its_assigned_camera_not_the_viewport_camera() -> void:
    var viewport_camera:Camera3D = add_child_autofree(Camera3D.new())
    var first:Camera3D = add_child_autofree(Camera3D.new())
    var second:Camera3D = add_child_autofree(Camera3D.new())
    first.position = PLAYER_POSITION
    second.position = Vector3(VEHICLE_OFFSET, 0.0, 0.0)
    viewport_camera.make_current()
    _streamer.camera = first
    _streamer.active = true
    assert_eq(SceneryStreamingServer.streaming_get_camera_position(), first.global_position)
    _streamer.active = false
    _streamer.camera = second
    assert_false(SceneryStreamingServer.streaming_has_camera())
    _streamer.active = true
    assert_eq(SceneryStreamingServer.streaming_get_camera_position(), second.global_position)
    _streamer.camera = first
    assert_eq(SceneryStreamingServer.streaming_get_camera_position(), first.global_position)


func test_exported_streamer_configuration_is_applied_on_ready() -> void:
    var camera:Camera3D = add_child_autofree(Camera3D.new())
    camera.position = PLAYER_POSITION
    var streamer:Node = STREAMER_SCRIPT.new()
    streamer.camera = camera
    streamer.active = true
    assert_false(SceneryStreamingServer.streaming_has_camera(), "configuration does not stream before entering the tree")
    add_child(streamer)
    assert_eq(SceneryStreamingServer.streaming_get_camera_position(), camera.global_position)
    streamer.free()
    assert_false(SceneryStreamingServer.streaming_has_camera())


func test_inactive_streamer_clears_an_existing_streaming_camera_on_ready() -> void:
    var camera:Camera3D = add_child_autofree(Camera3D.new())
    SceneryStreamingServer.streaming_set_camera(camera.get_instance_id())
    assert_true(SceneryStreamingServer.streaming_has_camera())
    var streamer:Node = STREAMER_SCRIPT.new()
    add_child(streamer)
    assert_false(streamer.active)
    assert_false(SceneryStreamingServer.streaming_has_camera())
    streamer.free()


func test_editor_camera_preserves_configuration_and_respects_active() -> void:
    var configured_camera:Camera3D = add_child_autofree(Camera3D.new())
    var editor_camera:Camera3D = add_child_autofree(Camera3D.new())
    configured_camera.position = PLAYER_POSITION
    editor_camera.position = Vector3(VEHICLE_OFFSET, 0.0, 0.0)
    _streamer.camera = configured_camera
    _streamer.editor_camera = editor_camera
    assert_false(SceneryStreamingServer.streaming_has_camera())
    _streamer.active = true
    assert_eq(SceneryStreamingServer.streaming_get_camera_position(), editor_camera.global_position)
    assert_eq(_streamer.camera, configured_camera, "the scene's camera is not replaced")
    assert_true(_streamer.use_editor_camera, "the editor's view is used by default")
    _streamer.use_editor_camera = false
    assert_eq(SceneryStreamingServer.streaming_get_camera_position(), configured_camera.global_position)
    _streamer.use_editor_camera = true
    assert_eq(SceneryStreamingServer.streaming_get_camera_position(), editor_camera.global_position)
    _streamer.active = false
    assert_false(SceneryStreamingServer.streaming_has_camera())
    _streamer.editor_camera = null
    assert_false(SceneryStreamingServer.streaming_has_camera())
    _streamer.active = true
    assert_eq(SceneryStreamingServer.streaming_get_camera_position(), configured_camera.global_position)


func test_first_streaming_camera_is_already_in_the_selected_cabin() -> void:
    _track = build_track(TRACK_NAME, TRACK_LENGTH)
    _vehicle = build_rail_vehicle("InitializationVehicle", TRACK_NAME, VEHICLE_OFFSET)
    assert_true(await wait_until(func() -> bool: return _vehicle.get_rid().is_valid(), LOAD_TIMEOUT))
    var cabin:Cabin3D = Cabin3D.new()
    var packed:PackedScene = PackedScene.new()
    packed.pack(cabin)
    cabin.free()
    CabinSystem.vehicle_set_cabin_scene(_vehicle.get_rid(), packed)
    _player = PLAYER_SCENE.instantiate()
    _player.camera_changed.connect(_streamer.set_camera)
    _player.position = PLAYER_POSITION
    add_child(_player)
    var positions:Array[Vector3] = []
    var driven:Array[RID] = []
    var observe:Callable = func() -> void:
        positions.append(SceneryStreamingServer.streaming_get_camera_position())
        driven.append(PlayerServer.player_get_vehicle())
    SceneryStreamingServer.streaming_camera_changed.connect(observe)
    PlayerServer.player_start(_vehicle.get_rid())
    SceneryStreamingServer.streaming_camera_changed.disconnect(observe)
    assert_eq(positions.size(), 1, "no streaming from an intermediate camera")
    assert_eq(driven[0], _vehicle.get_rid(), "seated before streaming starts")
    var shown:Cabin3D = CabinSystem.vehicle_get_cabin(_vehicle.get_rid())
    assert_eq(positions[0], shown.get_camera_transform().origin)
    PlayerCameraServer.camera_toggle_cabin()
    assert_eq(SceneryStreamingServer.streaming_get_camera_position(), _player.free_view.global_position)
    assert_eq(PlayerServer.player_get_vehicle(), _vehicle.get_rid(), "view changes do not leave the vehicle")
    PlayerServer.player_stop()
    assert_false(SceneryStreamingServer.streaming_has_camera())


func test_world_initializes_on_each_scenery_load_and_detaches_on_unload() -> void:
    _world = WORLD_SCENE.instantiate()
    add_child(_world)
    _player = _world.get_node("Player") as Player
    watch_signals(PlayerServer)
    assert_false(SceneryStreamingServer.streaming_has_camera())
    var trainset:Array[VehicleData] = []
    var ep07:SceneryInfo = SceneryInfo.new()
    ep07.provider = MaszynaSceneryProvider.NAME
    ep07.id = "ep07.scn"
    _world.load_scenery(ep07, trainset)
    assert_true(await wait_until(func() -> bool:
        return PlayerServer.player_get_vehicle() == VehicleServer.vehicle_get_rid_by_id("ep07-424") \
                and _player.camera, LOAD_TIMEOUT), "the player stands in the scenery's first vehicle")
    assert_signal_emit_count(PlayerServer, "player_started", 1)
    assert_true(SceneryStreamingServer.streaming_has_camera())
    await _world.unload_scenery()
    assert_false(SceneryStreamingServer.streaming_has_camera())
    assert_false(PlayerServer.player_get_vehicle().is_valid())
    _world.load_scenery(ep07, trainset, "NoSuchVehicle")
    assert_true(await wait_until(func() -> bool:
        return get_signal_emit_count(PlayerServer, "player_started") == 2, LOAD_TIMEOUT))
    assert_false(PlayerServer.player_get_vehicle().is_valid())
    assert_eq(SceneryStreamingServer.streaming_get_camera_position(), _player.free_view.global_position)


func test_scenery_vehicle_without_a_cabin_scene_waits_for_its_cabin() -> void:
    _track = build_track(TRACK_NAME, TRACK_LENGTH)
    _vehicle = build_rail_vehicle("NoCabinInitializationVehicle", TRACK_NAME, VEHICLE_OFFSET)
    assert_true(await wait_until(func() -> bool: return _vehicle.get_rid().is_valid(), LOAD_TIMEOUT))
    _player = PLAYER_SCENE.instantiate()
    _player.camera_changed.connect(_streamer.set_camera)
    _player.position = PLAYER_POSITION
    watch_signals(_player)
    add_child(_player)
    PlayerServer.player_start(_vehicle.get_rid())
    assert_false(PlayerServer.player_get_vehicle().is_valid())
    assert_signal_emit_count(_player, "camera_changed", 0)
    assert_false(SceneryStreamingServer.streaming_has_camera())
