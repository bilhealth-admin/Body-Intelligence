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
    assert modified.count(REPLACE)==1, "Unexpected temporary signing-parser patch"
    # Actual Xcode 26.6 emits single-byte x86_64 dumps and little-endian
    # 32-bit arm64 dump words for the same Mach-O entitlement plist.
    # Keep the strict full-plist comparison, platform and section count.
    word_reader='''            current.extend(bytes.fromhex(match.group(1)))'''
    strict_reader='''            tokens = match.group(1).split()
            if section_format is None:
                if len(tokens)>1 and all(re.fullmatch(r"[0-9a-fA-F]{2}", t) for t in tokens):
                    section_format = "byte-pairs"
                elif len(tokens)>1 and all(re.fullmatch(r"[0-9a-fA-F]{8}", t) for t in tokens):
                    section_format = "little-endian-words"
                elif len(tokens)==1 and re.fullmatch(r"(?:[0-9a-fA-F]{2})+",tokens[0]):
                    # Existing fixture form: one continuous 1..16-byte hex row.
                    section_format = "continuous-bytes"
                else:
                    raise ValueError("Unrecognized otool entitlement hex representation")
            if section_format=="byte-pairs" and tokens and all(re.fullmatch(r"[0-9a-fA-F]{2}",t) for t in tokens):
                payload = bytes.fromhex("".join(tokens))
            elif section_format=="little-endian-words" and tokens and all(re.fullmatch(r"[0-9a-fA-F]{8}",t) for t in tokens):
                payload = b"".join(bytes.fromhex(t)[::-1] for t in tokens)
            elif section_format=="continuous-bytes" and len(tokens)==1 and re.fullmatch(r"(?:[0-9a-fA-F]{2})+",tokens[0]):
                payload = bytes.fromhex(tokens[0])
            else:
                raise ValueError("Mixed or malformed otool entitlement rows")
            current.extend(payload)'''
    if modified.count(word_reader)!=1:
        raise ValueError("Frozen otool reader changed; no QA patch")
    modified=modified.replace(word_reader,strict_reader)
    if modified.count(strict_reader)!=1:
        raise ValueError("Only one architecture-aware reader is permitted")
    start='''    sections = []
    current = None
    for line in raw.decode("utf-8").splitlines():'''
    revised_start='''    sections = []
    current = None
    section_format = None
    for line in raw.decode("utf-8").splitlines():'''
    marker='''            current = bytearray()
            sections.append(current)
            continue'''
    revised_marker='''            current = bytearray()
            section_format = None
            sections.append(current)
            continue'''
    if modified.count(start)!=1 or modified.count(marker)!=1:
        raise ValueError("Original architecture section initialization drifted")
    modified=modified.replace(start,revised_start).replace(marker,revised_marker)
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
    (out / "test_qa_empty_unrelated_export.py").write_text(r'''
import unittest
from bil_ios_simulator_adhoc_sign import resolve_simulated_entitlements_path
class RealBuildLogRegression(unittest.TestCase):
    def test_unrelated_empty_export_before_runner_is_allowed(self):
        path="/tmp/DerivedData/Runner.build/Runner.app-Simulated.xcent"
        log="    export LD_ENTITLEMENTS_SECTION=\n    export LD_ENTITLEMENTS_SECTION\\="+path+"\n"
        self.assertEqual(str(resolve_simulated_entitlements_path({},log)),path)
    def test_empty_only_still_fails(self):
        with self.assertRaises(ValueError):
            resolve_simulated_entitlements_path({}, "export LD_ENTITLEMENTS_SECTION=\n")
    def test_conflicting_nonempty_paths_still_fail(self):
        a="/tmp/A/Runner.app-Simulated.xcent"
        b="/tmp/B/Runner.app-Simulated.xcent"
        with self.assertRaises(ValueError):
            resolve_simulated_entitlements_path({}, "export LD_ENTITLEMENTS_SECTION="+a+"\nexport LD_ENTITLEMENTS_SECTION="+b)
''',encoding="utf-8")
    (out / "test_qa_otool_arm64_word_hex.py").write_text(r'''
import plistlib
import unittest
from bil_ios_simulator_adhoc_sign import verify_simulated_sections

class ActualOtoolHexRegression(unittest.TestCase):
    def setUp(self):
        self.expected = {
            "application-identifier": "43F9Y5Y96K.com.bilhealth.bodyintelligencelog",
            "com.apple.developer.healthkit": True,
        }
        raw = plistlib.dumps(self.expected, fmt=plistlib.FMT_XML)
        self.blob = raw + b"\0" * ((-len(raw)) % 4)

    def section(self, arch, style, blob=None):
        raw = self.blob if blob is None else blob
        lines = ["Runner (architecture %s):" % arch,
                 "Contents of (__TEXT,__entitlements) section"]
        for offset in range(0, len(raw), 16):
            chunk = raw[offset:offset+16]
            if style == "bytes":
                hex_words = " ".join("%02x" % b for b in chunk)
            elif style == "le32":
                if len(chunk) % 4:
                    raise AssertionError("Fixture must be 4-byte padded")
                hex_words = " ".join(chunk[n:n+4][::-1].hex()
                                     for n in range(0,len(chunk),4))
            else:
                raise AssertionError("Unsupported fixture")
            lines.append("%016x  %s" % (0x100003000+offset,hex_words))
        return "\n".join(lines)

    def test_real_xcode26_two_architecture_formats(self):
        raw = (self.section("x86_64","bytes") + "\n"
               + self.section("arm64","le32") + "\n").encode()
        self.assertEqual(verify_simulated_sections(raw,self.expected,2),2)

    def test_original_contiguous_mock_hex_still_passes(self):
        lines=["Runner (architecture arm64):",
               "Contents of (__TEXT,__entitlements) section"]
        for offset in range(0,len(self.blob),16):
            lines.append("%016x %s" % (4096+offset,self.blob[offset:offset+16].hex()))
        self.assertEqual(verify_simulated_sections(
            "\n".join(lines).encode(),self.expected,1),1)

    def test_legacy_single_hex_row_for_complete_plist(self):
        raw=("Contents of (__TEXT,__entitlements) section"+"\n"
             +"0000000100003000 "+self.blob.hex()+"\n").encode()
        self.assertEqual(verify_simulated_sections(raw,self.expected,1),1)

    def test_absent_architecture_still_fails(self):
        with self.assertRaises(ValueError):
            verify_simulated_sections(
                self.section("arm64","le32").encode(),self.expected,2)

    def test_mismatched_arm64_entitlements_still_fail(self):
        wrong = plistlib.dumps({"different":True},fmt=plistlib.FMT_XML)
        wrong += b"\0"*((-len(wrong))%4)
        raw = (self.section("x86_64","bytes")+"\n"
               +self.section("arm64","le32",wrong)).encode()
        with self.assertRaises(ValueError):
            verify_simulated_sections(raw,self.expected,2)

    def test_malformed_word_tokens_still_fail(self):
        raw = b"Contents of (__TEXT,__entitlements) section\n0000000100003000 abcd12\n"
        with self.assertRaises(ValueError):
            verify_simulated_sections(raw,self.expected,1)
''',encoding="utf-8")
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
