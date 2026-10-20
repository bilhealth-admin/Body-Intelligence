#!/usr/bin/env python3
"""Select exact CocoaPods in a fresh job-local gem home; never change global gems."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

EXPECTED_VERSION = "1.16.2"
POD_SHIM = """#!/usr/bin/env ruby
require 'rubygems'
gem 'cocoapods', '=1.16.2'
load Gem.bin_path('cocoapods', 'pod', '=1.16.2')
"""
PROBE = """require 'json'; require 'rubygems'
gem 'cocoapods', '=1.16.2'
require 'cocoapods'; require 'xcodeproj'
puts JSON.generate({cocoapods_version: Pod::VERSION,
  xcodeproj_version: Xcodeproj::VERSION,
  cocoapods_gem_path: Gem.loaded_specs.fetch('cocoapods').full_gem_path,
  xcodeproj_gem_path: Gem.loaded_specs.fetch('xcodeproj').full_gem_path,
  resolved_gems: Gem.loaded_specs.values.map { |s| {name: s.name, version: s.version.to_s} }.sort_by { |s| s[:name] }})
"""


def isolated_environment(original, root):
    env = dict(original)
    gem_home = str(root / "gems")
    env.update(GEM_HOME=gem_home, GEM_PATH=gem_home,
               PATH=str(root / "bin") + os.pathsep + original.get("PATH", ""))
    return env


def validate_probe(probe, root):
    if probe.get("cocoapods_version") != EXPECTED_VERSION:
        raise ValueError("Exact CocoaPods1.16.2 was not selected")
    if not isinstance(probe.get("xcodeproj_version"), str) or not probe["xcodeproj_version"]:
        raise ValueError("Resolved xcodeproj version was not recorded")
    gem_home = (root / "gems").resolve()
    for key in ("cocoapods_gem_path", "xcodeproj_gem_path"):
        value = probe.get(key)
        if not isinstance(value, str) or not Path(value).resolve().is_relative_to(gem_home):
            raise ValueError("Selected dependency escaped the isolated gem home")
    rows = probe.get("resolved_gems")
    if not isinstance(rows, list) or not rows or not all(
        isinstance(row, dict) and set(row) == {"name", "version"}
        and isinstance(row["name"], str) and isinstance(row["version"], str)
        for row in rows
    ):
        raise ValueError("Resolved public dependency inventory is invalid")


def _write_receipt(output, receipt):
    target = Path(output)
    target.parent.mkdir(parents=True, exist_ok=True)
    descriptor, name = tempfile.mkstemp(prefix=".bil-cocoapods-receipt-", suffix=".tmp", dir=target.parent)
    temporary = Path(name)
    try:
        with os.fdopen(descriptor, "wb") as file:
            file.write((json.dumps(receipt, sort_keys=True, indent=2) + "\n").encode("utf-8"))
        os.replace(temporary, target)
    finally:
        try:
            temporary.unlink(missing_ok=True)
        except OSError:
            pass


def _failure_exit_code(error):
    if isinstance(error, subprocess.TimeoutExpired):
        return 124
    if isinstance(error, subprocess.CalledProcessError):
        code = error.returncode
        if isinstance(code, int) and code != 0:
            code = code if code > 0 else 128 - code
            if code <= 255:
                return code
    return 1


def _failure_receipt(stage, error):
    # Never copy an exception message, environment, command, stdout or stderr.
    receipt = {"schema": "bil.qa.isolated-cocoapods-installation.v1",
               "status": "FAIL", "stage": stage,
               "exit_code": _failure_exit_code(error),
               "error_type": type(error).__name__}
    if isinstance(error, subprocess.CalledProcessError):
        receipt["subprocess_exit_code"] = error.returncode
    if isinstance(error, subprocess.TimeoutExpired):
        receipt["timed_out"] = True
    return receipt


def install(output, *, run=subprocess.run, environ=None):
    stage = "preflight"
    try:
        _write_receipt(output, {"schema": "bil.qa.isolated-cocoapods-installation.v1",
                                "status": "IN_PROGRESS", "stage": stage, "exit_code": None})
        original = dict(os.environ if environ is None else environ)
        for key in ("RUNNER_TEMP", "GITHUB_ENV", "GITHUB_PATH"):
            if not original.get(key) or "\n" in original[key] or "\r" in original[key]:
                raise ValueError("Actual safe GitHub job paths are required: " + key)
        runner_temp = Path(original["RUNNER_TEMP"]).resolve()
        if not runner_temp.is_dir():
            raise ValueError("Actual runner temporary directory missing")
        # Existing Bundler activation can pre-load another CocoaPods dependency graph.
        if original.get("BUNDLE_GEMFILE") or original.get("BUNDLE_BIN_PATH"):
            raise ValueError("Unexpected active Bundler environment")
        ruby = shutil.which("ruby", path=original.get("PATH"))
        gem = shutil.which("gem", path=original.get("PATH"))
        if not ruby or not gem:
            raise ValueError("Existing runner Ruby and RubyGems are required")
        root = Path(tempfile.mkdtemp(prefix="bil-cocoapods-1.16.2-", dir=runner_temp))
        (root / "gems").mkdir()
        (root / "bin").mkdir()
        env = isolated_environment(original, root)
        stage = "gem_install"
        run([gem, "install", "cocoapods", "--norc", "--version", EXPECTED_VERSION,
             "--no-document", "--clear-sources", "--source", "https://rubygems.org",
             "--install-dir", env["GEM_HOME"], "--bindir", str(root / "bin")],
            env=env, check=True, timeout=600)
        stage = "pod_shim"
        pod = root / "bin" / "pod"
        # Exact activation prevents a newer preinstalled version taking over.
        pod.write_text(POD_SHIM)
        pod.chmod(0o755)
        stage = "dependency_probe"
        completed = run([ruby, "-e", PROBE], env=env, capture_output=True, text=True,
                        check=True, timeout=90)
        if len(completed.stdout) > 64 * 1024:
            raise ValueError("Unexpected dependency version output")
        probe = json.loads(completed.stdout)
        stage = "dependency_validation"
        validate_probe(probe, root)
        stage = "pod_version"
        version = run([str(pod), "--version"], env=env, capture_output=True, text=True,
                      check=True, timeout=90).stdout.strip()
        stage = "pod_version_validation"
        if version != EXPECTED_VERSION:
            raise ValueError("Isolated pod executable did not select exact CocoaPods1.16.2")
        # Publish only after all real probes pass. A failed export is not PASS.
        stage = "environment_export"
        with Path(original["GITHUB_ENV"]).open("a") as file:
            file.write("GEM_HOME=" + env["GEM_HOME"] + "\nGEM_PATH=" + env["GEM_PATH"] + "\n")
        with Path(original["GITHUB_PATH"]).open("a") as file:
            file.write(str(root / "bin") + "\n")
        receipt = {"schema": "bil.qa.isolated-cocoapods-installation.v1",
                   "status": "PASS", "stage": "completed", "exit_code": 0,
                   "cocoapods_version": version,
                   "xcodeproj_version": probe["xcodeproj_version"],
                   "resolved_gems": probe["resolved_gems"],
                   "global_gem_directories_modified": False,
                   "cocoapods_and_xcodeproj_inside_fresh_job_gem_home": True,
                   "pod_shim_sha256": hashlib.sha256(pod.read_bytes()).hexdigest()}
        stage = "receipt_publication"
        _write_receipt(output, receipt)
        print(json.dumps({"cocoapods_version": version,
                          "xcodeproj_version": receipt["xcodeproj_version"],
                          "isolated_installation_verified": True}))
        return receipt
    except Exception as error:
        try:
            _write_receipt(output, _failure_receipt(stage, error))
        except Exception:
            print('{"status":"FAIL","receipt_write_failed":true}', file=sys.stderr)
        raise


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", required=True)
    try:
        install(parser.parse_args().output)
    except Exception as error:
        print(json.dumps({"status": "FAIL", "exit_code": _failure_exit_code(error)}), file=sys.stderr)
        raise SystemExit(_failure_exit_code(error)) from None
