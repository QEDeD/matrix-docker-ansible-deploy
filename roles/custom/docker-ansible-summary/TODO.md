<!--
SPDX-FileCopyrightText: 2025 MDAD project contributors
SPDX-License-Identifier: AGPL-3.0-or-later
-->

# Docker Ansible Summary TODO

- Validate overall role structure (task layout, variable resolution, fact writing) and align with house style.
- Cross-check role practices (become usage, tagging, idempotency) against MDAD/MASH conventions and document any deliberate deviations.
- Refine container name/version logic (e.g. capture image digests, detect renamed services, surface pending restarts).
- Review the summary table for readability (monitor column sizing/alignment as the dataset grows and tweak defaults if needed).
- Iterate on the NOTES column content (e.g. digests, restart reasons, health indicators) to maximise usefulness without clutter.
- Explore richer change-detail exports (JSON, CSV) that complement the concise on-screen STATUS column.
- Consider capturing ancillary run artifacts (compressed terminal output, fact snapshots) if they strengthen the change-audit story without bloating scope.
- Keep regression coverage for the baseline (`BASELINE (INITIAL)`) and scope-change safeguards up to date (see `tests/test_scope_change.yml` once CI is wired).
