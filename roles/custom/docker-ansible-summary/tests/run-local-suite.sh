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

# Verify the stdout rendering path using the default callback so regressions show up early.
OUTPUT_PLAYBOOK="${REPO_ROOT}/roles/custom/docker-ansible-summary/tests/output_snapshot.yml"
OUTPUT_LOG="$(mktemp -t das-output-XXXX.log)"
if ! ANSIBLE_FORCE_COLOR=0 ANSIBLE_STDOUT_CALLBACK=default "${ANSIBLE_PLAYBOOK_BIN}" "${OUTPUT_PLAYBOOK}" >"${OUTPUT_LOG}"
then
  echo "[das-tests] output snapshot playbook failed (log: ${OUTPUT_LOG})" >&2
  exit 1
fi

if ! rg -q "DOCKER SERVICE VERSION CHANGES" "${OUTPUT_LOG}"; then
  echo "[das-tests] summary header missing from stdout snapshot (log: ${OUTPUT_LOG})" >&2
  exit 1
fi

if rg -q '"DOCKER SERVICE VERSION CHANGES' "${OUTPUT_LOG}"; then
  echo "[das-tests] summary header appears quoted, expected raw lines (log: ${OUTPUT_LOG})" >&2
  exit 1
fi

if ! rg -q "\|\s+app-api" "${OUTPUT_LOG}"; then
  echo "[das-tests] summary rows missing from stdout snapshot (log: ${OUTPUT_LOG})" >&2
  exit 1
fi

if ! rg -q "^\|" "${OUTPUT_LOG}"; then
  echo "[das-tests] table rows should start at column 1 (log: ${OUTPUT_LOG})" >&2
  exit 1
fi

if rg -q "^  \|" "${OUTPUT_LOG}"; then
  echo "[das-tests] detected indented table rows, expected flush-left '|' (log: ${OUTPUT_LOG})" >&2
  exit 1
fi

rm -f "${OUTPUT_LOG}"
