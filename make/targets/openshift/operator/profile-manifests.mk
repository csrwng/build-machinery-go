self_dir :=$(dir $(lastword $(MAKEFILE_LIST)))
scripts_dir :=$(shell realpath $(self_dir)../../../../scripts)
repo_dir := $(realpath $(dir $(abspath $(firstword $(MAKEFILE_LIST)))))

PROFILE_PATCHES_DIR ?= $(repo_dir)/profile-patches
MANIFESTS_DIR ?= $(repo_dir)/manifests

.PHONY: update-profile-manifests
update-profile-manifests:
	$(scripts_dir)/update-profile-manifests.sh "$(PROFILE_PATCHES_DIR)" "$(MANIFESTS_DIR)"

.PHONY: verify-profile-manifests
verify-profile-manifests:
	$(scripts_dir)/verify-profile-manifests.sh "$(PROFILE_PATCHES_DIR)" "$(MANIFESTS_DIR)"
