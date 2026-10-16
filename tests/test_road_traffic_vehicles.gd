extends MaszynaGutTest

## RoadTrafficVehicles: a RoadTrafficServer type per vehicle and skin of the weighed categories of
## dynamic/, its size and speed from its .fiz, its model from its .mmd, its category's weight shared
## among its types

const GAME_DIR: String = "res://tests/fixtures/game_dir"
const CAR_DATA_PATH: String = "/dynamic/road/testcar"
const CAR_WEIGHT: float = 0.8
## The fixture car's .fiz and .mmd (its `models: body.t3d`, named without the extension) and the
## skin listed first
const CAR_LENGTH: float = 4.2
const CAR_WIDTH: float = 1.7
const CAR_MAX_VELOCITY: float = 120.0
const CAR_MODEL: String = "body"
const CAR_SKIN: String = "red"
## How far off a value read from the .fiz may be
const TOLERANCE: float = 0.001

var _previous_game_dir: String = ""


func before_each() -> void:
    _previous_game_dir = UserSettings.get_maszyna_game_dir()
    UserSettings.save_maszyna_game_dir(ProjectSettings.globalize_path(GAME_DIR))


func after_each() -> void:
    UserSettings.save_maszyna_game_dir(_previous_game_dir)


func _read() -> Array[RoadTrafficVehicleType]:
    var weights: Dictionary[MaszynaVehiclesBank.Category, float] = {MaszynaVehiclesBank.Category.CARS: CAR_WEIGHT}
    return RoadTrafficVehicles.read(ProjectSettings.globalize_path(GAME_DIR), weights)


func test_a_type_per_skin_of_a_weighed_category_only() -> void:
    var types: Array[RoadTrafficVehicleType] = _read()

    assert_eq(types.size(), 2, "the car's two skins; the walker's category is not weighed, nofiz has no .fiz")
    for type: RoadTrafficVehicleType in types:
        assert_eq(type.data_path, CAR_DATA_PATH)


func test_a_type_is_as_large_and_fast_as_its_fiz_says_and_drawn_with_its_mmd_model() -> void:
    var types: Array[RoadTrafficVehicleType] = _read()
    assert_eq(types.size(), 2)
    if not types:
        return

    assert_almost_eq(types[0].length, CAR_LENGTH, TOLERANCE)
    assert_almost_eq(types[0].width, CAR_WIDTH, TOLERANCE)
    assert_almost_eq(types[0].max_velocity, CAR_MAX_VELOCITY, TOLERANCE)
    assert_eq(types[0].model_filename, CAR_MODEL)
    assert_eq(types[0].skins, PackedStringArray([CAR_SKIN]), "the skin is resolved")


func test_a_category_weight_is_shared_among_its_types() -> void:
    var types: Array[RoadTrafficVehicleType] = _read()
    var total: float = 0.0
    for type: RoadTrafficVehicleType in types:
        total += type.weight

    assert_almost_eq(total, CAR_WEIGHT, TOLERANCE)
