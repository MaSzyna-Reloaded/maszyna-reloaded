class_name SceneryWorldPck
extends SceneryWorld

## The world of a scenery of the game's own format, opened by WorldPack (its .pck mounted, its
## regions in this scene's Terrain3D, its biomes on it) and made a child of this node, its signals
## wired here (it is made at run time).

var _world: MaszynaWorld = null
## The world's biomes (Biomes, BiomesGrass), grown by gnd_biomes' BiomesServer on the Terrain3D
var _biomes: Node3D = null
## The Terrain3D regions of the world, by location
var _regions: Array[Vector2i] = []


func _open_scenery(filename: String) -> MaszynaSceneryContentNode:
    var description: Dictionary = MaszynaWorld.read_description(filename)
    WorldPack.mount(description)
    _world = WorldPack.open_world(description)
    _regions = WorldPack.add_regions(%Terrain3D, _world, description)
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
    WorldPack.remove_regions(%Terrain3D, _regions)
    _regions.clear()


func get_scenery() -> MaszynaSceneryContentNode:
    return _world
