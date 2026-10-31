.PHONY: terrain3d links libreloaded-local libreloaded-submodule plugin-local plugin-submodule compile-debug compile-release compile-profiling compile-release-symbols compile-release-linux compile-windows-release compile-android-release build-number release release-linux release-linux-symbols release-windows release-android release-clear-godot-cache export-template-linux export-template-windows windows-installer-image windows-installer-image-push run-tests check-staged-uids install-git-hooks
.DEFAULT_GOAL = compile-debug

# libreloaded is the vendor/libreloaded submodule, built with its plugin libmaszyna - MaSzyna's
# vehicles and sceneries (LIBRELOADED_PLUGINS); its make builds the
# library into this project (bin/libreloaded/) - GODOT_PROJECT_DIR - and mounts this checkout, which
# holds it, into the Linux SDK container - LINUX_SDK_MOUNT. For development against a local checkout
# of libreloaded instead (its uncommitted work included): make libreloaded-local
# LIBRELOADED_LOCAL=<path>; the path is kept in .libreloaded-local (not versioned) until make
# libreloaded-submodule. The Linux SDK container mounts this checkout and the local one, so a release
# builds from either.
LIBRELOADED_LOCAL_FILE:=.libreloaded-local
LIBRELOADED:=$(or $(shell cat $(LIBRELOADED_LOCAL_FILE) 2>/dev/null),vendor/libreloaded)
# The plugins, each a repository of its own: the vendor/<name> submodule, or a local checkout of it
# (make plugin-local PLUGIN=<name> PLUGIN_LOCAL=<path>, kept in .<name>-local until make
# plugin-submodule PLUGIN=<name>)
PLUGINS:=libmaszyna
LIBMASZYNA:=$(or $(shell cat .libmaszyna-local 2>/dev/null),$(CURDIR)/vendor/libmaszyna)
# A game built on this one (its project in PROJECT_DIR, its own checkout) builds the library into
# its project with its own plugins besides (EXTRA_PLUGINS, ;-separated)
PROJECT_DIR?=$(CURDIR)
EXTRA_PLUGINS?=
# They are named here: libreloaded builds none of its own accord. ;-separated, so quoted wherever it
# is handed on - the shell takes a bare ; for the end of the command
LIBRELOADED_PLUGINS:=$(LIBMASZYNA)$(if $(EXTRA_PLUGINS),;$(EXTRA_PLUGINS))
LIBRELOADED_MAKE=$(MAKE) -C $(LIBRELOADED) GODOT_PROJECT_DIR=$(PROJECT_DIR) LINUX_SDK_MOUNT=$(PROJECT_DIR) \
	"LIBRELOADED_PLUGINS=$(LIBRELOADED_PLUGINS)"
# The addon of libreloaded, in its checkout; a plugin's is addons/<name> in its own
LIBRELOADED_ADDON:=addons/libreloaded
# The sound addon the game uses, libreloaded's own (its build makes its library)
GND_SFX_ADDON:=vendor/gnd-sfx/addons/gnd_sfx

# The app shows the build number (vendor/libreloaded/cmake/write_build_number.cmake), so the archive
# name stays the same from build to build and does not carry a branch or a date
LINUX_ZIP:=bin/linux/maszyna-reloaded-linux64.zip
ANDROID_APK:=bin/android/maszyna-reloaded-android-arm64.apk
WINDOWS_ZIP:=bin/windows/maszyna-reloaded-win64.zip
WINDOWS_SETUP:=bin/windows/maszyna-reloaded-win64-setup.exe
BUILD_NUMBER_FILE:=$(PROJECT_DIR)/build_number.txt
# The extension is built against double precision godot-cpp, so only a Godot built the same way
# can load it (libreloaded's Makefile). Override when your double precision build is named
# differently: make release-linux GODOT=godot-double
GODOT?=godot-double
# The engine the release is exported with - libreloaded's; the export looks its template up by its
# version, and libreloaded builds it under the name of its build: the version and its godot-patches,
# in the engines' directory of the machine (its make godot-bin)
GODOT_VERSION:=$(shell sed -n 's/^GODOT_VERSION:=//p' $(LIBRELOADED)/Makefile)
GODOT_BIN:=$(shell MAKEFLAGS= $(MAKE) -s --no-print-directory -C $(LIBRELOADED) godot-bin)
LINUX_TEMPLATE:=$(GODOT_BIN)/godot.linuxbsd.template_release.double.x86_64
LINUX_TEMPLATE_INSTALLED:=$(HOME)/.local/share/godot/export_templates/$(GODOT_VERSION).stable.double/linux_release.x86_64
WINDOWS_TEMPLATE:=$(GODOT_BIN)/godot.windows.template_release.double.x86_64.exe
WINDOWS_TEMPLATE_INSTALLED:=$(HOME)/.local/share/godot/export_templates/$(GODOT_VERSION).stable.double/windows_release_x86_64.exe
# The engine's editor as well, built beside the templates when GODOT_EDITOR is set - the
# upgrade-*.sh scripts set it; make alone does not, the editor takes as long again (the environment
# reaches make, a game built on this one's included)
GODOT_EDITOR?=
LINUX_EDITOR:=$(GODOT_BIN)/godot.linuxbsd.editor.double.x86_64
# The Windows installer is made by NSIS in ci/docker/windows-installer; the checkout is mounted at
# its own path and the build runs as the host user
# Published on ghcr.io and tagged by its Dockerfile: the CI pulls it, and a changed Dockerfile is a
# new tag the CI builds once and publishes itself (make windows-installer-image-push)
WINDOWS_INSTALLER_IMAGE:=ghcr.io/maszyna-reloaded/windows-installer:$(shell sha256sum ci/docker/windows-installer/Dockerfile | cut -c1-12)
WINDOWS_INSTALLER_RUN=docker run --rm --user $(shell id -u):$(shell id -g) -v $(CURDIR):$(CURDIR) -w $(CURDIR) $(WINDOWS_INSTALLER_IMAGE)


# addons/libreloaded, addons/gnd_sfx and addons/<plugin> lead to the checkout in use - the submodule, or a local one
# (make libreloaded-local, make plugin-local) - so they are not versioned (.gitignore): working
# against a local checkout changes nothing git sees. make links makes them, after a clone too;
# libreloaded's build makes only those missing and never replaces one
links:
	ln -sfn $(if $(wildcard $(LIBRELOADED_LOCAL_FILE)),"$(LIBRELOADED)",../vendor/libreloaded)/$(LIBRELOADED_ADDON) addons/libreloaded
	ln -sfn $(if $(wildcard $(LIBRELOADED_LOCAL_FILE)),"$(LIBRELOADED)",../vendor/libreloaded)/$(GND_SFX_ADDON) addons/gnd_sfx
	for plugin in $(PLUGINS); do \
		if [ -f ".$$plugin-local" ]; then ln -sfn "$$(cat .$$plugin-local)/addons/$$plugin" "addons/$$plugin" || exit 1; \
		else ln -sfn "../vendor/$$plugin/addons/$$plugin" "addons/$$plugin" || exit 1; fi; \
	done


libreloaded-local:
	@test -n "$(LIBRELOADED_LOCAL)" || { echo "Which libreloaded checkout? make libreloaded-local LIBRELOADED_LOCAL=<path>" >&2; exit 1; }
	@test -d "$(LIBRELOADED_LOCAL)/$(LIBRELOADED_ADDON)" || { echo "$(LIBRELOADED_LOCAL) is not a libreloaded checkout: it has no $(LIBRELOADED_ADDON)" >&2; exit 1; }
	realpath "$(LIBRELOADED_LOCAL)" > $(LIBRELOADED_LOCAL_FILE)
	$(MAKE) links


libreloaded-submodule:
	rm -f $(LIBRELOADED_LOCAL_FILE)
	$(MAKE) links


plugin-local:
	@case " $(PLUGINS) " in *" $(PLUGIN) "*) ;; *) echo "Which plugin? make plugin-local PLUGIN=<$(PLUGINS)> PLUGIN_LOCAL=<path>" >&2; exit 1;; esac
	@test -d "$(PLUGIN_LOCAL)/addons/$(PLUGIN)" || { echo "$(PLUGIN_LOCAL) is not a $(PLUGIN) checkout: it has no addons/$(PLUGIN)" >&2; exit 1; }
	realpath "$(PLUGIN_LOCAL)" > .$(PLUGIN)-local
	$(MAKE) links


plugin-submodule:
	@case " $(PLUGINS) " in *" $(PLUGIN) "*) ;; *) echo "Which plugin? make plugin-submodule PLUGIN=<$(PLUGINS)>" >&2; exit 1;; esac
	rm -f .$(PLUGIN)-local
	$(MAKE) links


compile-debug compile-release compile-profiling compile-release-symbols compile-release-linux compile-windows-release compile-android-release: $(BUILD_NUMBER_FILE) links
	$(LIBRELOADED_MAKE) $@


# Terrain3D (the ground the biomes grow on) patched and built double precision: the release
# RELOADED_TERRAIN of reloaded-terrain (github.com/MaSzyna-Reloaded/reloaded-terrain, tags
# YYMMDDHHMM) - its reloaded-terrain-<tag>.zip, of which addons/terrain_3d is unzipped here. Nothing
# here builds Terrain3D.
RELOADED_TERRAIN:=2610152101
RELOADED_TERRAIN_ZIP:=https://github.com/MaSzyna-Reloaded/reloaded-terrain/releases/download/$(RELOADED_TERRAIN)/reloaded-terrain-$(RELOADED_TERRAIN).zip
terrain3d:
	curl -fsSL -o .reloaded-terrain.zip $(RELOADED_TERRAIN_ZIP)
	unzip -qo .reloaded-terrain.zip 'addons/terrain_3d/*'
	rm .reloaded-terrain.zip


# The build number is stamped only when it is asked for, so a build never changes it: it describes
# a release rather than the last time somebody compiled anything. Bump it deliberately: `make
# build-number` - the game directory's `upgrade-linux.sh` and `upgrade-windows.sh` do, unless run
# with KEEP_BUILD_NUMBER=1 to ship another platform with the number already stamped.
build-number:
	cmake -DOUT=$(BUILD_NUMBER_FILE) -P $(LIBRELOADED)/cmake/write_build_number.cmake

# A checkout that has never been stamped gets a number on its first build, and keeps it.
$(BUILD_NUMBER_FILE):
	$(MAKE) build-number


# The export keeps each scene converted to binary and converts it again only when that scene's own
# file changes - a scene instancing another, changed one keeps the old diff of it (libreloaded's
# FINDINGS.md), so a release is exported from no cache at all
release-clear-godot-cache:
	rm -rf .godot/exported


# The templates of the engine's build - its version and its godot-patches: libreloaded builds the
# one missing (its Makefile), which takes hours and is done once per build (vendor/libreloaded/
# ci/fetch-godot.sh fetches CI's instead), and the one newer than the installed one is installed -
# a patch added is a new template, which upgrade-linux.sh and upgrade-windows.sh export with
$(LINUX_TEMPLATE) $(WINDOWS_TEMPLATE) $(LINUX_EDITOR):
	$(MAKE) -C $(LIBRELOADED) $@


$(LINUX_TEMPLATE_INSTALLED): $(LINUX_TEMPLATE)
	install -D $< $@


$(WINDOWS_TEMPLATE_INSTALLED): $(WINDOWS_TEMPLATE)
	install -D $< $@


# The installed template of a platform by name: what a release exports with, a game built on this
# one (PROJECT_DIR) included
export-template-linux: $(LINUX_TEMPLATE_INSTALLED) $(if $(GODOT_EDITOR),$(LINUX_EDITOR))


export-template-windows: $(WINDOWS_TEMPLATE_INSTALLED) $(if $(GODOT_EDITOR),$(LINUX_EDITOR))


windows-installer-image:
	docker image inspect $(WINDOWS_INSTALLER_IMAGE) > /dev/null 2>&1 || docker pull -q $(WINDOWS_INSTALLER_IMAGE) \
	    || docker build -q -t $(WINDOWS_INSTALLER_IMAGE) ci/docker/windows-installer


windows-installer-image-push: windows-installer-image
	docker push $(WINDOWS_INSTALLER_IMAGE)


# The export is run by the editor, which loads the debug library (libreloaded.gdextension, the
# editor's own feature tag), so that one is built as well - a stale one fails the scripts that use
# a newer API
release-linux: release-clear-godot-cache compile-debug compile-release-linux export-template-linux
	mkdir -p bin/linux
	$(GODOT) --headless --path . --export-release "linux_x86_64" bin/linux/reloaded.zip
	mv bin/linux/reloaded.zip $(LINUX_ZIP)
	@echo "Exported: $(LINUX_ZIP)"


release-linux-symbols: release-clear-godot-cache compile-debug compile-release-symbols
	mkdir -p bin/linux
	$(GODOT) --headless --path . --export-release "linux_x86_64" bin/linux/reloaded.zip
	mv bin/linux/reloaded.zip $(LINUX_ZIP)
	@echo "Exported with symbols: $(LINUX_ZIP)"


release-windows: release-clear-godot-cache compile-debug compile-windows-release export-template-windows windows-installer-image
	mkdir -p bin/windows
	$(GODOT) --headless --path . --export-release "windows_x86_64" bin/windows/reloaded.zip
	mv bin/windows/reloaded.zip $(WINDOWS_ZIP)
	@echo "Exported: $(WINDOWS_ZIP)"
	$(WINDOWS_INSTALLER_RUN) sh -c 'rm -rf bin/windows/installer && unzip -q $(WINDOWS_ZIP) -d bin/windows/installer \
	    && makensis -V2 -DSOURCE_DIR=$(CURDIR)/bin/windows/installer -DBUILD_NUMBER=$$(cat $(BUILD_NUMBER_FILE)) \
	       -DOUTFILE=$(CURDIR)/$(WINDOWS_SETUP) ci/windows/maszyna-reloaded.nsi \
	    && rm -rf bin/windows/installer'
	@echo "Exported: $(WINDOWS_SETUP)"


release-android: release-clear-godot-cache compile-debug compile-android-release
	mkdir -p bin/android
	$(GODOT) --headless --path . --export-release "android_arm64" $(ANDROID_APK)
	@echo "Exported: $(ANDROID_APK)"


release: release-linux release-windows


run-tests: compile-debug
	$(GODOT) --path . --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/ -gexit


# A staged script or shader goes in with its .uid (libreloaded's scripts/check-staged-uids)
check-staged-uids:
	@$(LIBRELOADED)/scripts/check-staged-uids

# The repository's hooks (scripts/git-hooks): pre-commit runs check-staged-uids
install-git-hooks:
	git config core.hooksPath scripts/git-hooks
