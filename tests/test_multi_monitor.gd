extends MaszynaGutTest

## The multimonitor addon: what a monitor's view computes to, and the windows and cameras the rig makes
## and lets go of. Headless, a window is embedded, which the rig's work does not depend on.

const NEAR: float = 0.1
const FAR: float = 1000.0
const EPSILON: float = 0.001
const VIEW_FOV: float = 50.0
## MultiMonitorRig.reference_fov
const REFERENCE_FOV: float = 45.0
const SETTINGS_SCREEN: PackedScene = preload("res://settings/settings_screen.tscn")
const INTERIOR_LAYER: int = 1 << 18
const ALL_LAYERS: int = (1 << 20) - 1

var _holder: Node3D = null
var _source: Camera3D = null
var _rig: MultiMonitorRig = null


func before_each() -> void:
    _holder = Node3D.new()
    _source = Camera3D.new()
    _source.near = NEAR
    _source.far = FAR
    _source.fov = REFERENCE_FOV
    _holder.add_child(_source)
    _rig = MultiMonitorRig.new()
    _rig.interior_layers = INTERIOR_LAYER
    # the rig goes first, as it does in the world: it stands after the camera's owner
    add_child_autofree(_rig)
    add_child_autofree(_holder)


## What the player has saved, back - nothing a test set stays
func after_each() -> void:
    UserSettings.load_config()


## The tests' monitors are their own, whatever the player has saved; loaded back after each test
func _forget_saved_monitors() -> void:
    UserSettings.erase_setting(MonitorSettings.SECTION, MonitorSettings.COUNT_KEY)
    for index: int in MonitorSettings.monitor_get_limit():
        for key: String in MonitorSettings.LAYOUT_KEYS:
            UserSettings.erase_setting(MonitorSettings.MONITOR_SECTION % index, key)


func _monitors(count: int) -> Array[Dictionary]:
    var monitors: Array[Dictionary] = []
    for index: int in count:
        var monitor: MonitorConfig = MonitorConfig.new()
        monitor.window_title = "monitor %d" % index
        monitors.append(monitor.to_dictionary())
    return monitors


func test_a_dictionary_gives_the_monitor_back() -> void:
    var monitor: MonitorConfig = MonitorConfig.new()
    monitor.screen = 2
    monitor.window_title = "left"
    monitor.projection_mode = MonitorConfig.ProjectionMode.GEOMETRY
    monitor.camera_angle = Vector3(-45.0, 0.0, 0.0)
    monitor.render_interior = false
    assert_eq(MonitorConfig.from_dictionary(monitor.to_dictionary()).to_dictionary(), monitor.to_dictionary())


func test_a_dictionary_without_a_field_leaves_its_default() -> void:
    assert_true(MonitorConfig.from_dictionary({}).is_default())


func test_yaw_turns_to_the_right() -> void:
    var forward: Vector3 = MonitorProjection.angle_to_basis(Vector3(90.0, 0.0, 0.0)) * Vector3.FORWARD
    assert_almost_eq(forward, Vector3.RIGHT, Vector3.ONE * EPSILON)


func test_pitch_turns_up() -> void:
    var forward: Vector3 = MonitorProjection.angle_to_basis(Vector3(0.0, 90.0, 0.0)) * Vector3.FORWARD
    assert_almost_eq(forward, Vector3.UP, Vector3.ONE * EPSILON)


func test_a_screen_straight_ahead_has_no_frustum_offset() -> void:
    var monitor: MonitorConfig = MonitorConfig.new()
    monitor.projection_mode = MonitorConfig.ProjectionMode.GEOMETRY
    monitor.screen_size = Vector2(0.6, 0.4)
    monitor.screen_center = Vector3(0.0, 0.0, -0.8)
    assert_almost_eq(MonitorProjection.frustum_size(monitor, NEAR), 0.4 * NEAR / 0.8, EPSILON)
    assert_almost_eq(MonitorProjection.frustum_offset(monitor, NEAR), Vector2.ZERO, Vector2.ONE * EPSILON)


func test_an_eye_beside_the_screen_shifts_the_frustum() -> void:
    var monitor: MonitorConfig = MonitorConfig.new()
    monitor.projection_mode = MonitorConfig.ProjectionMode.GEOMETRY
    monitor.screen_center = Vector3(0.4, 0.0, -0.8)
    assert_almost_eq(MonitorProjection.frustum_offset(monitor, NEAR), Vector2(0.05, 0.0), Vector2.ONE * EPSILON)


## The screen turned about the head at 45 or 60 degrees stands square before its camera, with no shift
func test_a_screen_turned_around_the_head_looks_straight_at_it() -> void:
    for angle: float in [45.0, 60.0]:
        var monitor: MonitorConfig = MonitorConfig.new()
        monitor.projection_mode = MonitorConfig.ProjectionMode.GEOMETRY
        monitor.screen_rotation = Vector3(angle, 0.0, 0.0)
        monitor.screen_center = MonitorProjection.angle_to_basis(monitor.screen_rotation) * Vector3(0.0, 0.0, -0.7)
        assert_almost_eq(MonitorProjection.frustum_offset(monitor, NEAR), Vector2.ZERO, Vector2.ONE * EPSILON)
        assert_almost_eq(
            MonitorProjection.frustum_size(monitor, NEAR), monitor.screen_size.y * NEAR / 0.7, EPSILON
        )


## Neighbours meet at their edge: seen from the head, the middle screen's right edge is the right
## one's left edge
func test_a_curved_row_meets_at_the_edges() -> void:
    var size: Vector2 = Vector2(0.6, 0.34)
    var row: Array[Dictionary] = MonitorProjection.curved_row(3, 1, size, 20.0, 0.4)
    var half: Vector3 = Vector3.RIGHT * size.x / 2.0
    assert_almost_eq(row[1][&"screen_center"], Vector3(0.0, 0.0, -0.4), Vector3.ONE * EPSILON)
    assert_almost_eq(
        row[1][&"screen_center"] + half,
        row[2][&"screen_center"] - MonitorProjection.angle_to_basis(row[2][&"screen_rotation"]) * half,
        Vector3.ONE * EPSILON
    )
    assert_almost_eq(
        row[1][&"screen_center"] - half,
        row[0][&"screen_center"] + MonitorProjection.angle_to_basis(row[0][&"screen_rotation"]) * half,
        Vector3.ONE * EPSILON
    )
    assert_eq(row[2][&"screen_rotation"], Vector3(20.0, 0.0, 0.0))
    assert_eq(row[0][&"screen_rotation"], Vector3(-20.0, 0.0, 0.0))


func test_a_curved_row_turns_towards_the_head() -> void:
    var row: Array[Dictionary] = MonitorProjection.curved_row(3, 1, Vector2(0.6, 0.34), 20.0, 0.4)
    assert_gt(row[2][&"screen_center"].z, -0.4)


func test_several_monitors_share_one_exposure() -> void:
    _rig.rig_configure(_monitors(2))
    _rig.rig_set_source_camera(_source)
    assert_not_null(_rig.rig_get_camera(0).attributes)
    assert_eq(_rig.rig_get_camera(0).attributes, _rig.rig_get_camera(1).attributes)


func test_the_mouse_camera_is_the_main_monitors_after_a_view_change() -> void:
    watch_signals(_rig)
    _rig.rig_configure(_monitors(2))
    _rig.rig_set_source_camera(_source)
    assert_signal_emitted_with_parameters(_rig, "rig_mouse_camera_changed", [_rig.rig_get_camera(0)])


func test_the_mouse_on_a_window_goes_to_its_camera() -> void:
    _rig.rig_configure(_monitors(2))
    _rig.rig_set_source_camera(_source)
    watch_signals(_rig)
    var motion: InputEventMouseMotion = InputEventMouseMotion.new()
    _rig.rig_get_camera(1).get_window().window_input.emit(motion)
    assert_signal_emitted_with_parameters(_rig, "rig_mouse_camera_changed", [_rig.rig_get_camera(1)])
    assert_signal_emitted_with_parameters(_rig, "rig_mouse_input", [motion])


func test_the_mouse_back_on_the_main_window_goes_to_its_camera() -> void:
    _rig.rig_configure(_monitors(2))
    _rig.rig_set_source_camera(_source)
    _rig.rig_get_camera(1).get_window().window_input.emit(InputEventMouseMotion.new())
    watch_signals(_rig)
    get_window().window_input.emit(InputEventMouseMotion.new())
    assert_signal_emitted_with_parameters(_rig, "rig_mouse_camera_changed", [_rig.rig_get_camera(0)])


func test_without_monitors_the_mouse_stays_on_the_source() -> void:
    watch_signals(_rig)
    _rig.rig_set_source_camera(_source)
    assert_signal_emitted_with_parameters(_rig, "rig_mouse_camera_changed", [_source])


## Whatever the zoom, neighbours meet: the shared edge is one direction from the head on both
func test_zoom_keeps_the_seams_of_a_curved_row() -> void:
    var size: Vector2 = Vector2(0.6, 0.34)
    var row: Array[Dictionary] = MonitorProjection.curved_row(3, 1, size, 20.0, 0.4)
    for zoom: float in [0.7, 1.0, 2.0, 5.0]:
        var main: MonitorConfig = _screen(row[1], size)
        var side: MonitorConfig = _screen(row[2], size)
        var main_view: MonitorConfig = MonitorProjection.zoomed(main, zoom, 0.4)
        var side_view: MonitorConfig = MonitorProjection.zoomed(side, zoom, 0.4)
        var half: Vector3 = Vector3.RIGHT * size.x / 2.0
        var main_edge: Vector3 = main_view.screen_center + half
        var side_edge: Vector3 = (
            side_view.screen_center - MonitorProjection.angle_to_basis(side.screen_rotation) * half
        )
        assert_almost_eq(main_edge, side_edge, Vector3.ONE * EPSILON)


func test_zoom_narrows_the_main_screen_by_the_zoom() -> void:
    var monitor: MonitorConfig = MonitorConfig.new()
    monitor.projection_mode = MonitorConfig.ProjectionMode.GEOMETRY
    var near_size: float = MonitorProjection.frustum_size(monitor, NEAR)
    var zoomed: MonitorConfig = MonitorProjection.zoomed(monitor, 2.0, 0.7)
    assert_almost_eq(MonitorProjection.frustum_size(zoomed, NEAR), near_size / 2.0, EPSILON)


func test_zooming_out_keeps_a_screen_in_front_of_the_head() -> void:
    var row: Array[Dictionary] = MonitorProjection.curved_row(3, 1, Vector2(0.6, 0.34), 60.0, 0.4)
    var side: MonitorConfig = _screen(row[2], Vector2(0.6, 0.34))
    var view: MonitorConfig = MonitorProjection.zoomed(side, 0.1, 0.4)
    assert_gt(MonitorProjection.frustum_size(view, NEAR), 0.0)


func test_the_cameras_follow_the_source_field_of_view() -> void:
    var monitors: Array[Dictionary] = _monitors(2)
    _source.fov = _rig.reference_fov
    _rig.rig_configure(monitors)
    _rig.rig_set_source_camera(_source)
    var fov: float = _rig.rig_get_camera(1).fov
    _source.fov = _rig.reference_fov / 2.0
    _rig.rig_update_zoom()
    assert_lt(_rig.rig_get_camera(1).fov, fov)


func _screen(place: Dictionary, size: Vector2) -> MonitorConfig:
    var monitor: MonitorConfig = MonitorConfig.from_dictionary(place)
    monitor.projection_mode = MonitorConfig.ProjectionMode.GEOMETRY
    monitor.screen_size = size
    return monitor


func test_one_default_monitor_makes_nothing() -> void:
    _source.make_current()
    var monitors: Array[Dictionary] = [MonitorConfig.new().to_dictionary()]
    _rig.rig_configure(monitors)
    _rig.rig_set_source_camera(_source)
    assert_eq(_rig.rig_get_window_count(), 0)
    assert_eq(_source.get_child_count(), 0)
    assert_true(_source.current)


func test_every_monitor_has_a_camera_and_the_main_one_is_current() -> void:
    _source.make_current()
    _rig.rig_configure(_monitors(3))
    _rig.rig_set_source_camera(_source)
    assert_eq(_rig.rig_get_window_count(), 2)
    assert_true(_rig.rig_get_camera(0).current)
    assert_eq(_rig.rig_get_camera(0).get_parent(), _source)
    assert_true(_rig.rig_get_camera(1).current)
    assert_ne(_rig.rig_get_camera(1).get_viewport(), _source.get_viewport())


func test_windows_share_the_world() -> void:
    _rig.rig_configure(_monitors(2))
    _rig.rig_set_source_camera(_source)
    assert_eq(_rig.rig_get_camera(1).get_world_3d(), _source.get_world_3d())


func test_a_side_camera_follows_the_source_through_a_new_parent() -> void:
    var monitors: Array[Dictionary] = _monitors(2)
    monitors[1]["camera_offset"] = Vector3(1.0, 0.0, 0.0)
    _rig.rig_configure(monitors)
    _rig.rig_set_source_camera(_source)
    var other: Node3D = Node3D.new()
    other.position = Vector3(10.0, 0.0, 0.0)
    add_child_autofree(other)
    _source.reparent(other, false)
    await wait_process_frames(1)
    assert_almost_eq(
        _rig.rig_get_camera(1).global_position, Vector3(11.0, 0.0, 0.0), Vector3.ONE * EPSILON
    )


func test_a_monitor_without_the_interior_leaves_its_layers_out() -> void:
    var monitors: Array[Dictionary] = _monitors(2)
    monitors[1]["render_interior"] = false
    _source.cull_mask = ALL_LAYERS
    _rig.rig_configure(monitors)
    _rig.rig_set_source_camera(_source)
    assert_eq(_rig.rig_get_camera(0).cull_mask, ALL_LAYERS)
    assert_eq(_rig.rig_get_camera(1).cull_mask, ALL_LAYERS & ~INTERIOR_LAYER)


func test_a_camera_takes_the_source_near_and_far() -> void:
    _rig.rig_configure(_monitors(2))
    _rig.rig_set_source_camera(_source)
    assert_eq(_rig.rig_get_camera(1).far, FAR)
    assert_eq(_rig.rig_get_camera(1).near, NEAR)


func test_render_settings_reach_the_windows() -> void:
    var viewport: Viewport = get_viewport()
    _rig.rig_configure(_monitors(2))
    _rig.rig_set_source_camera(_source)
    var taa: bool = viewport.use_taa
    viewport.use_taa = not taa
    _rig.rig_copy_viewport_settings(viewport)
    assert_eq(_rig.rig_get_camera(1).get_viewport().use_taa, not taa)
    viewport.use_taa = taa


func test_a_change_of_a_view_keeps_the_windows() -> void:
    var monitors: Array[Dictionary] = _monitors(2)
    _rig.rig_configure(monitors)
    _rig.rig_set_source_camera(_source)
    var camera: Camera3D = _rig.rig_get_camera(1)
    var changed: Array[Dictionary] = _monitors(2)
    changed[1]["fov_vertical"] = VIEW_FOV
    changed[1]["window_title"] = "changed"
    _rig.rig_configure(changed)
    assert_eq(_rig.rig_get_camera(1), camera)
    assert_eq(camera.fov, VIEW_FOV)
    assert_eq(camera.get_window().title, "changed")


func test_another_display_makes_the_window_anew() -> void:
    _rig.rig_configure(_monitors(2))
    _rig.rig_set_source_camera(_source)
    var camera: Camera3D = _rig.rig_get_camera(1)
    var changed: Array[Dictionary] = _monitors(2)
    changed[1]["screen"] = 1
    _rig.rig_configure(changed)
    assert_ne(_rig.rig_get_camera(1), camera)


func test_the_settings_default_to_no_monitors() -> void:
    _forget_saved_monitors()
    assert_eq(MonitorSettings.monitors_get().size(), 0)


## Headless there is one display, so a count above it is cut to the monitors that can stand
func test_the_settings_keep_to_the_displays() -> void:
    UserSettings.set_setting(MonitorSettings.SECTION, MonitorSettings.COUNT_KEY, 8)
    UserSettings.set_setting(MonitorSettings.MONITOR_SECTION % 0, "fov_vertical", VIEW_FOV)
    assert_eq(MonitorSettings.monitors_get().size(), MonitorSettings.monitor_get_limit())


func test_the_settings_rows_reach_the_monitor() -> void:
    var section: String = MonitorSettings.MONITOR_SECTION % 0
    UserSettings.set_setting(section, "fov_vertical", VIEW_FOV)
    UserSettings.set_setting(section, "camera_yaw", 45.0)
    UserSettings.set_setting(section, "render_interior", false)
    var monitor: MonitorConfig = MonitorConfig.from_dictionary(MonitorSettings.monitors_get()[0])
    assert_eq(monitor.fov_vertical, VIEW_FOV)
    assert_eq(monitor.camera_angle, Vector3(45.0, 0.0, 0.0))
    assert_false(monitor.render_interior)


func test_the_display_page_sets_up_the_chosen_monitor() -> void:
    var screen: Control = SETTINGS_SCREEN.instantiate()
    add_child_autofree(screen)
    await wait_process_frames(1)
    var rows: Array[Node] = screen.find_children("*", "SettingMonitorChoice", true, false)
    assert_eq(rows.size(), 1)
    var choice: SettingMonitorChoice = rows[0] as SettingMonitorChoice
    assert_gt(choice.monitor_rows.size(), 0)
    assert_eq(choice.get_parent(), choice.monitor_rows[0].get_parent())
    choice.choose_monitor(1)
    for row: SettingRow in choice.monitor_rows:
        assert_eq(row.section, MonitorSettings.MONITOR_SECTION % 1)
    choice.restore_default()
    assert_eq(choice.monitor_rows[0].section, MonitorSettings.MONITOR_SECTION % 0)


func test_a_new_configuration_lets_go_of_the_old_monitors() -> void:
    _rig.rig_configure(_monitors(3))
    _rig.rig_set_source_camera(_source)
    _rig.rig_configure(_monitors(2))
    await wait_process_frames(1)
    assert_eq(_rig.rig_get_window_count(), 1)
    # the new monitor 0's camera and the follower of monitor 1
    assert_eq(_source.get_child_count(), 2)


func test_leaving_the_tree_leaves_nothing_under_the_source() -> void:
    _rig.rig_configure(_monitors(2))
    _rig.rig_set_source_camera(_source)
    remove_child(_rig)
    await wait_process_frames(1)
    assert_eq(_source.get_child_count(), 0)
    add_child(_rig)
