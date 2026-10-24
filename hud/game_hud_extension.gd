class_name GameHudExtension
extends Control

## A game's own windows over the HUD (GameExtensions.hud_extension_register()), made by the HUD as
## it starts: its windows go into the Diagnostics menu after the DebugHud's and are shown whenever
## the DebugHud shows its own - the DebugHud takes no other's windows.


## Its windows as entries of `menu`, after the entries it has
func fill_menu(_menu: PopupMenu) -> void:
    pass


## An entry of the Diagnostics menu was picked, by its index - one of its own or not
func menu_index_pressed(_index: int) -> void:
    pass


## Its windows shown or hidden with the DebugHud's
func set_windows_shown(_shown: bool) -> void:
    pass


## The world being shown, once its scenery has loaded
func attach_world(_world: SceneryWorld) -> void:
    pass
