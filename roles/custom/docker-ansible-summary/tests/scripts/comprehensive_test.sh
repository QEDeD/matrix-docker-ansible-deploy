#!/bin/bash
# Docker Ansible Summary – Comprehensive Test Wrapper
# Delegates to the master test suite for complete coverage.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MASTER_SCRIPT="${SCRIPT_DIR}/master_test_suite.sh"

if [ ! -x "$MASTER_SCRIPT" ]; then
  echo "Master test suite missing at $MASTER_SCRIPT" >&2
  exit 1
fi

printf "=== Docker Ansible Summary – Comprehensive Test Suite ===\n\n"
exec "$MASTER_SCRIPT"
