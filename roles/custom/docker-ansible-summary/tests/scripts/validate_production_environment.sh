#!/bin/bash
# Docker Ansible Summary – Production Environment Validation

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MASTER_SCRIPT="${SCRIPT_DIR}/master_test_suite.sh"

if [ ! -x "$MASTER_SCRIPT" ]; then
  echo "Master test suite missing at $MASTER_SCRIPT" >&2
  exit 1
fi

if "$MASTER_SCRIPT"; then
  printf "Production environment validation passed.\n"
else
  status=$?
  printf "Production environment validation failed. See /tmp/docker-ansible-summary-test.log.\n" >&2
  exit $status
fi
