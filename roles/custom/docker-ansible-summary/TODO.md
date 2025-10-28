# Docker Ansible Summary TODO

- Validate overall role structure (task layout, variable resolution, fact writing) and align with house style.
- Cross-check role practices (become usage, tagging, idempotency) against MDAD/MASH conventions and document any deliberate deviations.
- Refine container name/version logic (e.g. capture image digests, detect renamed services, surface pending restarts).
- Review the summary table for readability (column sizing, alignment) and add configuration hooks as needed.
- Introduce flexible table render options (ASCII/Unicode, optional additional columns).
- Revisit status labelling so rows only report `CHANGED`/`UNCHANGED` (or similar high-signal values) instead of multiple labels.
- Consider capturing ancillary run artifacts (compressed terminal output, fact snapshots) if they strengthen the change-audit story without bloating scope.
