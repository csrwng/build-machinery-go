#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail


# This script verifies that profile-specific manifests in
# the manifests directory are up to date.
#
# Arguments:
# - $1 - The directory where profile patches live
# - $2 - The directory where the operator manifests live

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
PROFILE_PATCHES_DIR="$1"
MANIFESTS_DIR="$2"
SCRIPT_TMP="$(mktemp -d)"

cleanup() {
  rm -rf "${SCRIPT_TMP}"
}
trap cleanup EXIT

verify_manifests() {
  # Generate manifests in temporary directory
  cp -R "${MANIFESTS_DIR}"/* "${SCRIPT_TMP}/"
  "${SCRIPT_DIR}"/update-profile-manifests.sh "${PROFILE_PATCHES_DIR}" "${MANIFESTS_DIR}"

  # Ensure there is no difference in existing manifests with the generated ones
  if ! diff -Na "${MANIFESTS_DIR}" "${SCRIPT_TMP}"; then
    echo "Profile manifests not up to date. Use 'make update-profile-manifests' to update"
    exit 1
  fi
}

verify_manifests
