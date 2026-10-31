#!/usr/bin/env bash
# The moving tag of the pre-release of a pull request from release/<name>: maszyna-reloaded-rc-<name>,
# "/" as "-". The build moves it to the pull request's head, the cleanup deletes it when the pull
# request closes (.github/workflows/build.yaml, release-candidate-cleanup.yaml).
set -euo pipefail

branch=${1:?usage: $0 release/<name>}
name=${branch#release/}
echo "maszyna-reloaded-rc-${name//\//-}"
