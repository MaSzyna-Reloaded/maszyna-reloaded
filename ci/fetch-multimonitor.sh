#!/usr/bin/env bash
# vendor/multimonitor is private: .gitmodules gives it `update = none`, so a plain `submodule update
# --init --recursive` (every build's own checkout) skips it, and this script alone fetches it - a
# read-only token (MULTIMONITOR_TOKEN) scoped to this one URL alone, never the run's own, so a pull
# request's build steps reading .git/config find no wider credential there (the security review that
# flagged the same of the run's own token, build.yaml's persist-credentials: false).
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
URL="https://x-access-token:${MULTIMONITOR_TOKEN:?MULTIMONITOR_TOKEN is not set}@github.com/MaSzyna-Reloaded/multimonitor-addon"

git -C "$REPO_DIR" config --global "url.$URL.insteadOf" "git@github.com:MaSzyna-Reloaded/multimonitor-addon.git"
trap 'git -C "$REPO_DIR" config --global --unset "url.$URL.insteadOf"' EXIT

# update = none (.gitmodules) keeps every other `submodule update --init --recursive` off this one;
# overridden here, the one place that is supposed to fetch it
git -C "$REPO_DIR" -c submodule.vendor/multimonitor.update=checkout submodule update --init --recursive -- vendor/multimonitor
