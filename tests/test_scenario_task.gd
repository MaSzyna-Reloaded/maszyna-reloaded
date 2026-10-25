extends MaszynaGutTest

const Order = MaszynaAIDriver.Order
const DEPARTURE:float = 12.0 + 40.0 / 60.0
const ARRIVAL:float = 13.0
const NO_TIME:float = StationServer.NO_TIME
const MASS:float = 210000.0
const VEHICLES:int = 5
const UNCOUPLED_VEHICLES:int = 3
## The texts are compared untranslated, whatever language the game runs in
const TEST_LOCALE:String = "en"

var _locale:String = ""
var _timetables:Array[RID] = []
var _trainsets:Array[RID] = []
var _stations:Array[RID] = []


func before_all() -> void:
    _locale = TranslationServer.get_locale()
    TranslationServer.set_locale(TEST_LOCALE)


func after_all() -> void:
    TranslationServer.set_locale(_locale)
    super()


func after_each() -> void:
    for trainset:RID in _trainsets:
        RailVehicleServer.trainset_free(trainset)
    _trainsets.clear()
    for timetable:RID in _timetables:
        StationServer.timetable_free(timetable)
    _timetables.clear()
    for station:RID in _stations:
        StationServer.station_free(station)
    _stations.clear()


func test_an_order_is_told_as_the_original_tells_it() -> void:
    assert_eq(MaszynaAIDriver.order_text(Order.WAIT_FOR_ORDERS, 0, false), "Wait for orders")
    assert_eq(MaszynaAIDriver.order_text(Order.PREPARE_ENGINE, 0, false), "Start the engine")
    assert_eq(MaszynaAIDriver.order_text(Order.OBEY_TRAIN, 0, false),
            "Drive according to signals and timetable")
    assert_eq(MaszynaAIDriver.order_text(Order.SHUNT | Order.CHANGE_DIRECTION, 0, false), "Change direction",
            "a change of direction first")
    assert_eq(MaszynaAIDriver.order_text(Order.CONNECT | Order.CHANGE_DIRECTION, 0, true),
            "Couple to consist ahead", "but not while coupling")
    assert_eq(MaszynaAIDriver.order_text(Order.DISCONNECT, 0, false), "Uncouple the engine")
    assert_eq(MaszynaAIDriver.order_text(Order.DISCONNECT, 1, false),
            "Uncouple the engine plus the next vehicle")
    assert_eq(MaszynaAIDriver.order_text(Order.DISCONNECT, UNCOUPLED_VEHICLES, false),
            "Uncouple the engine plus 3 next vehicles")
    assert_eq(MaszynaAIDriver.order_text(Order.DISCONNECT, -1, false), "Wait for orders",
            "done with uncoupling")


func test_a_train_is_told_by_its_timetable_and_order() -> void:
    var driver_state:DriverState = DriverState.new()
    driver_state.waiting_for_orders = false
    driver_state.task = "Start the engine"
    var task:ScenarioTask = ScenarioTask.compose("SU45-123", driver_state, _run(), VEHICLES, MASS)

    assert_eq(task.title, "Scenario progress for SU45-123")
    assert_eq(task.paragraphs, PackedStringArray([
        "You drive train Os 34229 from Kalisz Pomorski to Szczecinek. Vehicles in the trainset: 5, mass 210 t.",
        "Start station: Kalisz Pomorski, departure at 12:40.",
        "Stops on the way: Wierzchowo, Szczecinek.",
        "Szczecinek: change of direction - uncouple the engine and shunt according to signals.",
        "Current task: Start the engine",
    ]))


func test_a_vehicle_without_a_driver_or_a_task_has_no_scenario() -> void:
    assert_eq(ScenarioTask.compose("SM42-1", null, RID(), 1, MASS).title, "No scenario set for SM42-1", "no driver")
    var driver_state:DriverState = DriverState.new()
    driver_state.waiting_for_orders = true
    driver_state.task = "Wait for orders"
    var waiting:ScenarioTask = ScenarioTask.compose("SM42-1", driver_state, RID(), 1, MASS)
    assert_eq(waiting.title, "No scenario set for SM42-1", "no timetable and nothing to do")
    assert_eq(waiting.paragraphs, PackedStringArray())
    assert_eq(ScenarioTask.describe(RID()).title, "No scenario set", "no vehicle")


## The run of a trainset by the test's timetable, at its start
func _run() -> RID:
    var timetable:RID = StationServer.timetable_create()
    _timetables.append(timetable)
    StationServer.timetable_set_train_name(timetable, "34229")
    StationServer.timetable_set_train_category(timetable, "Os")
    _entry(timetable, "Kalisz Pomorski", NO_TIME, DEPARTURE)
    _entry(timetable, "Wierzchowo", ARRIVAL, ARRIVAL)
    _entry(timetable, "Przelot", NO_TIME, NO_TIME)
    var turn:int = _entry(timetable, "Szczecinek", ARRIVAL, NO_TIME)
    StationServer.timetable_entry_set_direction_change(timetable, turn, true)
    var trainset:RID = RailVehicleServer.trainset_create()
    _trainsets.append(trainset)
    return StationServer.run_create(timetable, trainset)


func _entry(timetable:RID, station_name:String, arrival:float, departure:float) -> int:
    var station:RID = StationServer.station_create()
    StationServer.station_set_name(station, station_name)
    _stations.append(station)
    return StationServer.timetable_add_entry(timetable, station, arrival, departure)
