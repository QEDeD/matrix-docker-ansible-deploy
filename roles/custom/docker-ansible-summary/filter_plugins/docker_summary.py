from __future__ import annotations

# SPDX-FileCopyrightText: 2025 MDAD project contributors
# SPDX-License-Identifier: AGPL-3.0-or-later

from fnmatch import fnmatch
from typing import Any, Dict, Iterable, List, Mapping, Optional

import yaml


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


def _coerce_to_mapping(value: Any, default: Optional[Mapping[str, Any]] = None) -> Dict[str, Any]:
    if isinstance(value, Mapping):
        return dict(value)
    if isinstance(value, str):
        try:
            parsed = yaml.safe_load(value)
            if isinstance(parsed, Mapping):
                return dict(parsed)
        except yaml.YAMLError:
            pass
    if isinstance(default, Mapping):
        return dict(default)
    return {}


def docker_summary_fact(facts: Any, key: Any, default: Optional[Mapping[str, Any]] = None) -> Dict[str, Any]:
    if default is None:
        default = {}
    if not isinstance(facts, Mapping):
        return _coerce_to_mapping(default)
    return _coerce_to_mapping(facts.get(key, default), default)


def docker_summary_ensure_history(history: Any) -> Dict[str, Any]:
    result = _coerce_to_mapping(history, {})
    result.setdefault("last_versions", {})
    result.setdefault("changes", [])
    result.setdefault("full_history", {})
    result.setdefault("last_metadata", {})
    return result


def docker_summary_container_name(container: Any) -> str:
    if not isinstance(container, Mapping):
        return ""
    names = container.get("Names")
    if isinstance(names, list) and names:
        name = names[0]
    else:
        name = container.get("Name") or container.get("Id") or container.get("ID") or ""
    return str(name).lstrip("/")


def docker_summary_container_image(container: Any) -> str:
    if not isinstance(container, Mapping):
        return ""
    image = container.get("Image") or container.get("ImageID") or container.get("Id") or ""
    return str(image)


def docker_summary_version(full_image: Any, smart: Any = True) -> str:
    if full_image is None:
        return ""
    image_str = str(full_image)
    smart_enabled = bool(smart)
    if not smart_enabled:
        return image_str
    if ":" in image_str:
        version_tag = image_str.split(":")[-1]
    else:
        version_tag = "latest"
    if "/" in image_str:
        image_name_part = image_str.split("/")[-1].split(":")[0]
    else:
        image_name_part = image_str.split(":")[0]
    return f"{image_name_part}:{version_tag}"


def docker_summary_metadata(full_image: Any, inspect_data: Optional[Mapping[str, Any]] = None) -> Dict[str, Any]:
    inspect_data = _coerce_to_mapping(inspect_data, {})
    state = _coerce_to_mapping(inspect_data.get("State"), {})
    repo_digest = ""
    digests = inspect_data.get("RepoDigests")
    if isinstance(digests, list) and digests:
        repo_digest = str(digests[0])
    return {
        "image": str(full_image) if full_image is not None else "",
        "image_id": inspect_data.get("Image", ""),
        "repo_digest": repo_digest,
        "created": inspect_data.get("Created", ""),
        "state": {
            "status": state.get("Status", "unknown"),
            "running": bool(state.get("Running", False)),
            "started_at": state.get("StartedAt", ""),
            "finished_at": state.get("FinishedAt", ""),
            "exit_code": state.get("ExitCode"),
            "restart_count": inspect_data.get("RestartCount", state.get("RestartCount", 0)),
        },
    }


def docker_summary_change_meta(
    name: str,
    current_versions: Mapping[str, Any],
    before_versions: Mapping[str, Any],
    first_run: bool = False,
) -> Dict[str, str]:
    current_versions = _coerce_to_mapping(current_versions, {})
    before_versions = _coerce_to_mapping(before_versions, {})
    if first_run:
        change_type = "baseline"
    else:
        previous = before_versions.get(name)
        if previous is None:
            change_type = "added"
        elif current_versions.get(name) != previous:
            change_type = "updated"
        else:
            change_type = "unchanged"

    if change_type == "baseline":
        status = "BASELINE"
    elif change_type == "unchanged":
        status = "UNCHANGED"
    else:
        status = "CHANGED"

    return {"change_type": change_type, "status": status}


def docker_summary_status_label(entry: Mapping[str, Any]) -> str:
    entry = _coerce_to_mapping(entry, {})
    change_type = entry.get("change_type")
    status = entry.get("status", "")
    if change_type in {"added", "updated", "removed"}:
        return f"{status} ({str(change_type).upper()})"
    if change_type == "baseline":
        return f"{status} (INITIAL)"
    return str(status)


def docker_summary_history_metadata(change_type: str, metadata: Mapping[str, Any]) -> Dict[str, Any]:
    metadata = _coerce_to_mapping(metadata, {})
    if change_type == "removed":
        return _coerce_to_mapping(metadata.get("previous"), {})
    return _coerce_to_mapping(metadata.get("current"), {})


def _append_note(notes: List[str], value: Any) -> None:
    if value is None:
        return
    text = str(value).strip()
    if not text:
        return
    notes.append(text)


def docker_summary_notes(entry: Mapping[str, Any], include_state: bool = True) -> str:
    entry = _coerce_to_mapping(entry, {})
    notes: List[str] = []

    change_type = entry.get("change_type")
    if change_type == "added":
        _append_note(notes, "New container")
    elif change_type == "removed":
        _append_note(notes, "Removed from host")
    elif change_type == "updated":
        _append_note(notes, "Version updated")
    elif change_type == "baseline":
        _append_note(notes, "Baseline snapshot")

    if include_state:
        metadata = _coerce_to_mapping(entry.get("metadata"), {})
        target_meta = metadata.get("current") if change_type != "removed" else metadata.get("previous")
        state = _coerce_to_mapping(_coerce_to_mapping(target_meta, {}).get("state"), {})

        status_text = str(state.get("Status") or state.get("status") or "").strip()
        running = state.get("running")
        exit_code = state.get("exit_code")
        restart_count = state.get("restart_count")

        if status_text and status_text.lower() != "unknown":
            if not running and isinstance(exit_code, int) and exit_code not in (0, None):
                _append_note(notes, f"{status_text} (exit {exit_code})")
            else:
                _append_note(notes, status_text)
        elif running:
            _append_note(notes, "running")

    if isinstance(restart_count, int) and restart_count > 0:
        _append_note(notes, f"restarts: {restart_count}")

    return " | ".join(dict.fromkeys(notes))  # preserve order, deduplicate


def docker_summary_truncate(value: Any, width: int, ellipsis: str = "...") -> str:
    """Return a string truncated to `width` characters with optional ellipsis."""
    if width <= 0:
        return ""
    raw = "" if value is None else str(value)
    if len(raw) <= width:
        return raw
    ell_len = len(ellipsis)
    if width > ell_len and ell_len > 0:
        return raw[: width - ell_len] + ellipsis
    return raw[:width]


class FilterModule(object):
    def filters(self) -> Dict[str, Any]:
        return {
            "docker_scope_patterns": docker_scope_patterns,
            "docker_scope_all": docker_scope_all,
            "docker_scope_filter": docker_scope_filter,
            "docker_scope_filter_dict": docker_scope_filter_dict,
            "docker_summary_fact": docker_summary_fact,
            "docker_summary_ensure_history": docker_summary_ensure_history,
            "docker_summary_container_name": docker_summary_container_name,
            "docker_summary_container_image": docker_summary_container_image,
            "docker_summary_version": docker_summary_version,
            "docker_summary_metadata": docker_summary_metadata,
            "docker_summary_change_meta": docker_summary_change_meta,
            "docker_summary_status_label": docker_summary_status_label,
            "docker_summary_history_metadata": docker_summary_history_metadata,
            "docker_summary_notes": docker_summary_notes,
            "docker_summary_truncate": docker_summary_truncate,
        }
