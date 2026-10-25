class_name TrainRun
extends RefCounted

## What the HUD shows of a train's timetable, read off the core's servers alone: the run of the
## trainset a vehicle is in (StationServer, RailVehicleServer), its timetable, and how late the
## train is.

const HOURS_PER_DAY:float = 24.0


## The run of the trainset the vehicle is in, RID() for none
static func of_vehicle(vehicle:RID) -> RID:
    if not vehicle.is_valid():
        return RID()
    return StationServer.run_find_by_trainset(RailVehicleServer.vehicle_get_trainset(vehicle))


## The train as its timetable names it: its category and name
static func train_title(timetable:RID) -> String:
    return ("%s %s" % [StationServer.timetable_get_train_category(timetable),
            StationServer.timetable_get_train_name(timetable)]).strip_edges()


## The stations the train runs from and to - the timetable's relation, else its first station and
## its last; empty for a timetable of neither
static func relation(timetable:RID) -> String:
    var origin:String = relation_origin(timetable)
    var destination:String = relation_destination(timetable)
    return "%s  →  %s" % [origin, destination] if origin and destination else ""


static func relation_origin(timetable:RID) -> String:
    var origin:RID = StationServer.timetable_get_origin(timetable)
    if origin.is_valid():
        return StationServer.station_get_name(origin)
    return station_name(timetable, 0) if StationServer.timetable_get_entry_count(timetable) > 0 else ""


static func relation_destination(timetable:RID) -> String:
    var destination:RID = StationServer.timetable_get_destination(timetable)
    if destination.is_valid():
        return StationServer.station_get_name(destination)
    var count:int = StationServer.timetable_get_entry_count(timetable)
    return station_name(timetable, count - 1) if count > 0 else ""


static func station_name(timetable:RID, entry:int) -> String:
    return StationServer.station_get_name(StationServer.timetable_entry_get_station(timetable, entry))


## The arrival and the departure planned at the entry, as the run's [h]: the timetable's shifted by
## its offset; StationServer.NO_TIME for none
static func arrival(run:RID, entry:int) -> float:
    return _shifted(run, StationServer.timetable_entry_get_arrival(StationServer.run_get_timetable(run), entry))


static func departure(run:RID, entry:int) -> float:
    return _shifted(run, StationServer.timetable_entry_get_departure(StationServer.run_get_timetable(run), entry))


## How late the train is now [min], early when negative
static func delay_minutes(run:RID) -> int:
    return roundi(StationServer.run_get_delay(run, SimulationServer.time_of_day))


## The entry the train stops at next - the one it drives to or stands at, or a later one; -1 for
## none left
static func next_stop(run:RID) -> int:
    var timetable:RID = StationServer.run_get_timetable(run)
    for entry:int in range(StationServer.run_get_current_entry(run), StationServer.timetable_get_entry_count(timetable)):
        if StationServer.timetable_entry_is_stop(timetable, entry):
            return entry
    return -1


## The train stands at its current entry: arrived there, not left it yet
static func is_standing(run:RID) -> bool:
    var entry:int = StationServer.run_get_current_entry(run)
    if entry >= StationServer.timetable_get_entry_count(StationServer.run_get_timetable(run)):
        return false
    return StationServer.run_entry_get_actual_arrival(run, entry) >= 0.0 \
            and StationServer.run_entry_get_actual_departure(run, entry) < 0.0


static func _shifted(run:RID, hours:float) -> float:
    return hours if hours < 0.0 else fposmod(hours + StationServer.run_get_offset(run), HOURS_PER_DAY)
