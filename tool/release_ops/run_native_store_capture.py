#!/usr/bin/env python3
"""Controller-only host driver. Run in macOS Actions, never in the app bundle."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import struct
import subprocess
import time
import urllib.request

SOURCE = '5da21a5660b26e59e9ead7b0927d4ed7cf2c3996'
BUNDLE = 'com.bilhealth.bodyintelligencelog'
TARGET = 'integration_test/store_workout_native_capture_test.dart'
MANIFEST = 'https://workouts.bilhealth.com/v2/manifest/wellness-workouts-v2-af6082ff28856f9154216067f16fe6a7147548c9a29f8e205b43bb81bc34efe8.json'


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, *args, **kwargs):
        return None


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--app', required=True)
    p.add_argument('--output', required=True)
    p.add_argument('--udid', required=True)
    p.add_argument('--device', choices=['iphone67', 'ipad129'], required=True)
    args = p.parse_args()
    app = Path(args.app).resolve()
    output = Path(args.output).resolve()
    output.mkdir(parents=True, exist_ok=True)
    controller = os.environ['GITHUB_SHA']
    run = os.environ['GITHUB_RUN_ID'] + '-' + os.environ['GITHUB_RUN_ATTEMPT']
    width, height = (1290, 2796) if args.device == 'iphone67' else (2064, 2752)
    defines = {
        'BIL_ENVIRONMENT': 'production', 'BIL_MOBILE_INTEGRITY_REQUIRED': 'false',
        'BIL_PAYMENTS_ENABLED': 'true', 'BIL_TERMS_URL': 'https://www.bilhealth.com/terms',
        'BIL_PRIVACY_URL': 'https://www.bilhealth.com/privacy',
        'BIL_MEAL_VISION_ENDPOINT': 'https://tgmanzhqulksykhslrzb.supabase.co/functions/v1/analyze-meal',
        'BIL_WELLNESS_MANIFEST_URL': MANIFEST, 'BIL_RECIPE_IMAGE_DELIVERY_ENABLED': 'true',
        'BIL_FACEBOOK_LOGIN_ENABLED': 'true', 'BIL_FACEBOOK_LOGIN_READY': 'true',
        'BIL_PUSH_ENABLED': 'true', 'BIL_PUSH_PROVIDER_READY': 'true',
        'BIL_ADS_ENABLED': 'false', 'BIL_AD_PROVIDER_READY': 'false',
        'BIL_ENABLE_CATALOG_TEST_ACCESS': 'false',
        'BIL_STORE_CAPTURE_CONTROLLER': controller, 'BIL_STORE_CAPTURE_RUN': run,
        'BIL_STORE_CAPTURE_DEVICE_CLASS': args.device,
        'BIL_STORE_CAPTURE_SYNTHETIC_GUEST': 'true',
    }
    command = ['flutter', 'test', '--no-pub', TARGET, '-d', args.udid,
               '--timeout', '15m'] + ['--dart-define=' + k + '=' + v for k, v in defines.items()]
    # Keep raw runtime logs outside public artifacts. No login credentials used.
    private_log = Path(os.environ['RUNNER_TEMP']) / ('bil-store-capture-' + args.device + '.log')
    evidence = {'status': 'DIAGNOSTIC_NOT_UPLOAD_READY', 'applicationSource': SOURCE,
                'controllerSource': controller, 'run': run, 'deviceClass': args.device,
                'entrypointSha256': hashlib.sha256((app / TARGET).read_bytes()).hexdigest(),
                'featureDefines': defines, 'nativeCapture': False,
                'physicalDeviceAcceptance': 'NOT_ESTABLISHED', 'storeMutation': False}
    process = None
    try:
        # Actions-only bounded public GET; no credential headers or redirects.
        opener = urllib.request.build_opener(NoRedirect())
        with opener.open(MANIFEST, timeout=20) as response:
            body = response.read(2 * 1024 * 1024 + 1)
        if len(body) > 2 * 1024 * 1024:
            raise RuntimeError('Public workout manifest exceeds capture evidence limit')
        json.loads(body)
        evidence['publicManifestEvidence'] = {
            'url': MANIFEST, 'bytes': len(body), 'sha256': hashlib.sha256(body).hexdigest(),
            'method': 'GET', 'authentication': False, 'redirects': False,
        }
        with private_log.open('wb') as log:
            process = subprocess.Popen(command, cwd=app, stdout=log, stderr=subprocess.STDOUT)
            deadline = time.monotonic() + 25 * 60
            control = None
            ready = None
            while time.monotonic() < deadline:
                if process.poll() is not None:
                    raise RuntimeError('Native harness exited before capture readiness')
                found = subprocess.run(['xcrun', 'simctl', 'get_app_container', args.udid,
                                        BUNDLE, 'data'], capture_output=True, text=True)
                if found.returncode == 0:
                    control = Path(found.stdout.strip()) / 'Documents/bil-store-capture-control'
                    ready_file = control / 'ready.json'
                    if ready_file.is_file():
                        if ready_file.stat().st_size > 65536:
                            raise RuntimeError('Unexpected ready manifest size')
                        ready = json.loads(ready_file.read_text())
                        break
                time.sleep(1)
            if ready is None or control is None:
                raise RuntimeError('Timed out waiting for actual native workout readiness')
            for key, expected in [('run', run), ('applicationSource', SOURCE),
                                  ('controllerSource', controller), ('deviceClass', args.device),
                                  ('route', '/wellness/workouts'),
                                  ('title', 'Workout Videos & Routines'),
                                  ('status', 'READY_FOR_EXTERNAL_NATIVE_SIMCTL_CAPTURE'),
                                  ('physicalWidth', width), ('physicalHeight', height),
                                  ('entitlementOverride', False), ('paidAccessClaimed', False),
                                  ('authenticated', False)]:
                if ready.get(key) != expected:
                    raise RuntimeError('Capture readiness identity/state mismatch: ' + key)
            if process.poll() is not None:
                raise RuntimeError('Native harness no longer alive at capture')
            png = output / ('workouts-' + args.device + '-native.png')
            subprocess.run(['xcrun', 'simctl', 'io', args.udid, 'screenshot',
                            '--type=png', str(png)], check=True, capture_output=True)
            data = png.read_bytes()
            if len(data) < 32768 or data[:8] != b'\x89PNG\r\n\x1a\n' or data[12:16] != b'IHDR':
                raise RuntimeError('Invalid or unexpectedly small native screenshot')
            if struct.unpack('>II', data[16:24]) != (width, height):
                raise RuntimeError('Native screenshot dimensions differ from selected model')
            digest = hashlib.sha256(data).hexdigest()
            acknowledgement = {'run': run, 'applicationSource': SOURCE, 'nativePngSha256': digest}
            temporary = control / 'ack.json.tmp'
            temporary.write_text(json.dumps(acknowledgement))
            temporary.replace(control / 'ack.json')
            code = process.wait(timeout=150)
            evidence.update({'harnessExitCode': code, 'ready': ready,
                             'nativeCapture': True, 'nativePngSha256': digest,
                             'nativePngBytes': len(data), 'nativeWidth': width, 'nativeHeight': height,
                             'captureTransport': 'XCRUN_SIMCTL_IO_SCREENSHOT',
                             'pngColorType': data[25],
                             'storeUploadFormatReview': 'REQUIRED_SEPARATELY_NO_EXPORT_PERFORMED',
                             'privateRuntimeLogSha256': hashlib.sha256(private_log.read_bytes()).hexdigest()})
            if code != 0:
                raise RuntimeError('Native harness did not pass after capture acknowledgement')
            evidence['status'] = 'NATIVE_CAPTURE_PASSED_VISUAL_AND_SOURCE_REVIEW_PENDING'
            print('Native workout capture passed:', args.device, digest)
    except Exception as error:
        # Error text here is controller-generated only; never dump app logs/data.
        evidence['failure'] = str(error)
        raise
    finally:
        if process is not None and process.poll() is None:
            process.terminate()
            try:
                process.wait(timeout=15)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait(timeout=15)
        (output / 'capture-result.json').write_text(json.dumps(evidence, indent=2) + '\n')


if __name__ == '__main__':
    main()
