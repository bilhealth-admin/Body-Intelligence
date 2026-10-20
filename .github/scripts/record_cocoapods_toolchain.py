#!/usr/bin/env python3
"""Record bounded public tool versions, never environment or credentials."""
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys


def capture(argv):
    result = subprocess.run(argv, capture_output=True, check=True, timeout=90)
    if len(result.stdout) > 64 * 1024:
        raise ValueError("Unexpected tool version output")
    return result.stdout.decode().strip()


def record(output):
    pod = Path(shutil.which("pod") or "MISSING_POD")
    if not pod.is_file():
        raise ValueError("CocoaPods executable missing")
    flutter = json.loads(capture(["flutter", "--version", "--machine"]))
    toolchain = {"schema": "bil.qa.public-cocoapods-toolchain.v1",
                 "cocoapods_version": capture([str(pod), "--version"]),
                 "flutter_version": flutter["frameworkVersion"],
                 "flutter_framework_revision": flutter["frameworkRevision"],
                 "flutter_engine_revision": flutter["engineRevision"],
                 "xcode_version": capture(["xcodebuild", "-version"]),
                 "ruby_version": capture(["ruby", "--version"]),
                 "xcodeproj_version": capture(["ruby", "-rxcodeproj", "-e", "puts Xcodeproj::VERSION"]),
                 "pod_executable_sha256": hashlib.sha256(pod.read_bytes()).hexdigest()}
    target = Path(output)
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(json.dumps(toolchain, indent=2, sort_keys=True) + "\n")
    if toolchain["cocoapods_version"] != "1.16.2" or toolchain["flutter_version"] != "3.44.6":
        raise ValueError("Expected exact CocoaPods1.16.2 and Flutter3.44.6; actual public versions retained in toolchain JSON")


if __name__ == "__main__":
    record(sys.argv[1])
