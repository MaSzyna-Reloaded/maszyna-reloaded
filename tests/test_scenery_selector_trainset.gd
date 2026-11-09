extends GutTest

## The trainset arranged in the scenery selector (scenery_selector_screen.gd): "+" adds a vehicle at
## the end, coupled to the one before; each vehicle's coupling with the next is chosen under its
## tile; the trainset is loaded with the couplings the player chose
## (scenery_selected). The sceneries come from a provider of the test's own, the only one registered
## while it runs - no game directory is read, no setting is written.

const SCREEN: PackedScene = preload("res://scenery_selector/scenery_selector_screen.tscn")
const PROVIDER_NAME: StringName = &"selector_test"
const SCENERY_ID: String = "selector_test.scn"
const LOCO_ID: String = "loco"
const WAGON_ID: String = "wagon"
const ADDED_VEHICLE: String = "dynamic/test/added"
## couplingdata 3 of a scenery: the coupler and the brake hose
const DECLARED:RailVehicleController.CouplingMode = RailVehicleController.COUPLING_MODE_BRAKE
## couplingdata 0 of the declared last wagon
const UNCOUPLED:RailVehicleController.CouplingMode = RailVehicleController.COUPLING_MODE_NONE
const FULL:RailVehicleController.CouplingMode = RailVehicleController.COUPLING_MODE_FULL


## A scenery of one trainset: a loco with its driver, coupled to a wagon by DECLARED, the wagon to
## nothing
class TestProvider extends SceneryProvider:
    func list() -> Array[SceneryInfo]:
        var info: SceneryInfo = SceneryInfo.new()
        info.provider = PROVIDER_NAME
        info.id = SCENERY_ID
        info.title = "Selector test"
        var sceneries: Array[SceneryInfo] = [info]
        return sceneries

    func describe(info: SceneryInfo) -> SceneryInfo:
        var trainset: TrainsetData = TrainsetData.new()
        trainset.members.append(_member(LOCO_ID, VehicleData.DRIVER_HEAD, 0, DECLARED))
        trainset.members.append(_member(WAGON_ID, VehicleData.DRIVER_NOBODY, 1, UNCOUPLED))
        info.trainsets.assign([trainset])
        return info

    static func _member(vehicle_id: String, driver: VehicleData.DriverType, place: int,
            coupling_mode: RailVehicleController.CouplingMode) -> TrainsetMemberData:
        var vehicle: VehicleData = VehicleData.new()
        vehicle.vehicle_id = vehicle_id
        vehicle.vehicle = "dynamic/test/%s" % vehicle_id
        vehicle.driver_type = driver
        var member: TrainsetMemberData = TrainsetMemberData.new()
        member.vehicle = vehicle
        member.trainset_index = place
        member.coupling_mode = coupling_mode
        return member


var _provider: TestProvider = null
## The providers registered before the test, by name - back after it
var _registered: Dictionary[StringName, int] = {}
var _screen: Control = null


func before_each() -> void:
    for provider_name: String in SceneryServer.provider_get_list():
        _registered[StringName(provider_name)] = SceneryServer.provider_get(provider_name)
        SceneryServer.provider_unregister(provider_name)
    _provider = TestProvider.new()
    _provider.title = "Test"
    add_child_autofree(_provider)
    SceneryServer.provider_register(PROVIDER_NAME, _provider.get_instance_id())
    _screen = SCREEN.instantiate()
    add_child_autofree(_screen)
    # the list selects its scenery and the scenery its trainset, which the grid then shows
    _screen.list_sceneries()


func after_each() -> void:
    SceneryServer.provider_unregister(PROVIDER_NAME)
    for provider_name: StringName in _registered:
        SceneryServer.provider_register(provider_name, _registered[provider_name])
    _registered.clear()


## The trainset the selector loads, as scenery_selected hands it on
func _loaded_trainset() -> Array:
    watch_signals(_screen)
    _screen.load_selected_scenery()
    assert_signal_emitted(_screen, "scenery_selected", "the scenery is loaded")
    var parameters: Array = get_signal_parameters(_screen, "scenery_selected")
    return parameters[2] if parameters else []


func _modes(members: Array) -> Array:
    return members.map(func(member: TrainsetMemberData) -> int: return member.coupling_mode)


func _vehicles(members: Array) -> Array:
    return members.map(func(member: TrainsetMemberData) -> String: return member.vehicle.vehicle)


## The joints between the tiles, front first
func _joints() -> Array:
    return _screen.get_node("%TrainsetGrid").find_children("Joint", "TextureButton", true, false)


## What the joints say on hover, front first
func _joint_tooltips() -> Array:
    return _joints().map(func(joint: TextureButton) -> String: return joint.tooltip_text)


func _mode_name(mode: RailVehicleController.CouplingMode) -> String:
    return tr(_screen.COUPLING_MODE_NAMES[mode])


func _added_vehicle() -> VehicleData:
    var vehicle: VehicleData = VehicleData.new()
    vehicle.vehicle = ADDED_VEHICLE
    return vehicle


func test_the_trainset_is_loaded_with_its_declared_couplings() -> void:
    assert_eq(_modes(_loaded_trainset()), [DECLARED, UNCOUPLED])


func test_a_vehicle_added_goes_at_the_end_coupled_to_the_last_one() -> void:
    _screen.add_vehicle(_added_vehicle())

    var members: Array = _loaded_trainset()
    assert_eq(_vehicles(members), ["dynamic/test/%s" % LOCO_ID, "dynamic/test/%s" % WAGON_ID, ADDED_VEHICLE],
            "at the end of the trainset")
    assert_eq(_modes(members), [DECLARED, FULL, FULL], "the last wagon couples to it fully")


func test_each_joint_draws_its_coupling_and_names_it_on_hover() -> void:
    var joints: Array = _joints()
    assert_eq(joints.size(), 1, "the loco's - the wagon has no next")
    assert_eq((joints[0] as TextureButton).texture_normal, _screen.COUPLING_MODE_ICONS[DECLARED], "drawn")
    assert_eq(_joint_tooltips(), [_mode_name(DECLARED)], "named")


func test_pressing_a_joint_changes_its_coupling_in_place() -> void:
    var grid: Node = _screen.get_node("%TrainsetGrid")
    var joint: TextureButton = _joints()[0]
    grid.joint_pressed.emit(0)

    assert_true(is_instance_valid(joint) and not joint.is_queued_for_deletion(), "the row stays as it is")
    assert_eq(joint.texture_normal, _screen.COUPLING_MODE_ICONS[FULL], "drawn anew")
    assert_eq(joint.tooltip_text, _mode_name(FULL), "named anew")
    assert_eq(_modes(_loaded_trainset()), [FULL, UNCOUPLED], "and loaded so")


func test_pressing_a_joint_goes_round_to_uncoupled() -> void:
    var grid: Node = _screen.get_node("%TrainsetGrid")
    var modes: Array = _screen.COUPLING_MODE_NAMES.keys()
    var presses: int = posmod(modes.find(UNCOUPLED) - modes.find(DECLARED), modes.size())
    for press: int in presses:
        grid.joint_pressed.emit(0)
    assert_eq(_joint_tooltips(), [_mode_name(UNCOUPLED)])
    assert_eq(_modes(_loaded_trainset()), [UNCOUPLED, UNCOUPLED], "uncoupled")


func test_the_viewers_button_goes_round_all_the_modes_and_the_joint_shows_it() -> void:
    _screen.change_coupling(0)
    assert_eq(_joint_tooltips(), [_mode_name(FULL)], "the next mode, at the joint")
    var modes: Array = _screen.COUPLING_MODE_NAMES.keys()
    for step: int in modes.size() - 1:
        _screen.change_coupling(0)
    assert_eq(_modes(_loaded_trainset()), [DECLARED, UNCOUPLED], "back where it started")


func test_the_last_vehicle_has_no_coupling_to_change() -> void:
    _screen.change_coupling(1)

    assert_eq(_modes(_loaded_trainset()), [DECLARED, UNCOUPLED])


## The joint stands on the meeting of two tiles, half over each, in the row's view; the tiles still
## meet buffer to buffer, and the tiles' buttons do not cover the joint
func test_the_joint_is_on_the_meeting_of_two_tiles_and_the_spacing_stays() -> void:
    await get_tree().process_frame
    var grid: Node = _screen.get_node("%TrainsetGrid")
    var joint: TextureButton = _joints()[0]
    var next: Control = joint.get_parent()
    var tile: Control = next.get_parent().get_child(next.get_index() - 1)
    var view: Rect2 = (grid.get_node("%Scroll") as Control).get_global_rect()
    var meeting: float = tile.get_global_rect().end.x
    assert_true(joint.is_visible_in_tree(), "shown")
    assert_gt(joint.get_global_rect().size.y, 0.0, "with a size")
    # the row scrolls sideways, so the joint is only kept from being cut off above or below
    var rect: Rect2 = joint.get_global_rect()
    assert_true(rect.position.y >= view.position.y and rect.end.y <= view.end.y,
            "inside the row's height %s: %s" % [view, rect])
    assert_almost_eq(joint.get_global_rect().get_center().x, meeting, 0.5, "on the meeting of the two")
    assert_almost_eq(next.get_global_rect().position.x, meeting, 0.5, "the next tile right behind - the spacing stays")
    for each: Control in [tile, next]:
        var actions: Control = each.find_children("", "PanelContainer", false, false)[0]
        actions.show()
        await get_tree().process_frame
        assert_false(actions.get_global_rect().intersects(joint.get_global_rect()),
                "%s over %s" % [actions.get_global_rect(), joint.get_global_rect()])
        actions.hide()


## A moved vehicle takes its coupling with it, and the joints follow the tiles: none after the last
func test_the_joints_follow_a_moved_vehicle() -> void:
    _screen.move_vehicle(1, 0)
    await get_tree().process_frame

    assert_eq(_joint_tooltips(), [_mode_name(UNCOUPLED)], "the wagon in front, uncoupled from the loco")
    assert_eq(_modes(_loaded_trainset()), [UNCOUPLED, DECLARED], "loaded so")
