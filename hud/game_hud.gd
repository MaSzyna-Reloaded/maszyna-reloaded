extends Control

## The game's HUD: the top bar with its menus - "Simulator", "View" and "Diagnostics", the last
## one filled and handled by the DebugHud's windows - and the cards. The "Simulator" menu's entries
## are the scene's business, each one a signal of its own - but "Help", a card of this HUD.

## "Simulator" > "Settings"
signal settings_requested
## "Simulator" > "Report a problem or suggestion"
signal problem_report_requested
## "Simulator" > "Exit to menu"
signal exit_to_menu_requested

## The entries of the "Simulator" menu, by their ids - a separator (id 3) stands before EXIT_TO_MENU
enum SimulatorItem { SETTINGS = 0, PROBLEM_REPORT = 1, EXIT_TO_MENU = 2, HELP = 4 }
## The entries of the "View" menu
enum ViewItem { TRANSCRIPTS, DRIVING_AID, HINTS, TIMETABLE, SCENARIO, CONTROLS, SCRIPTS, TRAINSETS, CARD, SIMULATION_SPEED, LOGS }

## The HUD elements' names in HUDServer
const PANEL_TRANSCRIPTS:StringName = &"transcripts"
const PANEL_DRIVING_AID:StringName = &"driving_aid"
const PANEL_HINTS:StringName = &"hints"
const PANEL_TIMETABLE:StringName = &"timetable"
const PANEL_SCENARIO:StringName = &"scenario"
const PANEL_SCRIPTS:StringName = &"scripts"
const PANEL_TRAINSETS:StringName = &"trainsets"
const PANEL_SIMULATION_SPEED:StringName = &"simulation_speed"
const PANEL_HELP:StringName = &"help"
const PANEL_LOGS:StringName = &"logs"
## The View menu's entries of HUD elements; CONTROLS is not one - the control windows are the
## DebugHud's
const VIEW_PANELS:Dictionary[ViewItem, StringName] = {
    ViewItem.TRANSCRIPTS: PANEL_TRANSCRIPTS,
    ViewItem.DRIVING_AID: PANEL_DRIVING_AID,
    ViewItem.HINTS: PANEL_HINTS,
    ViewItem.TIMETABLE: PANEL_TIMETABLE,
    ViewItem.SCENARIO: PANEL_SCENARIO,
    ViewItem.SCRIPTS: PANEL_SCRIPTS,
    ViewItem.TRAINSETS: PANEL_TRAINSETS,
    ViewItem.SIMULATION_SPEED: PANEL_SIMULATION_SPEED,
    ViewItem.LOGS: PANEL_LOGS,
}

const VEHICLE_CARD:PackedScene = preload("vehicle_card.tscn")

## The "Diagnostics" entry of the frame time statistics (DebugMenu), after the DebugHud's
var _frame_times_index: int = -1
## The vehicle card, while HUDServer has one open
var _card: VehicleCard = null
## Where the card was when it was last closed; it opens there again (no area until then)
var _card_rect: Rect2 = Rect2()


## The HUD draws what HUDServer, PlayerCameraServer and PlayerServer hold, and asks them for every change
func _ready() -> void:
    HUDServer.panel_visibility_changed.connect(_on_panel_visibility_changed)
    HUDServer.hud_visibility_changed.connect(_on_hud_visibility_changed)
    HUDServer.card_changed.connect(_on_card_changed)
    PlayerCameraServer.camera_changed.connect(_show_chips)
    PlayerServer.player_vehicle_changed.connect(_on_player_vehicle_changed)
    SceneryHUDMouseServer.vehicle_pressed.connect(HUDServer.card_open)
    %DebugHud.fill_menu(%Diagnostics)
    %Diagnostics.add_item("Frame time statistics")
    _frame_times_index = %Diagnostics.item_count - 1
    %Diagnostics.set_item_shortcut(_frame_times_index, ActionShortcut.create(&"cycle_debug_menu"))
    # the menus show their keys and handle them: a key picks its entry as a click would
    %Simulator.set_item_shortcut(
        %Simulator.get_item_index(SimulatorItem.EXIT_TO_MENU), ActionShortcut.create(&"menu_back")
    )
    # F11 - free in the original
    %Simulator.set_item_shortcut(
        %Simulator.get_item_index(SimulatorItem.SETTINGS), ActionShortcut.create(&"settings_open")
    )
    # F2, as the original's (driveruilayer.cpp:155)
    %View.set_item_shortcut(ViewItem.TIMETABLE, ActionShortcut.create(&"timetable_toggle"))
    # Shift+F2 - free in the original, whose F-keys ignore modifiers (driveruilayer.cpp:115)
    %View.set_item_shortcut(ViewItem.SCENARIO, ActionShortcut.create(&"scenario_toggle"))
    # F12 - free in the original without Shift (driveruilayer.cpp:174)
    %View.set_item_shortcut(ViewItem.CONTROLS, ActionShortcut.create(&"hud_toggle"))
    # F1, as the original's driving aid (driveruilayer.cpp:76)
    %View.set_item_shortcut(ViewItem.DRIVING_AID, ActionShortcut.create(&"driving_aid_toggle"))
    # F3, as the original's scenario window with its hints (driveruilayer.cpp:168)
    %View.set_item_shortcut(ViewItem.HINTS, ActionShortcut.create(&"hints_toggle"))
    # F7 and Shift+F7 - the original's F7 works only in its debug mode (wireframe), Shift+F7 not at
    # all (drivermode.cpp:994-1020)
    %View.set_item_shortcut(ViewItem.CARD, ActionShortcut.create(&"vehicle_card_toggle"))
    %View.set_item_shortcut(ViewItem.TRAINSETS, ActionShortcut.create(&"trainsets_toggle"))
    # the transcripts, the driving aid and the hints are open from the start
    HUDServer.panel_set_visible(PANEL_TRANSCRIPTS, true)
    HUDServer.panel_set_visible(PANEL_DRIVING_AID, true)
    HUDServer.panel_set_visible(PANEL_HINTS, true)


func _exit_tree() -> void:
    HUDServer.panel_visibility_changed.disconnect(_on_panel_visibility_changed)
    HUDServer.hud_visibility_changed.disconnect(_on_hud_visibility_changed)
    HUDServer.card_changed.disconnect(_on_card_changed)
    PlayerCameraServer.camera_changed.disconnect(_show_chips)
    PlayerServer.player_vehicle_changed.disconnect(_on_player_vehicle_changed)
    SceneryHUDMouseServer.vehicle_pressed.disconnect(HUDServer.card_open)


func _on_diagnostics_menu_index_pressed(index: int) -> void:
    if index == _frame_times_index:
        DebugMenu.cycle_style()


func _on_simulator_menu_id_pressed(id: int) -> void:
    match id:
        SimulatorItem.SETTINGS:
            settings_requested.emit()
        SimulatorItem.PROBLEM_REPORT:
            problem_report_requested.emit()
        SimulatorItem.HELP:
            HUDServer.panel_toggle(PANEL_HELP)
        SimulatorItem.EXIT_TO_MENU:
            exit_to_menu_requested.emit()


## The "View" menu: its entries show or hide the transcripts, the driving aid, the hints, the timetable, the
## scenario, all the control windows at once, the Lua editor, the trainset list, the vehicle card,
## the simulation speed and the logs
func _on_view_menu_index_pressed(index: int) -> void:
    # the card of the player's vehicle, or the open one closed
    if index == ViewItem.CARD:
        if HUDServer.card_get_vehicle().is_valid():
            HUDServer.card_close()
            return
        HUDServer.card_open(PlayerServer.player_get_vehicle())
        return
    if index == ViewItem.CONTROLS:
        %View.toggle_item_checked(index)
        %DebugHud.windows_set_visible(%View.is_item_checked(index))
        return
    HUDServer.panel_toggle(VIEW_PANELS[index])


## A HUD element opened or closed in HUDServer: its View menu entry ticked, the element shown
func _on_panel_visibility_changed(panel: StringName, shown: bool) -> void:
    var item: Variant = VIEW_PANELS.find_key(panel)
    if not item == null:
        %View.set_item_checked(item, shown)
    match panel:
        PANEL_TRANSCRIPTS:
            %TranscriptsPanel.set_shown(shown)
        PANEL_DRIVING_AID:
            %DrivingAid.visible = shown
        PANEL_HINTS:
            %DriverHints.visible = shown
        PANEL_TIMETABLE:
            %TimetablePanel.visible = shown
        PANEL_SCENARIO:
            %ScenarioPanel.visible = shown
        PANEL_SCRIPTS:
            %ScriptEditorPanel.visible = shown
        PANEL_TRAINSETS:
            %VehicleSelectorPanel.visible = shown
        PANEL_SIMULATION_SPEED:
            %SimulationSpeedPanel.visible = shown
        PANEL_HELP:
            %HelpPanel.visible = shown
        PANEL_LOGS:
            %LogsPanel.visible = shown


func _on_hud_visibility_changed(shown: bool) -> void:
    visible = shown


func _on_timetable_panel_close_requested() -> void:
    HUDServer.panel_set_visible(PANEL_TIMETABLE, false)


func _on_timetable_panel_timetable_received() -> void:
    HUDServer.panel_set_visible(PANEL_TIMETABLE, true)


func _on_scenario_panel_close_requested() -> void:
    HUDServer.panel_set_visible(PANEL_SCENARIO, false)


func _on_help_panel_close_requested() -> void:
    HUDServer.panel_set_visible(PANEL_HELP, false)


func _on_script_editor_panel_close_requested() -> void:
    HUDServer.panel_set_visible(PANEL_SCRIPTS, false)


func _on_vehicle_selector_panel_close_requested() -> void:
    HUDServer.panel_set_visible(PANEL_TRAINSETS, false)


func _on_logs_panel_close_requested() -> void:
    HUDServer.panel_set_visible(PANEL_LOGS, false)


## A click on a selector row: the card shows the row's vehicle; the vehicle of the open card clicked
## again closes it
func _on_vehicle_selector_panel_vehicle_activated(vehicle: RID) -> void:
    if HUDServer.card_get_vehicle() == vehicle:
        HUDServer.card_close()
        return
    HUDServer.card_open(vehicle)


## The followed vehicle's floating button gives way to its card
func _on_followed_vehicle_chip_pressed() -> void:
    HUDServer.card_open(%FollowedVehicleChip.vehicle)


func _on_followed_vehicle_chip_action_pressed() -> void:
    PlayerCameraServer.camera_set_mode(PlayerCameraServer.CAMERA_MODE_FREE)


## The card shows HUDServer's vehicle, on top, and its row is lit; a card opened anew stands where
## the last one was closed, and takes the place of the followed vehicle's floating button. Closed,
## it is remembered where it stood and no row is lit.
func _on_card_changed(vehicle: RID) -> void:
    %VehicleSelectorPanel.show_active_vehicle(vehicle)
    %View.set_item_checked(ViewItem.CARD, vehicle.is_valid())
    if not vehicle.is_valid():
        _card_rect = _card.get_rect()
        _card.queue_free()
        _card = null
        _show_chips()
        return
    if not _card:
        _card = VEHICLE_CARD.instantiate()
        _card.close_requested.connect(HUDServer.card_close)
        _card.remove_trainset_requested.connect(_remove_trainset)
        %VehicleCards.add_child(_card)
        if _card_rect.has_area():
            _card.position = _card_rect.position
            _card.size = _card_rect.size
        _show_chips()
    %VehicleCards.move_child(_card, -1)
    _card.show_vehicle(vehicle)


## The floating buttons: the followed vehicle's while no card is open, the player's vehicle's while
## the player has one, in its cab as well
func _show_chips() -> void:
    %FollowedVehicleChip.show_vehicle(PlayerCameraServer.camera_get_target()
            if PlayerCameraServer.camera_get_mode() == PlayerCameraServer.CAMERA_MODE_FOLLOW and not _card else RID())
    %PlayerVehicleChip.show_vehicle(PlayerServer.player_get_vehicle())


## Every vehicle of the trainset freed; a player in its cab steps out first, as before a scenery
## is freed - the camera lives in the vehicle's cabin (MaszynaPlayer.clear_start_train())
func _remove_trainset(vehicle: RID) -> void:
    var trainset: Array[RID] = RailVehicleServer.vehicle_get_coupled(
            vehicle, RailVehicleController.COUPLER_END_FRONT, RailVehicleController.COUPLING_FLAG_COUPLER)
    if trainset.has(PlayerServer.player_get_vehicle()):
        PlayerServer.player_leave_vehicle()
    # a vehicle built from MaSzyna data is freed where it was made; one assembled by hand goes
    # with its nodes, and stays (TODO.md)
    for trainset_vehicle: RID in trainset:
        if MaszynaLegacyVehicleSystem.vehicle_exists(trainset_vehicle):
            MaszynaLegacyVehicleSystem.vehicle_free(trainset_vehicle)


## The script context of the scenario being played, for the Lua editor; an invalid RID while none is
func attach_script_context(context: RID) -> void:
    %ScriptEditorPanel.attach_context(context)


## The environment of the world being shown, for the weather and time window; null while there is
## no world (the menu)
func attach_environment(environment: MaszynaEnvironmentNode) -> void:
    %DebugHud.attach_environment(environment)


## The scenario the player has started, for the "Scenario" entry of the View menu - hidden until
## the player opens it
func show_scenario(info: MaszynaSceneryInfo, train_id: String) -> void:
    %ScenarioPanel.show_scenario(info, train_id)
    %VehicleSelectorPanel.show_scenario(info)


## What shows the player's train follows the vehicle the player drives: the timetable of its
## trainset, the driving aid, its row in the selector (the control windows follow it themselves,
## DebugHud)
func _on_player_vehicle_changed(vehicle: RID, _previous: RID) -> void:
    %TimetablePanel.follow_vehicle(vehicle)
    %DrivingAid.show_vehicle(vehicle)
    %DriverHints.show_vehicle(vehicle)
    %VehicleSelectorPanel.follow_player_vehicle(vehicle)
    _show_chips()


func _on_player_vehicle_chip_pressed() -> void:
    PlayerCameraServer.camera_set_mode(PlayerCameraServer.CAMERA_MODE_CABIN)


func _on_player_vehicle_chip_action_pressed() -> void:
    PlayerServer.player_leave_vehicle()


## The driver of the player's vehicle switched, as by the vehicle card's AI button: the player's to
## the AI, the AI's and nobody's to the player
func _on_player_vehicle_chip_driver_pressed() -> void:
    var vehicle: RID = %PlayerVehicleChip.vehicle
    if VehicleSelectorRow.driver_of(vehicle, true) == VehicleSelectorRow.Driver.PLAYER:
        PlayerServer.player_hand_over_vehicle()
    else:
        PlayerServer.player_take_back_vehicle()

