#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2025 MDAD project contributors
# SPDX-License-Identifier: AGPL-3.0-or-later
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
PLAYBOOK="${REPO_ROOT}/roles/custom/docker-ansible-summary/tests/local_suite.yml"
ANSIBLE_PLAYBOOK_BIN="${REPO_ROOT}/.venv/bin/ansible-playbook"

if [[ ! -x "${ANSIBLE_PLAYBOOK_BIN}" ]]; then
  ANSIBLE_PLAYBOOK_BIN="$(command -v ansible-playbook || true)"
fi

if [[ -z "${ANSIBLE_PLAYBOOK_BIN}" ]]; then
  echo "[das-tests] ansible-playbook not found. Install ansible-core or run ./bin/lint-playbook.sh." >&2
  exit 1
fi

if [[ "${1:-}" == "--cleanup" ]]; then
  "${ANSIBLE_PLAYBOOK_BIN}" "${PLAYBOOK}" --tags fixtures --skip-tags "mock,matrix-scope,matrix-mash-scope,custom-namespace,status-mode,history-view,custom-facts"
  exit 0
fi

"${ANSIBLE_PLAYBOOK_BIN}" "${PLAYBOOK}" "$@"
