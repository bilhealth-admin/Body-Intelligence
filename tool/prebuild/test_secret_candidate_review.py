import base64
import json
import unittest

from review_secret_candidates import review


class CandidateReviewTest(unittest.TestCase):
    def review_value(self, value, label='SUPABASE_KEY = ', path='app_config.txt'):
        return review({'StartLine':1,'EndLine':1,'Match':label+'REDACTED',
                       'RuleID':'generic-api-key'}, label+value, path)

    def token(self, role):
        body=base64.urlsafe_b64encode(json.dumps({'role':role}).encode()).decode().rstrip('=')
        return 'header.'+body+'.deliberately-invalid-signature'

    def test_public_key_is_distinguished_from_secret_key(self):
        self.assertIsNotNone(self.review_value('sb_publishable_fixture_only'))
        self.assertIsNone(self.review_value('sb_secret_fixture_only'))

    def test_privileged_or_malformed_jwt_never_auto_passes(self):
        self.assertIsNotNone(self.review_value(self.token('anon')))
        self.assertIsNone(self.review_value(self.token('service_role')))
        self.assertIsNone(self.review_value('not-a-jwt'))

    def test_identifier_allowance_is_both_path_and_value_bounded(self):
        label='instructionKey = '
        value='recipe-one.step1'
        self.assertIsNotNone(self.review_value(value,label,'assets/catalogs/recipes/v1/shards/recipes-00.json'))
        self.assertIsNone(self.review_value(value,label,'service_credentials.txt'))
        self.assertIsNone(self.review_value('unexpected-secret',label,'assets/catalogs/recipes/v1/shards/recipes-00.json'))

    def test_unknown_findings_and_missing_source_remain_unresolved(self):
        self.assertIsNone(self.review_value('unclassified-opaque-value','api_key = '))
        self.assertIsNone(review({'StartLine':50,'EndLine':50,'Match':'key=REDACTED',
                                 'RuleID':'generic-api-key'},'short file','file.txt'))
