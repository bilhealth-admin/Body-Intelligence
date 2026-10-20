#!/usr/bin/env python3
"""Validate reviewed CocoaPods integration semantics; never repair source."""
import argparse
import copy
import hashlib
import json
from pathlib import Path
import re
import subprocess
import tempfile
import xml.etree.ElementTree as ET

DERIVED_PATHS = (
    "ios/Flutter/Debug.xcconfig", "ios/Flutter/Release.xcconfig",
    "ios/Runner.xcodeproj/project.pbxproj",
    "ios/Runner.xcworkspace/contents.xcworkspacedata",
)
SCHEMA = "bil.qa.reviewed-cocoapods-derived.v1"
POD_VERSION = "1.16.2"


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def parse_openstep(data):
    """Strict small parser for this reviewed ASCII plist; duplicate keys fail."""
    source = data.decode("utf-8")
    tokens = []
    index = 0
    pattern = re.compile(r'\s+|/\*.*?\*/|//[^\n]*|"(?:\\.|[^"\\])*"|[{}()=;,]|[^\s{}()=;,"]+', re.S)
    while index < len(source):
        match = pattern.match(source, index)
        if not match:
            raise ValueError("Unsupported OpenStep token")
        token = match.group()
        index = match.end()
        if token.isspace() or token.startswith(("/*", "//")):
            continue
        tokens.append(token)
    position = 0

    def take(expected=None):
        nonlocal position
        if position >= len(tokens):
            raise ValueError("Truncated OpenStep plist")
        value = tokens[position]
        position += 1
        if expected is not None and value != expected:
            raise ValueError("Unexpected OpenStep delimiter")
        return value

    def value():
        token = take()
        if token == "{":
            result = {}
            while tokens[position] != "}":
                key = take()
                if key.startswith('"'):
                    key = json.loads(key)
                if key in result or key in "{}()=;,":
                    raise ValueError("Duplicate or invalid OpenStep key")
                take("=")
                result[key] = value()
                take(";")
            take("}")
            return result
        if token == "(":
            result = []
            while tokens[position] != ")":
                result.append(value())
                if tokens[position] != ")":
                    take(",")
            take(")")
            return result
        if token in "}=;,)":
            raise ValueError("Invalid OpenStep value")
        return json.loads(token) if token.startswith('"') else token

    result = value()
    if position != len(tokens) or not isinstance(result, dict):
        raise ValueError("Extra OpenStep input")
    return result


def parse_pbx(data, *, require_plutil=True):
    parsed = parse_openstep(data)
    if require_plutil:
        with tempfile.NamedTemporaryFile(suffix=".pbxproj") as handle:
            handle.write(data)
            handle.flush()
            output = subprocess.run(["/usr/bin/plutil", "-convert", "json", "-o", "-", "--", handle.name],
                                    capture_output=True, check=False)
        if output.returncode or json.loads(output.stdout) != parsed:
            raise ValueError("Apple plutil and strict plist parser disagree")
    return parsed


def new_roles(original, generated):
    before, after = original["objects"], generated["objects"]
    if not set(before) <= set(after):
        raise ValueError("A preexisting Xcode object was removed")
    new = set(after) - set(before)
    roles = {}
    for identifier in new:
        obj = after[identifier]
        isa = obj.get("isa")
        if isa == "PBXFileReference":
            role = "file:" + obj.get("path", "")
        elif isa == "PBXBuildFile":
            ref = obj.get("fileRef")
            if ref not in new:
                raise ValueError("New build file targets preexisting source")
            role = "build:" + after[ref].get("path", "")
        elif isa == "PBXGroup":
            role = "group:" + obj.get("name", "")
        elif isa == "PBXFrameworksBuildPhase":
            role = "phase:RunnerTestsFrameworks"
        elif isa == "PBXShellScriptBuildPhase":
            role = "script:" + obj.get("name", "") + ":" + json.dumps(obj.get("outputPaths", []))
        else:
            raise ValueError("Unreviewed generated Xcode object class")
        if role in roles.values() or not re.fullmatch(r"[0-9A-F]{24}", identifier):
            raise ValueError("Ambiguous or invalid generated Xcode object")
        roles[identifier] = role
    return roles


def normalize_generated(original, generated):
    roles = new_roles(original, generated)

    def normalize(value):
        if isinstance(value, dict):
            return {roles.get(key, key): normalize(item) for key, item in value.items()}
        if isinstance(value, list):
            return [normalize(item) for item in value]
        return roles.get(value, value)

    return normalize(generated)


def workspace_model(data):
    # No DTD/entities, processing instructions or non-file payloads accepted.
    declaration = b'<?xml version="1.0" encoding="UTF-8"?>'
    if not (data.startswith(declaration + b"\n") or data.startswith(declaration + b"\r\n")) or b"<!" in data or b"<?" in data[len(declaration):]:
        raise ValueError("Unreviewed workspace XML declaration")
    root = ET.fromstring(data)
    if root.tag != "Workspace" or root.attrib != {"version": "1.0"} or (root.text or "").strip():
        raise ValueError("Unreviewed workspace root")
    result = []
    for element in root:
        if element.tag != "FileRef" or set(element.attrib) != {"location"} or len(element) or (element.text or "").strip() or (element.tail or "").strip():
            raise ValueError("Unreviewed workspace child")
        result.append(element.attrib["location"])
    return result


def make_contract(originals, generated):
    before = parse_pbx(originals[DERIVED_PATHS[2]], require_plutil=False)
    after = parse_pbx(generated[DERIVED_PATHS[2]], require_plutil=False)
    return {"schema": SCHEMA, "cocoapods_version": POD_VERSION,
            "reviewed_original_sha256": {path: sha256(originals[path]) for path in DERIVED_PATHS},
            "reviewed_observed_generated_sha256": {path: sha256(generated[path]) for path in DERIVED_PATHS},
            "reviewed_original_pbx": before,
            "reviewed_generated_pbx_normalized": normalize_generated(before, after),
            "reviewed_generated_roles": sorted(new_roles(before, after).values()),
            "original_workspace": workspace_model(originals[DERIVED_PATHS[3]]),
            "generated_workspace": workspace_model(generated[DERIVED_PATHS[3]])}


def validate(originals, generated, contract, *, require_plutil=True):
    if contract.get("schema") != SCHEMA or set(originals) != set(DERIVED_PATHS) or set(generated) != set(DERIVED_PATHS):
        raise ValueError("Exact reviewed four derived inputs required")
    for path in DERIVED_PATHS:
        if sha256(originals[path]) != contract["reviewed_original_sha256"][path]:
            raise ValueError("Frozen original input differs from reviewed source: " + path)
    for config in ("Debug", "Release"):
        path = "ios/Flutter/" + config + ".xcconfig"
        addition = ('#include? "Pods/Target Support Files/Pods-Runner/Pods-Runner.' + config.lower() + '.xcconfig"\n').encode()
        if generated[path] != addition + originals[path]:
            raise ValueError("xcconfig permits only exact reviewed Pods include")
    before = parse_pbx(originals[DERIVED_PATHS[2]], require_plutil=require_plutil)
    after = parse_pbx(generated[DERIVED_PATHS[2]], require_plutil=require_plutil)
    if before != contract["reviewed_original_pbx"]:
        raise ValueError("Frozen Xcode project semantic mismatch")
    if normalize_generated(before, after) != contract["reviewed_generated_pbx_normalized"]:
        raise ValueError("Unreviewed Xcode object, setting, source, script or phase order")
    if workspace_model(originals[DERIVED_PATHS[3]]) != contract["original_workspace"]:
        raise ValueError("Frozen workspace differs")
    if contract["generated_workspace"] != contract["original_workspace"] + ["group:Pods/Pods.xcodeproj"]:
        raise ValueError("Reviewed workspace addition is not exclusively Pods")
    if workspace_model(generated[DERIVED_PATHS[3]]) != contract["generated_workspace"]:
        raise ValueError("Workspace permits only the reviewed Pods reference")
    return [{"path": path, "committed_sha256": sha256(originals[path]),
             "actual_generated_sha256": sha256(generated[path]),
             "semantic_validation": "PASS"} for path in DERIVED_PATHS]


def validate_toolchain(root, toolchain):
    if toolchain.get("cocoapods_version") != POD_VERSION or toolchain.get("flutter_version") != "3.44.6":
        raise ValueError("Pinned CocoaPods and Flutter versions required")
    for field in ("xcode_version", "ruby_version", "xcodeproj_version", "pod_executable_sha256"):
        if not isinstance(toolchain.get(field), str) or not toolchain[field].strip():
            raise ValueError("Actual build toolchain evidence missing: " + field)
    if not re.fullmatch(r"[0-9a-f]{64}", toolchain["pod_executable_sha256"]):
        raise ValueError("Pod executable hash required")
    lock = root / "ios/Podfile.lock"
    manifest = root / "ios/Pods/Manifest.lock"
    if any(path.is_symlink() or not path.is_file() for path in (lock, manifest)):
        raise ValueError("Regular actual Pod and sandbox lockfiles required")
    data = lock.read_bytes()
    if data != manifest.read_bytes() or not data.rstrip().endswith(("COCOAPODS: " + POD_VERSION).encode()):
        raise ValueError("Actual Pod/sandbox lock mismatch or unpinned generator")
    return {"podfile_lock_sha256": sha256(data), "manifest_lock_sha256": sha256(manifest.read_bytes())}


if __name__ == "__main__":
    raise SystemExit("Import from the reviewed source receipt collector; no repair operation exists")
