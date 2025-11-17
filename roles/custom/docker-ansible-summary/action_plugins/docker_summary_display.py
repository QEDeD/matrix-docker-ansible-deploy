# SPDX-FileCopyrightText: 2025 MDAD project contributors
# SPDX-License-Identifier: AGPL-3.0-or-later

"""Display helper for Docker Ansible Summary tables.

The default Ansible callback escapes newline characters inside debug output,
which makes wide ASCII tables unreadable when users capture logs with the
default callback (`result_format = json`).  This lightweight action plugin
prints each line directly through Ansible's Display helper so the rendered
table looks identical across callbacks, while still returning a dry `ok`
result to avoid cluttering the log with large dictionaries.
"""

from __future__ import annotations

from ansible import constants as C
from ansible.plugins.action import ActionBase
from ansible.module_utils.common.text.converters import to_text


def _coerce_lines(value: object) -> list[str]:
    """Return a list of text lines from the provided input."""
    if value is None:
        return []
    if isinstance(value, str):
        return to_text(value).splitlines()
    # Accept any iterable (lists, tuples, generators)
    try:
        return [to_text(item) for item in value]  # type: ignore[arg-type]
    except TypeError:
        return [to_text(value)]


class ActionModule(ActionBase):
    """Action plugin that prints summary text without JSON escaping."""

    TRANSFERS_FILES = False
    _VALID_STYLES = {
        "ok": C.COLOR_OK,
        "info": C.COLOR_HIGHLIGHT,
        "warn": C.COLOR_WARN,
        "error": C.COLOR_ERROR,
    }

    def run(self, tmp=None, task_vars=None):
        if task_vars is None:
            task_vars = {}

        result = super().run(tmp, task_vars)
        text = self._task.args.get("text")
        lines = self._task.args.get("lines")
        heading = self._task.args.get("heading")
        style = (self._task.args.get("style") or "ok").lower()
        color = self._VALID_STYLES.get(style, C.COLOR_OK)

        computed_lines = _coerce_lines(lines or text)
        display = self._display

        if heading:
            display.banner(to_text(heading))

        for line in computed_lines:
            display.display(line, color=color)

        result.update(
            changed=False,
            skipped=False,
            failed=False,
            displayed_line_count=len(computed_lines),
        )
        return result
