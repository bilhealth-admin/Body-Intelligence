"""Reject stale source, missing gates and incorrect candidate build identities."""
from copy import deepcopy
import unittest
from unittest.mock import Mock

import bil_candidate_release as candidate
import bil_release_delivery as delivery
from test_bil_release_delivery import fixture, reports

HEAD = 'a' * 40


class CandidateReleaseTest(unittest.TestCase):
    def test_only_authorized_platform_build_pairs_and_branch_are_accepted(self):
        for platform, build in candidate.TARGETS.items():
            candidate.validate_identity(platform, build, HEAD, candidate.BRANCH)
        for platform, build, head, branch in (
                ('ios', '37', HEAD, candidate.BRANCH),
                ('android', '38', HEAD, candidate.BRANCH),
                ('android', 33, HEAD, candidate.BRANCH),
                ('ios', '38', 'short', candidate.BRANCH),
                ('ios', '38', HEAD, delivery.BRANCH),
                ('other', '38', HEAD, candidate.BRANCH)):
            with self.subTest(platform=platform, build=build), self.assertRaises(ValueError):
                candidate.validate_identity(platform, build, head, branch)

    def test_incomplete_duplicate_or_stale_manifest_blocks_signing(self):
        for platform, build in candidate.TARGETS.items():
            text = '\n'.join((
                '`STAGING_MANIFEST_COMPLETE: YES`', '`CANDIDATE_FROZEN_OR_ACCEPTED: YES`',
                '`UNRESOLVED_REVIEW_COUNT: 0`', '`RELEASE_VERSION: 1.0.0`',
                f'`RELEASE_BUILD_NUMBER: {build}`'))
            candidate.validate_manifest(text, platform)
            for broken in (text.replace('COMPLETE: YES', 'COMPLETE: NO'),
                           text.replace('ACCEPTED: YES', 'ACCEPTED: NO'),
                           text.replace('COUNT: 0', 'COUNT: 1'),
                           text.replace(f'NUMBER: {build}', 'NUMBER: 8'),
                           text + '\n`CANDIDATE_FROZEN_OR_ACCEPTED: YES`'):
                with self.subTest(platform=platform), self.assertRaises(ValueError):
                    candidate.validate_manifest(broken, platform)

    def test_candidate_branch_is_explicit_and_does_not_relax_legacy_guard(self):
        manifest, run = fixture()
        run['head_branch'] = candidate.BRANCH
        def api(endpoint):
            return {'jobs': [{'name': 'Actual E2E', 'status': 'completed', 'conclusion': 'success'}]} if '/jobs?' in endpoint else deepcopy(run)
        with self.assertRaises(ValueError):
            delivery.validate_prerequisites(manifest, {'synthetic': 12}, HEAD, api)
        self.assertEqual(len(delivery.validate_prerequisites(manifest, {'synthetic': 12},
            HEAD, api, expected_branch=candidate.BRANCH)), 1)
        run['head_sha'] = 'b' * 40
        with self.assertRaises(ValueError):
            delivery.validate_prerequisites(manifest, {'synthetic': 12}, HEAD, api,
                                           expected_branch=candidate.BRANCH)

    def test_codeql_evidence_cannot_be_reused_across_candidate_branches(self):
        semgrep, mobsf, analyses, alerts = reports()
        with self.assertRaises(ValueError):
            delivery.security_reports(semgrep, mobsf, analyses, alerts, HEAD,
                                      expected_branch=candidate.BRANCH)
        for item in analyses:
            item['ref'] = 'refs/heads/' + candidate.BRANCH
        delivery.security_reports(semgrep, mobsf, analyses, alerts, HEAD,
                                  expected_branch=candidate.BRANCH)
        with self.assertRaises(ValueError):
            delivery.security_reports(semgrep, mobsf, analyses, alerts, HEAD)

    def test_moved_protected_branch_blocks_before_ci_or_security_calls(self):
        api = Mock(return_value={'object': {'sha': 'b' * 40}})
        with self.assertRaisesRegex(ValueError, 'Protected'):
            candidate.verify_ci('ios', HEAD, {}, api)
        api.assert_called_once_with('git/ref/heads/integration/bil-qa-media-policy-20261011')

    def test_missing_ci_inventory_blocks_even_with_matching_protected_branch(self):
        api = Mock(return_value={'object': {'sha': candidate.PROTECTED}})
        with self.assertRaises(ValueError):
            candidate.verify_ci('ios', HEAD, {}, api)
        api.assert_called_once_with('git/ref/heads/integration/bil-qa-media-policy-20261011')


if __name__ == '__main__':
    unittest.main()
