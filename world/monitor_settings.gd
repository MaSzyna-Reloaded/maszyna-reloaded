class_name MonitorSettings
extends RefCounted

## The monitors as the player sets them (settings.json, "Monitors in use" and the rows of the
## configured monitor on the Display page): one UserSettings section per monitor, of plain numbers the settings' rows can hold, turned
## into what MultiMonitorRig takes. The main window is the first monitor.

const SECTION: String = "multimonitor"
const COUNT_KEY: String = "monitor_count"
const MONITOR_SECTION: String = "multimonitor_%d"
## The display a monitor stands on; by default its own number
const SCREEN_KEY: String = "screen"
## The other monitors' windows, for a window manager's rules (a monitor's "window_title" unset)
const WINDOW_TITLE: String = "MaSzyna Reloaded - Monitor %d"


## The monitors stand in a row, curved by this angle between neighbours, and the eye this far from
## the middle one: layout_apply() works every monitor's view out of them
const ANGLE_KEY: String = "monitor_angle"
const EYE_DISTANCE_KEY: String = "eye_distance"
const DEFAULT_ANGLE: float = 0.0
const DEFAULT_EYE_DISTANCE: float = 0.4
## What layout_apply() sets of a monitor, and from what
const LAYOUT_KEYS: Array[String] = [
    "projection_mode", "screen_yaw", "center_x", "center_y", "center_z",
]


## The monitors the player can set up: one per display connected
static func monitor_get_limit() -> int:
    return maxi(DisplayServer.get_screen_count(), 1)


## The monitors in use; none while the main window alone stands as it does without the addon
static func monitors_get() -> Array[Dictionary]:
    var monitors: Array[Dictionary] = []
    var count: int = clampi(int(UserSettings.get_setting(SECTION, COUNT_KEY, 1)), 1, monitor_get_limit())
    for index: int in count:
        monitors.append(_monitor_get(index))
    if count == 1 and MonitorConfig.from_dictionary(monitors[0]).is_default():
        monitors.clear()
    return monitors


## Every monitor in use set up from the angle between them, the eye's distance and the size of the
## first one: the monitors ordered as their displays stand, left to right, around the main window's.
## The main window alone goes back to what it is without the addon
static func layout_apply() -> void:
    var count: int = clampi(int(UserSettings.get_setting(SECTION, COUNT_KEY, 1)), 1, monitor_get_limit())
    if count == 1:
        for key: String in LAYOUT_KEYS:
            UserSettings.erase_setting(MONITOR_SECTION % 0, key)
        return
    var order: Array[int] = []
    for index: int in count:
        order.append(index)
    order.sort_custom(func(a: int, b: int) -> bool:
        return _screen_get(a).x < _screen_get(b).x
    )
    var first: MonitorConfig = MonitorConfig.from_dictionary(_monitor_get(0))
    var row: Array[Dictionary] = MonitorProjection.curved_row(
        count, order.find(0), first.screen_size,
        UserSettings.get_setting(SECTION, ANGLE_KEY, DEFAULT_ANGLE),
        UserSettings.get_setting(SECTION, EYE_DISTANCE_KEY, DEFAULT_EYE_DISTANCE)
    )
    for place: int in count:
        var section: String = MONITOR_SECTION % order[place]
        var center: Vector3 = row[place][&"screen_center"]
        UserSettings.set_setting(section, "projection_mode", MonitorConfig.ProjectionMode.GEOMETRY)
        UserSettings.set_setting(section, "screen_yaw", (row[place][&"screen_rotation"] as Vector3).x)
        UserSettings.set_setting(section, "center_x", center.x)
        UserSettings.set_setting(section, "center_y", center.y)
        UserSettings.set_setting(section, "center_z", center.z)


## Where the display of monitor `index` stands on the desktop
static func _screen_get(index: int) -> Vector2i:
    var screen: int = int(UserSettings.get_setting(MONITOR_SECTION % index, SCREEN_KEY, index))
    return DisplayServer.screen_get_position(screen)


static func _monitor_get(index: int) -> Dictionary:
    var defaults: MonitorConfig = MonitorConfig.new()
    var section: String = MONITOR_SECTION % index
    var title: String = UserSettings.get_setting(section, "window_title", "")
    var monitor: MonitorConfig = MonitorConfig.new()
    monitor.screen = int(UserSettings.get_setting(section, SCREEN_KEY, index))
    monitor.window_title = title if title or index == 0 else WINDOW_TITLE % (index + 1)
    monitor.projection_mode = int(UserSettings.get_setting(section, "projection_mode", defaults.projection_mode))
    monitor.fov_vertical = UserSettings.get_setting(section, "fov_vertical", defaults.fov_vertical)
    monitor.render_interior = UserSettings.get_setting(section, "render_interior", defaults.render_interior)
    monitor.camera_angle = _vector_get(section, "camera", ["yaw", "pitch", "roll"], defaults.camera_angle)
    monitor.camera_offset = _vector_get(section, "offset", ["x", "y", "z"], defaults.camera_offset)
    monitor.screen_center = _vector_get(section, "center", ["x", "y", "z"], defaults.screen_center)
    monitor.screen_rotation = _vector_get(section, "screen", ["yaw", "pitch", "roll"], defaults.screen_rotation)
    monitor.screen_size = Vector2(
        UserSettings.get_setting(section, "screen_width", defaults.screen_size.x),
        UserSettings.get_setting(section, "screen_height", defaults.screen_size.y)
    )
    return monitor.to_dictionary()


## A vector of the three keys `<prefix>_<axis>`
static func _vector_get(section: String, prefix: String, axes: Array[String], default: Vector3) -> Vector3:
    var vector: Vector3 = default
    for axis: int in axes.size():
        vector[axis] = UserSettings.get_setting(section, "%s_%s" % [prefix, axes[axis]], default[axis])
    return vector
