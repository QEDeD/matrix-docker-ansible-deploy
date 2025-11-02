#!/bin/bash
# Docker Ansible Summary – Quick Validation
# Runs a focused subset of linting and regression checks using the project virtualenv.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROLE_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
PROJECT_DIR="$(cd "${ROLE_DIR}/../../.." && pwd)"
VENV_DIR="${PROJECT_DIR}/.venv"
BIN_DIR="${VENV_DIR}/bin"
ANSIBLE_LINT_BIN="${ANSIBLE_LINT:-${BIN_DIR}/ansible-lint}"
ANSIBLE_PLAYBOOK_BIN="${ANSIBLE_PLAYBOOK:-${BIN_DIR}/ansible-playbook}"

for tool in "$ANSIBLE_LINT_BIN" "$ANSIBLE_PLAYBOOK_BIN"; do
  if [ ! -x "$tool" ]; then
    echo "Missing tool: $tool" >&2
    echo "Run 'just setup' or install the role tooling into the virtualenv." >&2
    exit 1
  fi
done

export PATH="${BIN_DIR}:$PATH"

GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

printf "${BLUE}=== Docker Ansible Summary – Quick Validation ===${NC}\n\n"

run_check() {
  local name="$1"
  local command="$2"

  printf "%-45s" "$name"
  if bash -lc "$command" >/dev/null 2>&1; then
    printf "${GREEN}OK${NC}\n"
  else
    printf "${RED}FAIL${NC}\n"
    return 1
  fi
}

RESULT=0
run_check "ansible-lint (production profile)" \
  "cd \"$ROLE_DIR\" && \"$ANSIBLE_LINT_BIN\" tasks --profile production" || RESULT=1
run_check "role syntax" \
  "cd \"$ROLE_DIR\" && \"$ANSIBLE_PLAYBOOK_BIN\" tests/test_role_syntax.yml --syntax-check" || RESULT=1
run_check "scope change regression" \
  "cd \"$PROJECT_DIR\" && \"$ANSIBLE_PLAYBOOK_BIN\" roles/custom/docker-ansible-summary/tests/test_scope_change.yml" || RESULT=1
run_check "history renderer" \
  "cd \"$PROJECT_DIR\" && \"$ANSIBLE_PLAYBOOK_BIN\" roles/custom/docker-ansible-summary/tests/test_history.yml" || RESULT=1

if [ $RESULT -eq 0 ]; then
  printf "\n${GREEN}Quick validation passed. Run tests/scripts/master_test_suite.sh for the full suite.${NC}\n"
else
  printf "\n${RED}Quick validation failed. Consult the log output above and the master test suite for details.${NC}\n"
fi

exit $RESULT
