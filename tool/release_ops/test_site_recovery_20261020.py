import copy
import io
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import MagicMock, patch
import zipfile

import site_recovery_20261020 as recovery


class RecoveryDeploymentTest(unittest.TestCase):
    def archive(self, corrupt=False):
        receipt = {'collection_status': 'COMPLETE', 'mutations': 0, 'origin_repaired': False, 'public_sources': {}}
        members = {}
        specs = copy.deepcopy(recovery.ASSOCIATIONS)
        for name, spec in specs.items():
            raw = json.dumps({'fixture': name}).encode()
            spec['sha256'] = recovery.sha(raw)
            members[spec['member']] = raw
            receipt['public_sources'][spec['label']] = {'http_status': 200, 'body_sha256': spec['sha256'], 'candidate_sha256': spec['sha256'],
                'url': 'https://7e894d19-bilhealth.bilhealth-app.workers.dev/.well-known/' + name}
        if corrupt:
            receipt['public_sources']['last_good_20261018_aasa']['url'] = 'https://other.invalid/forged'
        members['association-recovery-report.json'] = json.dumps(receipt).encode()
        stream = io.BytesIO()
        with zipfile.ZipFile(stream, 'w') as archive:
            for name, raw in members.items():
                archive.writestr(name, raw)
        raw = stream.getvalue()
        metadata = {'id': recovery.ARTIFACT, 'expired': False, 'name': f'association-recovery-candidates-{recovery.RECOVERY_RUN}',
            'workflow_run': {'id': recovery.RECOVERY_RUN, 'head_sha': recovery.RECOVERY_CONTROLLER}, 'digest': 'sha256:' + recovery.sha(raw)}
        return specs, raw, metadata

    def test_recovered_bytes_are_unchanged_after_verified_archive(self):
        specs, raw, metadata = self.archive()
        with patch.object(recovery, 'ASSOCIATIONS', specs), patch.object(recovery, 'ZIP_SHA', recovery.sha(raw)):
            documents = recovery.artifact_documents(metadata, raw, {})
        for name, body in documents.items():
            self.assertEqual(recovery.sha(body), specs[name]['sha256'])

    def test_wrong_artifact_run_or_digest_never_pass(self):
        for fault in ('run', 'digest', 'expired'):
            specs, raw, metadata = self.archive()
            if fault == 'run': metadata['workflow_run']['id'] = 0
            elif fault == 'digest': metadata['digest'] = 'sha256:' + '0' * 64
            else: metadata['expired'] = True
            with self.subTest(fault=fault), patch.object(recovery, 'ASSOCIATIONS', specs), patch.object(recovery, 'ZIP_SHA', recovery.sha(raw)), self.assertRaises(ValueError):
                recovery.artifact_documents(metadata, raw, {})

    def test_forged_source_url_rejected_even_with_matching_zip_digest(self):
        specs, raw, metadata = self.archive(corrupt=True)
        with patch.object(recovery, 'ASSOCIATIONS', specs), patch.object(recovery, 'ZIP_SHA', recovery.sha(raw)), self.assertRaisesRegex(ValueError, 'PROVENANCE'):
            recovery.artifact_documents(metadata, raw, {})

    def test_policy_comparison_cannot_pass_with_missing_page_or_later_success(self):
        rows = [{'label': f'policy-{number}', 'matches_candidate': True} for number in range(18)]
        recovery.require_public_match(rows)
        with self.assertRaisesRegex(ValueError, 'INCOMPLETE'):
            recovery.require_public_match(rows[:-1])
        rows[0]['matches_candidate'] = False
        with self.assertRaisesRegex(ValueError, 'DIFFER'):
            recovery.require_public_match(rows)

    def test_external_actor_drift_blocks_mutation(self):
        before = {'deployment_id': recovery.DEPLOYMENT, 'version_id': recovery.VERSION, 'modules': [{'sha256': recovery.ACTIVE_CODE}], 'protected_configuration': {'routes': []}}
        for field in ('deployment_id', 'version_id', 'modules', 'protected_configuration'):
            current = copy.deepcopy(before)
            current[field] = 'changed'
            with self.subTest(field=field), self.assertRaisesRegex(ValueError, 'ANOTHER_ACTOR'):
                recovery.assert_unchanged(before, current)

    def test_backup_upload_required_before_any_mutation(self):
        with patch.dict(recovery.os.environ, {'BIL_BACKUP_ARTIFACT_ID': '', 'BIL_BACKUP_ARTIFACT_DIGEST': ''}), patch.object(recovery, 'gh') as gh:
            with self.assertRaisesRegex(ValueError, 'UPLOAD_NOT_PROVEN'):
                recovery.backup_bound()
            gh.assert_not_called()

    def test_policy_language_header_is_retained_without_cookies(self):
        response = MagicMock()
        response.__enter__.return_value = response
        response.code = 200
        response.headers = {'Content-Type': 'text/html', 'Content-Language': 'ar', 'Set-Cookie': 'secret-cookie'}
        response.read.return_value = b'public-html'
        opener = MagicMock()
        opener.open.return_value = response
        with patch.object(recovery.request, 'build_opener', return_value=opener):
            record, _ = recovery.probe('https://www.bilhealth.com/privacy?lang=ar')
        self.assertEqual(record['headers']['content-language'], 'ar')
        self.assertNotIn('secret-cookie', json.dumps(record))

    def test_matching_policy_body_cannot_hide_security_header_drift(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            site = root / 'public_site'
            site.mkdir()
            (site / '_headers').write_text("/*\n  Content-Security-Policy: default-src 'self'\n/app.js\n/styles.css\n/.well-known/apple-app-site-association\n/.well-known/assetlinks.json\n")
            page = site / 'page.html'
            page.write_bytes(b'policy')
            spec = {'url': recovery.BASE + '/privacy?lang=en', 'local': page, 'language': 'en', 'label': 'policy-privacy-en'}
            row = {'status': 200, 'body_sha256': recovery.sha(b'policy'), 'headers': {'content-type': 'text/html', 'content-language': 'en'}}
            with patch.object(recovery, 'expected_public', return_value=[spec]), patch.object(recovery, 'probe', return_value=(row, b'policy')):
                actual = recovery.compare_public(root, [])
            self.assertFalse(actual[0]['matches_candidate'])
            self.assertFalse(actual[0]['candidate_header_behavior_match'])

    def test_redirect_and_spa_behavior_are_checked_before_overwriting_config(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            site = root / 'public_site'
            site.mkdir()
            (site / '_redirects').write_text('/delete-account /account-deletion 301\n/delete-account/ /account-deletion 301\n')
            (site / 'index.html').write_bytes(b'index')
            def probe(url, method='GET'):
                if '/delete-account' in url:
                    return {'status': 301, 'headers': {'location': '/wrong-target'}}, b''
                if '/.well-known/' in url:
                    return {'status': 404}, b''
                return {'status': 200, 'body_sha256': recovery.sha(b'index'), 'headers': {'content-type': 'text/html'}}, b'index'
            with patch.object(recovery, 'probe', side_effect=probe):
                rows = recovery.config_behavior(root)
            self.assertEqual(len(rows), 7)
            self.assertFalse(all(row['passed'] for row in rows))

    def test_code_backup_excludes_metadata_binding_values(self):
        raw = b'--x\r\nContent-Disposition: form-data; name="metadata"\r\n\r\n{"secret":"private-value"}\r\n--x\r\nContent-Disposition: form-data; name="worker.js"; filename="worker.js"\r\nContent-Type: application/javascript\r\n\r\nexport default {};\r\n--x--\r\n'
        found = recovery.modules(raw, 'multipart/form-data; boundary=x')
        self.assertEqual(found, [('worker.js', b'export default {};')])

    def test_unexpected_rollback_module_blocks_incomplete_backup(self):
        raw = b'--x\r\nContent-Disposition: form-data; name="../../secret.js"\r\nContent-Type: application/javascript\r\n\r\ncode\r\n--x--\r\n'
        with self.assertRaisesRegex(ValueError, 'UNEXPECTED_ROLLBACK_MODULE'):
            recovery.modules(raw, 'multipart/form-data; boundary=x')


if __name__ == '__main__':
    unittest.main()
