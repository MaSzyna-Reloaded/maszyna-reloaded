extends Node3D

## One take of the trailer: a scenery loaded as the game loads it, without the game's screens and
## HUD, and its shots shown one after another through PlayerServer and PlayerCameraServer while
## Godot's movie writer records the run (make_trailer.py, --write-movie). The scenery's drivers
## drive, until the take's "drive" lets one of them go and sets the master controller itself - a
## train of the trailer runs faster than its timetable. A shot is a view of the game (the cab, the
## following camera) or a rig: the free camera moved by the director, frame by frame. Each shot's
## frames are printed, for the edit to cut by.

## Command line, after Godot's "--": the take of SHOTS_FILE to record
const ARG_TAKE: String = "--take"
## ...and, with a list of shot names after it, the shots to film: the others of the take pass as
## they would - the same views, the same seconds - with the 3D world not drawn, so the film holds
## empty frames for them, and the take ends after the last one filmed (make_trailer.py,
## TRAILER_USED_ONLY)
const ARG_ONLY: String = "--only"
## The takes and their shots - read here and by make_trailer.py
const SHOTS_FILE: String = "shots.json"
## Exit code of a run without a take of SHOTS_FILE named
const EXIT_UNKNOWN_TAKE: int = 1
## The chunks around the camera built before a shot, as the game's loading screen waits for
## (game.gd SURROUNDINGS_CHUNK_RADIUS)
const SURROUNDINGS_CHUNK_RADIUS: int = 1
## A shot's "view" in SHOTS_FILE: the cab, a rig, or a view of the following camera
const VIEW_CABIN: String = "cabin"
const VIEW_RIG: String = "rig"
## A rig's "anchor": its camera rides with the train, or stands where the train was when the shot
## began and turns after it
const ANCHOR_GROUND: String = "ground"
## A rig's lens without "fov" [degrees]
const RIG_FOV: float = 50.0
## Frames between the two positions a train's way is read from
const HEADING_FRAMES: int = 2
## A rig's "focus" [m]: how far from it, in shares of it, the picture is sharp, how wide the blur
## grows from there, and how strong it is
const FOCUS_NEAR_SHARE: float = 0.6
const FOCUS_FAR_SHARE: float = 1.6
const FOCUS_TRANSITION_SHARE: float = 0.8
const FOCUS_BLUR: float = 0.1
const FOLLOW_VIEWS: Dictionary[String, PlayerCameraServer.CameraFollowView] = {
    "trainset_front": PlayerCameraServer.CAMERA_FOLLOW_VIEW_TRAINSET_FRONT,
    "trainset_rear": PlayerCameraServer.CAMERA_FOLLOW_VIEW_TRAINSET_REAR,
    "bogie": PlayerCameraServer.CAMERA_FOLLOW_VIEW_BOGIE,
    "driveby": PlayerCameraServer.CAMERA_FOLLOW_VIEW_DRIVEBY,
}
## A take's "weather" in SHOTS_FILE
const WEATHERS: Dictionary[String, SimulationServer.Weather] = {
    "clear": SimulationServer.WEATHER_CLEAR,
    "cloudy": SimulationServer.WEATHER_CLOUDY,
    "rain": SimulationServer.WEATHER_RAIN,
    "snow": SimulationServer.WEATHER_SNOW,
}

## The cab's light switches a take's "cab_lights" turns on in a cab shot: the instruments' and the
## dashboard's, as a driver has them at night - the cab light itself stays off
const CAB_LIGHT_CONTROLS: Array[StringName] = [
    LegacyCabinCabLights.INSTRUMENT_LIGHT, LegacyCabinCabLights.DASHBOARD_LIGHT,
]

## The trainsets as the scenery declares them
const DECLARED_TRAINSET: Array[MaszynaDynamicData] = []

# The rig shot shown, empty with none; its train's first vehicle on the way it runs, whether that
# vehicle runs tail first, where it was when the shot began and the seconds since
var _rig: Dictionary = {}
var _rig_vehicle: RID
var _rig_reversed: bool = false
var _rig_ground: Transform3D
var _rig_elapsed: float = 0.0
# The camera a rig's "focus" was put on, to take it off after the shot
var _focused: Camera3D
# The vehicle the take drives itself, its driver let go
var _driven: RID
# Seconds of the take since its scenery was loaded
var _elapsed: float = 0.0


## Before _ready(): the original's driver thinks for the drivers a scenery declares, as in the
## game (game.gd)
func _enter_tree() -> void:
    DriverServer.implementation_register(SceneryInstancer.DRIVER_IMPLEMENTATION, MaszynaLegacyAIDriver.new())


func _exit_tree() -> void:
    DriverServer.implementation_unregister(SceneryInstancer.DRIVER_IMPLEMENTATION)


func _ready() -> void:
    var args: PackedStringArray = OS.get_cmdline_user_args()
    var take_name: String = args[args.find(ARG_TAKE) + 1] if ARG_TAKE in args else ""
    var only: PackedStringArray = args[args.find(ARG_ONLY) + 1].split(",") if ARG_ONLY in args else PackedStringArray()
    var shots_path: String = (get_script() as Script).resource_path.get_base_dir().path_join(SHOTS_FILE)
    var take: Dictionary = {}
    for candidate: Dictionary in JSON.parse_string(FileAccess.get_file_as_string(shots_path))["takes"]:
        if candidate["name"] == take_name:
            take = candidate
    if not take:
        print("[Trailer] no take '%s' in %s" % [take_name, shots_path])
        get_tree().quit(EXIT_UNKNOWN_TAKE)
        return
    SimulationServer.simulation_unpause()
    SimulationServer.simulation_reset_speed()
    await %World.load_scenery(take["scenery"], DECLARED_TRAINSET)
    # after the scenery's own declarations, which its load applies
    if take.has("time_of_day"):
        SimulationServer.time_of_day = take["time_of_day"]
    if take.has("weather"):
        %World.get_environment().weather = WEATHERS[take["weather"]]
    # a mist: how much of the picture the fog takes at its distance [m]
    if take.has("fog"):
        %World.get_environment().fog_density = take["fog"]["density"]
        %World.get_environment().fog_distance = take["fog"]["distance"]
    # the vehicle the scenery starts the player in; let go, its driver drives it
    var start_vehicle: RID = PlayerServer.player_get_vehicle()
    PlayerServer.player_leave_vehicle()
    _elapsed = 0.0
    if take.has("drive"):
        _drive(take["drive"])
    var last_filmed: int = take["shots"].size() - 1
    while not only.is_empty() and last_filmed >= 0 and not take["shots"][last_filmed]["name"] in only:
        last_filmed -= 1
    for shot: Dictionary in take["shots"].slice(0, last_filmed + 1):
        var vehicle: RID = (
            VehicleServer.vehicle_get_rid_by_id(shot["vehicle"]) if shot.has("vehicle") else start_vehicle
        )
        _rig = {}
        if _focused:
            _focused.attributes = null
            _focused = null
        if shot["view"] == VIEW_RIG:
            await _show_rig(shot, vehicle)
        elif shot["view"] == VIEW_CABIN:
            PlayerServer.player_enter_vehicle(vehicle)
            PlayerCameraServer.camera_set_mode(PlayerCameraServer.CAMERA_MODE_CABIN)
            if take.get("cab_lights", false):
                var cabin: RID = RailVehicleServer.vehicle_get_driver_cabin(vehicle)
                for control: StringName in CAB_LIGHT_CONTROLS:
                    if CabinSystem.has_control(cabin, control):
                        CabinSystem.act(cabin, control, &"toggle", true)
        else:
            PlayerServer.player_leave_vehicle()
            PlayerCameraServer.camera_set_target(vehicle)
            PlayerCameraServer.camera_set_mode(PlayerCameraServer.CAMERA_MODE_FOLLOW)
            PlayerCameraServer.camera_set_follow_view(FOLLOW_VIEWS[shot["view"]])
        # with the view already on the first shot's vehicle, so the streaming follows it there:
        # it reads the camera on its own tick, and asked in the frame of a jump to a vehicle far
        # away it still answers for the place the view left
        # a shot's "at": the take's second it starts at - a train is fast when its timetable has
        # it so. The wait runs at the simulation's own speed (a faster one breaks the signals'
        # blinking) with the 3D world not drawn: it is recorded frame by frame, black frames cost
        # the least
        if shot.has("at") and _elapsed < shot["at"]:
            get_viewport().disable_3d = true
            await get_tree().create_timer(shot["at"] - _elapsed).timeout
        get_viewport().disable_3d = not (only.is_empty() or shot["name"] in only)
        # the world around the view built, announced also when it already is (area_watch())
        SceneryStreamingServer.area_watch(SURROUNDINGS_CHUNK_RADIUS)
        await SceneryStreamingServer.area_ready
        SceneryStreamingServer.area_unwatch(SURROUNDINGS_CHUNK_RADIUS)
        # a rig starts with its pre-roll: the wait for the world is not a part of its move
        if shot["view"] == VIEW_RIG:
            await _show_rig(shot, vehicle)
        # a cab shot's "pitch" and "fov" [degrees]: the driver's look lowered onto the desk and its
        # screens, the lens narrowed on them
        if shot["view"] == VIEW_CABIN:
            await get_tree().process_frame
            var head: Camera3D = get_viewport().get_camera_3d()
            if shot.has("pitch"):
                head.rotation_degrees.x = shot["pitch"]
            if shot.has("fov"):
                head.fov = shot["fov"]
        await get_tree().create_timer(shot["pre_roll"]).timeout
        var first_frame: int = Engine.get_process_frames()
        await get_tree().create_timer(shot["duration"]).timeout
        print("[Trailer] %s frames %d %d speed %.1f km/h at %.0f s" % [
            shot["name"], first_frame, Engine.get_process_frames(), VehicleServer.vehicle_get_speed(vehicle), _elapsed,
        ])
    await %World.unload_scenery()
    get_tree().quit()


func _process(delta: float) -> void:
    _elapsed += delta
    if _driven.is_valid():
        _acknowledge_alerter()
    if _rig.is_empty():
        return
    _rig_elapsed += delta
    var camera: Camera3D = get_viewport().get_camera_3d()
    var train: Transform3D = _travel_frame()
    var weight: float = clampf(_rig_elapsed / (_rig["pre_roll"] + _rig["duration"]), 0.0, 1.0)
    var from: Vector3 = _rig_point(_rig["from"])
    var anchor: Transform3D = _rig_ground if _rig.get("anchor", "") == ANCHOR_GROUND else train
    camera.global_position = anchor * from.lerp(_rig_point(_rig.get("to", _rig["from"])), weight)
    var look: Vector3 = _rig_point(_rig["look"])
    camera.look_at(train * look.lerp(_rig_point(_rig.get("look_to", _rig["look"])), weight))
    var fov: float = _rig.get("fov", RIG_FOV)
    camera.fov = lerpf(fov, _rig.get("fov_to", fov), weight)
    if _rig.has("focus") and not camera == _focused:
        var focus: float = _rig["focus"]
        var lens: CameraAttributesPractical = CameraAttributesPractical.new()
        lens.dof_blur_near_enabled = true
        lens.dof_blur_near_distance = focus * FOCUS_NEAR_SHARE
        lens.dof_blur_near_transition = focus * FOCUS_NEAR_SHARE
        lens.dof_blur_far_enabled = true
        lens.dof_blur_far_distance = focus * FOCUS_FAR_SHARE
        lens.dof_blur_far_transition = focus * FOCUS_TRANSITION_SHARE
        lens.dof_blur_amount = FOCUS_BLUR
        camera.attributes = lens
        _focused = camera


## The free camera taken for the shot's rig, beside the first vehicle of `vehicle`'s train on the
## way it runs - read from where the vehicle goes, a train runs either end first
func _show_rig(shot: Dictionary, vehicle: RID) -> void:
    var before: Vector3 = VehicleServer.vehicle_get_position(vehicle)
    for frame: int in HEADING_FRAMES:
        await get_tree().process_frame
    var way: Vector3 = VehicleServer.vehicle_get_position(vehicle) - before
    _rig_vehicle = vehicle
    for end: RailVehicleController.CouplerEnd in [
        RailVehicleController.COUPLER_END_FRONT, RailVehicleController.COUPLER_END_REAR,
    ]:
        var last: RID = RailVehicleServer.vehicle_get_coupled(
            vehicle, end, RailVehicleController.COUPLING_FLAG_COUPLER)[0]
        if (VehicleServer.vehicle_get_position(last) - VehicleServer.vehicle_get_position(_rig_vehicle)).dot(way) > 0.0:
            _rig_vehicle = last
    _rig_reversed = RailVehicleServer.vehicle_get_transform(_rig_vehicle).basis.z.dot(way) > 0.0
    # a train standing has no way: ahead is where its driver's cab looks
    if way.is_zero_approx():
        _rig_reversed = RailVehicleServer.cabin_get_kind(RailVehicleServer.vehicle_get_driver_cabin(
            _rig_vehicle)) == RailVehicleCabinKind.RAIL_VEHICLE_CABIN_REAR
    _rig_ground = _travel_frame()
    _rig_elapsed = 0.0
    PlayerServer.player_leave_vehicle()
    PlayerCameraServer.camera_show_vehicle(_rig_vehicle)
    _rig = shot


## The rig's vehicle as the rig's points are given: x to the right of the way it runs, y up, -z ahead
func _travel_frame() -> Transform3D:
    var body: Transform3D = RailVehicleServer.vehicle_get_transform(_rig_vehicle)
    var ahead: Vector3 = body.basis.z.normalized() if _rig_reversed else -body.basis.z.normalized()
    var up: Vector3 = body.basis.y.normalized()
    return Transform3D(Basis(ahead.cross(up), up, -ahead), body.origin)


## A rig's point of SHOTS_FILE - metres to the right, up and ahead of the vehicle's middle
func _rig_point(values: Array) -> Vector3:
    return Vector3(values[0], values[1], -values[2])


## A take's "drive": after its "after" seconds the vehicle's driver is let go and the master
## controller put at "controller" - at once, or a position every "step" seconds, as a controller of
## resistor steps is moved. The train runs on with nobody minding signals or limits
func _drive(drive: Dictionary) -> void:
    await get_tree().create_timer(drive["after"]).timeout
    var vehicle: RID = VehicleServer.vehicle_get_rid_by_id(drive["vehicle"])
    DriverServer.driver_attach_implementation(DriverServer.vehicle_get_driver(vehicle), &"")
    _driven = vehicle
    if not drive.has("step"):
        VehicleServer.vehicle_send_command(vehicle, "main_controller_set_position", int(drive["controller"]), null)
        return
    for position: int in int(drive["controller"]):
        VehicleServer.vehicle_send_command(vehicle, "main_controller_increase", null, null)
        await get_tree().create_timer(drive["step"]).timeout


## The alerter and the cab signal of the vehicle driven answered as its driver did (the AI
## driver's own step, MaszynaLegacyDriverHints), or they would brake the train
func _acknowledge_alerter() -> void:
    var security: RailVehicleSecuritySystem = RailVehicleServer.vehicle_component_get(
        _driven, RailVehicleComponentType.COMPONENT_SECURITY) as RailVehicleSecuritySystem
    if not security or not security.get_blinking():
        return
    var cabin: RID = RailVehicleServer.vehicle_get_driver_cabin(_driven)
    for control: StringName in [MaszynaLegacyDriverHints.SECURITY_RESET, MaszynaLegacyDriverHints.CABSIGNAL_RESET]:
        if CabinSystem.has_control(cabin, control):
            CabinSystem.act(cabin, control, &"hold")
            CabinSystem.act(cabin, control, &"release")
