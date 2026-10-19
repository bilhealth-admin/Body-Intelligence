"""Exercise actual Android intent delivery and visible destinations on a QA app."""
import argparse
import json
from pathlib import Path
import subprocess
import time
import xml.etree.ElementTree as ET


APP = 'com.bilhealth.bodyintelligencelog'


def adb(*args):
    return subprocess.check_output(['adb', *args], text=True, stderr=subprocess.STDOUT, timeout=25)


def visible(xml, expected):
    nodes = ET.fromstring(xml).iter('node')
    values = [node.attrib.get('text', '') + ' ' + node.attrib.get('content-desc', '') for node in nodes]
    return all(any(marker in value for value in values) for marker in expected)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    cases = [
        ('cold-login', 'bil://login', True, ['Email address', 'Store reviewer access']),
        # Android intentionally names this page "Health Connect"; iOS uses
        # "Apps & Devices". Both platforms show the shared Health Hub section.
        ('warm-health', 'bil://connected-health', False, ['Health Connect', 'Health Hub']),
        ('warm-login-path', 'bil:/login', False, ['Email address', 'Store reviewer access']),
        ('removed-admin-rejected', 'bil://admin/ai-coach', False, ['Email address', 'Store reviewer access']),
        ('removed-review-rejected', 'bil://community/moderation', False, ['Email address', 'Store reviewer access']),
        ('removed-food-review-rejected', 'bil://community/food-review', False, ['Email address', 'Store reviewer access']),
    ]
    results = []
    for name, url, cold, markers in cases:
        if cold:
            adb('shell', 'am', 'force-stop', APP)
        receipt = adb('shell', 'am', 'start', '-W', '-a', 'android.intent.action.VIEW', '-p', APP, '-d', url)
        (args.output / f'{name}-intent.txt').write_text(receipt)
        if 'Error:' in receipt or 'Status: ok' not in receipt:
            raise RuntimeError(f'{name}: OS did not deliver intent successfully')
        deadline = time.monotonic() + 45
        xml = ''
        while time.monotonic() < deadline:
            adb('shell', 'uiautomator', 'dump', '/sdcard/bil-deep-link-qa.xml')
            xml = adb('shell', 'cat', '/sdcard/bil-deep-link-qa.xml')
            if visible(xml, markers):
                break
            time.sleep(1)
        (args.output / f'{name}-ui.xml').write_text(xml)
        with (args.output / f'{name}.png').open('wb') as image:
            subprocess.run(['adb', 'exec-out', 'screencap', '-p'], stdout=image, check=True, timeout=20)
        if not visible(xml, markers):
            raise RuntimeError(f'{name}: delivered intent did not reach expected visible destination')
        results.append({'case': name, 'uri': url, 'visible_destination_verified': True})
        (args.output / 'results.json').write_text(json.dumps({'status': 'IN_PROGRESS', 'cases': results}, indent=2))
    (args.output / 'results.json').write_text(json.dumps({'status': 'PASS', 'cases': results,
        'scope': 'Real custom-scheme Android OS delivery; verified HTTPS domain association is a separate gate'}, indent=2))


if __name__ == '__main__':
    main()
