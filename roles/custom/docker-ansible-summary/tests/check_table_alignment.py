# SPDX-FileCopyrightText: 2025 MDAD project contributors
# SPDX-License-Identifier: AGPL-3.0-or-later

from __future__ import annotations

import sys
from pathlib import Path


def main() -> int:
    if len(sys.argv) < 2:
        print("[das-tests] usage: check_table_alignment.py <logfile>", file=sys.stderr)
        return 1
    lines = Path(sys.argv[1]).read_text(encoding="utf-8").splitlines()
    table_lines = [ln for ln in lines if ln.startswith(("|", "│"))]
    if not table_lines:
        print("[das-tests] no table rows starting with '|' or '│' found", file=sys.stderr)
        return 1
    sep_char = table_lines[0][0]
    ref_positions = [i for i, ch in enumerate(table_lines[0]) if ch == sep_char]
    for ln in table_lines[1:]:
        if not ln.startswith(sep_char):
            continue
        positions = [i for i, ch in enumerate(ln) if ch == sep_char]
        if positions != ref_positions:
            print(
                f"[das-tests] misaligned row: {ln!r} "
                f"(expected positions {ref_positions}, got {positions})",
                file=sys.stderr,
            )
            return 1

    border_lines = [ln for ln in lines if ln.startswith("+")]
    for ln in border_lines:
        positions = [i for i, ch in enumerate(ln) if ch == "+"]
        if positions != ref_positions:
            print(
                f"[das-tests] misaligned border row: {ln!r} "
                f"(expected positions {ref_positions}, got {positions})",
                file=sys.stderr,
            )
            return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
