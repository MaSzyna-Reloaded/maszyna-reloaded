---
name: prerelease-screenshot
description: Make a pre-release (pre-alpha) promo screenshot of MaSzyna Reloaded with the loading screen logo and the build number in one consistent look. Use when the operator gives an in-game screenshot and asks to put the logo and/or the build number (from a maszyna-reloaded.pl changelog link) on it.
---

## Rule zero: only what the operator orders

REQUIRED, ABSOLUTE: **do always and only what the operator orders.** Nothing is edited, reverted,
"restored", renamed, redesigned or posted (an issue, a comment, a PR) without the operator's
explicit order - not even one's own work after a complaint. A complaint is not an order: name the
facts and wait. Never touch an existing, reviewed mechanism outside the task.

REQUIRED, ABSOLUTE: **no separation-of-concerns breach, ever.** Before any new state, API, enum,
command or read from another layer, name to the operator which layer owns the value, where it is
read from and why that keeps every layer to its own concern - and write nothing until the operator
says yes. Data a scenery or a starter hands in is never read as live state; a value is read from
its owner, never from a plugin's implementation, a dump or a copy.

# Pre-release screenshot

Every release screenshot uses the same layout. Do not invent a new one; only the vertical
position changes from shot to shot.

## Layout

* **One line across the frame:** the logo on the left and the build number on the right, at the
  same height. The logo is centred on the digits.
* **Logo:** `loading_screen/logo.png` (the loading screen's), trimmed, 400 px wide, 44 px
  from the left edge.
* **Build number:** Noto Sans Black, 96 px, `#e6edfc`, right-aligned 44 px from the right edge.
  Only the number goes in the big text (`20261003-1708`).
* **Label above it:** `PRE-ALPHA BUILD`, Noto Sans SemiBold, 22 px, letter-spaced, `#73b8ff`,
  right-aligned. The colours are the `Scenery` and `Eyebrow` labels of `loading_board.tscn`.
* **Shadow:** a soft, heavily blurred dark ellipse under each side, so the text reads on any
  background. No hard box edges.

The sizes are for 1920x1080; the script scales them to the input's width.

## Steps

1. Get the build number from the changelog link (WebFetch). The page title reads
   `... Pre-Alpha <date> (build <id>)`; use `<id>`. The link's last path segment is usually the
   same id.
2. Look at the screenshot and pick the line's height: below the HUD and the main subject,
   above the bottom HUD (speed bar, vehicle card) and not over people's heads or faces. The
   first approved shot used `760`: just above the head of a person walking along the bottom.
3. Compose:

   ```bash
   .claude/skills/prerelease-screenshot/compose.sh <input.png> <build> <output.png> [line_top_y] [label]
   ```

   `line_top_y` is the top of the build number in 1080p pixels (default 760). `label` defaults to
   `PRE-ALPHA BUILD`.
4. Read the output image and check it. If the number covers a figure or the HUD, change only
   `line_top_y`. Do not change sizes, fonts or colours.
5. Save next to the original as `<name>_build.png`. Never overwrite the operator's original.
