.PHONY: libmaszyna-local libmaszyna-submodule compile-debug compile-release compile-profiling compile-release-symbols compile-release-linux compile-windows-release compile-android-release build-number release release-linux release-linux-symbols release-windows release-android release-clear-godot-cache windows-installer-image windows-installer-image-push run-tests check-staged-uids install-git-hooks
.DEFAULT_GOAL = compile-debug

# libmaszyna is the vendor/libmaszyna submodule; its make builds the library into this project
# (bin/libmaszyna/) - GODOT_PROJECT_DIR - and mounts this checkout, which holds it, into the Linux
# SDK container - LINUX_SDK_MOUNT. For development against a local checkout of libmaszyna instead
# (its uncommitted work included): make libmaszyna-local LIBMASZYNA_LOCAL=<path>; the path is kept
# in .libmaszyna-local (not versioned) until make libmaszyna-submodule. The Linux SDK container
# mounts this checkout only, so compile-release-linux needs the submodule.
LIBMASZYNA_LOCAL_FILE:=.libmaszyna-local
LIBMASZYNA:=$(or $(shell cat $(LIBMASZYNA_LOCAL_FILE) 2>/dev/null),vendor/libmaszyna)
LIBMASZYNA_MAKE=$(MAKE) -C $(LIBMASZYNA) GODOT_PROJECT_DIR=$(CURDIR) LINUX_SDK_MOUNT=$(CURDIR)

# The app shows the build number (vendor/libmaszyna/cmake/write_build_number.cmake), so the archive
# name stays the same from build to build and does not carry a branch or a date
LINUX_ZIP:=bin/linux/maszyna-reloaded-linux64.zip
ANDROID_APK:=bin/android/maszyna-reloaded-android-arm64.apk
WINDOWS_ZIP:=bin/windows/maszyna-reloaded-win64.zip
WINDOWS_SETUP:=bin/windows/maszyna-reloaded-win64-setup.exe
BUILD_NUMBER_FILE:=build_number.txt
# The extension is built against double precision godot-cpp, so only a Godot built the same way
# can load it (libmaszyna's Makefile). Override when your double precision build is named
# differently: make release-linux GODOT=godot-double
GODOT?=godot-double
# The engine the release is exported with - libmaszyna's; the export looks its template up by it
GODOT_VERSION:=$(shell sed -n 's/^GODOT_VERSION:=//p' $(LIBMASZYNA)/Makefile)
GODOT_BIN:=$(LIBMASZYNA)/build-godot-$(GODOT_VERSION)/bin
LINUX_TEMPLATE:=$(GODOT_BIN)/godot.linuxbsd.template_release.double.x86_64
LINUX_TEMPLATE_INSTALLED:=$(HOME)/.local/share/godot/export_templates/$(GODOT_VERSION).stable.double/linux_release.x86_64
# The Windows installer is made by NSIS in ci/docker/windows-installer; the checkout is mounted at
# its own path and the build runs as the host user
# Published on ghcr.io and tagged by its Dockerfile, as libmaszyna's Linux SDK: the CI pulls it, a
# changed Dockerfile is a new tag, built here and published with make windows-installer-image-push
WINDOWS_INSTALLER_IMAGE:=ghcr.io/maszyna-reloaded/windows-installer:$(shell sha256sum ci/docker/windows-installer/Dockerfile | cut -c1-12)
WINDOWS_INSTALLER_RUN=docker run --rm --user $(shell id -u):$(shell id -g) -v $(CURDIR):$(CURDIR) -w $(CURDIR) $(WINDOWS_INSTALLER_IMAGE)


# addons/libmaszyna leads to the local checkout; git leaves the versioned link (to the submodule)
# out of the status meanwhile
libmaszyna-local:
	test -d "$(LIBMASZYNA_LOCAL)/addons/libmaszyna"
	realpath "$(LIBMASZYNA_LOCAL)" > $(LIBMASZYNA_LOCAL_FILE)
	! git ls-files --error-unmatch addons/libmaszyna > /dev/null 2>&1 || git update-index --skip-worktree addons/libmaszyna
	ln -sfn "$$(cat $(LIBMASZYNA_LOCAL_FILE))/addons/libmaszyna" addons/libmaszyna


libmaszyna-submodule:
	rm -f $(LIBMASZYNA_LOCAL_FILE)
	! git ls-files --error-unmatch addons/libmaszyna > /dev/null 2>&1 || git update-index --no-skip-worktree addons/libmaszyna
	ln -sfn ../vendor/libmaszyna/addons/libmaszyna addons/libmaszyna


compile-debug compile-release compile-profiling compile-release-symbols compile-release-linux compile-windows-release compile-android-release: $(BUILD_NUMBER_FILE)
	$(LIBMASZYNA_MAKE) $@


# The build number is stamped only when it is asked for, so a build never changes it: it describes
# a release rather than the last time somebody compiled anything. Bump it deliberately: `make
# build-number` - the game directory's `upgrade-linux.sh` and `upgrade-windows.sh` do, unless run
# with KEEP_BUILD_NUMBER=1 to ship another platform with the number already stamped.
build-number:
	cmake -DOUT=$(BUILD_NUMBER_FILE) -P $(LIBMASZYNA)/cmake/write_build_number.cmake

# A checkout that has never been stamped gets a number on its first build, and keeps it.
$(BUILD_NUMBER_FILE):
	$(MAKE) build-number


# The export keeps each scene converted to binary and converts it again only when that scene's own
# file changes - a scene instancing another, changed one keeps the old diff of it (libmaszyna's
# FINDINGS.md), so a release is exported from no cache at all
release-clear-godot-cache:
	rm -rf .godot/exported


# The template is built only while none is installed for this engine version - libmaszyna builds
# the engine (its Makefile), which takes hours and is done once per version
$(LINUX_TEMPLATE_INSTALLED):
	$(MAKE) -C $(LIBMASZYNA) $(patsubst $(LIBMASZYNA)/%,%,$(LINUX_TEMPLATE))
	install -D $(LINUX_TEMPLATE) $@


windows-installer-image:
	docker image inspect $(WINDOWS_INSTALLER_IMAGE) > /dev/null 2>&1 || docker pull -q $(WINDOWS_INSTALLER_IMAGE) \
	    || docker build -q -t $(WINDOWS_INSTALLER_IMAGE) ci/docker/windows-installer


windows-installer-image-push: windows-installer-image
	docker push $(WINDOWS_INSTALLER_IMAGE)


# The export is run by the editor, which loads the debug library (libmaszyna.gdextension, the
# editor's own feature tag), so that one is built as well - a stale one fails the scripts that use
# a newer API
release-linux: release-clear-godot-cache compile-debug compile-release-linux $(LINUX_TEMPLATE_INSTALLED)
	mkdir -p bin/linux
	$(GODOT) --headless --path . --export-release "linux_x86_64" bin/linux/reloaded.zip
	mv bin/linux/reloaded.zip $(LINUX_ZIP)
	@echo "Exported: $(LINUX_ZIP)"


release-linux-symbols: release-clear-godot-cache compile-debug compile-release-symbols
	mkdir -p bin/linux
	$(GODOT) --headless --path . --export-release "linux_x86_64" bin/linux/reloaded.zip
	mv bin/linux/reloaded.zip $(LINUX_ZIP)
	@echo "Exported with symbols: $(LINUX_ZIP)"


release-windows: release-clear-godot-cache compile-debug compile-windows-release windows-installer-image
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


# A staged script or shader goes in with its .uid (libmaszyna's scripts/check-staged-uids)
check-staged-uids:
	@$(LIBMASZYNA)/scripts/check-staged-uids

# The repository's hooks (scripts/git-hooks): pre-commit runs check-staged-uids
install-git-hooks:
	git config core.hooksPath scripts/git-hooks
