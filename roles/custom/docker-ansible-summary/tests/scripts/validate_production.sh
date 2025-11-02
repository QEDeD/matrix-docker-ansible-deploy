#!/bin/bash
# Docker Ansible Summary – Validate Production

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "${SCRIPT_DIR}/validate_production_environment.sh"
