extends Control

## Vehicle of a trainset: its exterior rotating in a SubViewport, its name and its liveries, all of
## them the catalogue's (VehicleCatalogServer) - any provider's vehicle. Shown in place of the
## scenery list.

## Emitted whichever way the viewer goes away. No "was it the back button" in it: the back button
## is a gesture of this scene and plays its own sound here.
signal closed
## The skin picked in the viewer was accepted
signal skin_applied(skin: String)
## "Change vehicle" - its owner lets the player choose another vehicle for its place
signal change_requested
## The trash - its owner takes the vehicle out of the trainset
signal remove_requested
## Turned round - its owner stands the vehicle the other way
signal reverse_requested

const ROTATION_SPEED: float = 0.35

## Same bank the scenery selector uses - the viewer is its own scene and plays its own gestures.
const UI_SOUNDS: SfxBank = preload("res://startup/ui_sounds.tres")
const FADE_TIME: float = 0.5
## Distance of the camera from the model, in model lengths
const CAMERA_DISTANCE: float = 1.15

var _vehicle: VehicleData = null
## The vehicle's exterior, its provider's (VehicleCatalogServer.vehicle_create_preview())
var _model: Node3D = null
## Livery of the model, the one the trainset gives the vehicle until another is picked
var _skin: String = ""
## Liveries of the vehicle, by name, in the order the grid shows them
var _skins: Array[String] = []
## Fading in or out; killed when the other fade starts, so they never fight over modulate
var _fade_tween: Tween = null
var _ui_sounds: SfxPlayer


func _ready() -> void:
    _ui_sounds = SfxPlayer.new()
    _ui_sounds.bank = UI_SOUNDS
    add_child(_ui_sounds)


func _process(delta: float) -> void:
    if _model:
        %ModelRoot.rotate_y(delta * ROTATION_SPEED)


## The vehicle on the turntable, with its liveries
func show_vehicle(vehicle: VehicleData) -> void:
    _vehicle = vehicle
    %Name.text = vehicle.vehicle.get_file()
    %Subtitle.text = "%s - %s" % [vehicle.name if vehicle.name else vehicle.vehicle_id, vehicle.vehicle]
    %ModelRoot.rotation = Vector3.ZERO
    _build_model(vehicle.livery)
    _build_skin_grid()
    # a viewer that is still fading out carries on from the alpha it reached, and does not blink
    if not visible:
        modulate.a = 0.0
    visible = true
    if _fade_tween:
        _fade_tween.kill()
    _fade_tween = create_tween()
    _fade_tween.tween_property(self, "modulate:a", 1.0, FADE_TIME)


## Keeps the turntable where it is - picking a skin only swaps the model
func _build_model(skin: String) -> void:
    _skin = skin
    if _model:
        _model.queue_free()

    _model = VehicleCatalogServer.vehicle_create_preview(_in_livery(skin))
    if not _model:
        return
    %ModelRoot.add_child(_model)
    _frame_model()


## Puts the model in the middle of the turntable and pulls the camera back to fit it
func _frame_model() -> void:
    var bounds: AABB = _get_model_bounds()
    _model.position = -bounds.get_center()
    var radius: float = maxf(bounds.size.length() * 0.5, 1.0)
    %Camera.position = Vector3(0.0, radius * 0.35, radius * CAMERA_DISTANCE * 2.0)
    %Camera.look_at(Vector3.ZERO)


## The box of the models of the preview, in the preview's own space
func _get_model_bounds() -> AABB:
    var bounds: AABB = AABB()
    var to_model: Transform3D = _model.global_transform.affine_inverse()
    var visuals: Array[Node] = _model.find_children("*", "VisualInstance3D", true, false)
    if _model is VisualInstance3D:
        visuals.push_front(_model)
    for visual: VisualInstance3D in visuals:
        var box: AABB = (to_model * visual.global_transform) * visual.get_aabb()
        bounds = box if visual == visuals[0] else bounds.merge(box)
    return bounds


## Liveries of the vehicle (VehicleCatalogServer.livery_list()), each as a tile of the grid
func _build_skin_grid() -> void:
    _skins.clear()
    # the trainset can give the vehicle a livery that is not listed - it is still a livery, and it
    # goes first, so it is the one the grid selects
    if _skin:
        _skins.append(_skin)
    var info: VehicleInfo = VehicleInfo.new()
    info.vehicle_provider = _vehicle.vehicle_provider
    info.vehicle = _vehicle.vehicle
    var titles: Dictionary[String, String] = {}
    for livery: VehicleLivery in VehicleCatalogServer.livery_list(info):
        titles[livery.name] = livery.title if livery.title else livery.name
        if not livery.name.to_lower() == _skin.to_lower():
            _skins.append(livery.name)
    var tiles: Array[TileGrid.Tile] = []
    for skin: String in _skins:
        var title: String = titles.get(skin, skin)
        tiles.append(TileGrid.Tile.new(_in_livery(skin), title, title))
    %SkinsGrid.set_tiles(tiles)


## A copy of the vehicle in [param livery] - the trainset's own stays as it is until one is applied
func _in_livery(livery: String) -> VehicleData:
    var vehicle: VehicleData = _vehicle.duplicate() as VehicleData
    vehicle.livery = livery
    return vehicle


## The grid moved onto another skin, so the model wears it from now on. Nothing to do when it is
## the skin the model was built with - that is the grid selecting its first tile after a rebuild.
func _on_skins_grid_item_selected() -> void:
    var index: int = %SkinsGrid.get_selected()
    if index < 0 or _skins[index] == _skin:
        return
    _build_model(_skins[index])


## The skins are a section of the screen's focus cycle, and the screen drives it through this node
func get_skins_section() -> FocusSection:
    return %SkinsGrid


## "Change vehicle" and the trash, a section of the screen's focus cycle as the skins are
func get_vehicle_actions_section() -> FocusSection:
    return %VehicleActions


## Whether the trash can take the vehicle away - not the one with a driver, nor the last one; the
## owner knows the trainset
func set_removable(removable: bool) -> void:
    %RemoveButton.disabled = not removable


func _on_back_button_pressed() -> void:
    _ui_sounds.play(&"back_button")
    close()


## Accepts the skin the grid has selected and leaves - the button and Enter on a tile are both
## wired straight to this, in the scene.
func apply_selected_skin() -> void:
    var index: int = %SkinsGrid.get_selected()
    if index >= 0:
        skin_applied.emit(_skins[index])
    close()


## Fades the viewer out; the scenery list fades in under it at the same time. A viewer that is
## already gone closes no second time - a repeated "closed" restarted the list's fade from zero.
func close() -> void:
    if not visible:
        return
    closed.emit()
    if _fade_tween:
        _fade_tween.kill()
    _fade_tween = create_tween()
    _fade_tween.tween_property(self, "modulate:a", 0.0, FADE_TIME)
    # a callback and not "await finished": killing a tween never finishes it, so a fade in started
    # meanwhile would leave the await hanging and the model alive
    _fade_tween.tween_callback(_close_finished)


func _close_finished() -> void:
    visible = false
    if _model:
        _model.queue_free()
        _model = null
