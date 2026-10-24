class_name TimetablePanel
extends PanelContainer

## The timetable of the player's train: the train, its relation, the clock and the delay, and every
## station with the times it is due - the original's timetable panel (timetable_panel::update(),
## driveruipanels.cpp:300-472; F2, driveruilayer.cpp:155) laid out anew. It shows the run of the
## trainset the player's vehicle is in (StationServer): the timetable, where the train is in it and
## how late it is.

## The close button asks the owner of the View menu to hide the panel and untick its entry
signal close_requested
## The player's train was given a timetable (or the player drives one that has it): the owner of the
## View menu shows the panel
signal timetable_received

const ROW:PackedScene = preload("timetable_row.tscn")
const MINUTES_PER_HOUR:float = 60.0
const SECONDS_PER_MINUTE:float = 60.0
const HOURS_PER_DAY:int = 24
const KILOGRAMS_PER_TONNE:float = 1000.0
const ON_TIME_COLOR:Color = Color(0.4, 0.85, 0.55)
const LATE_COLOR:Color = Color(1.0, 0.45, 0.4)
const EARLY_COLOR:Color = Color(0.45, 0.72, 1.0)

## The vehicle the player drives, the run of its trainset (StationServer) and its timetable
var _vehicle:RID = RID()
var _run:RID = RID()
var _timetable:RID = RID()
## The row shown as the train's station: the run's current entry, the one it drives to or stands at
var _current:int = 0
var _rows:Array[TimetableRow] = []


func _ready() -> void:
    StationServer.run_created.connect(_on_run)
    StationServer.run_freed.connect(_on_run)
    for progress:Signal in [StationServer.run_entry_changed, StationServer.run_arrived,
            StationServer.run_departed, StationServer.run_passed]:
        progress.connect(_on_run_progress)
    RailVehicleServer.vehicle_trainset_changed.connect(_on_vehicle_trainset_changed)
    _follow_trainset()


func _exit_tree() -> void:
    StationServer.run_created.disconnect(_on_run)
    StationServer.run_freed.disconnect(_on_run)
    for progress:Signal in [StationServer.run_entry_changed, StationServer.run_arrived,
            StationServer.run_departed, StationServer.run_passed]:
        progress.disconnect(_on_run_progress)
    RailVehicleServer.vehicle_trainset_changed.disconnect(_on_vehicle_trainset_changed)


## The player drives another vehicle, or none
func follow_vehicle(vehicle:RID) -> void:
    _vehicle = vehicle
    _follow_trainset()


## A run began or ended: it may be the one of the player's trainset
func _on_run(_changed:RID) -> void:
    _follow_trainset()


## The run followed moved on, its train arrived, left or passed
func _on_run_progress(run:RID, _entry:int) -> void:
    if run == _run:
        _follow_trainset()


## The player's vehicle was coupled or uncoupled: its trainset, and the run, may be another one
func _on_vehicle_trainset_changed(vehicle:RID) -> void:
    if vehicle == _vehicle:
        _follow_trainset()


## The run of the player's trainset: the train and its stations rebuilt for a new timetable, the
## progress and the delay shown
func _follow_trainset() -> void:
    _run = TrainRun.of_vehicle(_vehicle)
    var timetable:RID = StationServer.run_get_timetable(_run) if _run.is_valid() else RID()
    _current = StationServer.run_get_current_entry(_run) if _run.is_valid() else 0
    if not timetable == _timetable:
        _timetable = timetable
        # the train and a row for each of its stations
        for row:TimetableRow in _rows:
            row.queue_free()
        _rows.clear()
        var known:bool = timetable.is_valid()
        if known:
            timetable_received.emit()
        %Train.text = TrainRun.train_title(timetable) if known else tr("No timetable")
        %TrainLabel.text = StationServer.timetable_get_train_label(timetable) if known else ""
        %TrainLabel.visible = not %TrainLabel.text == ""
        %Relation.text = TrainRun.relation(timetable) if known else ""
        %Relation.visible = not %Relation.text == ""
        # what the train is to be, its mass beside the trainset's own (driveruipanels.cpp:376-381)
        var details:PackedStringArray = []
        if known and StationServer.timetable_get_required_locomotive(timetable):
            details.append(StationServer.timetable_get_required_locomotive(timetable))
        if known and StationServer.timetable_get_required_mass(timetable) > 0.0:
            details.append(tr("%d t, actual %d t") % [StationServer.timetable_get_required_mass(timetable),
                    roundi(RailVehicleServer.trainset_get_mass(StationServer.run_get_trainset(_run)) / KILOGRAMS_PER_TONNE)])
        if known and StationServer.timetable_get_required_brake_ratio(timetable) > 0.0:
            details.append(tr("braked %d%%") % StationServer.timetable_get_required_brake_ratio(timetable))
        %Details.text = "  ·  ".join(details)
        %Details.visible = details.size() > 0
        var count:int = StationServer.timetable_get_entry_count(timetable) if known else 0
        # a timetable of no stations is only the train's speed limit (mtable.cpp:279)
        var speed_limit:float = StationServer.timetable_get_speed_limit(timetable) if known else 0.0
        %NoStations.text = tr("Line speed %d km/h, no stations") % speed_limit \
                if speed_limit > 0.0 else tr("The train follows no timetable")
        %NoStations.visible = count == 0
        %Delay.visible = count > 0
        %StationsScroll.visible = count > 0
        var velocity:float = TimetableRow.NO_SPEED
        for index:int in count:
            var row:TimetableRow = ROW.instantiate()
            %Stations.add_child(row)
            var place:TimetableRow.Place = TimetableRow.Place.BETWEEN
            if index == 0:
                place = TimetableRow.Place.FIRST
            elif index == count - 1:
                place = TimetableRow.Place.LAST
            var entry_velocity:float = StationServer.timetable_entry_get_speed_limit(timetable, index)
            row.show_entry(_run, index, place, entry_velocity if not entry_velocity == velocity else TimetableRow.NO_SPEED)
            velocity = entry_velocity
            _rows.append(row)
        # a new timetable fits the card to what it shows; its size is the player's until the next.
        # The card stands in the bottom right corner, above the vehicle chips, and grows up and
        # left: its bottom right corner stays where it is
        var corner:Vector2 = position + size
        reset_size()
        position = corner - size
    for index:int in _rows.size():
        var progress:TimetableRow.Progress = TimetableRow.Progress.AHEAD
        if index == _current:
            progress = TimetableRow.Progress.NEXT
        elif index < _current:
            progress = TimetableRow.Progress.PASSED
        _rows[index].show_progress(progress)
    _scroll_to_next_station()
    _tick()


## The list scrolled to the station passed last with the next one below it - on every new progress,
## and once the rows are laid out (the list's sort_children, a [connection] in the scene)
func _scroll_to_next_station() -> void:
    var shown:int = clampi(_current - 1, 0, _rows.size() - 1)
    %StationsScroll.scroll_vertical = int(_rows[shown].position.y) if _rows else 0


## The clock, the delay and the status of the train's station, on the panel's timer (a [connection]
## in the scene)
func _tick() -> void:
    var hours:float = SimulationServer.time_of_day
    var seconds:int = floori(hours * MINUTES_PER_HOUR * SECONDS_PER_MINUTE)
    var seconds_per_hour:int = int(MINUTES_PER_HOUR * SECONDS_PER_MINUTE)
    %Clock.text = "%02d:%02d:%02d" % [
        (seconds / seconds_per_hour) % HOURS_PER_DAY, (seconds / int(SECONDS_PER_MINUTE)) % int(MINUTES_PER_HOUR),
        seconds % int(SECONDS_PER_MINUTE)
    ]
    var late_minutes:int = TrainRun.delay_minutes(_run) if _run.is_valid() else 0
    %DelayText.text = tr("On time") if late_minutes == 0 else "%+d min" % late_minutes
    %DelayText.add_theme_color_override(&"font_color",
            ON_TIME_COLOR if late_minutes == 0 else (LATE_COLOR if late_minutes > 0 else EARLY_COLOR))
    if _current >= _rows.size():
        return
    var row:TimetableRow = _rows[_current]
    # the train's dispatch at the stop, kept under the vehicle its train is driven from
    var vehicle:RID = _driven_vehicle()
    var dispatch_step:StationServer.DispatchStep = StationServer.dispatch_get_step(vehicle)
    if not TrainRun.is_standing(_run) or not StationServer.timetable_entry_is_stop(_timetable, _current):
        row.show_status(tr("Next station"), TimetableRow.Tone.NEUTRAL)
    elif _current == _rows.size() - 1:
        row.show_status(tr("Terminus"), TimetableRow.Tone.NEUTRAL)
    elif dispatch_step == StationServer.DISPATCH_STEP_EXCHANGE:
        row.show_status(tr("Passenger exchange · %d s") % ceili(StationServer.dispatch_get_exchange_time(vehicle)),
                TimetableRow.Tone.EXCHANGE)
    elif dispatch_step == StationServer.DISPATCH_STEP_CLOSE_DOORS:
        row.show_status(tr("Closing doors"), TimetableRow.Tone.WAIT)
    else:
        var minutes:float = StationServer.run_get_time_to_departure(_run, hours)
        if minutes > 0.0:
            var wait:int = ceili(minutes * SECONDS_PER_MINUTE)
            row.show_status(tr("Stop · departure in %d:%02d") % [
                wait / int(SECONDS_PER_MINUTE), wait % int(SECONDS_PER_MINUTE)
            ], TimetableRow.Tone.WAIT)
        else:
            row.show_status(tr("Departure"), TimetableRow.Tone.GO)


## The vehicle of the trainset somebody drives it from - its driver's - RID() for none
func _driven_vehicle() -> RID:
    for vehicle:RID in RailVehicleServer.trainset_get_vehicles(StationServer.run_get_trainset(_run)):
        var driver:RID = DriverServer.vehicle_get_driver(vehicle)
        if driver.is_valid():
            return VehicleServer.person_get_vehicle(driver)
    return RID()


## The clock runs only while the panel is shown
func _on_visibility_changed() -> void:
    if not visible:
        %Timer.stop()
        return
    _tick()
    %Timer.start()


func _on_close_button_pressed() -> void:
    close_requested.emit()
