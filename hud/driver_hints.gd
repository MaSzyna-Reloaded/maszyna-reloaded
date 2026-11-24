class_name DriverHints
extends Control

## The driver's hints to the player (the "Hints" of the original's scenario window,
## driveruipanels.cpp:280-294): the steps the driver of the player's vehicle would take, in the
## order it decided on them, translated - a step the vehicle already shows done in green until the
## driver's next update. On its left the key that does it in the cab of the moment
## (CabinLogic.get_action()) - the pad's button or axis while a pad is in use and binds it, drawn as
## on that pad (InputBindings.get_shown_events()); a hint no key does starts at the left edge. With no hints, or no
## driver, the tile says so. Read on a Timer while shown and the player has a vehicle; without one
## the tile is hidden, as the driving aid's (show_vehicle()).

const ROW:PackedScene = preload("driver_hint_row.tscn")

## The vehicle the player drives; an invalid RID while none
var vehicle:RID = RID()


func _ready() -> void:
    DrivingAid.apply_style(%HintsTile)
    # the keys shown follow the device in use at once, not at the next read
    InputBindings.device_changed.connect(_on_visibility_changed)
    InputBindings.pad_layout_changed.connect(_on_visibility_changed)
    InputBindings.bindings_changed.connect(_on_visibility_changed)


## The vehicle whose driver's hints are shown; an invalid RID hides the tile
func show_vehicle(p_vehicle:RID) -> void:
    vehicle = p_vehicle
    %HintsTile.visible = vehicle.is_valid()
    _on_visibility_changed()


func _on_visibility_changed() -> void:
    if is_visible_in_tree() and vehicle.is_valid():
        %RefreshTimer.start()
        _on_refresh_timer_timeout()
    else:
        %RefreshTimer.stop()


func _on_refresh_timer_timeout() -> void:
    var hints:Array = []
    var driver:RID = DriverServer.vehicle_get_driver(vehicle)
    var driver_state:DriverState = DriverServer.driver_get_state(driver) if driver.is_valid() else null
    if driver_state:
        hints = driver_state.hints
    var cab_logic:CabinLogic = CabinSystem.vehicle_get_cab_logic(vehicle)
    # two hints the same key already does at once (closing the left and the right doors with one
    # all-doors button) are the one step to the player, shown once
    var shown:Array[Dictionary] = []
    for hint:DriverHint in hints:
        var action:StringName = &""
        var event:InputEvent = null
        if cab_logic and hint.control:
            action = cab_logic.get_action(hint.control, hint.gesture)
            if action and InputMap.has_action(action):
                var events: Array[InputEvent] = InputBindings.get_shown_events(action)
                if events:
                    event = events[0]
        var duplicate:bool = false
        for entry:Dictionary in shown:
            if entry["action"] == action and entry["text"] == hint.text and entry["done"] == hint.done:
                duplicate = true
                break
        if duplicate:
            continue
        shown.append({"action": action, "event": event, "text": hint.text, "done": hint.done})
    var rows:Array[Node] = %HintList.get_children()
    for index:int in shown.size():
        var row:DriverHintRow
        if index < rows.size():
            row = rows[index] as DriverHintRow
        else:
            row = ROW.instantiate()
            %HintList.add_child(row)
        row.show_hint(shown[index]["event"], shown[index]["text"], shown[index]["done"])
        row.visible = true
    for index:int in range(shown.size(), rows.size()):
        (rows[index] as Control).visible = false
    %EmptyText.visible = not shown
