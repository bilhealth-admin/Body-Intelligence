import unittest

from bil_cloud_restore_cycle_runner import loopback_base


class CycleLoopbackTest(unittest.TestCase):
    def test_owned_fixture_endpoint_is_preserved(self):
        self.assertEqual(loopback_base('http://127.0.0.1:55435'), 'http://127.0.0.1:55435')
        self.assertEqual(loopback_base('http://127.0.0.1:55435/'), 'http://127.0.0.1:55435')

    def test_corruption_cannot_send_cleanup_to_a_remote_service(self):
        for value in ['https://example.com:54321', 'http://example.com:54321',
                      'http://127.0.0.1.example.com:54321', 'http://127.0.0.1:54321@evil.invalid',
                      'http://user@127.0.0.1:54321', 'http://127.0.0.1:54321\n']:
            with self.assertRaises(ValueError):
                loopback_base(value)

    def test_ambiguous_paths_ports_and_non_urls_fail_closed(self):
        for value in [None, {}, '', 'http://127.0.0.1', 'http://127.0.0.1:0',
                      'http://127.0.0.1:99999', 'http://127.0.0.1:54321/rest/v1',
                      'http://127.0.0.1:54321?target=other', 'http://127.0.0.1:54321#other']:
            with self.assertRaises(ValueError):
                loopback_base(value)


if __name__ == '__main__':
    unittest.main()
