#!/bin/bash
# SPDX-FileCopyrightText: 2025 MDAD project contributors
# SPDX-License-Identifier: AGPL-3.0-or-later
# Docker Ansible Summary – Role Test Shortcut

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
QUICK_SCRIPT="${SCRIPT_DIR}/quick_validation.sh"

if [ ! -x "$QUICK_SCRIPT" ]; then
  echo "Quick validation script missing at $QUICK_SCRIPT" >&2
  exit 1
fi

exec "$QUICK_SCRIPT"
