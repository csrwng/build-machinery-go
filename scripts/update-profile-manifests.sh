#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

# This script generates profile-specific manifests by applying
# JSON patches found under the profile-patches directory of the
# operator repository to existing manifests in the operator's
# manifests directory. It uses the 'oc patch' command to apply
# the JSON patch. If 'oc' is not available locally, it will
# download it.
#
# The expected structure of the profile-patches directory is as
# follows:
#
# profile-patches/
#   profile-1/
#     manifest-1.yaml.patch
#     manifest-2.yaml.patch
#   profile-2/
#     manifest-1.yaml.patch
#
# Each patch is expected to be in JSON patch format. It will be
# applied to the manifest named the same as the patch and will result
# in a new manifest suffixed with the profile name.
# The above directory structure will result in the following files:
#
# manifests/
#   manifest-1-profile-1.yaml
#   manifest-2-profile-1.yaml
#   manifest-1-profile-2.yaml
#
# This is in addition to existing manifest-1.yaml and manifest-2.yaml
# files.
#
#
# Dependencies:
# - curl - used to download an oc binary if necessary
# - tar - used to extract an oc binary if necessary
#
# Arguments:
# - $1 - The directory where profile patches live
# - $2 - The directory where the operator manifests live

PROFILE_PATCHES_DIR="$1"
MANIFESTS_DIR="$2"
SCRIPT_TMP="$(mktemp -d)"
OC_CLI="oc"
MANIFEST_HEADER="# WARNING: DO NOT EDIT; generated with 'make update-profile-manifests'."

ensure_oc() {
  # Ensure that a dummy config is available for oc to use
  # The patch is applied locally, but oc will complain that
  # no configuration is present if one is not specified.
  cat <<EOF > "${SCRIPT_TMP}/config"
apiVersion: v1
kind: Config
clusters:
- cluster:
    server: https://example.com:443
  name: cluster
contexts:
- context:
    cluster: cluster
    namespace: default
    user: user
  name: default
current-context: default
users:
- name: user
  user:
    token: MTIzNDUK
EOF

  if which oc &> /dev/null; then
    return
  fi

  local os_type="linux"
  if [[ "${OSTYPE}" == "darwin"* ]]; then
    os_type="macosx"
  fi

  local download_url="https://mirror.openshift.com/pub/openshift-v4/clients/oc/latest/${os_type}/oc.tar.gz"
  curl --silent --fail --location "${download_url}" --output - | tar -C "${SCRIPT_TMP}" -xz
  OC_CLI="${SCRIPT_TMP}/oc"
  chmod +x "${OC_CLI}"
}

cleanup() {
  rm -rf "${SCRIPT_TMP}"
}
trap cleanup EXIT

apply_patch() {
  local profile="$1"
  local patch_file="$2"

  # Derive the name of the file to patch based on the
  # patch file name
  local file_to_patch
  file_to_patch="$(basename "${patch_file}")"
  file_to_patch="${file_to_patch%.*}"               # Remove .patch extension
  file_to_patch="${MANIFESTS_DIR}/${file_to_patch}" # Prefix with manifests directory path

  # Derive the name of the output file based on the
  # file to patch and the profile name
  local target_file="${file_to_patch}"
  target_file="${target_file%.*}"                   # Remove .yaml extension
  target_file="${target_file}-${profile}.yaml"      # Append profile name as suffix and restore extension
  tmp_manifest=${SCRIPT_TMP}/tmp.yaml

  if [[ ! -f "${file_to_patch}" ]]; then
    echo "Expected file not found: ${file_to_patch}. Remove corresponding patch file ${patch_file}"
    exit 1
  fi

  KUBECONFIG="${SCRIPT_TMP}/config" "${OC_CLI}" patch --local \
    --filename "${file_to_patch}" --type=json \
    --patch "$(cat "${patch_file}")" \
    --output yaml > "${tmp_manifest}"

  cat <(echo "${MANIFEST_HEADER}") "${tmp_manifest}" > "${target_file}"
}

# Iterates over patch files inside a profile directory and
# applies them, resulting in profile-specific manifests in
# the manifests directory
apply_profile_patches() {
  local profile_dir="$1"
  while read -r patch_file; do
    apply_patch "$(basename "${profile_dir}")" "${patch_file}"
  done < <(ls "${profile_dir}"*.patch 2> /dev/null)
}

# Iterates over profile directories under the profile-patches
# directory and applies all patches within
apply_all_profile_patches() {
  local profile_dir
  while read -r profile_dir; do
    apply_profile_patches "${profile_dir}"
  done < <(ls -d "${PROFILE_PATCHES_DIR}/"*/ 2> /dev/null)
}

ensure_oc
apply_all_profile_patches
