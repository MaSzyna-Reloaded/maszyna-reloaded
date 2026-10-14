class_name SceneryWorld
extends Node3D

## The 3D world of a scenery - its environment, the player, the scenery itself, its weather sounds
## and its keys. The menu has none of it: the world is made when a scenery is chosen and freed when
## the player goes back to the menu (game.gd), so the menu renders nothing behind it.

## A step of the load (MaszynaSceneryContentNode.load_progress)
signal load_progress(progress: float, stage: MaszynaSceneryContentNode.LoadStage, message: String)
## The includes parsed so far (MaszynaSceneryContentNode.load_files_parsed)
signal load_files_parsed(count: int, filename: String)
## The scenery has loaded, with its first vehicle's vehicle_id (MaszynaSceneryContentNode.scenery_loaded)
signal scenery_loaded(first_vehicle_id: String)
## The share of the scenario's start done (0..1), between the load and scenery_loaded
## (MaszynaLegacyScenario.start())
signal scenario_progress(progress: float)

## The scenery's scenario, running from its load until it unloads
var _scenario: MaszynaLegacyScenario = null


## Loads scenery/<filename>, the player's trainset as arranged (MaszynaSceneryContentNode.trainset_override),
## and starts its scenario - done once `scenery_loaded` has been emitted
func load_scenery(filename: String, trainset: Array[MaszynaDynamicData], vehicle_id: String = "") -> void:
    var scenery: MaszynaSceneryContentNode = _open_scenery(filename)
    scenery.trainset_override.assign(trainset)
    %Player.clear_start_train()
    %Player.start_vehicle_id = vehicle_id
    scenery.load()
    await %Player.initialization_ready


## Frees what the scenery holds, spread over frames - the world itself goes with queue_free()
func unload_scenery() -> void:
    %Player.clear_start_train()
    await _close_scenery()


## The scenery node set to `filename`, to be loaded: the .scn's (the world of a .pck: SceneryWorldPck)
func _open_scenery(filename: String) -> MaszynaSceneryContentNode:
    %MaszynaLegacySceneryNode.filename = filename
    return %MaszynaLegacySceneryNode


## What _open_scenery() opened, freed
func _close_scenery() -> void:
    %MaszynaLegacySceneryNode.filename = ""
    await %MaszynaLegacySceneryNode.load()


## The ScenarioScriptServer context the scenery's scripts run in, invalid without a scenario
func get_script_context() -> RID:
    return _scenario.get_script_context() if _scenario else RID()


func get_environment() -> MaszynaEnvironmentNode:
    return %MaszynaEnvironmentNode


## The scenery node: its file, title and start time
func get_scenery() -> MaszynaSceneryContentNode:
    return %MaszynaLegacySceneryNode


func _on_scenery_load_progress(progress: float, stage: MaszynaSceneryContentNode.LoadStage, message: String) -> void:
    load_progress.emit(progress, stage, message)


func _on_scenery_load_files_parsed(count: int, filename: String) -> void:
    load_files_parsed.emit(count, filename)


## The game runs the scenario of a loaded scenery; the scenery only loads it
func _on_scenery_loaded(first_vehicle_id: String) -> void:
    _scenario = MaszynaLegacyScenario.new()
    # started - a scenery without sounds tells no share of it on the way
    scenario_progress.emit(0.0)
    await _scenario.start(get_scenery(), scenario_progress.emit)
    if not %Player.start_vehicle_id:
        %Player.start_vehicle_id = first_vehicle_id
    scenery_loaded.emit(first_vehicle_id)


func _on_scenery_unloading() -> void:
    if _scenario:
        _scenario.stop()
        _scenario = null
