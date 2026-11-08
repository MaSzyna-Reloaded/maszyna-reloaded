class_name VehicleBrowserWindow
extends Control

## Every vehicle of the catalogue (VehicleCatalogServer), any provider's, in a window of the game
## (UIWindow) over the screen that opened it: a search field over the side views of the vehicles
## found, PAGE_SIZE of them at a time, of the category chosen in the sidebar
## (VehicleInfo.VehicleCategory). Enter or "Select vehicle" chooses the selected one, Escape or the
## close button leaves without; what the choice means is its owner's. The categories, the grid and
## the buttons are its three sections, Tab goes round them.

## A vehicle was chosen, in its first livery
signal vehicle_chosen(vehicle: VehicleData)
## The window went, with a vehicle chosen or without
signal closed

## The part of the game's window it takes, each way
const WINDOW_RATIO: float = 0.8
## Vehicles on one page of the grid - as many as the editor's vehicles panel shows
const PAGE_SIZE: int = 50
## The sidebar's first row, every category together
const ALL_CATEGORIES: int = -1
## The categories' names on the sidebar, as msgids, in the sidebar's order
const CATEGORY_NAMES: Dictionary[VehicleInfo.VehicleCategory, String] = {
    VehicleInfo.VehicleCategory.ELECTRIC_LOCOMOTIVE: "Electric locos",
    VehicleInfo.VehicleCategory.DIESEL_LOCOMOTIVE: "Diesel locos",
    VehicleInfo.VehicleCategory.STEAM_LOCOMOTIVE: "Steam locos",
    VehicleInfo.VehicleCategory.RAILCAR: "Railcars",
    VehicleInfo.VehicleCategory.MULTIPLE_UNIT: "EMU",
    VehicleInfo.VehicleCategory.UTILITY_VEHICLE: "Utility",
    VehicleInfo.VehicleCategory.DRAISINE: "Draisines",
    VehicleInfo.VehicleCategory.TRAM: "Trams",
    VehicleInfo.VehicleCategory.PASSENGER_CAR: "Passenger cars",
    VehicleInfo.VehicleCategory.FREIGHT_CAR: "Freight cars",
    VehicleInfo.VehicleCategory.SPECIAL: "Special",
    VehicleInfo.VehicleCategory.ROAD_TRUCK: "Trucks",
    VehicleInfo.VehicleCategory.ROAD_BUS: "Buses",
    VehicleInfo.VehicleCategory.ROAD_CAR: "Cars",
    VehicleInfo.VehicleCategory.OTHER: "Other",
}

## Every vehicle of the catalogue, by its name, as the window was last opened
var _vehicles: Array[VehicleInfo] = []
## The names of the liveries of each of them - its provider's, not the player's
var _liveries: Dictionary[VehicleInfo, PackedStringArray] = {}
## The vehicles the search found, and the page of them the grid shows
var _found: Array[VehicleInfo] = []
var _page: int = 0
## The category of each sidebar row - ALL_CATEGORIES first, then those the vehicles have - and the
## one chosen
var _listed_categories: Array[int] = []
var _category: int = ALL_CATEGORIES


## Shown as it was left - the search, the page, the selected vehicle and the scroll stay; only a
## catalogue of other vehicles (another game directory) is listed and searched anew
func open() -> void:
    _read_vehicles()
    visible = true
    %Window.show_part(WINDOW_RATIO)
    %SearchInput.grab_typing_focus()
    focus_vehicles()


func close() -> void:
    %CategoryList.release_section_focus()
    %VehicleGrid.release_section_focus()
    %ActionsSection.release_section_focus()
    %SearchInput.release_typing_focus()
    %Window.hide()
    visible = false
    closed.emit()


## The catalogue's vehicles; their categories listed again when they are not the ones listed
func _read_vehicles() -> void:
    var vehicles: Array[VehicleInfo] = []
    for category: VehicleInfo.VehicleCategory in CATEGORY_NAMES:
        vehicles.append_array(VehicleCatalogServer.vehicle_list(category))
    vehicles.sort_custom(func(a: VehicleInfo, b: VehicleInfo) -> bool: return a.vehicle < b.vehicle)
    if _vehicles.size() == vehicles.size() and range(vehicles.size()).all(
            func(index: int) -> bool: return _vehicles[index].vehicle == vehicles[index].vehicle):
        return
    _vehicles = vehicles
    _liveries.clear()
    for vehicle: VehicleInfo in _vehicles:
        var names: PackedStringArray = []
        for livery: VehicleLivery in VehicleCatalogServer.livery_list(vehicle):
            # a player's livery is not drawn yet
            if not livery.base:
                names.append(livery.name)
        _liveries[vehicle] = names
    _list_categories()


## The categories the vehicles have, in their order; the list selects the first row - every
## vehicle - and reports it back, so the search follows from there and counts them
func _list_categories() -> void:
    var categories: Dictionary[int, bool] = {}
    for vehicle: VehicleInfo in _vehicles:
        categories[vehicle.category] = true
    _listed_categories.assign([ALL_CATEGORIES])
    var names: PackedStringArray = [tr("All vehicles")]
    for category: VehicleInfo.VehicleCategory in CATEGORY_NAMES:
        if categories.has(category):
            _listed_categories.append(category)
            names.append(tr(CATEGORY_NAMES[category]))
    var notes: PackedStringArray = []
    notes.resize(names.size())
    %CategoryList.set_rows(names, notes)


func _on_category_list_item_selected(index: int) -> void:
    _category = _listed_categories[index] if index >= 0 else ALL_CATEGORIES
    search_vehicles()


## The vehicles of the chosen category whose name or a livery holds the search text (any case), from
## their first page. Every category counts what the search found in it, so the sidebar tells where
## else the text is.
func search_vehicles() -> void:
    var text: String = %SearchInput.get_text().strip_edges().to_lower()
    var matching: Array[VehicleInfo] = _vehicles.filter(func(vehicle: VehicleInfo) -> bool:
        return (not text or vehicle.vehicle.to_lower().contains(text) or vehicle.title.to_lower().contains(text)
                or " ".join(_liveries[vehicle]).to_lower().contains(text)))
    var counts: Dictionary[int, int] = {ALL_CATEGORIES: matching.size()}
    for vehicle: VehicleInfo in matching:
        counts[vehicle.category] = counts.get(vehicle.category, 0) + 1
    for row: int in _listed_categories.size():
        %CategoryList.set_row_note(row, str(counts.get(_listed_categories[row], 0)))
    _found = matching
    if not _category == ALL_CATEGORIES:
        _found = matching.filter(func(vehicle: VehicleInfo) -> bool: return vehicle.category == _category)
    show_page(0)


func show_page(page: int) -> void:
    var page_count: int = maxi(ceili(float(_found.size()) / PAGE_SIZE), 1)
    _page = clampi(page, 0, page_count - 1)
    %PageLabel.text = "%d/%d" % [_page + 1, page_count]
    %PreviousPageButton.disabled = _page <= 0
    %NextPageButton.disabled = _page >= page_count - 1
    %SelectButton.disabled = not _found
    var tiles: Array[TileGrid.Tile] = []
    for vehicle: VehicleInfo in _found.slice(_page * PAGE_SIZE, (_page + 1) * PAGE_SIZE):
        var caption: String = vehicle.title if vehicle.title else vehicle.vehicle
        tiles.append(TileGrid.Tile.new(_of(vehicle), vehicle.vehicle, caption))
    # an empty grid hides itself; the column keeps its room and says so, with the way back from a
    # search that found nothing
    %VehicleGrid.set_tiles(tiles)
    %NoneFound.visible = not tiles
    %ClearSearchButton.visible = not tiles and not %SearchInput.get_text() == ""


## The next page; past the last one the keyboard steps down to the buttons
func show_next_page() -> void:
    if _page * PAGE_SIZE + PAGE_SIZE >= _found.size():
        focus_actions()
        return
    show_page(_page + 1)


func show_previous_page() -> void:
    show_page(_page - 1)


## Up from the first row of a page: the page before, its last vehicle selected - the one right
## above where the keyboard was
func _on_vehicle_grid_navigate_up() -> void:
    if _page <= 0:
        return
    show_previous_page()
    %VehicleGrid.select(PAGE_SIZE - 1)


## The vehicle the grid has selected goes to the owner, and the window closes
func choose_selected_vehicle() -> void:
    var index: int = %VehicleGrid.get_selected()
    if index < 0:
        return
    vehicle_chosen.emit(_of(_found[_page * PAGE_SIZE + index]))
    close()


## The VehicleData of the catalogue's [param vehicle], in its first livery
func _of(vehicle: VehicleInfo) -> VehicleData:
    var data: VehicleData = VehicleData.new()
    data.vehicle_provider = vehicle.vehicle_provider
    data.vehicle = vehicle.vehicle
    var liveries: PackedStringArray = _liveries[vehicle]
    data.livery = liveries[0] if liveries else ""
    return data


## The categories, the grid and the buttons are exclusive; every way between them ends in one of
## these three
func focus_categories() -> void:
    %VehicleGrid.release_section_focus()
    %ActionsSection.release_section_focus()
    %CategoryList.grab_section_focus()


func focus_vehicles() -> void:
    if not %VehicleGrid.visible:
        focus_actions()
        return
    %CategoryList.release_section_focus()
    %ActionsSection.release_section_focus()
    %VehicleGrid.grab_section_focus()


func focus_actions() -> void:
    %CategoryList.release_section_focus()
    %VehicleGrid.release_section_focus()
    %ActionsSection.grab_section_focus()


## The search waits for the typing to stop - a page of side views is no work for every key
func _on_search_input_typed(_text: String) -> void:
    %SearchDebounce.start()


## Tab and Shift+Tab: the next or the previous of the three sections
func _on_window_window_input(event: InputEvent) -> void:
    var step: int = (
        1 if event.is_action_pressed("menu_next_section", true, true)
        else -1 if event.is_action_pressed("menu_previous_section", true, true)
        else 0
    )
    if step == 0:
        return
    %Window.set_input_as_handled()
    var sections: Array[FocusSection] = [%CategoryList, %VehicleGrid, %ActionsSection]
    var at: int = sections.find_custom(func(section: FocusSection) -> bool: return section.focused)
    [focus_categories, focus_vehicles, focus_actions][wrapi(at + step, 0, sections.size())].call()
