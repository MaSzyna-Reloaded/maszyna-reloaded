class_name SceneryWorld
extends Node3D

## The 3D world of a scenery - its environment, the player, the scenery itself, its weather sounds
## and its keys. The menu has none of it: the world is made when a scenery is chosen and freed when
## the player goes back to the menu (game.gd), so the menu renders nothing behind it.

## A step of the load (SceneryContentNode.load_progress)
signal load_progress(progress: float, stage: SceneryContentNode.LoadStage, message: String)
## The includes parsed so far (SceneryContentNode.load_files_parsed)
signal load_files_parsed(count: int, filename: String)
## The scenery has loaded, with its first vehicle's vehicle_id (SceneryContentNode.scenery_loaded)
signal scenery_loaded(first_vehicle_id: String)
## The share of the scenario's start done (0..1), between the load and scenery_loaded
## (SceneryProvider.scenario_start())
signal scenario_progress(progress: float)

## A position in the main window no control of the HUD stands under
const OFF_THE_PICTURE: Vector2 = Vector2(-1.0, -1.0)

## The scenery's node its provider made (SceneryProvider.create_scenery()); null while there is none
var _scenery: SceneryContentNode = null
## The monitors in use (UserSettings), so a change of another setting leaves the windows as they are
var _monitors: Array[Dictionary] = []
## The provider of the scenery, which runs its scenario from its load until it unloads
var _provider: SceneryProvider = null
## The vehicle_id the player starts in (load_scenery()); empty: the scenery's first vehicle
var _start_vehicle_id: String = ""


func _ready() -> void:
    %MultiMonitorRig.interior_layers = EnvironmentNode.CABIN_RENDER_LAYER
    %Player.cabin_view.fov_changed.connect(%MultiMonitorRig.rig_update_zoom.unbind(1))
    %Player.free_view.fov_changed.connect(%MultiMonitorRig.rig_update_zoom.unbind(1))
    UserSettings.config_changed.connect(_apply_monitor_settings)
    _apply_monitor_settings()


func _exit_tree() -> void:
    UserSettings.config_changed.disconnect(_apply_monitor_settings)


## Loads the scenery `info` by its provider, the player's trainset as arranged
## (SceneryContentNode.trainset_override), and starts its scenario and the player in `vehicle_id` -
## done once the player stands there with its camera (Player.camera_changed)
func load_scenery(info: SceneryInfo, trainset: Array[VehicleData], vehicle_id: String = "") -> void:
    var scenery: SceneryContentNode = _open_scenery(info)
    scenery.trainset_override.assign(trainset)
    PlayerServer.player_stop()
    _start_vehicle_id = vehicle_id
    scenery.load()
    await %Player.camera_changed


## Frees what the scenery holds, spread over frames - the world itself goes with queue_free(); the
## player stops first, out of the scenery's vehicles
func unload_scenery() -> void:
    PlayerServer.player_stop()
    await _close_scenery()


## The monitors of the player's settings onto the rig, with the main window's render settings -
## the settings screen connected first, so the main window has them already
func _apply_monitor_settings() -> void:
    var monitors: Array[Dictionary] = MonitorSettings.monitors_get()
    if not monitors == _monitors:
        _monitors = monitors
        %MultiMonitorRig.rig_configure(monitors)
    %MultiMonitorRig.rig_copy_viewport_settings(get_viewport())


## The mouse picks through the camera of the monitor it is on, the current one in that window
func _on_multi_monitor_rig_mouse_camera_changed(camera: Camera3D) -> void:
    CabinHUDMouseSystem.mouse_set_camera(camera.get_instance_id())
    SceneryHUDMouseServer.mouse_set_camera(camera.get_instance_id())


## The mouse in a monitor's window beside the main one: it picks there as Player does in the main
## window. What it leaves - the look with the right button, the wheel - is the player's: into the
## main window off its picture, where no control of the HUD stands under it. A motion only while
## the look holds the mouse, as the picking would take a position off the picture for its own
func _on_multi_monitor_rig_mouse_input(event: InputEventMouse) -> void:
    if CabinHUDMouseSystem.mouse_input(event) or SceneryHUDMouseServer.mouse_input(event):
        return
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        return
    if event is InputEventMouseMotion and not Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
        return
    var outside: InputEventMouse = event.duplicate()
    outside.position = OFF_THE_PICTURE
    outside.global_position = OFF_THE_PICTURE
    get_viewport().push_input(outside)


## The node of the scenery `info` its provider makes, in the world under its environment and wired
## to it (made at run time), to be loaded
func _open_scenery(info: SceneryInfo) -> SceneryContentNode:
    _provider = instance_from_id(SceneryServer.provider_get(info.provider)) as SceneryProvider
    _scenery = _provider.create_scenery(info)
    add_child(_scenery)
    _scenery.environment_node_path = _scenery.get_path_to(%EnvironmentNode)
    _scenery.load_files_parsed.connect(_on_scenery_load_files_parsed)
    _scenery.load_progress.connect(_on_scenery_load_progress)
    _scenery.scenery_loaded.connect(_on_scenery_loaded)
    _scenery.unloading.connect(_on_scenery_unloading)
    return _scenery


## What _open_scenery() opened, cleared and freed at once: a scenery node freed stops every load in
## flight (SceneryServer.scenery_cancel()), so freed later it would stop the next scenery's
func _close_scenery() -> void:
    if not _scenery:
        return
    await _scenery.clear()
    _scenery.free()
    _scenery = null
    _provider = null


## The ScenarioScriptServer context the scenery's scripts run in, invalid without a scenario
func get_script_context() -> RID:
    return _provider.scenario_get_script_context(_scenery) if _scenery else RID()


func get_environment() -> EnvironmentNode:
    return %EnvironmentNode


## The scenery node: its file, title and start time; null while there is none
func get_scenery() -> SceneryContentNode:
    return _scenery


func _on_scenery_load_progress(progress: float, stage: SceneryContentNode.LoadStage, message: String) -> void:
    load_progress.emit(progress, stage, message)


func _on_scenery_load_files_parsed(count: int, filename: String) -> void:
    load_files_parsed.emit(count, filename)


## The game has the scenario of a loaded scenery run by its provider; the scenery only loads it
func _on_scenery_loaded(first_vehicle_id: String) -> void:
    # started - a scenery without sounds tells no share of it on the way
    scenario_progress.emit(0.0)
    await _provider.scenario_start(_scenery, scenario_progress.emit)
    var vehicle_id: String = _start_vehicle_id if _start_vehicle_id else first_vehicle_id
    var vehicle: RID = VehicleServer.vehicle_get_rid_by_id(vehicle_id) if vehicle_id else RID()
    if vehicle_id and not vehicle.is_valid():
        push_warning("World: vehicle '%s' is not registered; the player starts outside." % vehicle_id)
    PlayerServer.player_start(vehicle)
    scenery_loaded.emit(first_vehicle_id)


func _on_scenery_unloading() -> void:
    _provider.scenario_stop(_scenery)
