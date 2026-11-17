"""Exercise the real protection gate; no cloud, CI, SDK or source mutation."""
import hashlib
from pathlib import Path
import re
import subprocess
import unittest
from unittest.mock import patch
import bil40_internal_build_ci as gate
import bil41_internal_build_ci as source_cloud_gate

STORE='lib/features/commerce/presentation/bil_dynamic_store_components.dart'
GLASS='lib/shared/widgets/bil_glass_press_feedback.dart'
REVIEWED_STORE='119f72914b468ff3db40dd07e72da96b837f7da7'
REVIEWED_GLASS='653d424ddb6cca8adeb0d394f5c8f8866da3792d'
SHA='a'*40
ROOT = Path(__file__).resolve().parents[2]

class ReachedMetadataAfterProtectedPins(Exception):
    pass

class ProtectedPurchase44Test(unittest.TestCase):
    def git(self, blobs):
        def read(arguments, **kwargs):
            self.assertTrue(kwargs.get('text'))
            args=arguments[1:]
            if args==['rev-parse','HEAD']:
                return SHA+'\n'
            if args==['status','--porcelain=v1','--untracked-files=all']:
                return ''
            if len(args)==2 and args[0]=='hash-object':
                return blobs[args[1]]+'\n'
            raise AssertionError('Unexpected Git operation in protected-gate fixture')
        return read

    def run_guard(self, blobs):
        with patch('sys.argv',['bil40_internal_build_ci.py','--sha',SHA,'--output','UNWRITTEN_FIXTURE.json']), \
             patch.object(gate.subprocess,'check_output',side_effect=self.git(blobs)), \
             patch.object(gate.subprocess,'run') as ancestry, \
             patch.object(gate,'api',side_effect=ReachedMetadataAfterProtectedPins) as network:
            try:
                gate.main()
            except ReachedMetadataAfterProtectedPins:
                self.assertEqual(ancestry.call_count,2)
                network.assert_called_once_with('/git/ref/heads/work/ios38-safe-fixes-20261025')
                return 'EXACT_PROTECTED_PINS_ACCEPTED_NEXT_METADATA_BLOCKED_BY_FIXTURE'
            except ValueError as error:
                network.assert_not_called()
                return str(error)
            raise AssertionError('Fixture must never certify a release')

    def test_exact_reviewed_store_and_glass_reach_metadata_without_release(self):
        self.assertEqual(gate.PROTECTED,{STORE:REVIEWED_STORE,GLASS:REVIEWED_GLASS})
        self.assertEqual(self.run_guard(dict(gate.PROTECTED)),
                         'EXACT_PROTECTED_PINS_ACCEPTED_NEXT_METADATA_BLOCKED_BY_FIXTURE')

    def test_old_store_pin_and_arbitrary_mutant_blobs_still_stop_before_metadata(self):
        content=b'non-approved protected storecomponent mutation\n'
        mutant=hashlib.sha1(b'blob '+str(len(content)).encode()+b'\0'+content).hexdigest()
        for candidate in ('fdd24dbfa5b16f78aad65a821a2f5cf1215f90d5','0'*40,mutant):
            with self.subTest(mutant_blob=candidate):
                blobs=dict(gate.PROTECTED);blobs[STORE]=candidate
                self.assertEqual(self.run_guard(blobs),'Protected checkout source changed: '+STORE)

    def test_glass_protection_remains_mandatory(self):
        blobs=dict(gate.PROTECTED);blobs[GLASS]='f'*40
        self.assertEqual(self.run_guard(blobs),'Protected checkout source changed: '+GLASS)

    def test_historical_literal_workflow_guards_match_the_reviewed_shared_gate(self):
        command = re.compile(
            r'^test "\$\(git hash-object ([^)]+)\)" = "([a-f0-9]{40})"$'
        )
        observed = {}
        for workflow in sorted((ROOT / '.github/workflows').glob('*.y*ml')):
            for line in workflow.read_text(encoding='utf-8').splitlines():
                if 'git hash-object' not in line or not any(
                    name in line for name in gate.PROTECTED
                ):
                    continue
                match = command.fullmatch(line.strip())
                self.assertIsNotNone(
                    match,
                    f'Unrecognized protected-source guard requires review: {workflow.name}',
                )
                name, expected_blob = match.groups()
                key = (workflow.name, name)
                self.assertNotIn(key, observed, 'Duplicate protected-source guard')
                observed[key] = expected_blob
                self.assertEqual(
                    expected_blob,
                    gate.PROTECTED[name],
                    f'Live workflow drifted from the reviewed gate: {workflow.name}: {name}',
                )
        for name, expected_blob in gate.PROTECTED.items():
            self.assertEqual(observed.get(('bil39-crystal.yml', name)), expected_blob)

    def test_version47_source_does_not_weaken_historical44_acceptance(self):
        blobs=dict(gate.PROTECTED)
        blobs[STORE]='da3c7dde8a1f9807345eb03e58c148874cfa8deb'
        self.assertEqual(self.run_guard(blobs),'Protected checkout source changed: '+STORE)

    def test_current_source_cloud_gate_shares_the_reviewed_protected_contract(self):
        self.assertEqual(source_cloud_gate.PROTECTED, gate.PROTECTED)

if __name__=='__main__':
    unittest.main()
