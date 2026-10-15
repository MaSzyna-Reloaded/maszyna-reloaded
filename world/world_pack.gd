class_name WorldPack
extends RefCounted

## A world of the game's own format as worlds/<name>.json of the game's directory describes it
## (MaszynaWorld.read_description()): its .pck mounted, its MaszynaWorld made and its biomes made on
## a Terrain3D, which its terrain is streamed into (WorldTerrainStreamer). The game's SceneryWorldPck
## and the importer's test scene (SISceneryTest, which has this file linked into it) open worlds by it.

## The biomes in the scene of the .json's "biomes" (open_biomes())
const VEGETATION_NODE: NodePath = ^"Vegetation"


## Mounts the world's .pck (MaszynaWorld.mount()); false when it cannot be - the editor mounts none
static func mount(description: Dictionary) -> bool:
    return MaszynaWorld.mount(description)


## The world's MaszynaWorld, not yet in the tree; null when its scene is not there
static func open_world(description: Dictionary) -> MaszynaWorld:
    var scene: PackedScene = load(description["scene"]) as PackedScene if ResourceLoader.exists(description["scene"]) else null
    return scene.instantiate() as MaszynaWorld if scene else null


## The biomes (Biomes, BiomesGrass) of the world [param world] growing on [param terrain] by
## gnd_biomes' BiomesServer, not yet in the tree; null when it has none. They are the .json's
## "biomes" scene's VEGETATION_NODE - the world assets' common biomes, the scene around it being
## what they are tuned on - instanced, over the world's sectors (its area)
static func open_biomes(description: Dictionary, terrain: Terrain3D, world: MaszynaWorld) -> Node3D:
    if not description.get("biomes", ""):
        return null
    var scene: Node = (load(description["biomes"]) as PackedScene).instantiate()
    var biomes: Node3D = scene.get_node(VEGETATION_NODE) as Node3D
    scene.remove_child(biomes)
    scene.free()
    # a sector's square: its corner is its largest X (X runs west)
    var area: Rect2 = Rect2()
    for id: String in world.sector_ids:
        var corner: Vector3 = MaszynaWorld.sector_corner(world.origin, MaszynaWorldSector.cell_of(id))
        var square: Rect2 = Rect2(corner.x - MaszynaWorld.SECTOR_SIZE, corner.z, MaszynaWorld.SECTOR_SIZE, MaszynaWorld.SECTOR_SIZE)
        area = square if area.size == Vector2.ZERO else area.merge(square)
    for layer: Node in biomes.get_children():
        if layer is Biomes:
            var scattered: Biomes = layer as Biomes
            scattered.terrain = terrain
            scattered.position = Vector3(area.get_center().x, 0.0, area.get_center().y)
            scattered.area_size = area.size
            # no thinning out of a large area
            scattered.max_instances = ceili(area.get_area() / (scattered.average_spacing * scattered.average_spacing)) + 1
        elif layer is BiomesGrass:
            (layer as BiomesGrass).terrain = terrain
    return biomes
