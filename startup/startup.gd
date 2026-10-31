extends Node

## First scene: shows the EU07 spinner while the main scene loads in a background thread and is
## added below. Then the spinner fades out to the background and the background fades out,
## fading the main scene (scenario selector) in.

## Seconds the spinner stays after the main scene has loaded
const EXTRA_DISPLAY_TIME: float = 2.0
const FADE_TIME: float = 0.5

## The main scene and the world of a scenery it shows (MaszynaReloadedGame.world_scene), by their
## paths - loaded here, in the background: the game's, or a game's built on it (its own startup
## scene, this one instanced, with its own world)
@export_file("*.tscn") var main_scene: String = "res://game.tscn"
@export_file("*.tscn") var world_scene: String = "res://world/world.tscn"


func _ready() -> void:
    ResourceLoader.load_threaded_request(main_scene)
    ResourceLoader.load_threaded_request(world_scene)


func _process(_delta: float) -> void:
    var loaded: int = 0
    for path: String in [main_scene, world_scene]:
        match ResourceLoader.load_threaded_get_status(path):
            ResourceLoader.THREAD_LOAD_LOADED:
                loaded += 1
            ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
                set_process(false)
                push_error("Cannot load " + path)
                return
    if loaded == 2:
        set_process(false)
        _show_main_scene(ResourceLoader.load_threaded_get(main_scene), ResourceLoader.load_threaded_get(world_scene))


## The main scene is added right away, with its world: its _ready() and first frames (shader
## compilation) stall the main thread while the spinner is still shown, not between the fades
func _show_main_scene(scene: PackedScene, world: PackedScene) -> void:
    var main: Node = scene.instantiate()
    var game: MaszynaReloadedGame = main as MaszynaReloadedGame
    if game:
        game.world_scene = world
    get_tree().root.add_child(main)
    get_tree().current_scene = main
    await get_tree().create_timer(EXTRA_DISPLAY_TIME).timeout
    await $SpinnerOverlay.fade_out_spinner(FADE_TIME)
    await $SpinnerOverlay.fade_out(FADE_TIME)
    queue_free()
