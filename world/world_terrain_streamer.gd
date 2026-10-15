@tool
class_name WorldTerrainStreamer
extends Node

## The terrain of a world (WorldPack) around the camera: the Terrain3D region of a sector the world
## loads (MaszynaWorld.sectors, sector_loaded) is read from its source's file
## (MaszynaWorld.SectorFile.TERRAIN) off the main thread and put into the Terrain3D, the region of a
## sector it unloads taken out. The Terrain3D's window of regions (Terrain3DData.region_map_origin)
## follows the streaming camera (SceneryStreamingServer), so a world may be of any size. The game's
## world (SceneryWorldPck) and the importer's test scene (SISceneryTest, which has this file linked
## into it) stream by it.
## The regions are read on a thread of the streamer's own, not in a WorkerThreadPool task:
## ResourceLoader.load() in a task returned null for one region of Stary Sącz every time while
## flying over it, the same file read at once on the main thread or a thread of its own
## (2026-10-15, FINDINGS.md). A region whose file cannot be read is reported once and not read
## again while its sector stays loaded.

@export var terrain: Terrain3D

var _world: MaszynaWorld = null
## Region location -> its file, of the loaded sectors with terrain
var _wanted: Dictionary[Vector2i, String] = {}
## The thread reading regions; null while none is
var _reader: Thread = null
## The regions whose file could not be read, not read again while their sectors stay loaded
var _unreadable: Dictionary[Vector2i, bool] = {}


## Streams the terrain of [param world] as [param description] (MaszynaWorld.read_description())
## describes it, with the game's terrain atlas
func open(world: MaszynaWorld, description: Dictionary) -> void:
    var terrain_description: Dictionary = description["terrain"]
    terrain.change_region_size(int(terrain_description["region_size"]))
    # the game's terrain atlas: files of the game's directory (the importer's editor reads no .pck)
    terrain.assets = load(UserSettings.get_maszyna_game_dir().path_join(terrain_description["assets"])) as Terrain3DAssets
    _world = world
    _world.sectors.sector_loaded.connect(_on_sector_loaded)
    _world.sectors.sector_unloaded.connect(_on_sector_unloaded)


## Stops streaming and takes the world's terrain out
func close() -> void:
    _world.sectors.sector_loaded.disconnect(_on_sector_loaded)
    _world.sectors.sector_unloaded.disconnect(_on_sector_unloaded)
    _world = null
    _wanted.clear()
    _unreadable.clear()
    if _reader:
        _reader.wait_to_finish()
        _reader = null
    # a copy: the data's own list shrinks with every region taken out
    for location: Vector2i in terrain.data.get_region_locations().duplicate():
        terrain.data.unload_region(location, false)
    terrain.data.update_maps()


## How many regions are wanted - the loaded sectors' with terrain
func get_wanted_count() -> int:
    return _wanted.size()


## Whether regions are being read
func is_reading() -> bool:
    return _reader != null


func _on_sector_loaded(id: String) -> void:
    var path: String = _world.sector_source.sector_get_path(id, MaszynaWorld.SectorFile.TERRAIN)
    if not ResourceLoader.exists(path):
        return
    _wanted[_region_location(id)] = path
    stream()


func _on_sector_unloaded(id: String) -> void:
    _wanted.erase(_region_location(id))
    _unreadable.erase(_region_location(id))
    stream()


## The Terrain3D brought to the regions wanted: the ones no longer wanted taken out, the window
## moved to the camera when a region to come lies out of it, and the ones to come read. While
## regions are being read, they are put in first and the regions wanted looked at again then
func stream() -> void:
    if _reader:
        return
    var data: Terrain3DData = terrain.data
    var leaving: Array[Vector2i] = []
    for location: Vector2i in data.get_region_locations():
        if not _wanted.has(location):
            leaving.append(location)
    var coming: Array[Vector2i] = []
    for location: Vector2i in _wanted:
        if not data.has_region(location) and not _unreadable.has(location):
            coming.append(location)
    # the window: REGION_MAP_SIZE regions a side, its origin in its middle
    var outside: Callable = func(location: Vector2i, origin: Vector2i) -> bool:
        var offset: Vector2i = location - origin + Vector2i.ONE * (Terrain3DData.REGION_MAP_SIZE / 2)
        return offset.x < 0 or offset.y < 0 or offset.x >= Terrain3DData.REGION_MAP_SIZE \
                or offset.y >= Terrain3DData.REGION_MAP_SIZE
    var origin: Vector2i = data.get_region_map_origin()
    if coming.any(outside.bind(origin)):
        var camera: Vector3 = SceneryStreamingServer.streaming_get_camera_position()
        origin = Vector2i(floori(camera.x / MaszynaWorld.SECTOR_SIZE), floori(camera.z / MaszynaWorld.SECTOR_SIZE))
        for location: Vector2i in data.get_region_locations():
            if outside.call(location, origin) and not location in leaving:
                leaving.append(location)
    for location: Vector2i in leaving:
        data.unload_region(location, false)
    if leaving:
        data.update_maps()
    if not origin == data.get_region_map_origin():
        # every region left in it lies within it: the move cannot fail
        data.set_region_map_origin(origin)
    # a region still out of the window around the camera waits for the camera to come nearer
    var reading: Dictionary[Vector2i, String] = {}
    for location: Vector2i in coming:
        if not outside.call(location, origin):
            reading[location] = _wanted[location]
    if reading:
        _reader = Thread.new()
        _reader.start(_read_regions.bind(reading))


## The region of the sector [param id]: its location is the square's corner - X runs west, so the
## corner is the region's largest X
func _region_location(id: String) -> Vector2i:
    var corner: Vector3 = MaszynaWorld.sector_corner(_world.origin, MaszynaWorldSector.cell_of(id))
    return Vector2i(roundi(corner.x / MaszynaWorld.SECTOR_SIZE) - 1, roundi(corner.z / MaszynaWorld.SECTOR_SIZE))


## Reads the regions [param files] (location -> file) - on the reader thread - and hands them, and
## the locations of the ones it could not read, to the main thread
func _read_regions(files: Dictionary[Vector2i, String]) -> void:
    var regions: Array[Terrain3DRegion] = []
    var unreadable: Array[Vector2i] = []
    for location: Vector2i in files:
        var region: Terrain3DRegion = ResourceLoader.load(files[location], "", ResourceLoader.CACHE_MODE_IGNORE) as Terrain3DRegion
        if not region:
            unreadable.append(location)
            continue
        region.set_location(location)
        regions.append(region)
    _put_regions.call_deferred(regions, unreadable)


## The regions read put into the Terrain3D - the ones still wanted - its maps rebuilt once, the
## ones not read reported; then the regions wanted looked at again. Nothing once the world is
## closed: close() has waited for the reader
func _put_regions(regions: Array[Terrain3DRegion], unreadable: Array[Vector2i]) -> void:
    if not _world:
        return
    _reader.wait_to_finish()
    _reader = null
    for location: Vector2i in unreadable:
        push_error("World terrain: cannot read the region %s (%s)" % [location, _wanted.get(location, "")])
        _unreadable[location] = true
    for region: Terrain3DRegion in regions:
        if _wanted.has(region.location):
            terrain.data.add_region(region, false)
    terrain.data.update_maps()
    stream()
