"""Whole tracked/untracked source inventory and conservative audit candidates.

Candidates are not automatically defects. Never logs matched secret values,
opens a device, decodes an image, or mutates product sources.
"""

from __future__ import annotations

import ast
from collections import Counter, defaultdict
import hashlib
import json
from pathlib import Path
import re
import subprocess
import xml.etree.ElementTree as ET

from run_gate import EVIDENCE, ROOT


TEXT = {".dart", ".ts", ".tsx", ".js", ".mjs", ".cjs", ".kt", ".java",
        ".swift", ".m", ".h", ".mm", ".cpp", ".c", ".sql", ".py", ".ps1",
        ".xml", ".plist", ".entitlements", ".storyboard", ".pbxproj", ".xcconfig",
        ".kts", ".gradle", ".properties", ".yaml", ".yml", ".json", ".jsonc",
        ".md", ".toml", ".arb", ".txt", ".lock", ".cmake", ".html", ".css",
        ".xcprivacy", ".xcworkspacedata", ".xcscheme", ".podspec", ".xcsettings",
        ".strings", ".xib", ".sh", ".pro", ".webmanifest", ".manifest",
        ".cc", ".rc", ".bat", ".deps", ".csv", ".example"}
CODE = {".dart", ".ts", ".js", ".mjs", ".kt", ".java", ".swift", ".sql", ".py", ".ps1"}
SECRETS = {
    "private_key": re.compile(r"-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----"),
    "github_token": re.compile(r"\b(?:gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{60,})\b"),
    "aws_access_key": re.compile(r"\b(?:AKIA|ASIA)[A-Z0-9]{16}\b"),
    "supabase_secret_key": re.compile(r"\bsb_secret_[A-Za-z0-9_-]{20,}\b"),
    "google_api_key": re.compile(r"\bAIza[0-9A-Za-z_-]{35}\b"),
    "credential_url": re.compile(r"(?:postgres(?:ql)?|https?)://[^\s/:]{2,}:[^\s/@]{6,}@"),
}


def git(*args: str) -> str:
    return subprocess.check_output(["git", *args], cwd=ROOT).decode("utf-8")


def cycles(graph: dict[str, set[str]]) -> list[list[str]]:
    index = 0
    indices: dict[str, int] = {}
    low: dict[str, int] = {}
    stack: list[str] = []
    active: set[str] = set()
    components: list[list[str]] = []

    def visit(node: str) -> None:
        nonlocal index
        indices[node] = low[node] = index
        index += 1
        stack.append(node)
        active.add(node)
        for other in sorted(graph.get(node, set())):
            if other not in indices:
                visit(other)
                low[node] = min(low[node], low[other])
            elif other in active:
                low[node] = min(low[node], indices[other])
        if low[node] == indices[node]:
            component = []
            while True:
                item = stack.pop()
                active.remove(item)
                component.append(item)
                if item == node:
                    break
            if len(component) > 1:
                components.append(sorted(component))

    for node in sorted(graph):
        if node not in indices:
            visit(node)
    return sorted(components, key=lambda c: (-len(c), c))


def main() -> int:
    paths = sorted(set(git("ls-files", "-z", "--cached", "--others", "--exclude-standard").split("\0")) - {""})
    counts: Counter[str] = Counter()
    inventory = []
    hashes: dict[str, list[str]] = defaultdict(list)
    todos = []
    secrets = []
    conflicts = []
    syntax_errors = []
    graph: dict[str, set[str]] = {}
    classes: dict[str, list[str]] = defaultdict(list)
    for relative in paths:
        path = ROOT / relative
        if not path.is_file():
            inventory.append({"path": relative, "state": "missing"})
            continue
        extension = path.suffix.lower()
        counts[extension or "[no extension]"] += 1
        item = {"path": relative, "bytes": path.stat().st_size}
        if extension not in TEXT and path.name not in {".gitignore", "Podfile", "Gemfile", "Dockerfile"}:
            item["inspection"] = "metadata only; binary content not inspected"
            inventory.append(item)
            continue
        content = path.read_bytes()
        try:
            source = content.decode("utf-8-sig")
        except UnicodeDecodeError:
            item["inspection"] = "non-UTF8; requires separate review"
            inventory.append(item)
            continue
        item["lines"] = source.count("\n") + 1
        item["sha256"] = hashlib.sha256(content).hexdigest()
        inventory.append(item)
        if extension in CODE and len(content) > 100:
            hashes[item["sha256"]].append(relative)
        for kind, pattern in SECRETS.items():
            for match in pattern.finditer(source):
                secrets.append({"path": relative, "line": source.count("\n", 0, match.start()) + 1,
                                "kind": kind, "value": "REDACTED"})
        for match in re.finditer(r"(?m)^(?:<{7}|>{7}|\|{7})(?: |$)", source):
            conflicts.append({"path": relative, "line": source.count("\n", 0, match.start()) + 1})
        if extension in CODE and not relative.endswith(".g.dart"):
            for match in re.finditer(r"\b(?:TODO|FIXME|HACK|TEMP|XXX)\b", source):
                todos.append({"path": relative, "line": source.count("\n", 0, match.start()) + 1,
                              "marker": match.group()})
        if extension == ".py":
            try:
                ast.parse(source, filename=relative)
            except SyntaxError as error:
                syntax_errors.append({"path": relative, "line": error.lineno, "error": error.msg})
        if extension in {".xml", ".plist", ".entitlements", ".storyboard",
                         ".xcprivacy", ".xcworkspacedata", ".xcscheme",
                         ".xcsettings", ".xib"}:
            try:
                ET.fromstring(source)
            except ET.ParseError as error:
                syntax_errors.append({"path": relative, "error": str(error)})
        if relative.startswith("lib/") and extension == ".dart" and not relative.endswith(".g.dart"):
            edges: set[str] = set()
            for match in re.finditer(r"(?:import|export)\s+['\"]([^'\"]+)['\"]", source):
                target = match[1]
                if target.startswith("package:body_intelligence_log/"):
                    edges.add("lib/" + target.removeprefix("package:body_intelligence_log/"))
                elif ":" not in target:
                    resolved = (path.parent / target).resolve()
                    if resolved.is_relative_to(ROOT):
                        edges.add(resolved.relative_to(ROOT).as_posix())
            graph[relative] = edges
            for match in re.finditer(r"(?m)^(?:(?:abstract|final|sealed|base|interface)\s+)*class\s+([A-Za-z_]\w*)", source):
                if not match[1].startswith("_"):
                    classes[match[1]].append(relative)
    report = {
        "head": git("rev-parse", "HEAD").strip(), "branch": git("branch", "--show-current").strip(),
        "status": git("status", "--porcelain=v1", "--untracked-files=all").splitlines(),
        "files": inventory, "extension_counts": dict(counts),
        "exact_code_duplicates": [v for v in hashes.values() if len(v) > 1],
        "duplicate_public_class_names": {k: v for k, v in classes.items() if len(v) > 1},
        "dart_import_cycles": cycles(graph), "todo_candidates": todos,
        "secret_candidates": secrets, "conflict_candidates": conflicts,
        "syntax_errors": syntax_errors,
    }
    EVIDENCE.mkdir(parents=True, exist_ok=True)
    output = EVIDENCE / "repository_inventory.json"
    output.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"report": str(output), "files": len(paths), "extensions": dict(counts),
                      "exact_code_duplicate_groups": len(report["exact_code_duplicates"]),
                      "duplicate_class_names": len(report["duplicate_public_class_names"]),
                      "import_cycle_groups": len(report["dart_import_cycles"]),
                      "todo_candidates": len(todos), "redacted_secret_candidates": len(secrets),
                      "conflict_candidates": len(conflicts), "syntax_errors": syntax_errors}))
    return int(bool(syntax_errors or conflicts))


if __name__ == "__main__":
    raise SystemExit(main())
