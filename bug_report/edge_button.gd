extends Button

## The report's button at the right edge of the screen: it waits past the edge with PEEK_WIDTH of
## its left side in sight, at RETRACTED_ALPHA, and slides in when the mouse touches the edge,
## anywhere along it, and back out once the mouse is left of it - as the top bar does at the top
## edge (hud/top_bar.gd). Anchored to the right edge, it slides by its offsets, so a resized window
## keeps it where it is.

## Pixels from the right edge of the screen that bring the button in
const REVEAL_EDGE: float = 2.0
## Pixels of the button's left side in sight while it waits past the edge
const PEEK_WIDTH: float = 4.0
## Opacity of the button waiting past the edge
const RETRACTED_ALPHA: float = 0.8
## Seconds of the slide in or out
const SLIDE_TIME: float = 0.15

var _shown: bool = false
var _slide_tween: Tween = null
## The width the scene gives it - not size.x, which shrinks to the minimum while the offsets pass
## through each other (a retract from the shown position)
var _width: float = 0.0


func _ready() -> void:
    _width = offset_right - offset_left
    offset_left = -PEEK_WIDTH
    offset_right = _width - PEEK_WIDTH
    modulate.a = RETRACTED_ALPHA


func _input(event: InputEvent) -> void:
    var motion: InputEventMouseMotion = event as InputEventMouseMotion
    if not motion:
        return
    var right: float = get_viewport_rect().size.x
    if motion.global_position.x >= right - REVEAL_EDGE:
        _slide(true)
    elif motion.global_position.x < right - _width:
        _slide(false)


func _slide(shown: bool) -> void:
    if shown == _shown:
        return
    _shown = shown
    if _slide_tween:
        _slide_tween.kill()
    _slide_tween = create_tween().set_parallel()
    var left: float = -_width if shown else -PEEK_WIDTH
    _slide_tween.tween_property(self, "offset_left", left, SLIDE_TIME)
    _slide_tween.tween_property(self, "offset_right", left + _width, SLIDE_TIME)
    _slide_tween.tween_property(self, "modulate:a", 1.0 if shown else RETRACTED_ALPHA, SLIDE_TIME)
