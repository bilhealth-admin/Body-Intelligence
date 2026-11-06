"""Fail closed on permissions excluded from the Android33 reviewer build."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import xml.etree.ElementTree as ET

ANDROID = '{http://schemas.android.com/apk/res/android}'
HEALTH_READS = frozenset({
    'android.permission.health.READ_STEPS',
    'android.permission.health.READ_DISTANCE',
    'android.permission.health.READ_ACTIVE_CALORIES_BURNED',
})
FORBIDDEN = frozenset({
    'android.permission.BLUETOOTH',
    'android.permission.BLUETOOTH_ADMIN',
    'android.permission.BLUETOOTH_SCAN',
    'android.permission.BLUETOOTH_CONNECT',
    'android.permission.BLUETOOTH_ADVERTISE',
    'android.permission.ACCESS_FINE_LOCATION',
    'android.permission.ACCESS_COARSE_LOCATION',
    'android.permission.ACCESS_BACKGROUND_LOCATION',
    'android.permission.BODY_SENSORS',
    'android.permission.BODY_SENSORS_BACKGROUND',
    'com.google.android.gms.permission.AD_ID',
})


def validate_manifest(raw: bytes) -> dict:
    root = ET.fromstring(raw)
    if root.tag != 'manifest' or root.get('package') != 'com.bilhealth.bodyintelligencelog':
        raise ValueError('Unexpected Android application manifest identity')
    permissions = {
        child.get(ANDROID + 'name', '')
        for child in root
        if child.tag in ('uses-permission', 'uses-permission-sdk-23')
    }
    health = {name for name in permissions if name.startswith('android.permission.health.')}
    if health != HEALTH_READS:
        raise ValueError('Health Connect permissions must be the exact three approved read types')
    forbidden = permissions.intersection(FORBIDDEN)
    forbidden.update(name for name in permissions if name.startswith('android.permission.ACCESS_ADSERVICES'))
    if forbidden:
        raise ValueError('Excluded reviewer permissions: ' + ', '.join(sorted(forbidden)))
    return {
        'schema': 'BIL_ANDROID33_PERMISSION_SCOPE_V1',
        'status': 'PASS',
        'package': root.get('package'),
        'manifest_sha256': hashlib.sha256(raw).hexdigest(),
        'health_reads': sorted(health),
        'health_writes': [],
        'bluetooth_permissions': [],
        'location_permissions': [],
        'advertising_identifier_permissions': [],
        'scope': 'Merged artifact permission evidence only; not a native reviewer or health-reading test',
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--manifest', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    result = validate_manifest(args.manifest.read_bytes())
    args.output.write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
    print('ANDROID33_FINAL_REVIEW_PERMISSION_SCOPE=PASS')


if __name__ == '__main__':
    main()
