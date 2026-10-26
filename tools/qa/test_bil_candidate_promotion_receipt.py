"""Execute the real workflow IPA verifier on synthetic signed evidence."""
import hashlib
import json
import os
from pathlib import Path
import plistlib
import re
import shutil
import subprocess
import sys
import tempfile
import unittest
import zipfile

ROOT = Path(__file__).resolve().parents[2]
HEAD = '1' * 40


class PromotionReceiptTest(unittest.TestCase):
    def test_policy_source_guard_accepts_candidate_and_protected_branch_only(self):
        text = (ROOT / '.github/workflows/bil_apple_google_policy_gate.yml').read_text(encoding='utf8')
        block = text.split('- name: Record source and branch before any checks',1)[1].split('\n      - name:',1)[0]
        script = '\n'.join(line[10:] if line.startswith('          ') else line
                           for line in block.split('run: |\n',1)[1].splitlines())
        # Exercise the real branch authorization before any Git/filesystem I/O.
        script = script.split('test "$(git rev-parse HEAD)"',1)[0]
        bash = shutil.which('bash')
        if os.name == 'nt':
            # WindowsApps/bash may be a disabled WSL launcher; use Git's Bash.
            git_bash = Path(shutil.which('git')).resolve().parents[1] / 'bin/bash.exe'
            if git_bash.is_file():
                bash = str(git_bash)
        self.assertIsNotNone(bash,'Policy workflow needs Bash')
        with tempfile.TemporaryDirectory() as temp:
            for branch, accepted in [('codex/bil-release-ios38-android33-20261022',True),
                                     ('integration/bil-qa-media-policy-20261011',True),
                                     ('feature/unapproved',False)]:
                with self.subTest(branch=branch):
                    env = dict(os.environ,GITHUB_REF='refs/heads/'+branch,GITHUB_SHA=HEAD,
                               POLICY_OUT=(Path(temp)/branch.rsplit('/',1)[1]).as_posix())
                    result = subprocess.run([bash,'-c',script],cwd=ROOT,env=env,capture_output=True,text=True)
                    self.assertEqual(accepted,result.returncode==0,result.stderr)

    def exercise(self, ipa_build='38', *, workflow='bil_ios_upload_existing_testflight.yml', receipt_build=38):
        text = (ROOT / '.github/workflows' / workflow).read_text(encoding='utf8')
        blocks = re.findall(r"python3 - <<'PY'\n(.*?)\n          PY", text, re.S)
        matched = [b for b in blocks if "identity={'source_sha'" in b]
        self.assertEqual(1, len(matched))
        code = '\n'.join(line[10:] if line.startswith('          ') else line for line in matched[0].splitlines())
        with tempfile.TemporaryDirectory() as temp:
            folder = Path(temp)
            delivery = folder / 'delivery'; delivery.mkdir()
            evidence = folder / 'evidence'; evidence.mkdir()
            ipa = delivery / 'test.ipa'
            info = {'CFBundleIdentifier':'com.bilhealth.bodyintelligencelog', 'CFBundleVersion':ipa_build,
                    'CFBundleShortVersionString':'1.0.0', 'ITSAppUsesNonExemptEncryption':False}
            with zipfile.ZipFile(ipa, 'w') as archive:
                archive.writestr('Payload/Runner.app/Info.plist',plistlib.dumps(info))
            digest = hashlib.sha256(ipa.read_bytes()).hexdigest()
            receipt = {'status':'SIGNED_IPA_BUILT_AND_LOCALLY_VERIFIED','source_sha':HEAD,
                       'build':receipt_build,'ipa_sha256':digest,'ipa_bytes':ipa.stat().st_size,
                       'native_crypto_runtime_status':'PASS'}
            (delivery/'BIL-ios-build-only-receipt.json').write_text(json.dumps(receipt))
            (delivery/'BIL-source-head.txt').write_text(HEAD)
            (delivery/'BIL-ios-codesign-verify.txt').write_text('SIGNED_IPA_CODESIGN_GATE=PASS')
            (delivery/'BIL-ios-crypto-scan.txt').write_text('SIGNED_IPA_FORBIDDEN_CRYPTO_MARKERS=0')
            (delivery/'BIL-ios-native-crypto-gate.txt').write_text('NATIVE_CRYPTO_RUNTIME_GATE=PASS')
            (delivery/'BIL-ios-final-artifact-inventory.json').write_text(json.dumps({
                'status':'FINAL_ARTIFACT_IDENTITY_PASS','build':str(receipt_build),
                'package':'com.bilhealth.bodyintelligencelog','version':'1.0.0'}))
            env = dict(os.environ, BIL_IPA_SHA256=digest, BIL_TESTED_SOURCE=HEAD,
                       BIL_VALIDATION_MODE='all_exact_source_ci',
                       BIL_INTERNAL_TESTFLIGHT='false', GITHUB_ENV=str(folder/'env'))
            result = subprocess.run([sys.executable,'-c',code],cwd=folder,env=env,capture_output=True,text=True)
            identity = evidence/'identity.json'
            return result, json.loads(identity.read_text()) if identity.exists() else None

    def test_actual_workflow_receipt_matches_verified_ipa_build(self):
        result, identity = self.exercise()
        self.assertEqual(0,result.returncode,result.stderr)
        self.assertEqual(38,identity['build'])
        self.assertEqual(HEAD,identity['source_sha'])

    def test_actual_workflow_rejects_old_binary_before_writing_receipt(self):
        result, identity = self.exercise('37')
        self.assertNotEqual(0,result.returncode)
        self.assertIsNone(identity)


if __name__ == '__main__':
    unittest.main(verbosity=2)
