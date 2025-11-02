#!/bin/bash
# Docker Ansible Summary – Production Test Harness

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MASTER_SCRIPT="${SCRIPT_DIR}/master_test_suite.sh"

if [ ! -x "$MASTER_SCRIPT" ]; then
  echo "Master suite missing at $MASTER_SCRIPT" >&2
  exit 1
fi

exec "$MASTER_SCRIPT"
