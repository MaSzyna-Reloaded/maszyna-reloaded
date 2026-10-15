class_name WorldTerrainPanel
extends VBoxContainer

## Live view of a world's terrain (WorldTerrainStreamer): the Terrain3D regions loaded and wanted,
## whether some are being read, and where the Terrain3D's window of regions stands. Shown in the
## HUD's world terrain window (GameHud.attach_world()); refreshed only while it is visible.

## Seconds between refreshes
const REFRESH_INTERVAL: float = 0.25
## Width of a row's caption [px], as the world window's (MaszynaWorldPanel)
const CAPTION_WIDTH: float = 130.0
const METRES_PER_KM: float = 1000.0

var _streamer: WorldTerrainStreamer = null
var _rows: Dictionary[String, Label] = {}
var _timer: Timer = Timer.new()


func _ready() -> void:
    for caption: String in ["Regions", "Wanted", "Waiting", "Reading", "Region size", "Window origin", "Window"]:
        var row: HBoxContainer = HBoxContainer.new()
        var caption_label: Label = Label.new()
        caption_label.text = caption
        caption_label.custom_minimum_size = Vector2(CAPTION_WIDTH, 0)
        var value_label: Label = Label.new()
        value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
        row.add_child(caption_label)
        row.add_child(value_label)
        add_child(row)
        _rows[caption] = value_label
    _timer.wait_time = REFRESH_INTERVAL
    _timer.timeout.connect(_refresh)
    add_child(_timer)
    _refresh()
    if is_visible_in_tree():
        _timer.start()


func _notification(what: int) -> void:
    if what == NOTIFICATION_VISIBILITY_CHANGED and _timer.is_inside_tree():
        if is_visible_in_tree():
            _refresh()
            _timer.start()
            return
        _timer.stop()


## What streams the terrain shown; null while there is no world of the own format
func attach_streamer(streamer: WorldTerrainStreamer) -> void:
    _streamer = streamer
    _refresh()


func _refresh() -> void:
    if not _streamer:
        for caption: String in _rows:
            _rows[caption].text = ""
        _rows["Regions"].text = tr("no world of the own format")
        return
    var data: Terrain3DData = _streamer.terrain.data
    var size: float = _streamer.terrain.region_size * _streamer.terrain.vertex_spacing
    var origin: Vector2i = data.get_region_map_origin()
    var half: int = Terrain3DData.REGION_MAP_SIZE / 2
    _rows["Regions"].text = str(data.get_region_count())
    _rows["Wanted"].text = str(_streamer.get_wanted_count())
    _rows["Waiting"].text = str(maxi(_streamer.get_wanted_count() - data.get_region_count(), 0))
    _rows["Reading"].text = tr("yes") if _streamer.is_reading() else tr("no")
    _rows["Region size"].text = "%.0f m" % size
    _rows["Window origin"].text = "%d, %d" % [origin.x, origin.y]
    # the window's extent in the world, REGION_MAP_SIZE regions a side around its origin
    _rows["Window"].text = "X %.1f..%.1f km, Z %.1f..%.1f km" % [
        (origin.x - half) * size / METRES_PER_KM, (origin.x + half) * size / METRES_PER_KM,
        (origin.y - half) * size / METRES_PER_KM, (origin.y + half) * size / METRES_PER_KM,
    ]
