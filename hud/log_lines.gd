class_name LogLines
extends RichTextLabel

## A log to scroll back through: the newest line at the bottom, followed while the view stands
## there. At least the last MAX_LINES are kept.
##
## The lines are kept beside the text and put into it only while the log is seen, so a hidden log
## (a tab in the back, the closed Logs panel) takes a line for the price of an append. The oldest
## lines go TRIM_BATCH at a time and the text is drawn again: RichTextLabel.remove_paragraph() walks
## every item of the text, and dropping the oldest line with each new one took most of the main
## thread on a scenery full of AI drivers (Wrzosy, docs/performance/changes.md).

## Lines kept; the oldest go, so a long session does not grow the text without end
const MAX_LINES: int = 5000
## Lines kept beyond MAX_LINES before the oldest go, all at once
const TRIM_BATCH: int = 1000
## The HUD's text colour (Label in timetable_theme.tres)
const TEXT_COLOR: Color = Color(0.9, 0.93, 0.97, 1)

var _lines: PackedStringArray = []
var _colors: PackedColorArray = []
## How many of _lines the text holds, from the first
var _drawn_count: int = 0


func _notification(what: int) -> void:
    if what == NOTIFICATION_VISIBILITY_CHANGED and is_visible_in_tree():
        _draw_lines()


## A line at the bottom, added as text, so a bracket in it is not read as BBCode
func add_line(line: String, color: Color = TEXT_COLOR) -> void:
    _lines.append(line)
    _colors.append(color)
    if _lines.size() > MAX_LINES + TRIM_BATCH:
        _lines = _lines.slice(-MAX_LINES)
        _colors = _colors.slice(-MAX_LINES)
        clear()
        _drawn_count = 0
    if is_visible_in_tree():
        _draw_lines()


## The kept lines the text does not hold yet, at its bottom
func _draw_lines() -> void:
    for index: int in range(_drawn_count, _lines.size()):
        if index:
            newline()
        push_color(_colors[index])
        add_text(_lines[index])
        pop()
    _drawn_count = _lines.size()
