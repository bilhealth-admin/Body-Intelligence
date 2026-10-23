import io
import plistlib
import struct
import unittest
import zipfile

from verify_ios_app_icon import inspect


class IconResourceTest(unittest.TestCase):
    def fixture(self, *, ipad=True, png=True, catalog=True):
        primary = {'CFBundlePrimaryIcon': {'CFBundleIconName': 'AppIcon',
                    'CFBundleIconFiles': ['AppIcon60x60']}}
        info = {'CFBundleIcons': primary}
        if ipad:
            info['CFBundleIcons~ipad'] = primary
        result = io.BytesIO()
        with zipfile.ZipFile(result, 'w') as archive:
            archive.writestr('Payload/Runner.app/Info.plist', plistlib.dumps(info))
            if png:
                archive.writestr('Payload/Runner.app/AppIcon60x60@2x.png',
                    b'\x89PNG\r\n\x1a\n' + struct.pack('>I', 13) + b'IHDR'
                    + struct.pack('>II', 120, 120) + b'\x08\x02\x00\x00\x00' + b'\x00' * 4)
            if catalog:
                archive.writestr('Payload/Runner.app/Assets.car', b'synthetic catalog')
        result.seek(0)
        return result

    def test_both_device_families_and_bytes_are_inventoried_without_ui_claim(self):
        result = inspect(self.fixture())
        self.assertEqual('FINAL_IPA_ICON_RESOURCES_PRESENT', result['status'])
        self.assertEqual(120, result['icons']['AppIcon60x60@2x.png']['width'])
        self.assertFalse(result['apple_purchase_sheet_display_verified'])

    def test_missing_ipad_metadata_png_or_catalog_fails(self):
        for change in ({'ipad': False}, {'png': False}, {'catalog': False}):
            with self.subTest(change=change), self.assertRaises((ValueError, KeyError)):
                inspect(self.fixture(**change))


if __name__ == '__main__':
    unittest.main()
