class_name DrivingAid
extends Control

## The original's driving aid (drivingaid_panel, driveruipanels.cpp:42-205) as floating tiles: the
## controllers, the brakes, the brake pipe, the speed, the speed allowed with the next limit and
## how far it is, and the vigilance (CA) and cab signal (SHP) lamps. The speed limit stands on its
## own in the top right corner, the rest in a row at the top left - two children of a full-screen
## root that lets the mouse through, each anchored to its corner. What changes is refreshed by one Timer while the tiles are shown and the player has a
## vehicle. The values are padded to a fixed width (the digits font is monospaced), as the
## original's "%3d" (driveruipanels.cpp:137, 170), so a tile does not change its width; the limit's
## sign is its tile's last item, so it stays put while the next limit comes and goes on its left.

## How the tiles look: cards (a framed panel each), or their text on a faint black background
enum Style { CARDS, TEXT }
## Project Setting choosing the Style
const STYLE_SETTING:String = "hud/driving_aid/style"
## A dark lamp greyed out over a dark scene
const LAMP_SHADER:Shader = preload("driving_aid_lamp.gdshader")
const METRES_PER_KILOMETRE:float = 1000.0
## The positions of a local brake (LocalBrakePosNo, hamulce.h:45)
const LOCAL_BRAKE_POSITIONS:float = 10.0
## The reverser of the vehicle that pulls (DirActive, "direction"): forward, neutral, backward
const DIRECTION_SYMBOLS:Dictionary[VehicleController.Direction, String] = {
    VehicleController.DIRECTION_FORWARD: "▲",
    VehicleController.DIRECTION_NEUTRAL: "—",
    VehicleController.DIRECTION_BACKWARD: "▼",
}
## The vigilance lamp is lit and dark this long in turn while it blinks [s] (fCzuwakBlink, Train.h:27)
const VIGILANCE_BLINK:float = 0.15
## Why the driver keeps the train standing, shown beside the stop sign; a stop ahead needs no words -
## the sign says it
const STOP_REASON_NAMES:Dictionary[DriverState.StopReason, String] = {
    DriverState.STOP_REASON_NOT_READY: "Vehicle not ready",
    DriverState.STOP_REASON_WAITING_FOR_ORDERS: "Waiting for orders",
    DriverState.STOP_REASON_SIGNAL: "Signal at stop",
    DriverState.STOP_REASON_DISPATCH: "Station dispatch",
}

## Why a vehicle of the trainset left the rails, as the stop reason's detail
const DERAIL_CAUSE_NAMES:Dictionary[RailVehicleController.DerailCause, String] = {
    RailVehicleController.DERAIL_CAUSE_NO_RAIL: "no rails",
    RailVehicleController.DERAIL_CAUSE_CURVE: "overturned on a curve",
    RailVehicleController.DERAIL_CAUSE_WIDE_GAUGE: "track too wide",
    RailVehicleController.DERAIL_CAUSE_TRACK_CATEGORY: "wrong kind of track",
    RailVehicleController.DERAIL_CAUSE_COLLISION: "collision",
}

## The vehicle the player drives; an invalid RID while none
var vehicle:RID = RID()
## The dark lamps' material, off while a lamp is lit
var _dark_lamp:ShaderMaterial = ShaderMaterial.new()


func _ready() -> void:
    %BlinkTimer.wait_time = VIGILANCE_BLINK
    _dark_lamp.shader = LAMP_SHADER
    _light_lamp(%VigilanceLamp, false)
    _light_lamp(%CabSignalLamp, false)
    for tile:Control in _tiles():
        apply_style(tile)


## A tile laid out in the Style the project chooses - Style.TEXT: the chip's text look (UIChip).
## For every tile of the HUD alike (SimulationSpeedPanel, the streaming spinner).
static func apply_style(tile:UIChip) -> void:
    if not ProjectSettings.get_setting(STYLE_SETTING, Style.CARDS) == Style.TEXT:
        return
    tile.set_look(UIChip.Look.TEXT)


## The vehicle whose aid is shown; an invalid RID hides the tiles
func show_vehicle(p_vehicle:RID) -> void:
    vehicle = p_vehicle
    for tile:Control in _tiles():
        tile.visible = vehicle.is_valid()
    _on_visibility_changed()


## The tiles: the row's and the speed limit's
func _tiles() -> Array[Control]:
    var tiles:Array[Control] = [%LimitTile]
    for child:Node in %Tiles.get_children():
        tiles.append(child as Control)
    return tiles


func _on_visibility_changed() -> void:
    if is_visible_in_tree() and vehicle.is_valid():
        %RefreshTimer.start()
        _on_refresh_timer_timeout()
    else:
        %RefreshTimer.stop()
        %BlinkTimer.stop()
        _light_lamp(%VigilanceLamp, false)


func _on_refresh_timer_timeout() -> void:
    if not VehicleServer.vehicle_exists(vehicle):
        return
    # the controllers of the vehicle that pulls (Controlling(), driveruipanels.cpp:139-140)
    var powered:RID = RailVehicleServer.vehicle_find_powered(vehicle)
    var direction:VehicleController.Direction = VehicleController.DIRECTION_NEUTRAL
    var main_position:int = 0
    var second_position:int = 0
    if VehicleServer.vehicle_exists(powered):
        direction = VehicleServer.vehicle_get_controller(powered).get_direction()
        var master_controller:RailVehicleMasterController = RailVehicleServer.vehicle_component_get(
                powered, RailVehicleComponentType.COMPONENT_MASTER_CONTROLLER) as RailVehicleMasterController
        if master_controller:
            main_position = master_controller.get_main_position()
            second_position = master_controller.get_second_position()
    %DirectionValue.text = DIRECTION_SYMBOLS[direction]
    %ControllerValue.text = "%2d + %-2d" % [main_position, second_position]
    var brakes:RailVehicleBrake = RailVehicleServer.vehicle_component_get(
            vehicle, RailVehicleComponentType.COMPONENT_BRAKES) as RailVehicleBrake
    var brake_position:float = 0.0
    var local_brake_position:float = 0.0
    var pipe_pressure:float = 0.0
    if brakes:
        brake_position = brakes.get_controller_position()
        local_brake_position = brakes.get_local_position_normalized()
        pipe_pressure = brakes.get_pipe_pressure()
    %BrakesValue.text = "%4.1f + %-2d" % [brake_position, roundi(local_brake_position * LOCAL_BRAKE_POSITIONS)]
    # the train pipe (PipePress, driveruipanels.cpp:160), as the cab's gauge
    %BrakePipeValue.text = "%4.2f" % pipe_pressure
    %SpeedValue.text = "%3d" % floori(absf(VehicleServer.vehicle_get_speed(vehicle)))
    # the vigilance lamp blinks while the alerter asks, the cab signal lamp is lit while it is
    # active (Train.cpp:9024-9039)
    var security:RailVehicleSecuritySystem = RailVehicleServer.vehicle_component_get(
            vehicle, RailVehicleComponentType.COMPONENT_SECURITY) as RailVehicleSecuritySystem
    var vigilance:bool = security and security.get_vigilance_blinking()
    if vigilance and %BlinkTimer.is_stopped():
        %BlinkTimer.start()
        _light_lamp(%VigilanceLamp, true)
    elif not vigilance and not %BlinkTimer.is_stopped():
        %BlinkTimer.stop()
        _light_lamp(%VigilanceLamp, false)
    _light_lamp(%CabSignalLamp, security and security.get_cabsignal_blinking())

    # the speed allowed and the next limit (driveruipanels.cpp:73-122), of a driver that shows them
    var driver:RID = DriverServer.vehicle_get_driver(vehicle)
    var driver_state:DriverState = DriverServer.driver_get_state(driver) if driver.is_valid() else null
    %LimitTile.visible = not driver_state == null
    if not driver_state:
        return
    var limit:float = driver_state.speed_limit
    var next_limit:float = driver_state.next_speed_limit
    var next_distance:float = driver_state.next_speed_limit_distance
    # told to stand (VelDesired 0 - not ready, waiting for orders or for the way out): a stop sign,
    # not a limit of 0; standing, there is no next limit (driveruipanels.cpp:76)
    var stop:bool = limit == 0.0
    %LimitSign.theme_type_variation = &"SpeedStopSign" if stop else &"SpeedLimitSign"
    %LimitValue.theme_type_variation = &"SpeedStopSignText" if stop else &"SpeedLimitSignDigits"
    %LimitValue.text = tr("STOP") if stop else "%d" % limit
    # why it stands, on the left of the sign where the next limit is otherwise
    %StopReason.visible = stop and STOP_REASON_NAMES.has(driver_state.stop_reason)
    # a derailed vehicle of the trainset says so whatever the driver wants - it stands for good
    var derailed:PackedStringArray = []
    for car:RID in RailVehicleServer.vehicle_get_coupled(
            vehicle, RailVehicleController.COUPLER_END_FRONT, RailVehicleController.COUPLING_FLAG_COUPLER):
        var cause:RailVehicleController.DerailCause = (VehicleServer.vehicle_get_controller(car) as RailVehicleController).get_derail_cause()
        if not cause == RailVehicleController.DERAIL_CAUSE_NONE and not tr(DERAIL_CAUSE_NAMES[cause]) in derailed:
            derailed.append(tr(DERAIL_CAUSE_NAMES[cause]))
    if derailed:
        %StopReason.visible = true
        %StopReasonValue.text = tr("Vehicle derailed")
        %StopReasonDetail.text = ", ".join(derailed)
        %StopReasonDetail.visible = true
    elif %StopReason.visible:
        %StopReasonValue.text = tr(STOP_REASON_NAMES[driver_state.stop_reason])
        %StopReasonDetail.text = ", ".join(driver_state.stop_reason_details)
        %StopReasonDetail.visible = driver_state.stop_reason_details.size() > 0
    # the next limit only when there is a change; the sign stays put, the tile narrows on its left
    %NextLimit.visible = not next_limit == limit
    if next_limit == limit:
        return
    # no limit ahead is a sign, not a word - a translation would change the width
    %NextLimitValue.text = "%3d km/h" % next_limit if next_limit >= 0.0 else "  ∞ km/h"
    %NextLimitDistance.text = tr("in %4.1f km") % (next_distance / METRES_PER_KILOMETRE)


func _on_blink_timer_timeout() -> void:
    _light_lamp(%VigilanceLamp, not %VigilanceLamp.theme_type_variation == &"DrivingAidLampLit")


## A lamp of the security tile lit or dark: its body and its caption
func _light_lamp(lamp:PanelContainer, lit:bool) -> void:
    lamp.theme_type_variation = &"DrivingAidLampLit" if lit else &"DrivingAidLamp"
    lamp.material = null if lit else _dark_lamp
    (lamp.get_child(0) as Label).theme_type_variation = &"DrivingAidLampLabelLit" if lit else &"DrivingAidLampLabel"
