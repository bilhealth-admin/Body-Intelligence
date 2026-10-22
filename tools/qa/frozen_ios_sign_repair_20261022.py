#!/usr/bin/env python3
"""Prepare a temporary, fail-closed iOS Simulator QA parser fix; source stays frozen."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess

SIGN_SHA = "8db7ceac93e7ab2cde338c1b446f8af6047e064a"
NATIVE_SHA = "42bbb8d33d00b2437c9f63a2db67f6350b29c9e7"
SOURCE_SHA = "31554b3e078667a38bd3c53aa105f5f1d2a4dc96"
NEEDLE = '''        if len(values) != 1 or not values[0]:
            raise ValueError("Xcode must emit one simulated entitlements path")'''
REPLACE = '''        if not values:
            # Xcode also exports an empty value while building other targets.
            # Only a nonempty Runner simulated-entitlement value is a candidate.
            # The final unique-path, file, signature, Mach-O, and source checks
            # below remain mandatory and fail closed.
            continue
        if len(values) != 1 or not values[0]:
            raise ValueError("Xcode must emit one simulated entitlements path")'''

def sha(obj):
    return hashlib.sha256(obj.encode("utf-8")).hexdigest()

def git_value(root, *args):
    return subprocess.check_output(["git", *args], cwd=root, text=True).strip()

def run(source, out):
    source = source.resolve()
    out = out.resolve()
    out.mkdir(parents=True, exist_ok=True)
    if git_value(source, "rev-parse", "HEAD") != SOURCE_SHA:
        raise ValueError("Never patch an unfrozen BIL source")
    original = source / ".github/scripts/bil_ios_simulator_adhoc_sign.py"
    native = source / ".github/scripts/bil_ios37_native_integration.sh"
    if git_value(source, "hash-object", str(original)) != SIGN_SHA:
        raise ValueError("Simulator signing helper differs from frozen original")
    if git_value(source, "hash-object", str(native)) != NATIVE_SHA:
        raise ValueError("Simulator native runner differs from frozen original")
    original_text=original.read_text(encoding="utf-8")
    assert original_text.count(NEEDLE)==1, "Expected one strict parser clause"
    modified=original_text.replace(NEEDLE, REPLACE)
    assert modified.count(NEEDLE)==0
    sign_out=out / "bil_ios_simulator_adhoc_sign.py"
    sign_out.write_text(modified, encoding="utf-8")
    for name in ("bil_native_bounded_command.py", "test_bil_ios_simulator_adhoc_sign.py"):
        shutil.copy2(source / ".github/scripts" / name, out / name)
    body=native.read_text(encoding="utf-8")
    token="python3 .github/scripts/bil_ios_simulator_adhoc_sign.py"
    assert body.count(token)==1
    body=body.replace(token, 'python3 "$BIL_SIGN_QA_HELPER"')
    native_out=out / "bil_ios37_native_integration.sh"
    native_out.write_text(body, encoding="utf-8")
    native_out.chmod(0o755)
    # Regression reproduces the observed Xcode build log: empty export in an
    # unrelated target followed by the actual Runner path.
    (out / "test_qa_empty_unrelated_export.py").write_text('''
import unittest
from bil_ios_simulator_adhoc_sign import resolve_simulated_entitlements_path
class RealBuildLogRegression(unittest.TestCase):
    def test_unrelated_empty_export_before_runner_is_allowed(self):
        path="/tmp/DerivedData/Runner.build/Runner.app-Simulated.xcent"
        log="    export LD_ENTITLEMENTS_SECTION=\\\\n    export LD_ENTITLEMENTS_SECTION\\\\\\\\="+path+"\\\\n"
        self.assertEqual(str(resolve_simulated_entitlements_path({},log)),path)
    def test_empty_only_still_fails(self):
        with self.assertRaises(ValueError):
            resolve_simulated_entitlements_path({}, "export LD_ENTITLEMENTS_SECTION=\\\\n")
    def test_conflicting_nonempty_paths_still_fail(self):
        a="/tmp/A/Runner.app-Simulated.xcent"
        b="/tmp/B/Runner.app-Simulated.xcent"
        with self.assertRaises(ValueError):
            resolve_simulated_entitlements_path({}, "export LD_ENTITLEMENTS_SECTION="+a+"\\\\nexport LD_ENTITLEMENTS_SECTION="+b)
'''.replace('\\\\n','\\n'),encoding="utf-8")
    summary={"source_sha":SOURCE_SHA,"original_sign_blob":SIGN_SHA,
        "original_runner_blob":NATIVE_SHA,"patched_sign_sha256":sha(modified),
        "source_unmodified":True,"scope":"QA temporary parser only; no signed store build",
        "testflight_invoked":False}
    (out/"manifest.json").write_text(json.dumps(summary,indent=2)+"\n")
    if git_value(source,"rev-parse","HEAD")!=SOURCE_SHA or git_value(source,"diff","--name-only","HEAD"):
        raise ValueError("Frozen source changed")
    print(json.dumps(summary,indent=2))

if __name__ == "__main__":
    p=argparse.ArgumentParser()
    p.add_argument("--source",required=True,type=Path)
    p.add_argument("--output",required=True,type=Path)
    a=p.parse_args()
    run(a.source,a.output)
