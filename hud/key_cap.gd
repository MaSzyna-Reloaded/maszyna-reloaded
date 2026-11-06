class_name KeyCap
extends PanelContainer

## A key drawn as a key: the name of an input event on a cap, or a pad's button or axis drawn as on
## the pad last used (PadIcon, InputBindings), without the cap. Its look is the `KeyCap` and
## `KeyCapLabel` theme types of whoever shows it (the help's, the hints').

## Height of a pad's icon [px]
@export var icon_height: int = 20


## Shows `event` as InputEventNames names it, or a pad's as PadIcon draws it
func show_event(event:InputEvent) -> void:
    var layout:InputEventNames.PadLayout = InputBindings.get_pad_layout()
    var icon:PadIcon = PadIcon.for_event(event, layout, icon_height)
    var pad:bool = not icon == null
    %Icon.texture = icon
    %Icon.visible = pad
    %Text.visible = not pad
    %Text.text = InputBindings.event_name(event, layout)
    # the cap's frame is its own drawing; its children keep their colours
    self_modulate.a = 0.0 if pad else 1.0
