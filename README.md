# MaSzyna Reloaded

The game - its screens, HUD, settings, problem reports and releases - built on
[libmaszyna](https://github.com/MaSzyna-Reloaded/libmaszyna), the `vendor/libmaszyna` submodule.

## Building

```bash
git submodule update --init --recursive
make compile-debug      # libmaszyna into bin/libmaszyna/, for the editor and the tests
make run-tests
make release-linux      # bin/linux/maszyna-reloaded-linux64.zip
make release-windows    # bin/windows/maszyna-reloaded-win64.zip and -setup.exe
make release-android    # bin/android/maszyna-reloaded-android-arm64.apk
```

The game needs the double precision Godot libmaszyna is built for (`godot-double`); libmaszyna's
`ci/fetch-godot.sh` fetches it and its export templates from libmaszyna's release
`godot-<version>-double`. To build against a local libmaszyna checkout:
`make libmaszyna-local LIBMASZYNA_LOCAL=<path>` (back: `make libmaszyna-submodule`).

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
