import unittest

from verify_android33_review_scope import HEALTH_READS, validate_manifest


def manifest(extra=(), omit=(), tag='uses-permission'):
    names = sorted((HEALTH_READS - set(omit)).union(extra))
    rows = ''.join(f'<{tag} android:name="{name}"/>' for name in names)
    return ('<manifest package="com.bilhealth.bodyintelligencelog" '
            'xmlns:android="http://schemas.android.com/apk/res/android">' + rows + '</manifest>').encode()


class Android33ReviewScopeTest(unittest.TestCase):
    def test_approved_read_scope_allows_attachment_permissions(self):
        result = validate_manifest(manifest(['android.permission.CAMERA', 'android.permission.RECORD_AUDIO']))
        self.assertEqual(result['status'], 'PASS')
        self.assertEqual(len(result['health_reads']), 3)

    def test_rejects_modern_and_legacy_bluetooth(self):
        for permission in ('BLUETOOTH', 'BLUETOOTH_ADMIN', 'BLUETOOTH_SCAN', 'BLUETOOTH_CONNECT', 'BLUETOOTH_ADVERTISE'):
            with self.subTest(permission=permission), self.assertRaises(ValueError):
                validate_manifest(manifest(['android.permission.' + permission]))

    def test_rejects_location_and_body_sensor_permissions(self):
        for permission in ('ACCESS_FINE_LOCATION', 'ACCESS_COARSE_LOCATION', 'ACCESS_BACKGROUND_LOCATION', 'BODY_SENSORS', 'BODY_SENSORS_BACKGROUND'):
            with self.subTest(permission=permission), self.assertRaises(ValueError):
                validate_manifest(manifest(['android.permission.' + permission]))

    def test_rejects_extra_health_reads_and_writes(self):
        for permission in ('READ_SLEEP', 'READ_BODY_FAT', 'WRITE_STEPS', 'READ_HEALTH_DATA_IN_BACKGROUND'):
            with self.subTest(permission=permission), self.assertRaises(ValueError):
                validate_manifest(manifest(['android.permission.health.' + permission]))

    def test_rejects_missing_read_permission(self):
        with self.assertRaises(ValueError):
            validate_manifest(manifest(omit=['android.permission.health.READ_DISTANCE']))

    def test_rejects_advertising_identifier_and_adservices(self):
        for permission in ('com.google.android.gms.permission.AD_ID', 'android.permission.ACCESS_ADSERVICES_ATTRIBUTION', 'android.permission.ACCESS_ADSERVICES_AD_ID'):
            with self.subTest(permission=permission), self.assertRaises(ValueError):
                validate_manifest(manifest([permission]))

    def test_sdk23_permission_form_cannot_bypass_scope(self):
        with self.assertRaises(ValueError):
            validate_manifest(manifest(['android.permission.BLUETOOTH_CONNECT'], tag='uses-permission-sdk-23'))

    def test_rejects_wrong_application(self):
        with self.assertRaises(ValueError):
            validate_manifest(manifest().replace(b'com.bilhealth.bodyintelligencelog', b'com.other.app'))


if __name__ == '__main__':
    unittest.main()
