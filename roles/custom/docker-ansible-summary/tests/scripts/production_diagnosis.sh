#!/bin/bash
# Docker Ansible Summary – Production Diagnostics
# Executes the master suite to surface actionable failures.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MASTER_SCRIPT="${SCRIPT_DIR}/master_test_suite.sh"
LOG_FILE="/tmp/docker-ansible-summary-test.log"

if [ ! -x "$MASTER_SCRIPT" ]; then
  echo "Master suite missing at $MASTER_SCRIPT" >&2
  exit 1
fi

printf "=== Docker Ansible Summary – Production Diagnostics ===\n\n"
if "$MASTER_SCRIPT"; then
  printf "No issues detected. Detailed log: %s\n" "$LOG_FILE"
else
  status=$?
  printf "Failures detected; inspect %s for details.\n" "$LOG_FILE" >&2
  exit $status
fi
