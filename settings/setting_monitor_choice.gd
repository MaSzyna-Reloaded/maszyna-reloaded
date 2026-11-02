class_name SettingMonitorChoice
extends SettingOption

## Which monitor the rows under it set up: the Display page has one set of rows of a monitor
## (settings.json "per_monitor"), and this choice points them at a monitor's UserSettings section. It
## is the page's state, not a setting: nothing of it is saved.

## The rows of a monitor, given by the settings screen before the row enters the tree
var monitor_rows: Array[SettingRow] = []
var _monitor: int = 0


func _ready() -> void:
    super()
    UserSettings.setting_changed.connect(_on_setting_changed)


func _exit_tree() -> void:
    UserSettings.setting_changed.disconnect(_on_setting_changed)


func _setup() -> void:
    for index: int in MonitorSettings.monitor_get_limit():
        %Options.add_item(tr("Monitor %d") % (index + 1), index)
    choose_monitor(0)


## The monitor's values on the rows
func choose_monitor(index: int) -> void:
    _monitor = index
    for row: SettingRow in monitor_rows:
        row.section = MonitorSettings.MONITOR_SECTION % index
        if row.key == MonitorSettings.SCREEN_KEY:
            row.default_value = index
        if row.is_inside_tree():
            row.revert()


## Every monitor's values go, not only the one shown
func restore_default() -> void:
    for index: int in MonitorSettings.monitor_get_limit():
        choose_monitor(index)
        for row: SettingRow in monitor_rows:
            row.restore_default()
    choose_monitor(0)
    revert()


## The count, the angle and the eye's distance work out every monitor; its rows show that at once
func _on_setting_changed(setting_section: String, _key: String) -> void:
    if setting_section == MonitorSettings.SECTION:
        MonitorSettings.layout_apply()
        choose_monitor(_monitor)


func _read() -> Variant:
    return _monitor


func _store(value: Variant) -> void:
    if not _showing:
        choose_monitor(value)
