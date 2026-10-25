extends MaszynaGutTest

## The HUD's Logs panel: a tab for every logger of GameLog as it comes, the lines of a logger in its
## tab only - the panel is a handler GameLog attaches to the loggers - and the tab gone with the
## logger. A tab puts its lines into its text once it is shown, so a tab is shown before it is read.

const LOGS_PANEL_SCENE: PackedScene = preload("res://hud/logs_panel.tscn")
const LOG_LINES_SCENE: PackedScene = preload("res://hud/log_lines.tscn")
const LOGGER_A: String = "test_logs_panel_a"
const LOGGER_B: String = "test_logs_panel_b"

var _panel: PanelContainer = null


func before_each() -> void:
    _panel = add_child_autofree(LOGS_PANEL_SCENE.instantiate())


func after_each() -> void:
    for logger_id: String in [LOGGER_A, LOGGER_B]:
        if logger_id in GameLog.get_loggers():
            GameLog.remove_logger(logger_id)


func _tab(logger_id: String) -> LogLines:
    return _panel.find_child(logger_id, true, false) as LogLines


## The tab's text, the panel shown and the tab made its current one
func _shown_text(logger_id: String) -> String:
    var tab: LogLines = _tab(logger_id)
    _panel.visible = true
    (tab.get_parent() as TabContainer).current_tab = tab.get_index()
    return tab.get_parsed_text()


func test_a_logger_has_its_tab_and_its_lines_only() -> void:
    GameLog.get_logger(LOGGER_A).info("for a")
    GameLog.get_logger(LOGGER_B).warning("for b")
    assert_not_null(_tab(LOGGER_A), "a tab for the logger that came after the panel")
    assert_eq(_shown_text(LOGGER_A), "for a")
    assert_eq(_shown_text(LOGGER_B), "for b")


func test_a_logger_from_before_the_panel_has_its_tab() -> void:
    assert_not_null(_tab("game"), "the game's logger is made with the log")
    GameLog.get_logger("game").info("game line")
    assert_string_contains(_shown_text("game"), "game line")


func test_a_removed_logger_takes_its_tab_along() -> void:
    GameLog.get_logger(LOGGER_A).info("line")
    GameLog.remove_logger(LOGGER_A)
    await wait_process_frames(1)
    assert_null(_tab(LOGGER_A))


func test_a_hidden_tab_takes_its_lines_when_shown() -> void:
    GameLog.get_logger(LOGGER_A).info("in front")
    GameLog.get_logger(LOGGER_B).info("in the back")
    assert_eq(_shown_text(LOGGER_A), "in front", "the panel open on another tab")
    GameLog.get_logger(LOGGER_B).info("while hidden")
    assert_eq(_tab(LOGGER_B).get_parsed_text(), "", "nothing drawn in a tab in the back")
    assert_eq(_shown_text(LOGGER_B), "in the back\nwhile hidden")


func test_the_oldest_lines_go_and_the_newest_stay() -> void:
    var lines: LogLines = add_child_autofree(LOG_LINES_SCENE.instantiate())
    var last: int = LogLines.MAX_LINES + LogLines.TRIM_BATCH
    for index: int in last + 1:
        lines.add_line(str(index))
    var text: PackedStringArray = lines.get_parsed_text().split("\n")
    assert_eq(text.size(), LogLines.MAX_LINES, "trimmed to the lines kept")
    assert_eq(text[0], str(last + 1 - LogLines.MAX_LINES), "the oldest kept line first")
    assert_eq(text[-1], str(last), "the newest line last")
