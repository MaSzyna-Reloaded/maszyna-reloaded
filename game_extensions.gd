class_name GameExtensions
extends RefCounted

## What a game built on this one adds to it without this one naming it: the scene a provider's
## sceneries are shown in (a SceneryWorld; world/world.tscn when none is registered) and its own
## windows over the HUD (GameHudExtension). Registered by that game's autoload, before the game's
## scene is made.

static var _world_scenes: Dictionary[StringName, PackedScene] = {}
static var _hud_extensions: Array[PackedScene] = []


## The sceneries of the provider `provider_name` are shown in `scene`, a SceneryWorld
static func world_scene_register(provider_name: StringName, scene: PackedScene) -> void:
    _world_scenes[provider_name] = scene


## The scene the sceneries of the provider `provider_name` are shown in; null for the game's own
static func world_scene_get(provider_name: StringName) -> PackedScene:
    return _world_scenes.get(provider_name)


## `scene`, a GameHudExtension, is made over the HUD as it starts
static func hud_extension_register(scene: PackedScene) -> void:
    _hud_extensions.append(scene)


static func hud_extension_get_all() -> Array[PackedScene]:
    return _hud_extensions
