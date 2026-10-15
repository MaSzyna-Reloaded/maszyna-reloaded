# Requirements

What building and releasing the game needs.

## Linux binaries: glibc 2.34

Every Linux binary of MaSzyna Reloaded that is released - a library (`.so`), an engine template, an
executable - is built against **glibc 2.34**, in libmaszyna's Linux SDK image
`ghcr.io/maszyna-reloaded/linux-sdk` (libmaszyna's `ci/docker/linux-sdk`: Godot's own buildroot
SDK, whose sysroot carries glibc 2.34; the image is tagged by the start of its Dockerfile's sha256).
glibc is only forward compatible: a binary linked against a newer host's glibc refuses to start on
any older distribution (Ubuntu 22.04/24.04, Debian 12, Mint). A binary built on the host is for that
machine only, never released. Every repository building or going to build binaries keeps this rule.

The game's Linux library is libmaszyna's, built in that image by libmaszyna's Makefile
(`make compile-release-linux`, Docker); its executable is libmaszyna's engine template, built there
too. Terrain3D comes built in it from reloaded-terrain.

## Engine

Godot 4.7.2, double precision (`godot-double`): libmaszyna's `GODOT_VERSION`, built once by
libmaszyna's CI and published as its release `godot-4.7.2-double` (editor and export templates),
which the other repositories fetch (libmaszyna's `ci/fetch-godot.sh`). Single precision builds -
Godot's own, Terrain3D's own - do not load.

## Windows binaries

Cross-compiled on Linux by MinGW-w64 with posix threads (`x86_64-w64-mingw32-g++-posix`, set by
`update-alternatives` as the CI does).

The Windows installer is built in `ghcr.io/maszyna-reloaded/windows-installer` (README.md).

## Android

A JDK 17 and the Android SDK/NDK (libmaszyna's REQUIREMENTS.md); the game has no Android Terrain3D
yet (TODO.md).

## Terrain3D

reloaded-terrain's release, the tag `RELOADED_TERRAIN` (`YYMMDDHHMM`) of the Makefile: `make
terrain3d` unzips its `addons/terrain_3d` (double precision, patched, Linux and Windows) and
`addons/reloaded_terrain`. Nothing here builds Terrain3D.

## Tools

- `git` with submodules (`vendor/`), `curl`, `unzip`.
- Docker, for the Linux release (libmaszyna's Linux SDK image).
