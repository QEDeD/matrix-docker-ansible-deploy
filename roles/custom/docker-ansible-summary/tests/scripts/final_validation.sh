#!/bin/bash
# SPDX-FileCopyrightText: 2025 MDAD project contributors
# SPDX-License-Identifier: AGPL-3.0-or-later
# Docker Ansible Summary – Final Validation Shortcut
# Runs the master suite and surfaces the log location.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MASTER_SCRIPT="${SCRIPT_DIR}/master_test_suite.sh"

if [ ! -x "$MASTER_SCRIPT" ]; then
  echo "Master suite not found at $MASTER_SCRIPT" >&2
  exit 1
fi

if "$MASTER_SCRIPT"; then
  printf "\nFinal validation completed successfully. Review /tmp/docker-ansible-summary-test.log for details.\n"
else
  status=$?
  printf "\nFinal validation detected failures. See /tmp/docker-ansible-summary-test.log.\n" >&2
  exit $status
fi
