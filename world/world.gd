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

## The scenery's node its provider made (SceneryProvider.create_scenery()); null while there is none
var _scenery: SceneryContentNode = null
## The provider of the scenery, which runs its scenario from its load until it unloads
var _provider: SceneryProvider = null
## The vehicle_id the player starts in (load_scenery()); empty: the scenery's first vehicle
var _start_vehicle_id: String = ""


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
