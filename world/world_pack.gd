class_name WorldPack
extends RefCounted

## A world of the game's own format as worlds/<name>.json of the game's directory describes it
## (MaszynaWorld.read_description()): its .pck mounted, its MaszynaWorld made, its sectors' Terrain3D
## regions put into a Terrain3D at their squares' places with the game's terrain atlas, and its
## biomes made on that Terrain3D. The game's SceneryWorldPck and the importer's test scene
## (SISceneryTest, which has this file linked into it) open worlds by it.


## Mounts the world's .pck (MaszynaWorld.mount()); false when it cannot be - the editor mounts none
static func mount(description: Dictionary) -> bool:
    return MaszynaWorld.mount(description)


## The world's MaszynaWorld, not yet in the tree; null when its scene is not there
static func open_world(description: Dictionary) -> MaszynaWorld:
    var scene: PackedScene = load(description["scene"]) as PackedScene if ResourceLoader.exists(description["scene"]) else null
    return scene.instantiate() as MaszynaWorld if scene else null


## Puts the sectors' terrain into [param terrain] with the game's terrain atlas; the locations of
## the regions put in. A sector's terrain lies beside its scene (sectors/<id>.terrain.res); its
## region's location is its square's corner in [param world] - X runs west, so the corner is the
## region's largest X.
static func add_regions(terrain: Terrain3D, world: MaszynaWorld, description: Dictionary) -> Array[Vector2i]:
    var regions: Array[Vector2i] = []
    var terrain_description: Dictionary = description["terrain"]
    terrain.change_region_size(int(terrain_description["region_size"]))
    # the game's terrain atlas: files of the game's directory (the importer's editor reads no .pck)
    terrain.assets = load(UserSettings.get_maszyna_game_dir().path_join(terrain_description["assets"])) as Terrain3DAssets
    var sectors_dir: String = String(description["scene"]).get_base_dir().path_join("sectors")
    for id: String in description["sectors"]:
        var path: String = sectors_dir.path_join(id + terrain_description["sector_suffix"])
        if not ResourceLoader.exists(path):
            continue
        var corner: Vector3 = world.get_sector_corner(MaszynaWorldSector.cell_of(id))
        var location: Vector2i = Vector2i(roundi(corner.x / MaszynaWorld.SECTOR_SIZE) - 1,
                roundi(corner.z / MaszynaWorld.SECTOR_SIZE))
        var region: Terrain3DRegion = load(path) as Terrain3DRegion
        region.set_location(location)
        terrain.data.add_region(region)
        regions.append(location)
    return regions


static func remove_regions(terrain: Terrain3D, regions: Array[Vector2i]) -> void:
    for location: Vector2i in regions:
        terrain.data.remove_regionl(location)


## The world's biomes (Biomes, BiomesGrass) growing on [param terrain] by gnd_biomes'
## BiomesServer, not yet in the tree; null when it has none
static func open_biomes(description: Dictionary, terrain: Terrain3D) -> Node3D:
    if not description.get("biomes", ""):
        return null
    var biomes: Node3D = (load(description["biomes"]) as PackedScene).instantiate() as Node3D
    for layer: Node in biomes.get_children():
        if layer is Biomes:
            (layer as Biomes).terrain = terrain
        elif layer is BiomesGrass:
            (layer as BiomesGrass).terrain = terrain
    return biomes
