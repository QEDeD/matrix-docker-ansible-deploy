<!--
SPDX-FileCopyrightText: 2025 MDAD project contributors
SPDX-License-Identifier: AGPL-3.0-or-later
-->

# Docker Ansible Summary – Test Suite Documentation

This directory contains the regression assets for the Docker Ansible Summary (DAS) role. The suite is designed to run entirely from the project virtualenv without Docker access, relying on the role's mock helpers and container overrides.

## Helper Scripts

| Script | Purpose |
|--------|---------|
| `master_test_suite.sh` | Runs linting, syntax checks, and a curated batch of regression playbooks. Outputs a consolidated log at `/tmp/docker-ansible-summary-test.log`. |
| `quick_validation.sh` | Executes the most important health checks (lint, syntax, scope change, history renderer). Ideal for pre-commit spot checks. |
| `production_ready.sh` | Convenience wrapper: runs `quick_validation.sh` and then the master suite. |
| `comprehensive_test.sh` | Legacy alias that now delegates to `master_test_suite.sh`. |
| `production_diagnosis.sh` / `production_diagnostic.sh` | Wrappers around the master suite for operators who expect the historical script names. |
| `production_test.sh`, `validate_production_environment.sh`, `validate_production.sh`, `final_validation.sh`, `test_role.sh` | Thin wrappers that execute either the master suite or quick validation to preserve CLI compatibility. |

All scripts automatically use the project virtualenv (`.venv/bin`) unless you override `ANSIBLE_LINT`, `ANSIBLE_PLAYBOOK`, or `PYTHON` in the environment.

## Key Playbooks

The playbooks live beside this documentation (`roles/custom/docker-ansible-summary/tests`). They disable live Docker discovery and fact writes by default, so they are safe to run locally.

| Playbook | Coverage |
|----------|----------|
| `test_scope_change.yml` | Baseline snapshots, scope changes, removal events. |
| `test_scope_filters.yml` | Filter plugin behaviour (`docker_scope_*` helpers). |
| `test_scope_variants.yml` | Multiple glob patterns and override combinations. |
| `test_bsd_retention.yml` | BSD-friendly retention logic (`date -v` fallback). |
| `test_mock_mode.yml` | Mock mode rendering and metadata packaging. |
| `test_history.yml` | History renderer (changes vs full) using the new templates. |
| `test_display_fix.yml` / `test_display_fix_direct.yml` | Table renderer ergonomics and column sizing. |
| `test_table_format_direct.yml`, `test_table_format_preview.yml`, `test_table_pure.yml` | Formatting previews for ASCII/Unicode output. |
| `test_table_notes.yml` | Exercises the NOTES column and adaptive width settings. |
| `test_restart_count.yml` | Restart count metadata capture via `docker_container_info`. |
| `test_all_functions.yml`, `test_new_table_format.yml`, `test_no_ljust.yml`, `test_border_formatting.yml` | Legacy regression scenarios retained for additional coverage. |

## Running the Suite

### Quick Check

```bash
cd /home/ansible-admin/matrix-docker-ansible-deploy/roles/custom/docker-ansible-summary
./tests/scripts/quick_validation.sh
```

### Full Coverage

```bash
cd /home/ansible-admin/matrix-docker-ansible-deploy/roles/custom/docker-ansible-summary
./tests/scripts/master_test_suite.sh
# Review /tmp/docker-ansible-summary-test.log for detailed output
```

### Individual Playbook

```bash
ANSIBLE_PLAYBOOK=/home/ansible-admin/matrix-docker-ansible-deploy/.venv/bin/ansible-playbook \
  $ANSIBLE_PLAYBOOK roles/custom/docker-ansible-summary/tests/test_scope_change.yml
```

> **Tip:** When running playbooks manually, ensure the virtualenv tooling is used (`.venv/bin/ansible-playbook`). System packages may lack the required Ansible modules and `community.docker` collection.

## Maintenance Checklist

1. Update `docs/TESTING.md` and this file whenever test workflows change.
2. Keep helper scripts pointing at the virtualenv so linting uses the bundled `ansible-core` modules.
3. Add new regression playbooks to both `master_test_suite.sh` and this documentation.
4. When adding a new dependency, list it in `collections/requirements.yml` and mention it in `docs/TESTING.md`.

## Troubleshooting

| Symptom | Likely Cause | Resolution |
|---------|--------------|------------|
| `ModuleNotFoundError: ansible.parsing.yaml.constructor` | Running system `ansible-lint` instead of the virtualenv binary. | Use `.venv/bin/ansible-lint` (scripts already do this). |
| Docker discovery fails with SDK error | Managed host lacks the Docker SDK for Python. | Install `python3-docker`/`pip install docker` on the target; DAS now hard-fails without it. |
| Tests attempt to write facts locally | `docker_summary_write_facts` not overridden. | The test includes disable writes; ensure new plays follow the pattern. |
| History tables misalign in terminals | Switch to ASCII via `docker_summary_table_style_unicode: false` (default) when capturing logs. |

Logs for the master suite are always written to `/tmp/docker-ansible-summary-test.log`; delete the file between runs if you prefer a clean slate.
