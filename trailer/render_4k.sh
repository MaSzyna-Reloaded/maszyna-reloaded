#!/usr/bin/env bash
# The trailer of shots.json in 3840x2160 at 60 frames a second: the takes the sequence cuts from
# recorded again at that size (bin/trailer/2160p/), then edited into the next
# bin/trailer/maszyna-reloaded-trailer-NN-2160p.mp4. The 1080p takes are left as they are.
#   trailer/render_4k.sh            record and edit
#   trailer/render_4k.sh record     only record (a take's name after it: only that take)
#   trailer/render_4k.sh edit       only edit what is recorded
# GODOT names the double precision Godot (default: godot).
set -euo pipefail

cd "$(dirname "$0")/.."
TRAILER_SIZE=3840x2160 TRAILER_USED_ONLY=1 GODOT="${GODOT:-godot}" exec trailer/make_trailer.py "$@"
