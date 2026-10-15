class_name SceneryWorldPck
extends SceneryWorld

## The world of a scenery of the game's own format, opened by WorldPack (its .pck mounted, its
## biomes on this scene's Terrain3D) and made a child of this node, its signals wired here (it is
## made at run time); its terrain streamed around the camera (WorldTerrainStreamer).

var _world: MaszynaWorld = null
## The world's biomes (Biomes, BiomesGrass), grown by gnd_biomes' BiomesServer on the Terrain3D
var _biomes: Node3D = null


func _open_scenery(filename: String) -> MaszynaSceneryContentNode:
    var description: Dictionary = MaszynaWorld.read_description(filename)
    WorldPack.mount(description)
    _world = WorldPack.open_world(description)
    %WorldTerrainStreamer.open(_world, description)
    add_child(_world)
    _biomes = WorldPack.open_biomes(description, %Terrain3D)
    if _biomes:
        add_child(_biomes)
    _world.environment_node_path = _world.get_path_to(%MaszynaEnvironmentNode)
    _world.load_files_parsed.connect(_on_scenery_load_files_parsed)
    _world.load_progress.connect(_on_scenery_load_progress)
    _world.scenery_loaded.connect(_on_scenery_loaded)
    _world.scenery_loaded.connect(%ScenarioKeyboard.take_launchers)
    _world.unloading.connect(_on_scenery_unloading)
    return _world


func _close_scenery() -> void:
    if _biomes:
        _biomes.queue_free()
        _biomes = null
    if _world:
        await _world.clear()
        _world.queue_free()
        _world = null
        %WorldTerrainStreamer.close()


func get_scenery() -> MaszynaSceneryContentNode:
    return _world


## What streams the world's terrain, for the HUD's world terrain window
func get_terrain_streamer() -> WorldTerrainStreamer:
    return %WorldTerrainStreamer
