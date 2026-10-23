"""Verify the actual committed projections, not merely source function names."""
import hashlib
import json
from pathlib import Path
import unittest

import build_home_smart_plan_prescriptions as projection


class HomeSourceProjectionTests(unittest.TestCase):
    def test_reviewed_home_projection_is_reproducible_from_actual_released_movements(self):
        expected = (json.dumps(projection.build(), ensure_ascii=False, indent=2) + '\n').encode('utf-8')
        self.assertEqual(projection.DESTINATION.read_bytes(), expected)
        data = json.loads(expected)
        self.assertEqual(len(data['sessions']), 10)
        self.assertEqual(sum(len(row['exercises']) for row in data['sessions']), 60)
        for session in data['sessions']:
            self.assertEqual(len({row['exerciseId'] for row in session['exercises']}), 6)
            for row in session['exercises']:
                self.assertTrue(row['titleAr'])
                self.assertIn(row['sets'], (2, 3))
                self.assertTrue(60 <= row['restSeconds'] <= 180)

    def test_warmups_keep_the_original_gym_source_and_only_exact_home_media_matches(self):
        expected = (json.dumps(projection.build_warmups(), ensure_ascii=False, indent=2) + '\n').encode('utf-8')
        self.assertEqual(projection.WARMUPS.read_bytes(), expected)
        source = projection.ROOT / 'artifacts/workout_media/gym_training_plan_source_v1.json'
        data = json.loads(expected)
        self.assertEqual(data['gymSourceSha256'], hashlib.sha256(source.read_bytes()).hexdigest())
        self.assertEqual(data['homeMinimumSeconds'], 360)
        self.assertEqual(sum('exerciseId' in row for row in data['home']), 3)
        self.assertEqual(len(data['home']), 5)
        self.assertNotIn('exerciseId', data['home'][3])
        self.assertNotIn('exerciseId', data['home'][4])


if __name__ == '__main__':
    unittest.main()
