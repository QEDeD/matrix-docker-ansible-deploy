#!/bin/sh

# SPDX-FileCopyrightText: 2026 MDAD project contributors
#
# SPDX-License-Identifier: AGPL-3.0-or-later

set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repository_dir=$(CDPATH= cd -- "${script_dir}/.." && pwd)
test_dir=$(mktemp -d "${TMPDIR:-/tmp}/matrix-playbook-preflight.XXXXXX")
trap 'rm -rf "${test_dir}"' EXIT HUP INT TERM

export ANSIBLE_LOCAL_TEMP="${test_dir}/ansible-local"
export ANSIBLE_ROLES_PATH="${repository_dir}/roles"

playbook="${repository_dir}/tests/matrix-playbook-preflight.yml"
error_marker=MDAD_PRIVILEGE_ESCALATION_CONFIGURATION_ERROR

expect_failure() {
    test_name=$1
    shift

    set +e
    output=$(ansible-playbook "$@" 2>&1)
    status=$?
    set -e

    if [ "$status" -eq 0 ]; then
        echo "Expected failure: ${test_name}" >&2
        exit 1
    fi

    if ! printf '%s\n' "$output" | grep -Fq "$error_marker"; then
        printf '%s\n' "$output" >&2
        echo "Expected preflight diagnostic: ${test_name}" >&2
        exit 1
    fi
}

ansible-playbook -i localhost, --connection=local "$playbook" --check --tags unrelated
ansible-playbook -i localhost, --connection=local "$playbook" --check --tags unrelated --extra-vars ansible_become_password=placeholder

old_inventory="${test_dir}/old-documented-inventory.ini"
printf '%s\n' 'localhost ansible_connection=local ansible_become=true ansible_become_user=root' > "$old_inventory"

expect_failure "old documented inventory" -i "$old_inventory" "$playbook" --check --tags unrelated
expect_failure "ansible_become=true" -i localhost, --connection=local "$playbook" --check --tags unrelated --extra-vars ansible_become=true
expect_failure "ansible_become=false" -i localhost, --connection=local "$playbook" --check --tags unrelated --extra-vars ansible_become=false
expect_failure "ansible_become_user" -i localhost, --connection=local "$playbook" --check --tags unrelated --extra-vars ansible_become_user=matrix
expect_failure "ansible_sudo_user" -i localhost, --connection=local "$playbook" --check --tags unrelated --extra-vars ansible_sudo_user=root
