<!--
SPDX-FileCopyrightText: 2025 MDAD project contributors
SPDX-License-Identifier: AGPL-3.0-or-later
-->

# Docker Ansible Summary TODO

- Validate overall role structure (task layout, variable resolution, fact writing) and align with house style.
- Cross-check role practices (become usage, tagging, idempotency) against MDAD/MASH conventions and document any deliberate deviations.
- Refine container name/version logic (e.g. capture image digests, detect renamed services, surface pending restarts).
- Review the summary table for readability (column sizing, alignment) and add configuration hooks as needed.
- Introduce flexible table render options (ASCII/Unicode, optional additional columns).
- Evaluate whether to expose change types (added/updated/removed) in an optional notes column or via metadata tooling while keeping the status column uniform.
- Consider capturing ancillary run artifacts (compressed terminal output, fact snapshots) if they strengthen the change-audit story without bloating scope.
