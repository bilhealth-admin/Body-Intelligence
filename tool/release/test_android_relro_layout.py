"""Official Android separate-LOAD exception; never waive writable overlap."""
import unittest
from verify_android_16k_alignment import _load_alignments, GateError


class RelroLayoutTest(unittest.TestCase):
    def test_official_separate_relro_load_is_valid(self):
        headers = '''
 LOAD 0x000000 0x000000 0x000000 0x000680 0x000680 R E 0x4000
 LOAD 0x000680 0x004680 0x004680 0x0001d8 0x000980 RW 0x4000
 GNU_RELRO 0x000680 0x004680 0x004680 0x0001d8 0x000980 R 0x1
'''
        self.assertEqual(_load_alignments(headers, library='official.so'), [0x4000, 0x4000])

    def test_datastore_padding_and_next_writable_page_are_safe(self):
        headers = '''
 LOAD 0x000000 0x000000 0x000000 0x0011c0 0x0011c0 R E 0x4000
 LOAD 0x0011c0 0x0051c0 0x0051c0 0x000268 0x000268 RW 0x4000
 LOAD 0x001428 0x009428 0x009428 0x000000 0x000001 RW 0x4000
 GNU_RELRO 0x0011c0 0x0051c0 0x0051c0 0x000268 0x000e40 R 0x1
'''
        self.assertEqual(len(_load_alignments(headers, library='datastore.so')), 3)

    def test_same_load_writable_tail_is_rejected(self):
        headers = '''
 LOAD 0x000680 0x004680 0x004680 0x003980 0x003980 RW 0x4000
 GNU_RELRO 0x000680 0x004680 0x004680 0x0001d8 0x000980 R 0x1
'''
        with self.assertRaisesRegex(GateError, 'overlaps writable'):
            _load_alignments(headers, library='unsafe.so')

    def test_another_writable_load_in_rounded_page_is_rejected(self):
        headers = '''
 LOAD 0x000680 0x004680 0x004680 0x0001d8 0x000980 RW 0x4000
 LOAD 0x001000 0x006000 0x006000 0x000100 0x000100 RW 0x4000
 GNU_RELRO 0x000680 0x004680 0x004680 0x0001d8 0x000980 R 0x1
'''
        with self.assertRaisesRegex(GateError, 'overlaps writable'):
            _load_alignments(headers, library='unsafe-next.so')

    def test_missing_containing_load_fails_closed(self):
        with self.assertRaisesRegex(GateError, 'without a separate'):
            _load_alignments('LOAD 0x0 0x0 0x0 0x100 0x100 R E 0x4000\nGNU_RELRO 0x100 0x4680 0x4680 0x1d8 0x980 R 0x1', library='unknown.so')


if __name__ == '__main__':
    unittest.main()
