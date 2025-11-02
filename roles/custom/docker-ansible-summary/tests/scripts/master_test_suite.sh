#!/bin/bash
# Docker Ansible Summary – Master Test Suite
# Runs curated linting, syntax, and regression playbooks using the project virtualenv.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROLE_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
PROJECT_DIR="$(cd "${ROLE_DIR}/../../.." && pwd)"
PLAY_DIR="${ROLE_DIR}/tests"
PLAYBOOK_DIR="${PROJECT_DIR}/playbooks/docker-ansible-summary"
LOG_PATH="/tmp/docker-ansible-summary-test.log"

VENV_DIR="${PROJECT_DIR}/.venv"
BIN_DIR_DEFAULT="${VENV_DIR}/bin"
ANSIBLE_LINT_BIN="${ANSIBLE_LINT:-${BIN_DIR_DEFAULT}/ansible-lint}"
ANSIBLE_PLAYBOOK_BIN="${ANSIBLE_PLAYBOOK:-${BIN_DIR_DEFAULT}/ansible-playbook}"
PYTHON_BIN="${PYTHON:-${BIN_DIR_DEFAULT}/python3}"

for tool in "$ANSIBLE_LINT_BIN" "$ANSIBLE_PLAYBOOK_BIN" "$PYTHON_BIN"; do
  if [ ! -x "$tool" ]; then
    echo "Required tool not found: $tool" >&2
    echo "Ensure the project virtualenv is bootstrapped (just setup) or export the path via ANSIBLE_LINT / ANSIBLE_PLAYBOOK / PYTHON." >&2
    exit 1
  fi
done

export PATH="${BIN_DIR_DEFAULT}:$PATH"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

TESTS_TOTAL=0
TESTS_PASSED=0
TESTS_FAILED=0

printf "${BLUE}=== Docker Ansible Summary – Master Test Suite ===${NC}\n"
printf "${BLUE}Log file:${NC} %s\n" "$LOG_PATH"
printf "${BLUE}Role dir:${NC} %s\n\n" "$ROLE_DIR"

{
  echo "Docker Ansible Summary – Master Test Suite"
  echo "Run started: $(date --iso-8601=seconds)"
  echo "Role directory: $ROLE_DIR"
  echo "Virtualenv: $VENV_DIR"
  echo "================================================="
} > "$LOG_PATH"

run_test() {
  local category="$1"
  local name="$2"
  local command="$3"
  local required="${4:-true}"

  TESTS_TOTAL=$((TESTS_TOTAL + 1))
  printf "[%s] %s: " "$category" "$name"

  {
    echo ""
    echo "[$category] $name"
    echo "Command: $command"
    echo "----------------------------------------"
  } >> "$LOG_PATH"

  if timeout 180 bash -lc "$command" >> "$LOG_PATH" 2>&1; then
    printf "${GREEN}PASS${NC}\n"
    echo "Result: PASS" >> "$LOG_PATH"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    if [ "${required}" = "true" ]; then
      printf "${RED}FAIL${NC}\n"
      echo "Result: FAIL (required)" >> "$LOG_PATH"
      TESTS_FAILED=$((TESTS_FAILED + 1))
    else
      printf "${YELLOW}SKIP${NC}\n"
      echo "Result: SKIP (optional)" >> "$LOG_PATH"
    fi
  fi
}

section() {
  local title="$1"
  printf "\n${BLUE}%s${NC}\n" "$title"
  printf "${BLUE}%s${NC}\n" "$(printf '=%0.s' $(seq 1 ${#title}))"
}

cd "$ROLE_DIR"

section "Static analysis"
run_test "STATIC" "ansible-lint (production profile)" \
  "cd \"$ROLE_DIR\" && \"$ANSIBLE_LINT_BIN\" tasks --profile production"
run_test "STATIC" "filter plugins compile" \
  "cd \"$ROLE_DIR\" && \"$PYTHON_BIN\" -m compileall filter_plugins"

section "Syntax checks"
run_test "SYNTAX" "role syntax" \
  "cd \"$ROLE_DIR\" && \"$ANSIBLE_PLAYBOOK_BIN\" tests/test_role_syntax.yml --syntax-check"
run_test "SYNTAX" "history playbook" \
  "cd \"$PROJECT_DIR\" && \"$ANSIBLE_PLAYBOOK_BIN\" playbooks/docker-ansible-summary/history_playbook.yml --syntax-check"
run_test "SYNTAX" "diagnostic playbook" \
  "cd \"$ROLE_DIR\" && \"$ANSIBLE_PLAYBOOK_BIN\" tests/production_diagnostic.yml --syntax-check"

section "Targeted regression plays"
for play in \
  test_scope_change.yml \
  test_scope_filters.yml \
  test_scope_variants.yml \
  test_mock_mode.yml \
  test_history.yml \
  test_bsd_retention.yml \
  test_display_fix.yml \
  test_table_format_direct.yml \
  test_table_notes.yml \
  test_restart_count.yml; do
  run_test "PLAY" "$play" \
    "cd \"$PROJECT_DIR\" && \"$ANSIBLE_PLAYBOOK_BIN\" roles/custom/docker-ansible-summary/tests/$play"
done

section "Extended coverage (optional)"
for play in \
  test_all_functions.yml \
  test_new_table_format.yml \
  test_no_ljust.yml \
  test_border_formatting.yml; do
  run_test "OPTIONAL" "$play" \
    "cd \"$PROJECT_DIR\" && \"$ANSIBLE_PLAYBOOK_BIN\" roles/custom/docker-ansible-summary/tests/$play" \
    false
done

printf "\n${BLUE}Summary${NC}\n"
printf "Total: %d, Passed: %d, Failed: %d\n" "$TESTS_TOTAL" "$TESTS_PASSED" "$TESTS_FAILED"
printf "Log: %s\n" "$LOG_PATH"

if [ "$TESTS_FAILED" -gt 0 ]; then
  exit 1
fi

exit 0
