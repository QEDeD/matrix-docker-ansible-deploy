<!--
SPDX-FileCopyrightText: 2025 MDAD project contributors
SPDX-License-Identifier: AGPL-3.0-or-later
-->

# Docker Ansible Summary – Testing Guide

This guide describes the supported test workflows for the role, including required tooling, recommended commands, and troubleshooting tips.

## Prerequisites

| Component | Purpose | Notes |
|-----------|---------|-------|
| Python 3.12 virtualenv (`.venv/`) | Provides isolated tooling (ansible-core, ansible-lint) | Activate with `source .venv/bin/activate` if you prefer an interactive shell. |
| `ansible-core` | Needed by the role and by `ansible-lint` | Installed in the virtualenv; the system package `ansible-core` is optional but useful for other tools. |
| `community.docker` collection | Supplies `community.docker.docker_host_info` and `docker_container_info` | Install via `ansible-galaxy collection install community.docker`. |

For local tests, no Docker daemon is required: the role’s default test harness disables discovery and fact writes.

## Linting

Always use the virtualenv binary to ensure the correct Ansible modules are available:

```bash
cd /home/ansible-admin/matrix-docker-ansible-deploy/roles/custom/docker-ansible-summary
../../../.venv/bin/ansible-lint tasks/ --profile=production
```

If `ansible-lint` warns about PATH alterations, it is safe to ignore so long as the run succeeds.

Before linting for the first time (or after pulling new dependencies) install the required collections:

```bash
ansible-galaxy collection install -r collections/requirements.yml
```

Additional lint helpers:

```bash
# Run every configured hook (yamllint, reuse, trimming, etc.)
pre-commit run --all-files

# Spot-check YAML files (uses the repo’s .yamllint config)
yamllint roles/custom/docker-ansible-summary
```

## Targeted Playbook Tests

Most regression coverage lives under `roles/custom/docker-ansible-summary/tests`. Useful subsets:

```bash
# Change-detection regression (scope changes, removals, etc.)
ansible-playbook roles/custom/docker-ansible-summary/tests/test_scope_change.yml

# Filter helper smoke tests
ansible-playbook roles/custom/docker-ansible-summary/tests/test_scope_filters.yml

# BSD retention fallback (date -v)
ansible-playbook roles/custom/docker-ansible-summary/tests/test_bsd_retention.yml

# Mock mode table rendering
ansible-playbook roles/custom/docker-ansible-summary/tests/test_mock_mode.yml

# History renderer smoke test
ansible-playbook roles/custom/docker-ansible-summary/tests/test_history.yml

# Notes column + auto width
ansible-playbook roles/custom/docker-ansible-summary/tests/test_table_notes.yml
```

Each play sets:
- `docker_summary_enable_discovery: false` – avoids Docker calls.
- `docker_summary_write_facts: false` – prevents filesystem writes.
- Synthetic `ansible_date_time` / `ansible_system` facts – ensures deterministic timestamps and platform handling.

## Running a Wider Suite

For a larger batch (but still curated to known-good plays), you can rely on the master script or loop below:

```bash
cd /home/ansible-admin/matrix-docker-ansible-deploy/roles/custom/docker-ansible-summary
./tests/scripts/master_test_suite.sh
```

To mimic the script’s play loop manually:

```bash
for play in \
  test_scope_change.yml \
  test_scope_filters.yml \
  test_scope_variants.yml \
  test_bsd_retention.yml \
  test_mock_mode.yml \
  test_display_fix.yml \
  test_table_format_direct.yml \
  test_table_notes.yml \
  test_new_table_format.yml \
  test_no_ljust.yml; do
  ansible-playbook roles/custom/docker-ansible-summary/tests/$play || break
done
```

### Quick Validation

When iterating on small changes, run the focused health check:

```bash
cd /home/ansible-admin/matrix-docker-ansible-deploy/roles/custom/docker-ansible-summary
./tests/scripts/quick_validation.sh
```

It covers lint, syntax, scope-change regression, and history rendering in under a minute.

## Common Issues

| Symptom | Likely Cause | Resolution |
|---------|--------------|------------|
| `ModuleNotFoundError: ansible.parsing.yaml.constructor` | Running system `ansible-lint` without `ansible-core` modules | Invoke the virtualenv version (`.venv/bin/ansible-lint`) or install `ansible-core` system-wide. |
| Docker discovery aborts with SDK error | `python3-docker` (Docker SDK) missing on remote host | Install via `sudo apt install python3-docker` or `pip install docker`; discovery is intentionally hard-failing. |
| Tests try to write to `/etc/ansible/facts.d/` | The play or include role sets `docker_summary_write_facts: true` | Override to `false` in the test vars or include helper tasks from `tests/tasks/`. |

## Workflow Checklist

1. Update docs (`docs/WORKLOG.md`, `docs/DESIGN.md`, this file) when behaviour changes.
2. Run lint: `../../../.venv/bin/ansible-lint tasks/ --profile=production`.
3. Execute relevant regression plays (`test_scope_change.yml`, `test_bsd_retention.yml`, etc.).
4. For large changes, consider running the full curated loop described above.
5. Capture any new or adjusted test commands here so future contributors remain aligned.
