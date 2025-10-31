from __future__ import annotations

# SPDX-FileCopyrightText: 2025 MDAD project contributors
# SPDX-License-Identifier: AGPL-3.0-or-later

from fnmatch import fnmatch
from typing import Any, Dict, Iterable, List, Mapping


def _normalize_scope(scope: Any) -> List[str]:
    if scope is None:
        return []
    if isinstance(scope, str):
        scope_list = [scope]
    else:
        scope_list = list(scope)
    cleaned: List[str] = []
    for item in scope_list:
        if item is None:
            continue
        text = str(item).strip()
        if text == "":
            continue
        cleaned.append(text)
    return cleaned


def _is_all(patterns: Iterable[str]) -> bool:
    patterns = list(patterns)
    if not patterns:
        return True
    lowered = {p.lower() for p in patterns}
    return "all" in lowered or "*" in lowered


def _match(name: str, patterns: Iterable[str]) -> bool:
    return any(fnmatch(name, pattern) for pattern in patterns)


def docker_scope_patterns(scope: Any) -> List[str]:
    return _normalize_scope(scope)


def docker_scope_all(scope: Any) -> bool:
    return _is_all(_normalize_scope(scope))


def docker_scope_filter(containers: Iterable[Mapping[str, Any]], scope: Any) -> List[Mapping[str, Any]]:
    if containers is None:
        return []
    patterns = _normalize_scope(scope)
    if _is_all(patterns):
        return list(containers)
    return [container for container in containers if _match(str(container.get("name", "")), patterns)]


def docker_scope_filter_dict(data: Mapping[str, Any], scope: Any) -> Dict[str, Any]:
    if not isinstance(data, Mapping):
        return {}
    patterns = _normalize_scope(scope)
    if _is_all(patterns):
        return dict(data)
    return {key: value for key, value in data.items() if _match(str(key), patterns)}


class FilterModule(object):
    def filters(self) -> Dict[str, Any]:
        return {
            "docker_scope_patterns": docker_scope_patterns,
            "docker_scope_all": docker_scope_all,
            "docker_scope_filter": docker_scope_filter,
            "docker_scope_filter_dict": docker_scope_filter_dict,
        }
