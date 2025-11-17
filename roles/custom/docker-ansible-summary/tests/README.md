<!--
SPDX-FileCopyrightText: 2025 MDAD project contributors
SPDX-License-Identifier: AGPL-3.0-or-later
-->

# Docker Ansible Summary – Local Test Suite

This directory contains a fresh local-only regression harness for the Docker
Ansible Summary (DAS) role. The suite is tailored for contributors who need to
validate changes quickly on the control host without deploying a full MDAD stack.

## Prerequisites

1. Python virtualenv prepared via the playbook helpers (run `./bin/lint-playbook.sh`
   once to ensure `.venv` contains `ansible-core`, `community.docker`, etc.).
2. Docker Engine available on the control node (the suite launches disposable
   containers named `matrix-*` and `mash-*`).
3. Passwordless `sudo` is **not** required—the tests disable fact writes so no
   privileged file operations occur.

## Running the Suite

```bash
cd /home/ansible-admin/matrix-docker-ansible-deploy
./roles/custom/docker-ansible-summary/tests/run-local-suite.sh
```

The helper script:

- Uses `.venv/bin/ansible-playbook` when available (falls back to the system
  binary otherwise).
- Executes `tests/local_suite.yml`, which orchestrates every scenario.
- Cleans up all Docker fixtures even if a scenario fails.

If you only need to re-run a subset, invoke the playbook directly and limit the
scenarios via tags:

```bash
.venv/bin/ansible-playbook roles/custom/docker-ansible-summary/tests/local_suite.yml \
  --tags fixtures,matrix-scope
```

(See the playbook header for the available tags.)

## Covered Scenarios

| Tag | Description |
|-----|-------------|
| `mock` | Verifies mock mode rendering without Docker. |
| `fixtures` | Creates/removes disposable `matrix-*` and `mash-*` containers. |
| `matrix-scope` | Baseline and update/removal detection for `matrix-*` containers. |
| `matrix-mash-scope` | Combined scope covering both Matrix and MASH prefixes. |
| `custom-namespace` | Ensures arbitrary prefixes (e.g. `mash-netbox-*`) are supported. |
| `status-mode` | Exercises the tag-only/status output branch. |
| `history-view` | Renders the history tables (changes/full) and retention logic using cached facts. |
| `state-notes` | Validates NOTES output for stopped/crashed containers. |
| `custom-facts` | Confirms alternative fact filenames and custom fact directories work. |

Each scenario runs as part of the `local_suite.yml` playbook; feel free to add
more tasks under `tests/tasks/` if you need additional coverage.

## Extending the Suite

1. Define new task files under `tests/tasks/` with focused assertions.
2. Import them from `local_suite.yml` (and optionally gate them behind their own
   tag for quick filtering).
3. Update this README if the workflow changes.

## Troubleshooting

- **`ERROR! the role 'custom/docker-ansible-summary' was not found`** – Run the
  playbook from the repository root so Ansible resolves relative paths.
- **`community.docker` module missing** – Install collections into the virtualenv
  (`./bin/lint-playbook.sh`) or `ansible-galaxy collection install -r collections/requirements.yml`.
- **Containers left running after abort** – `run-local-suite.sh` has an `--cleanup`
  flag that removes the fixtures without running the suite:
  `./roles/.../tests/run-local-suite.sh --cleanup`.

Happy hacking!
