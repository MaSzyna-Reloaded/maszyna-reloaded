#!/bin/sh
# The files of the unpacked Windows export as the lines of ci/windows/maszyna-reloaded.nsi that
# install and remove them, each by its name: a library an addon adds to the export (gnd_sfx,
# Terrain3D) is never left out of the installer.
#   export-files.sh <source dir> <install lines> <uninstall lines>
set -e
: > "$2"
: > "$3"
for path in "$1"/*; do
    printf 'File "%s"\n' "$path" >> "$2"
    printf 'Delete "$INSTDIR\\%s"\n' "${path##*/}" >> "$3"
done
