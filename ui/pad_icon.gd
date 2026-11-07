class_name PadIcon
extends Texture2D

## A pad's button or axis drawn as it looks on a pad of a maker's layout (InputEventNames.PadLayout)
## - the face buttons in their colours, PlayStation's by their symbols, the shoulders, triggers and
## small buttons by their labels, the d-pad with its arm lit and a stick with the side it is pushed
## to - drawn, not a picture, so it is sharp at any height. A texture, so a Button's icon, a
## TextureRect, anything that takes one shows it. for_event() makes it. A combination
## (InputBindings.get_pad_modifier()) is drawn as its modifier, a plus and its button or axis.

enum Shape {
    FACE,
    SHOULDER,
    TRIGGER,
    SMALL,
    DPAD,
    STICK,
}

enum Symbol {
    NONE,
    CROSS,
    CIRCLE,
    SQUARE,
    TRIANGLE,
}

const FONT: Font = preload("fonts/vend_sans_bold.tres")
## The face buttons by their place - bottom, right, left, top - as Godot maps every pad
const FACE_BUTTONS: Array[JoyButton] = [JOY_BUTTON_A, JOY_BUTTON_B, JOY_BUTTON_X, JOY_BUTTON_Y]
## Their colours on each maker's pads, in the same order
const FACE_COLORS: Dictionary[InputEventNames.PadLayout, Array] = {
    InputEventNames.PadLayout.XBOX: [
        Color(0.42, 0.75, 0.27), Color(0.9, 0.3, 0.26),
        Color(0.25, 0.55, 0.95), Color(0.98, 0.78, 0.2),
    ],
    InputEventNames.PadLayout.PLAYSTATION: [
        Color(0.5, 0.65, 1.0), Color(1.0, 0.4, 0.42),
        Color(0.93, 0.55, 0.85), Color(0.3, 0.85, 0.7),
    ],
    InputEventNames.PadLayout.NINTENDO: [
        Color(0.92, 0.94, 0.97), Color(0.92, 0.94, 0.97),
        Color(0.92, 0.94, 0.97), Color(0.92, 0.94, 0.97),
    ],
}
## PlayStation's face buttons carry symbols, in the same order
const PLAYSTATION_SYMBOLS: Array[Symbol] = [Symbol.CROSS, Symbol.CIRCLE, Symbol.SQUARE, Symbol.TRIANGLE]
const SHOULDERS: Array[JoyButton] = [JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER]
const STICK_BUTTONS: Array[JoyButton] = [JOY_BUTTON_LEFT_STICK, JOY_BUTTON_RIGHT_STICK]
const TRIGGERS: Array[JoyAxis] = [JOY_AXIS_TRIGGER_LEFT, JOY_AXIS_TRIGGER_RIGHT]
## The d-pad's arms
const DPAD_DIRECTIONS: Dictionary[JoyButton, Vector2] = {
    JOY_BUTTON_DPAD_UP: Vector2.UP,
    JOY_BUTTON_DPAD_DOWN: Vector2.DOWN,
    JOY_BUTTON_DPAD_LEFT: Vector2.LEFT,
    JOY_BUTTON_DPAD_RIGHT: Vector2.RIGHT,
}
## A stick's axes: across or along, and which stick
const STICK_ACROSS: Array[JoyAxis] = [JOY_AXIS_LEFT_X, JOY_AXIS_RIGHT_X]
const STICK_LABELS: Dictionary[JoyAxis, String] = {
    JOY_AXIS_LEFT_X: "L",
    JOY_AXIS_LEFT_Y: "L",
    JOY_AXIS_RIGHT_X: "R",
    JOY_AXIS_RIGHT_Y: "R",
}
## InputEventNames' names begin with it; the icon shows the label alone
const NAME_PREFIX: String = "Pad "

## The button's body and its outline
const BODY_COLOR: Color = Color(0.13, 0.15, 0.19)
const OUTLINE_COLOR: Color = Color(0.82, 0.87, 0.95)
## A label, a d-pad arm or a stick's side not lit, and lit
const LABEL_COLOR: Color = Color(0.95, 0.96, 0.98)
const DIM_COLOR: Color = Color(0.45, 0.5, 0.58)
## Parts of the icon's height: the outline, the label, a symbol, the rounding of a shoulder's corners,
## a small button's height, the d-pad's arm and a stick's arrow
const OUTLINE: float = 0.08
const LABEL_SIZE: float = 0.5
const SMALL_LABEL_SIZE: float = 0.42
const SYMBOL_SIZE: float = 0.22
const SYMBOL_WIDTH: float = 0.08
const CORNER: float = 0.3
const SMALL_HEIGHT: float = 0.72
const DPAD_ARM: float = 0.32
const ARROW: float = 0.2
## Width of a shoulder, a trigger or a small button: at least this part of its height, and its
## label with this part of its height on each side
const LABELLED_MIN_WIDTH: float = 1.3
const LABEL_PADDING: float = 0.3
## Width of the plus between a combination's modifier and its button, a part of the height
const PLUS_WIDTH: float = 0.7
const PLUS: String = "+"

var _shape: Shape = Shape.FACE
## The label shown, or the symbol in its place
var _label: String = ""
var _symbol: Symbol = Symbol.NONE
## The colour of the label or the symbol
var _color: Color = LABEL_COLOR
## The d-pad's arm lit, or the side a stick is pushed to - none for a stick pressed
var _direction: Vector2 = Vector2.ZERO
var _height: int = 0
var _width: int = 0
## A combination's modifier, drawn before the plus and the button or axis
var _modifier_icon: PadIcon = null


## `event` - a pad's button or axis - drawn `height` pixels high as on a pad of `layout`; null for
## any other event
static func for_event(event: InputEvent, layout: InputEventNames.PadLayout, height: int) -> PadIcon:
    var icon: PadIcon = PadIcon.new()
    icon._height = height
    icon._label = InputEventNames.event_name(event, layout).trim_prefix(NAME_PREFIX)
    var button: InputEventJoypadButton = event as InputEventJoypadButton
    var motion: InputEventJoypadMotion = event as InputEventJoypadMotion
    if button:
        var face: int = FACE_BUTTONS.find(button.button_index)
        if face >= 0:
            icon._shape = Shape.FACE
            icon._color = FACE_COLORS[layout][face]
            if layout == InputEventNames.PadLayout.PLAYSTATION:
                icon._symbol = PLAYSTATION_SYMBOLS[face]
        elif button.button_index in SHOULDERS:
            icon._shape = Shape.SHOULDER
        elif DPAD_DIRECTIONS.has(button.button_index):
            icon._shape = Shape.DPAD
            icon._direction = DPAD_DIRECTIONS[button.button_index]
        elif button.button_index in STICK_BUTTONS:
            icon._shape = Shape.STICK
        else:
            icon._shape = Shape.SMALL
    elif motion:
        if motion.axis in TRIGGERS:
            icon._shape = Shape.TRIGGER
        else:
            icon._shape = Shape.STICK
            icon._label = STICK_LABELS.get(motion.axis, "")
            var side: float = signf(motion.axis_value)
            icon._direction = Vector2(side, 0.0) if motion.axis in STICK_ACROSS else Vector2(0.0, side)
    else:
        return null
    icon._width = height
    if icon._shape in [Shape.SHOULDER, Shape.TRIGGER, Shape.SMALL]:
        var text_width: float = FONT.get_string_size(
            icon._label, HORIZONTAL_ALIGNMENT_LEFT, -1, icon._label_size_for(height)
        ).x
        icon._width = ceili(maxf(height * LABELLED_MIN_WIDTH, text_width + 2.0 * height * LABEL_PADDING))
    var modifier: int = InputBindings.get_pad_modifier(event)
    if modifier != InputBindings.PadModifier.NONE:
        icon._modifier_icon = for_event(InputBindings.get_modifier_event(modifier), layout, height)
        icon._width += icon._modifier_icon.get_width() + ceili(height * PLUS_WIDTH)
    return icon


func _get_width() -> int:
    return _width


func _get_height() -> int:
    return _height


func _has_alpha() -> bool:
    return true


func _draw(to_canvas_item: RID, pos: Vector2, modulate: Color, _transpose: bool) -> void:
    _draw_rect(to_canvas_item, Rect2(pos, Vector2(_width, _height)), false, modulate, false)


func _draw_rect_region(
    to_canvas_item: RID, rect: Rect2, _src_rect: Rect2, modulate: Color, _transpose: bool,
    _clip_uv: bool
) -> void:
    _draw_rect(to_canvas_item, rect, false, modulate, false)


## Drawn into `rect` as it is given - the controls that show a texture keep its proportions; a
## combination's modifier and the plus take its left part
func _draw_rect(
    item: RID, rect: Rect2, _tile: bool, modulate: Color, _transpose: bool
) -> void:
    if _modifier_icon:
        var scale: float = rect.size.y / float(_height)
        var modifier_width: float = _modifier_icon.get_width() * scale
        var plus_width: float = rect.size.y * PLUS_WIDTH
        _modifier_icon._draw_rect(
            item, Rect2(rect.position, Vector2(modifier_width, rect.size.y)), false, modulate, false
        )
        var plus_center: Vector2 = Vector2(
            rect.position.x + modifier_width + plus_width * 0.5, rect.get_center().y
        )
        _draw_text(item, plus_center, rect.size.y * LABEL_SIZE, PLUS, LABEL_COLOR * modulate)
        rect.position.x += modifier_width + plus_width
        rect.size.x -= modifier_width + plus_width
    _draw_shape(item, rect, modulate)


func _draw_shape(item: RID, rect: Rect2, modulate: Color) -> void:
    var height: float = rect.size.y
    var center: Vector2 = rect.get_center()
    var outline: float = maxf(1.0, height * OUTLINE)
    match _shape:
        Shape.FACE:
            RenderingServer.canvas_item_add_circle(item, center, height * 0.5, _color * modulate)
            RenderingServer.canvas_item_add_circle(
                item, center, height * 0.5 - outline, BODY_COLOR * modulate
            )
            if _symbol == Symbol.NONE:
                _draw_label(item, center, height * LABEL_SIZE, _color * modulate)
            else:
                _draw_symbol(item, center, height, _color * modulate, BODY_COLOR * modulate)
        Shape.SHOULDER, Shape.TRIGGER, Shape.SMALL:
            var body: Rect2 = rect
            var corners: float = height * CORNER
            if _shape == Shape.SMALL:
                body = Rect2(
                    rect.position.x, center.y - height * SMALL_HEIGHT * 0.5, rect.size.x, height * SMALL_HEIGHT
                )
                corners = body.size.y * 0.5
            var style: StyleBoxFlat = StyleBoxFlat.new()
            style.bg_color = BODY_COLOR * modulate
            style.border_color = OUTLINE_COLOR * modulate
            style.set_border_width_all(ceili(outline))
            style.set_corner_radius_all(ceili(corners))
            # a trigger is rounded at its top, where the finger pulls it
            if _shape == Shape.TRIGGER:
                style.corner_radius_top_left = ceili(height * 0.5)
                style.corner_radius_top_right = ceili(height * 0.5)
            style.draw(item, body)
            _draw_label(item, center, _label_size_for(height), LABEL_COLOR * modulate)
        Shape.DPAD:
            var arm: float = height * DPAD_ARM
            RenderingServer.canvas_item_add_rect(
                item, Rect2(center.x - arm * 0.5, rect.position.y, arm, height), DIM_COLOR * modulate
            )
            RenderingServer.canvas_item_add_rect(
                item, Rect2(center.x - height * 0.5, center.y - arm * 0.5, height, arm), DIM_COLOR * modulate
            )
            # the lit arm, from the middle out
            var lit: Rect2 = Rect2(center - Vector2(arm, arm) * 0.5, Vector2(arm, arm))
            lit = lit.expand(center + _direction * height * 0.5 + _direction.orthogonal() * arm * 0.5)
            lit = lit.expand(center + _direction * height * 0.5 - _direction.orthogonal() * arm * 0.5)
            RenderingServer.canvas_item_add_rect(item, lit, LABEL_COLOR * modulate)
        Shape.STICK:
            RenderingServer.canvas_item_add_circle(item, center, height * 0.5, OUTLINE_COLOR * modulate)
            RenderingServer.canvas_item_add_circle(
                item, center, height * 0.5 - outline, BODY_COLOR * modulate
            )
            # the label moved off the arrow
            var label_center: Vector2 = center - _direction * height * ARROW * 0.5
            _draw_label(item, label_center, height * SMALL_LABEL_SIZE, LABEL_COLOR * modulate)
            if not _direction == Vector2.ZERO:
                var tip: Vector2 = center + _direction * (height * 0.5 - outline)
                var base: Vector2 = tip - _direction * height * ARROW
                var across: Vector2 = _direction.orthogonal() * height * ARROW
                RenderingServer.canvas_item_add_polygon(
                    item, PackedVector2Array([tip, base + across, base - across]),
                    PackedColorArray([LABEL_COLOR * modulate])
                )


func _label_size_for(height: float) -> int:
    return maxi(1, roundi(height * (SMALL_LABEL_SIZE if _shape == Shape.SMALL else LABEL_SIZE)))


func _draw_label(item: RID, center: Vector2, font_size: float, color: Color) -> void:
    _draw_text(item, center, font_size, _label, color)


func _draw_text(item: RID, center: Vector2, font_size: float, text: String, color: Color) -> void:
    var size: int = maxi(1, roundi(font_size))
    var text_size: Vector2 = FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
    # the baseline that puts the text's ascent and descent around the middle
    var baseline: float = center.y + (FONT.get_ascent(size) - FONT.get_descent(size)) * 0.5
    FONT.draw_string(item, Vector2(center.x - text_size.x * 0.5, baseline), text,
        HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


func _draw_symbol(item: RID, center: Vector2, height: float, color: Color, body: Color) -> void:
    var reach: float = height * SYMBOL_SIZE
    var width: float = maxf(1.0, height * SYMBOL_WIDTH)
    match _symbol:
        Symbol.CROSS:
            RenderingServer.canvas_item_add_line(
                item, center - Vector2(reach, reach), center + Vector2(reach, reach), color, width, true
            )
            RenderingServer.canvas_item_add_line(
                item, center + Vector2(-reach, reach), center + Vector2(reach, -reach), color, width, true
            )
        Symbol.CIRCLE:
            RenderingServer.canvas_item_add_circle(item, center, reach + width * 0.5, color)
            RenderingServer.canvas_item_add_circle(item, center, reach - width * 0.5, body)
        Symbol.SQUARE:
            RenderingServer.canvas_item_add_polyline(item, PackedVector2Array([
                center + Vector2(-reach, -reach), center + Vector2(reach, -reach),
                center + Vector2(reach, reach), center + Vector2(-reach, reach),
                center + Vector2(-reach, -reach),
            ]), PackedColorArray([color]), width, true)
        Symbol.TRIANGLE:
            # a little lower than the middle, as the triangle's weight is at its base
            var middle: Vector2 = center + Vector2(0.0, reach * 0.15)
            RenderingServer.canvas_item_add_polyline(item, PackedVector2Array([
                middle + Vector2(0.0, -reach * 1.1), middle + Vector2(reach, reach * 0.75),
                middle + Vector2(-reach, reach * 0.75), middle + Vector2(0.0, -reach * 1.1),
            ]), PackedColorArray([color]), width, true)
