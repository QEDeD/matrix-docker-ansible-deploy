#!/bin/bash
# SPDX-FileCopyrightText: 2025 MDAD project contributors
# SPDX-License-Identifier: AGPL-3.0-or-later
# Docker Ansible Summary – Production Readiness Shortcut
# Runs quick validation followed by the master suite to mirror production expectations.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROLE_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"

QUICK_SCRIPT="${SCRIPT_DIR}/quick_validation.sh"
MASTER_SCRIPT="${SCRIPT_DIR}/master_test_suite.sh"

if [ ! -x "$QUICK_SCRIPT" ] || [ ! -x "$MASTER_SCRIPT" ]; then
  echo "Missing helper scripts in ${SCRIPT_DIR}." >&2
  exit 1
fi

printf "=== Docker Ansible Summary – Production Readiness ===\n\n"

if "$QUICK_SCRIPT"; then
  printf "\nQuick validation succeeded. Running the master suite...\n\n"
else
  printf "\nQuick validation failed; see output above. Master suite run aborted.\n"
  exit 1
fi

if "$MASTER_SCRIPT"; then
  printf "\nProduction readiness checks completed successfully for role at %s\n" "$ROLE_DIR"
else
  printf "\nMaster suite reported failures. Review /tmp/docker-ansible-summary-test.log.\n" >&2
  exit 1
fi
