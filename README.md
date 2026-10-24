# MaSzyna Reloaded

The game - its screens, HUD, settings, problem reports and releases - built on
[libreloaded](https://github.com/MaSzyna-Reloaded/libreloaded), the `vendor/libreloaded`
submodule, with its plugin [libmaszyna](https://github.com/MaSzyna-Reloaded/libmaszyna), the
`vendor/libmaszyna` submodule.

## Building

```bash
git submodule update --init --recursive
make links              # addons/libreloaded and addons/libmaszyna, not versioned
make terrain3d          # addons/terrain_3d, not versioned
make compile-debug      # libreloaded with libmaszyna into bin/libreloaded/, for the editor and the tests
make run-tests
make release-linux      # bin/linux/maszyna-reloaded-linux64.zip
make release-windows    # bin/windows/maszyna-reloaded-win64.zip and -setup.exe
make release-android    # bin/android/maszyna-reloaded-android-arm64.apk
```

After a pull or a change of branch, run `git submodule update --init --recursive` and `make links`
again: a submodule moved by the pull stays at its old commit, and libreloaded's own submodules
(`godot-cpp`, `vendor/lua`, ...) are checked out only with `--recursive`. `git clean -dff` removes
`addons/terrain_3d` as well - `make terrain3d` brings it back.

The game needs the double precision Godot libreloaded is built for (`godot-double`); libreloaded's
`ci/fetch-godot.sh` fetches it and its export templates from libreloaded's release
`godot-<version>-double`. To build against a local checkout:
`make libreloaded-local LIBRELOADED_LOCAL=<path>` (back: `make libreloaded-submodule`),
`make plugin-local PLUGIN=libmaszyna PLUGIN_LOCAL=<path>` (back:
`make plugin-submodule PLUGIN=libmaszyna`).

## CI

CI uses no Docker Hub image. Godot comes from libmaszyna's release, the Linux release library is
built in libmaszyna's Linux SDK image and the Windows installer in
`ghcr.io/maszyna-reloaded/windows-installer`, both pulled from ghcr.io. An image is tagged by the
hash of its Dockerfile (`ci/docker/windows-installer/Dockerfile` here), so a changed Dockerfile is
a new tag that is not on ghcr.io yet - CI then builds the image on every run. After changing the
Dockerfile, build and publish the image yourself (a `gh` token with the `write:packages` scope:
`gh auth refresh -h github.com -s write:packages`):

```bash
gh auth token | docker login ghcr.io -u <github user> --password-stdin
make windows-installer-image-push
```
