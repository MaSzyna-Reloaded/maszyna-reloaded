extends MaszynaGutTest

## The HUD's Logs panel: a tab for every logger of GameLog as it comes, the lines of a logger in its
## tab only - the panel is a handler GameLog attaches to the loggers - and the tab gone with the
## logger

const LOGS_PANEL_SCENE: PackedScene = preload("res://hud/logs_panel.tscn")
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


func test_a_logger_has_its_tab_and_its_lines_only() -> void:
    GameLog.get_logger(LOGGER_A).info("for a")
    GameLog.get_logger(LOGGER_B).warning("for b")
    assert_not_null(_tab(LOGGER_A), "a tab for the logger that came after the panel")
    assert_eq(_tab(LOGGER_A).get_parsed_text(), "for a")
    assert_eq(_tab(LOGGER_B).get_parsed_text(), "for b")


func test_a_logger_from_before_the_panel_has_its_tab() -> void:
    assert_not_null(_tab("game"), "the game's logger is made with the log")
    GameLog.get_logger("game").info("game line")
    assert_string_contains(_tab("game").get_parsed_text(), "game line")


func test_a_removed_logger_takes_its_tab_along() -> void:
    GameLog.get_logger(LOGGER_A).info("line")
    GameLog.remove_logger(LOGGER_A)
    await wait_process_frames(1)
    assert_null(_tab(LOGGER_A))
