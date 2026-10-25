class_name ScenarioTask
extends RefCounted

## What the player is to do in the vehicle they drive, told in sentences for the scenario panel:
## the train and its relation, the trainset, the station it starts from or drives to, the stops
## left, the stations it turns at and the driver's current order. Scenarios seldom describe the
## task, so it is read from the run of the vehicle's trainset (StationServer) and from the orders
## the scenario's events have given its driver (the original shows only the current order,
## driveruipanels.cpp:226-235). Translated when made.

## The heading: the vehicle's task, or that it has none
var title:String = ""
## The sentences, a paragraph each
var paragraphs:PackedStringArray = []


## The task of `vehicle`, read from its driver and the run of its trainset; a vehicle without a
## driver has none
static func describe(vehicle:RID) -> ScenarioTask:
    if not vehicle.is_valid():
        var task:ScenarioTask = ScenarioTask.new()
        task.title = TranslationServer.translate("No scenario set")
        return task
    var driver:RID = DriverServer.vehicle_get_driver(vehicle)
    var trainset:RID = RailVehicleServer.vehicle_get_trainset(vehicle)
    return compose(VehicleServer.vehicle_get_name(vehicle),
            DriverServer.driver_get_state(driver) if driver.is_valid() else null, TrainRun.of_vehicle(vehicle),
            RailVehicleServer.trainset_get_vehicles(trainset).size() if trainset.is_valid() else 0,
            RailVehicleServer.trainset_get_mass(trainset) if trainset.is_valid() else 0.0)


## The task told from a driver's state (DriverServer.driver_get_state()), the run of its trainset
## (StationServer) and the trainset's vehicles and mass [kg]; without a driver's state, and without
## a timetable while the driver waits for orders, there is none
static func compose(vehicle_name:String, driver_state:DriverState, run:RID, vehicle_count:int,
        mass:float) -> ScenarioTask:
    var task:ScenarioTask = ScenarioTask.new()
    var timetable:RID = StationServer.run_get_timetable(run) if run.is_valid() else RID()
    if not driver_state or (not timetable.is_valid() and driver_state.waiting_for_orders):
        task.title = TranslationServer.translate("No scenario set for %s") % vehicle_name
        return task
    task.title = TranslationServer.translate("Scenario progress for %s") % vehicle_name
    var train:PackedStringArray = []
    if timetable.is_valid():
        var name:String = TrainRun.train_title(timetable)
        if TrainRun.relation(timetable):
            train.append(TranslationServer.translate("You drive train %s from %s to %s.") % [
                name, TrainRun.relation_origin(timetable), TrainRun.relation_destination(timetable)])
        else:
            train.append(TranslationServer.translate("You drive train %s.") % name)
    if vehicle_count:
        train.append(TranslationServer.translate("Vehicles in the trainset: %d, mass %d t.") % [
            vehicle_count, roundi(mass / VehicleCard.KILOGRAMS_PER_TONNE)])
    if train:
        task.paragraphs.append(" ".join(train))
    var count:int = StationServer.timetable_get_entry_count(timetable) if timetable.is_valid() else 0
    var index:int = StationServer.run_get_current_entry(run) if run.is_valid() else 0
    if index < count:
        var station:String = TranslationServer.translate("Start station: %s" if index == 0 else "Next station: %s") \
                % TrainRun.station_name(timetable, index)
        if TrainRun.departure(run, index) >= 0.0:
            station += TranslationServer.translate(", departure at %s") % TimetableRow.format_time(TrainRun.departure(run, index))
        task.paragraphs.append(station + ".")
    var stops:PackedStringArray = []
    for later:int in range(index + 1, count):
        if StationServer.timetable_entry_is_stop(timetable, later):
            stops.append(TrainRun.station_name(timetable, later))
    if stops:
        task.paragraphs.append(TranslationServer.translate("Stops on the way: %s.") % ", ".join(stops))
    for later:int in range(index, count):
        if StationServer.timetable_entry_is_direction_change(timetable, later):
            task.paragraphs.append(TranslationServer.translate(
                    "%s: change of direction - uncouple the engine and shunt according to signals.")
                    % TrainRun.station_name(timetable, later))
    if driver_state.task:
        task.paragraphs.append("%s %s" % [TranslationServer.translate("Current task:"), driver_state.task])
    return task
