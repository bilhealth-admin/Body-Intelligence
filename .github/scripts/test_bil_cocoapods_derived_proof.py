import copy
import hashlib
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import bil_cocoapods_derived_proof as m

ROOT = Path(__file__).parent


class DerivedProofTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.original = {p: (ROOT / "fixtures/original" / p).read_bytes() for p in m.DERIVED_PATHS}
        cls.generated = {p: (ROOT / "fixtures/generated" / p).read_bytes() for p in m.DERIVED_PATHS}
        cls.contract = json.loads((ROOT / "cocoapods-derived-contract.json").read_text())

    def check(self, generated=None, original=None, contract=None):
        return m.validate(original or self.original, generated or self.generated,
                          contract or self.contract, require_plutil=False)

    def mutated(self, old, new, path=m.DERIVED_PATHS[2]):
        result = self.generated.copy()
        self.assertIn(old, result[path])
        result[path] = result[path].replace(old, new, 1)
        return result

    def test_actual_four_observed_outputs_hash_match_and_pass(self):
        self.assertEqual(len(self.check()), 4)
        self.assertEqual({p: m.sha256(b) for p, b in self.generated.items()},
                         self.contract["reviewed_observed_generated_sha256"])

    def test_generated_object_identifiers_can_change_without_changing_semantics(self):
        generated = self.generated.copy()
        before = m.parse_openstep(self.original[m.DERIVED_PATHS[2]])
        after = m.parse_openstep(generated[m.DERIVED_PATHS[2]])
        data = generated[m.DERIVED_PATHS[2]]
        for i, identifier in enumerate(sorted(m.new_roles(before, after))):
            replacement = ("F0" + format(i, "022X")).encode()
            data = data.replace(identifier.encode(), replacement)
        generated[m.DERIVED_PATHS[2]] = data
        self.assertEqual(len(self.check(generated)), 4)

    def test_old_source_bridge_cannot_be_removed(self):
        with self.assertRaises(ValueError):
            self.check(self.mutated(b'path = BILSystemCryptoBridge.swift;', b'path = OtherBridge.swift;'))

    def test_build_settings_unchanged(self):
        for old, new in [(b'43F9Y5Y96K', b'ANOTHER1234'),
                         (b'Runner/Runner.entitlements', b'Runner/Other.entitlements'),
                         (b'com.bilhealth.bodyintelligencelog', b'com.fake.app')]:
            with self.subTest(old=old), self.assertRaises(ValueError):
                self.check(self.mutated(old, new))

    def test_existing_shell_script_cannot_change(self):
        with self.assertRaises(ValueError):
            self.check(self.mutated(b'xcode_backend.sh', b'evil_backend.sh'))

    def test_new_pods_shell_script_exact_not_name_only(self):
        with self.assertRaises(ValueError):
            self.check(self.mutated(b'Pods-Runner-frameworks.sh', b'Pods-Runner-other.sh'))

    def test_manifest_check_cannot_be_short_circuited(self):
        with self.assertRaises(ValueError):
            self.check(self.mutated(b'diff \\"${PODS_PODFILE_DIR_PATH}', b'true; diff \\"${PODS_PODFILE_DIR_PATH}'))

    def test_existing_source_order_unchanged(self):
        with self.assertRaises(ValueError):
            self.check(self.mutated(b'\t\t\t\t1498D2341E8E89220040F4C2 /* GeneratedPluginRegistrant.m in Sources */,', b''))

    def test_original_target_build_phase_order_unchanged(self):
        value = self.generated.copy()
        p = m.DERIVED_PATHS[2]
        a = b'\t\t\t\t9740EEB61CF901F6004384FC /* Run Script */,\n'
        b = b'\t\t\t\t97C146EA1CF9000F007C117D /* Sources */,\n'
        self.assertIn(a + b, value[p])
        value[p] = value[p].replace(a + b, b + a)
        with self.assertRaises(ValueError):
            self.check(value)

    def test_generated_framework_path_cannot_escape(self):
        with self.assertRaises(ValueError):
            self.check(self.mutated(b'path = Pods_Runner.framework;', b'path = ../../Other.framework;'))

    def test_new_object_cannot_hide_in_existing_group(self):
        with self.assertRaises(ValueError):
            self.check(self.mutated(b'objects = {', b'objects = { FFFFFFFF0000000000000000 = {isa = PBXFileReference; path = Evil.swift;};'))

    def test_no_removed_existing_object(self):
        before = m.parse_openstep(self.original[m.DERIVED_PATHS[2]])
        after = m.parse_openstep(self.generated[m.DERIVED_PATHS[2]])
        del after["objects"][next(iter(before["objects"]))]
        with self.assertRaises(ValueError):
            m.normalize_generated(before, after)

    def test_xcconfig_accepts_exact_include_only(self):
        for p in m.DERIVED_PATHS[:2]:
            for delta in (b'OTHER_SWIFT_FLAGS=EVIL\n', b'#include "Other.xcconfig"\n'):
                generated = self.generated.copy()
                generated[p] += delta
                with self.subTest(path=p, delta=delta), self.assertRaises(ValueError):
                    self.check(generated)

    def test_workspace_accepts_only_pods_reference(self):
        p = m.DERIVED_PATHS[3]
        for original, replacement in [(b'group:Pods/Pods.xcodeproj', b'group:Other/Other.xcodeproj'),
                                      (b'group:Runner.xcodeproj', b'group:Fake.xcodeproj'),
                                      (b'</Workspace>', b'<Group location="group:Injected"/></Workspace>')]:
            with self.subTest(replacement=replacement), self.assertRaises(ValueError):
                self.check(self.mutated(original, replacement, p))

    def test_xml_entity_or_processing_instruction_rejected(self):
        for payload in (b'<!DOCTYPE Workspace [<!ENTITY e SYSTEM "file:///etc/passwd">]>', b'<?evil script?>'):
            generated = self.generated.copy()
            generated[m.DERIVED_PATHS[3]] = payload + generated[m.DERIVED_PATHS[3]]
            with self.assertRaises(ValueError):
                self.check(generated)

    def test_xml_declaration_cannot_be_replaced_removed_or_followed_by_processing_instruction(self):
        path = m.DERIVED_PATHS[3]
        declaration = b'<?xml version="1.0" encoding="UTF-8"?>'
        cases = [self.generated[path].replace(declaration, b'<?evil script?>', 1),
                 self.generated[path].replace(declaration + b'\n', b'', 1),
                 self.generated[path].replace(b'</Workspace>', b'<?evil script?></Workspace>', 1),
                 self.generated[path].replace(b'encoding="UTF-8"', b'encoding="UTF-8" standalone="yes"', 1)]
        for data in cases:
            generated = self.generated.copy()
            generated[path] = data
            with self.subTest(data=data[:70]), self.assertRaisesRegex(ValueError, "workspace XML declaration"):
                self.check(generated)

    def test_frozen_original_hash_must_match(self):
        original = self.original.copy()
        original[m.DERIVED_PATHS[0]] += b'\n'
        with self.assertRaises(ValueError):
            self.check(original=original)

    def test_all_four_inputs_required(self):
        generated = self.generated.copy()
        del generated[m.DERIVED_PATHS[3]]
        with self.assertRaises(ValueError):
            self.check(generated)

    def test_duplicate_plist_key_rejected(self):
        with self.assertRaises(ValueError):
            m.parse_openstep(b'{a=one;a=two;}')

    def test_apple_plutil_crosscheck_is_required_in_production(self):
        with patch.object(m.subprocess, "run") as run:
            run.return_value.returncode = 0
            run.return_value.stdout = b'{}'
            with self.assertRaises(ValueError):
                m.parse_pbx(self.original[m.DERIVED_PATHS[2]])
            self.assertEqual(run.call_args.args[0][0], "/usr/bin/plutil")

    def test_toolchain_and_lockfiles_are_not_optional(self):
        toolchain = {"cocoapods_version": "1.16.2", "flutter_version": "3.44.6",
                     "ruby_version": "ruby 3.3.0", "xcode_version": "Xcode 26.6",
                     "xcodeproj_version": "1.27.0", "pod_executable_sha256": "a" * 64}
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / "ios/Pods").mkdir(parents=True)
            for p in ("ios/Podfile.lock", "ios/Pods/Manifest.lock"):
                (root / p).write_bytes(b'PODS:\n  - SDK (1.0)\nCOCOAPODS: 1.16.2\n')
            self.assertEqual(m.validate_toolchain(root, toolchain)["podfile_lock_sha256"],
                             m.sha256((root / "ios/Podfile.lock").read_bytes()))
            for key in toolchain:
                broken = toolchain.copy()
                del broken[key]
                with self.subTest(missing=key), self.assertRaises(ValueError):
                    m.validate_toolchain(root, broken)
            (root / "ios/Pods/Manifest.lock").write_text("different")
            with self.assertRaises(ValueError):
                m.validate_toolchain(root, toolchain)


if __name__ == "__main__":
    unittest.main()
