#!/bin/sh

# SPDX-FileCopyrightText: 2026 MDAD project contributors
#
# SPDX-License-Identifier: AGPL-3.0-or-later

set -eu

script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
repo_root=$(CDPATH='' cd -- "${script_dir}/../../../.." && pwd)
ansible_playbook_bin=${ANSIBLE_PLAYBOOK_BIN:-}

if [ -z "$ansible_playbook_bin" ] && [ -x "${repo_root}/.venv/bin/ansible-playbook" ]; then
	ansible_playbook_bin="${repo_root}/.venv/bin/ansible-playbook"
fi
if [ -z "$ansible_playbook_bin" ]; then
	ansible_playbook_bin=$(command -v ansible-playbook || true)
fi
if [ -z "$ansible_playbook_bin" ]; then
	printf 'ansible-playbook not found; set ANSIBLE_PLAYBOOK_BIN or install ansible-core\n' >&2
	exit 1
fi

tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT HUP INT TERM
: "${ANSIBLE_LOCAL_TEMP:=${tmp_dir}/ansible-local}"
: "${ANSIBLE_REMOTE_TEMP:=${tmp_dir}/ansible-remote}"
export ANSIBLE_LOCAL_TEMP ANSIBLE_REMOTE_TEMP

"${script_dir}/test-systemd-healthcheck.sh"
"$ansible_playbook_bin" "${script_dir}/startup-timing.yml" --extra-vars "timing_test_output_dir=${tmp_dir}"

if command -v systemd-analyze >/dev/null 2>&1; then
	systemd-analyze verify "${tmp_dir}"/*.service
else
	printf 'systemd-analyze not found; rendered-unit verification skipped\n' >&2
fi

printf 'Synapse startup timing tests passed\n'
