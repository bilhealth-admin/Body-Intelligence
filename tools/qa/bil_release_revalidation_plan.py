#!/usr/bin/env python3
"""Pure release-plan inventory and evidence validation; never runs commands.

Inventories contain complete Dart entrypoint filenames, never test-name filters.
The caller owns execution, source binding, GitHub I/O and physical verification.
PENDING physical gates permit a test plan, but never readiness certification.
"""
from __future__ import annotations

import ast
from collections import deque
from collections.abc import Iterable, Mapping, Sequence
from datetime import datetime, timezone
import json
import math
from pathlib import Path, PurePosixPath
import re
import shlex
from urllib.parse import unquote


class PlanValidationError(ValueError):
    """A plan or CI receipt is incomplete, ambiguous or outside its scope."""


LADDER_CONSTANTS = ("P0", "FOCUSED", "BROAD")
EXTRA_FOCUSED_TESTS = (
    "test/features/cloud_platform/cloud_sync_consent_copy_test.dart",
    "test/features/cloud_platform/cloud_sync_consent_owner_dialog_test.dart",
    "test/features/cloud_platform/cloud_sync_consent_state_test.dart",
    "test/features/cloud_platform/cloud_restore_consent_repository_test.dart",
    "test/features/cloud_platform/cloud_restore_consent_transport_test.dart",
    "test/features/cloud_platform/cloud_restore_v2_engine_test.dart",
    "test/features/cloud_platform/cloud_manual_sync_scope_refresh_test.dart",
    "test/features/cloud_platform/cloud_manual_sync_status_provider_test.dart",
    "test/features/cloud_platform/cloud_auto_sync_behavior_test.dart",
    "test/features/settings/settings_language_and_sync_status_test.dart",
    "test/features/commerce/app_purchase_confirmation_test.dart",
    "test/features/commerce/app_subscription_confirmation_test.dart",
    "test/features/commerce/store_transaction_queue_test.dart",
    "test/features/intelligence_center/ai_coach_failure_surface_regression_test.dart",
    "test/features/intelligence_center/coach_25_locale_matrix_test.dart",
    "test/features/intelligence_center/coach_cloud_request_reconciliation_test.dart",
    "test/features/intelligence_center/coach_conversation_and_routing_test.dart",
    "test/features/intelligence_center/coach_gateway_owner_transport_test.dart",
    "test/features/intelligence_center/coach_page_lifecycle_regression_test.dart",
    "test/features/nutrition/meal_vision_consent_layout_test.dart",
    "test/features/nutrition/meal_vision_consent_owner_test.dart",
    "test/features/onboarding/onboarding_review_mode_test.dart",
    "test/features/onboarding/premium_consent_surface_contract_test.dart",
    "test/shared/widgets/bil_premium_ai_consent_sheet_test.dart",
)

_GOLDEN = re.compile(r"golden|matchesReferenceImage", re.IGNORECASE)
_DIRECTIVE = re.compile(r"\b(?:import|export|part(?!\s+of\b))\s+([^;]+);", re.DOTALL)
_QUOTED = re.compile(r"(?:r)?(['\"])(.*?)\1", re.DOTALL)
_PART_URI = re.compile(r"\bpart\s+of\s+(?:r)?(['\"])(.*?)\1\s*;")
_LIBRARY = re.compile(r"\blibrary\s+([\w.]+)\s*;")
_PART_NAME = re.compile(r"\bpart\s+of\s+([\w.]+)\s*;")
_WORKFLOW = re.compile(r"(?:\.github/workflows/)?([A-Za-z0-9_.-]+\.ya?ml)\Z")


def _source(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8-sig")
    except (OSError, UnicodeError) as exc:
        raise PlanValidationError(f"Cannot inspect source: {path}") from exc


def golden_inventory(root: str | Path) -> list[str]:
    """Return all golden-related test entrypoints, including imported helpers.

Local import/export/part and URI/named part-of links are followed transitively
inside test/. Conditional-import alternatives are all inspected. Comments and
source-contract strings may overinclude tests; no test-name selector is used.
"""
    root = Path(root).resolve()
    test_root = root / "test"
    if not test_root.is_dir():
        raise PlanValidationError("Missing test/ directory")
    files: dict[Path, str] = {}
    for path in test_root.rglob("*.dart"):
        resolved = path.resolve()
        if not resolved.is_relative_to(test_root):
            raise PlanValidationError(f"Test source escapes test/: {path}")
        if path.is_file():
            files[resolved] = path.relative_to(root).as_posix()
    contents = {path: _source(path) for path in files}
    importers: dict[Path, set[Path]] = {path: set() for path in files}
    libraries: dict[str, set[Path]] = {}
    for path, content in contents.items():
        for match in _LIBRARY.finditer(content):
            libraries.setdefault(match.group(1), set()).add(path)

    def local(path: Path, uri: str) -> Path | None:
        if ":" in uri or uri.startswith("/"):
            return None
        candidate = (path.parent / unquote(uri)).resolve()
        return candidate if candidate in files else None

    for path, content in contents.items():
        for directive in _DIRECTIVE.finditer(content):
            for quoted in _QUOTED.finditer(directive.group(1)):
                target = local(path, quoted.group(2))
                if target is not None:
                    importers[target].add(path)
        for match in _PART_URI.finditer(content):
            parent = local(path, match.group(2))
            if parent is not None:
                importers[path].add(parent)
        for match in _PART_NAME.finditer(content):
            importers[path].update(libraries.get(match.group(1), ()))
    found = {
        path for path, content in contents.items()
        if _GOLDEN.search(files[path]) or _GOLDEN.search(content)
    }
    pending = deque(found)
    while pending:
        for parent in importers[pending.popleft()]:
            if parent not in found:
                found.add(parent)
                pending.append(parent)
    return sorted(files[path] for path in found if files[path].endswith("_test.dart"))


def _test_file(root: Path, value: str) -> str:
    path = PurePosixPath(value)
    if (not value.startswith("test/") or not value.endswith("_test.dart")
            or path.is_absolute() or ".." in path.parts or "\\" in value
            or path.as_posix() != value):
        raise PlanValidationError(f"Not a complete test entrypoint: {value!r}")
    resolved = (root / value).resolve()
    if not resolved.is_relative_to(root / "test") or not resolved.is_file():
        raise PlanValidationError(f"Missing or unsafe focused test: {value}")
    return value


def focused_inventory(root: str | Path) -> list[str]:
    """Union literal P0/FOCUSED/BROAD lists and current regression entrypoints.

The old ladder is parsed with ast.literal_eval; importing it or invoking its
branch-specific main is deliberately unnecessary.
"""
    root = Path(root).resolve()
    ladder = root / "tools/qa/bil_codex_test_ladder.py"
    try:
        tree = ast.parse(_source(ladder), filename=str(ladder))
    except SyntaxError as exc:
        raise PlanValidationError("Cannot parse QA ladder constants") from exc
    constants: dict[str, object] = {}
    for node in tree.body:
        if not isinstance(node, (ast.Assign, ast.AnnAssign)):
            continue
        targets = node.targets if isinstance(node, ast.Assign) else [node.target]
        for target in targets:
            if not isinstance(target, ast.Name) or target.id not in LADDER_CONSTANTS:
                continue
            if target.id in constants:
                raise PlanValidationError(f"Repeated ladder constant: {target.id}")
            try:
                constants[target.id] = ast.literal_eval(node.value)
            except (ValueError, TypeError) as exc:
                raise PlanValidationError(f"Nonliteral ladder constant: {target.id}") from exc
    if set(constants) != set(LADDER_CONSTANTS):
        raise PlanValidationError("Missing P0/FOCUSED/BROAD ladder constants")
    result = {_test_file(root, path) for path in EXTRA_FOCUSED_TESTS}
    for name in LADDER_CONSTANTS:
        rows = constants[name]
        if not isinstance(rows, (list, tuple)) or not rows:
            raise PlanValidationError(f"Empty or invalid ladder constant: {name}")
        for row in rows:
            if (not isinstance(row, (list, tuple)) or len(row) != 2
                    or not all(isinstance(item, str) and item.strip() for item in row)):
                raise PlanValidationError(f"Invalid ladder row: {name}")
            try:
                tokens = shlex.split(row[1])
            except ValueError as exc:
                raise PlanValidationError(f"Invalid ladder test filenames: {name}") from exc
            if not tokens:
                raise PlanValidationError(f"Empty ladder test filenames: {name}")
            result.update(_test_file(root, token) for token in tokens)
    return sorted(result)


def _id(value: object, label: str, *, floor: bool = False) -> int:
    if isinstance(value, bool) or not (
        isinstance(value, int) or isinstance(value, str) and re.fullmatch(r"-?\d+", value)
    ):
        raise PlanValidationError(f"Invalid {label}")
    result = int(value)
    if result < (-1 if floor else 1):
        raise PlanValidationError(f"Invalid {label}")
    return result


def e2e_inventory(root, manifest):
    """Every current E2E entrypoint must have an explicit executable authority.

    Old isolated BIL07 fixture migrations were removed from this source. Its
    retained Python diagnostic is mapped explicitly to the current real-stack
    RPC/RLS suites, never described as having executed itself.
    """
    root = Path(root)
    discovered = set()
    patterns = {
        'integration_test': ('*_test.dart',),
        'supabase/tests': ('*e2e*.mjs', '*e2e*.py'),
        'tool': ('run*e2e.ps1', '*rollback_e2e.sql'),
    }
    for folder, globs in patterns.items():
        for pattern in globs:
            discovered.update(path.relative_to(root).as_posix() for path in (root / folder).rglob(pattern))
    entries = manifest.get('e2e_coverage', {})
    if not isinstance(entries, dict) or set(entries) != discovered:
        raise PlanValidationError('E2E coverage inventory changed or has an unassigned entrypoint: '
                                  + repr(sorted(discovered.symmetric_difference(entries))))
    lanes = {entry['lane_id'] for entry in manifest['workflows']}
    result = {}
    for name, entry in entries.items():
        if (not isinstance(entry, dict) or not entry.get('reason')
                or not isinstance(entry.get('lanes'), list) or not entry['lanes']
                or not set(entry['lanes']) <= lanes
                or entry.get('mode') not in ('direct', 'equivalent_wrapper', 'retired_fixture_replaced')):
            raise PlanValidationError('Invalid E2E coverage authority: ' + name)
        result[name] = dict(entry, sha256=__import__('hashlib').sha256((root / name).read_bytes()).hexdigest())
    return result


def _names(value: object, label: str) -> list[str]:
    if not isinstance(value, Sequence) or isinstance(value, (str, bytes)) or not value:
        raise PlanValidationError(f"Empty or invalid {label}")
    result = list(value)
    if any(not isinstance(name, str) or not name or name.strip() != name
           or any(char in name for char in "*?\n\r") for name in result):
        raise PlanValidationError(f"{label} requires exact nonempty names")
    if len(result) != len(set(result)):
        raise PlanValidationError(f"Duplicate {label}")
    return result


def _evidence(value: object) -> bool:
    return (isinstance(value, str) and bool(value.strip())) or (
        isinstance(value, Sequence) and not isinstance(value, (str, bytes))
        and bool(value) and all(isinstance(item, str) and item.strip() for item in value)
    )


def validate_ci_manifest(
    manifest: Mapping[str, object], *, required_workflow_ids: Iterable[int | str],
    require_physical_pass: bool = False,
) -> list[dict[str, object]]:
    """Validate a complete CI plan and return copied workflow records.

    Required workflow fields: workflow_id, workflow (filename), required_jobs,
    inputs, reason. Reused workflows require distinct explicit lane_id values
    and unique input profiles. manual_physical is a nonempty name/status list.
PASS always needs evidence. Other physical statuses permit planning only;
require_physical_pass=True is mandatory before a caller declares readiness.
Evidence contents/authenticity and artifact identity remain the caller's gate.
"""
    if not isinstance(manifest, Mapping):
        raise PlanValidationError("CI manifest must be an object")
    if (not isinstance(required_workflow_ids, Iterable)
            or isinstance(required_workflow_ids, (str, bytes, Mapping))):
        raise PlanValidationError("Required workflow inventory must be an explicit iterable")
    required_ids = [_id(value, "required workflow ID") for value in required_workflow_ids]
    if not required_ids or len(required_ids) != len(set(required_ids)):
        raise PlanValidationError("Required workflow inventory is empty or duplicated")
    workflows = manifest.get("workflows")
    if not isinstance(workflows, list) or not workflows:
        raise PlanValidationError("Missing or empty workflows")
    found_ids, result = set(), []
    workflow_files, file_ids, profiles, lane_ids = {}, {}, set(), set()
    id_lanes: dict[int, list[object]] = {}
    for entry in workflows:
        if not isinstance(entry, Mapping):
            raise PlanValidationError("Workflow entry must be an object")
        workflow_id = _id(entry.get("workflow_id"), "workflow ID")
        filename = entry.get("workflow")
        match = _WORKFLOW.fullmatch(filename) if isinstance(filename, str) else None
        if match is None:
            raise PlanValidationError("Workflow filename must identify one YAML workflow")
        file_key = match.group(1).casefold()
        if (workflow_id in workflow_files and workflow_files[workflow_id] != file_key
                or file_key in file_ids and file_ids[file_key] != workflow_id):
            raise PlanValidationError("Workflow ID and filename mappings are inconsistent")
        found_ids.add(workflow_id)
        workflow_files[workflow_id] = file_key
        file_ids[file_key] = workflow_id
        jobs = _names(entry.get("required_jobs"), "required jobs")
        inputs, reason = entry.get("inputs"), entry.get("reason")
        if (not isinstance(inputs, Mapping)
                or any(not isinstance(key, str) or not key for key in inputs)
                or any(not isinstance(value, (str, bool, int, float))
                       or isinstance(value, float) and not math.isfinite(value)
                       for value in inputs.values())):
            raise PlanValidationError("Workflow inputs must be explicit scalar inputs")
        if not isinstance(reason, str) or not reason.strip():
            raise PlanValidationError("Missing workflow scope reason")
        lane_id = entry.get("lane_id")
        if lane_id is not None:
            if (not isinstance(lane_id, str) or not lane_id or lane_id.strip() != lane_id
                    or "\n" in lane_id or "\r" in lane_id or lane_id in lane_ids):
                raise PlanValidationError("Invalid or duplicate lane_id")
            lane_ids.add(lane_id)
        id_lanes.setdefault(workflow_id, []).append(lane_id)
        profile = (workflow_id, file_key, json.dumps(dict(inputs), sort_keys=True))
        if profile in profiles:
            raise PlanValidationError("Duplicate workflow input profile")
        profiles.add(profile)
        result.append(dict(entry, workflow_id=workflow_id, required_jobs=jobs, inputs=dict(inputs)))
    if any(len(lanes) > 1 and any(lane is None for lane in lanes)
           for lanes in id_lanes.values()):
        raise PlanValidationError("Reused workflow profiles require explicit unique lane_id")
    if set(required_ids) - found_ids:
        raise PlanValidationError("Required workflows are missing")
    # A dependent scanner must consume the producer from this exact sequence.
    by_lane = {entry.get('lane_id'): entry for entry in result}
    for entry in result:
        dependencies = entry.get('depends_on', [])
        bindings = entry.get('input_from_run', {})
        if (not isinstance(dependencies, list) or len(set(dependencies)) != len(dependencies)
                or any(value not in by_lane or value == entry.get('lane_id') for value in dependencies)
                or not isinstance(bindings, dict)
                or any(key not in entry['inputs'] or value not in dependencies
                       for key, value in bindings.items())):
            raise PlanValidationError('Invalid CI dependency or producer input binding')
    pending = {entry.get('lane_id'): set(entry.get('depends_on', [])) for entry in result}
    while pending:
        ready = {name for name, deps in pending.items() if not deps}
        if not ready:
            raise PlanValidationError('CI dependency cycle')
        pending = {name: deps - ready for name, deps in pending.items() if name not in ready}
    physical = manifest.get("manual_physical")
    if not isinstance(physical, list) or not physical:
        raise PlanValidationError("Missing manual physical gates")
    physical_names = set()
    for check in physical:
        if not isinstance(check, Mapping):
            raise PlanValidationError("Physical gate must be an object")
        name, status = check.get("name"), check.get("status")
        if (not isinstance(name, str) or not name.strip() or name != name.strip()
                or name in physical_names or not isinstance(status, str)
                or status not in {"PASS", "PENDING", "FAIL", "BLOCKED", "NOT_RUN"}):
            raise PlanValidationError("Invalid or duplicate physical gate")
        physical_names.add(name)
        if status == "PASS" and not _evidence(check.get("evidence")):
            raise PlanValidationError("Physical PASS has no evidence")
        if require_physical_pass and status != "PASS":
            raise PlanValidationError("Physical gates do not prove readiness")
    return result


def _utc(value: object, label: str) -> datetime:
    try:
        parsed = datetime.fromisoformat(value.replace("Z", "+00:00")) if isinstance(value, str) else value
    except ValueError as exc:
        raise PlanValidationError(f"Invalid {label}") from exc
    if not isinstance(parsed, datetime) or parsed.tzinfo is None or parsed.utcoffset() is None:
        raise PlanValidationError(f"{label} must be timezone-aware")
    return parsed.astimezone(timezone.utc)


def validate_ci_run(
    run: Mapping[str, object], *, expected_head: str,
    expected_workflow_id: int | str, after_run_id: int,
    created_after: str | datetime, required_job_names: Sequence[str],
) -> dict[str, object]:
    """Require a new successful run and all explicit required jobs on exact SHA.

Accept jobs as a list or an unpaginated {jobs,total_count} API response. Every
job matching a required exact name must succeed, including repeated names.
Optional jobs may skip; their observed scope is returned rather than promoted
to required coverage. GitHub's second-resolution created_at is compared to a
UTC second-floor boundary as well as the caller's previous maximum run ID.
"""
    if not isinstance(run, Mapping):
        raise PlanValidationError("CI run must be an object")
    if not isinstance(expected_head, str) or not re.fullmatch(r"[0-9a-f]{40}", expected_head):
        raise PlanValidationError("Expected head must be an exact full SHA")
    if run.get("head_sha") != expected_head:
        raise PlanValidationError("CI run source SHA is stale or different")
    workflow_id = _id(expected_workflow_id, "expected workflow ID")
    if _id(run.get("workflow_id"), "run workflow ID") != workflow_id:
        raise PlanValidationError("CI run belongs to another workflow")
    run_id = _id(run.get("id"), "run ID")
    if run_id <= _id(after_run_id, "previous run ID", floor=True):
        raise PlanValidationError("CI run is not newer than the dispatch boundary")
    boundary = _utc(created_after, "dispatch boundary").replace(microsecond=0)
    if _utc(run.get("created_at"), "run creation time") < boundary:
        raise PlanValidationError("CI run predates the dispatch boundary")
    if run.get("status") != "completed" or run.get("conclusion") != "success":
        raise PlanValidationError("CI run has not completed successfully")
    required = _names(required_job_names, "required job names")
    jobs = run.get("jobs")
    if isinstance(jobs, Mapping):
        count, values = jobs.get("total_count"), jobs.get("jobs")
        if (not isinstance(count, int) or isinstance(count, bool)
                or not isinstance(values, list) or count != len(values)):
            raise PlanValidationError("CI job inventory is incomplete or paginated")
        jobs = values
    if not isinstance(jobs, list) or not jobs:
        raise PlanValidationError("Missing CI jobs")
    observed: dict[str, list[dict[str, object]]] = {}
    for job in jobs:
        if not isinstance(job, Mapping) or not isinstance(job.get("name"), str) or not job["name"]:
            raise PlanValidationError("Malformed CI job")
        observed.setdefault(job["name"], []).append(dict(job))
    for name in required:
        matches = observed.get(name)
        if not matches:
            raise PlanValidationError(f"Required CI job missing: {name}")
        if any(job.get("status") != "completed" or job.get("conclusion") != "success"
               for job in matches):
            raise PlanValidationError(f"Required CI job failed, skipped or incomplete: {name}")
    return {
        "run_id": run_id, "head_sha": expected_head, "workflow_id": workflow_id,
        "required_jobs": {name: len(observed[name]) for name in required},
        "optional_jobs": [
            {"name": name, "status": job.get("status"), "conclusion": job.get("conclusion")}
            for name in sorted(observed) if name not in required for job in observed[name]
        ],
    }
