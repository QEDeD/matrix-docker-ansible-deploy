#!/bin/sh

# SPDX-FileCopyrightText: 2026 MDAD project contributors
#
# SPDX-License-Identifier: AGPL-3.0-or-later

set -eu

repository_path=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
test_playbook="$repository_path/tests/conditional-restart-command-semantics.yml"
test_temporary_directory=$(mktemp -d "${TMPDIR:-/tmp}/mdad-conditional-restart-test.XXXXXX")
trap 'rm -rf -- "$test_temporary_directory"' EXIT HUP INT TERM

ANSIBLE_LOCAL_TEMP="$test_temporary_directory/local"
ANSIBLE_REMOTE_TEMP="$test_temporary_directory/remote"
export ANSIBLE_LOCAL_TEMP ANSIBLE_REMOTE_TEMP

run_scenario() {
    scenario=$1
    tags=$2
    expected=$3

    echo "Testing $scenario tags: $tags"
    ansible-playbook \
        --inventory localhost, \
        --connection local \
        --tags "$tags" \
        --extra-vars "{\"conditional_restart_expected\": $expected}" \
        "$test_playbook"
}

run_scenario install "install-synapse,start-group" true
run_scenario setup "setup-synapse,start-group" false
run_scenario start "start-group" false
run_scenario restart "restart-group" false
run_scenario mixed-install-setup "install-synapse,setup-synapse,start-group" false

echo "Testing explicit boolean override"
ansible-playbook \
    --inventory localhost, \
    --connection local \
    --tags "install-synapse,start-group" \
    --extra-vars '{"conditional_restart_expected": false}' \
    --extra-vars '{"devture_systemd_service_manager_conditional_restart_enabled": false}' \
    "$test_playbook"
