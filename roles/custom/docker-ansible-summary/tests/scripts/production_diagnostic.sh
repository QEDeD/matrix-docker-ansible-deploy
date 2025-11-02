#!/bin/bash
# Docker Ansible Summary – Production Diagnostic Wrapper

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "${SCRIPT_DIR}/production_diagnosis.sh"
