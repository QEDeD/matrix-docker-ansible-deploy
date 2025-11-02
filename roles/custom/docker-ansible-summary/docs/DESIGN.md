<!--
SPDX-FileCopyrightText: 2025 MDAD project contributors
SPDX-License-Identifier: AGPL-3.0-or-later
-->

# Docker Ansible Summary – Design Overview

This document captures the current architecture of the role, the rationale behind key decisions, and expectations for future changes. Update it whenever the role’s structure or intent shifts.

## Goals and Scope

The role provides a playbook-integrated summary of Docker containers managed by MDAD/MASH playbooks. It:
- Discovers containers (optionally filtered) and records their version, image metadata, and runtime state.
- Compares current state against previous Ansible fact snapshots to classify services as baseline/added/updated/removed.
- Persists machine-readable history (current versions + change log) in `/etc/ansible/facts.d`.
- Renders a compact, terminal-friendly summary table and optional history output.

The design prioritises:
1. Safe default behaviour for production runs (real Docker discovery, persisted facts).
2. Deterministic execution in offline/test environments.
3. Readable diffs and historical traceability.

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│ tasks/main.yml                                                      │
│  ├─ mock_mode.yml (optional, toggled via docker_summary_mock_mode)  │
│  ├─ display_summary.yml (primary execution path)                    │
│  └─ view_history*.yml (invoked when docker_summary_show_history)    │
└─────────────────────────────────────────────────────────────────────┘
```

Supporting components:
- `filter_plugins/docker_summary.py` – normalises scopes, facts, container metadata, change detection, and history metadata.
- `templates/summary_table.j2` – renders the main summary table (ASCII/Unicode configurable).
- `templates/history_*.j2` – render change and full history tables.
- `tests/` – curated playbooks for unit/regression scenarios plus include helpers (`tests/tasks/*.yml`) for executing the role with controlled inputs.

## Key Design Choices

### 1. Helper-Driven Data Normalisation
Previously, `display_summary.yml` and `view_history.yml` contained long `set_fact` chains with inline Jinja gymnastics. The new helper filters consolidate that logic:
- `docker_summary_fact` / `docker_summary_ensure_history` normalise facts retrieved from `ansible_local`.
- `docker_summary_container_*` parse names/images from Docker inspect responses.
- `docker_summary_version` / `docker_summary_metadata` extract version strings and metadata.
- `docker_summary_change_meta`, `docker_summary_status_label`, and `docker_summary_history_metadata` provide consistent change classification and history storage.

**Why:** This keeps the tasks readable, reduces duplication, and makes future tweaks (e.g. alternative change semantics) centralised.

### 2. Module-First Discovery with Explicit Failures
`community.docker.docker_host_info` is the primary discovery path. If it fails because the Docker Python SDK or daemon is missing, the role aborts quickly with a descriptive message. A CLI fallback is not maintained.

**Why:** Module-based discovery yields structured data, avoids shell parsing, and ensures metadata (repo digests, state) is immediately available. Failing fast prevents silent skips when production hosts are misconfigured.

### 3. Toggleable Discovery & Fact Writes
`docker_summary_enable_discovery` and `docker_summary_write_facts` default to `true` but can be disabled for offline or local tests. The helper include files in `tests/tasks/` set them to false along with standardising `ansible_date_time`/`ansible_system`.

**Why:** Automated tests should not require Docker access or filesystem writes, yet production runs should keep the original behaviour.

### 4. Template-Based Output
Both the summary table and history views use Jinja templates rather than shell commands. The templates now support adaptive column sizing (bounded by min/max settings), optional change-notes output, and automatic truncation with ASCII/Unicode ellipses. Keeping this logic in Jinja ensures consistent formatting and simplifies future layout tweaks without returning to shell one-liners.

### 5. Fact Storage Contract
The role reads and writes JSON facts under `/etc/ansible/facts.d/` (`docker_summary_versions_fact_file`, `docker_summary_history_fact_file`). Filenames remain customisable, but the JSON schema is:
```json
{
  "service": {
    "current": "...",
    "previous": "...",
    "status": "CHANGED|UNCHANGED|BASELINE|CURRENT",
    "change_type": "added|updated|removed|baseline|status",
    "metadata": {
      "current": { ... },
      "previous": { ... }
    }
  }
}
```
History data stores a `changes` array and `full_history` map per service, each maintaining up to 20 latest updates.

## Configurability

Key variables (see `defaults/main.yml`):
- `docker_summary_scope`: glob(s) controlling which containers are included.
- `docker_summary_display`, `docker_summary_show_history`: toggle output paths.
- `docker_summary_history_max_entries`, `docker_summary_retention_days`: enforce retention.
- `docker_summary_table_*`: configure column widths, opt into adaptive sizing, switch Unicode/ASCII borders, and expose the optional NOTES column.
- `docker_summary_container_overrides`: inject test data instead of real discovery.

## File Responsibilities

- `defaults/main.yml`: all tunable options, grouped for clarity.
- `tasks/main.yml`: high-level orchestration (facts directory, optional mocks/history).
- `tasks/display_summary.yml`: runtime; orchestrates discovery, diffing, table output, fact writes.
- `tasks/view_history.yml`: standalone history viewer; consumes facts, applies retention, renders tables.
- `templates/*.j2`: presentation layer for summary/history output.
- `filter_plugins/docker_summary.py`: data transformation helpers; required for many tasks.
- `tests/`: regression coverage and debugging tooling.

## Extension Guidelines

When adding new features:
1. Prefer augmenting the helper filters before expanding per-task Jinja expressions.
2. Guard optional behaviour with defaults in `defaults/main.yml` and document them in `README.md`.
3. Keep summary/history facts backwards compatible unless the change is coordinated with consumers.
4. Update `docs/WORKLOG.md` and this design document to reflect structural changes.
5. Add or adapt tests under `tests/` and document new execution steps in `docs/TESTING.md`.
