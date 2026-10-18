# FINDINGS

Rules left by root causes found in the game, one line each; libmaszyna's own are in
`vendor/libmaszyna/FINDINGS.md`.

* From Godot 4.8 a size set on a control moves it in its grow directions (godotengine/godot#120418):
  a control sized from code grows from its own corner (`GROW_DIRECTION_END`), or takes its
  position after its size. *(2026-10-18 the loading board shifted by half its shrink at 2560x1440)*
* From Godot 4.8 `x in typed_array` with `x` of another type (or null) is an error, not `false`:
  check the type first. *(2026-10-18 settings' "Advanced" folding, `settings_page.gd`)*
