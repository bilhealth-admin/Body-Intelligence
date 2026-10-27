import json
import unittest
from pathlib import Path
import subprocess
import tempfile
from unittest.mock import patch

import bil39_simulator_vm_attach as attach
from bil39_simulator_vm_attach import BUNDLE, launch_pid, vm_url_from_log


class ExactSimulatorVmTests(unittest.TestCase):
    def row(self, url='http://127.0.0.1:52553/synthetic-auth=/', **changes):
        return {'processID': 37093, 'processImagePath': '/qa/Runner.app/Runner',
                'eventMessage': 'flutter: The Dart VM service is listening on ' + url, **changes}

    def parse(self, *rows):
        return vm_url_from_log(json.dumps(rows), 37093)

    def test_actual_unified_log_shape_and_exact_pid(self):
        self.assertEqual(self.parse(self.row()), 'http://127.0.0.1:52553/synthetic-auth=/')
        self.assertIsNone(self.parse(self.row(processID=999)))
        self.assertIsNone(self.parse(self.row(processImagePath='/other/Other.app/Other')))
        self.assertIsNone(self.parse(self.row(eventMessage='unrelated http://127.0.0.1:52553/a=/')))
        self.assertIsNone(self.parse())

    def test_no_network_destination_injection(self):
        for url in ['http://example.org:52553/a=/', 'https://127.0.0.1:52553/a=/',
                    'http://127.0.0.1:80/a=/', 'http://127.0.0.1:52553/a=/?x=1',
                    'http://x@127.0.0.1:52553/a=/', 'http://127.0.0.1:52553/../../',
                    'http://127.0.0.1:52553/a=/#fragment']:
            with self.subTest(url=url), self.assertRaises(ValueError):
                self.parse(self.row(url))

    def test_ambiguous_vm_refused_and_duplicates_deduplicated(self):
        self.assertIsNotNone(self.parse(self.row(), self.row()))
        with self.assertRaises(ValueError):
            self.parse(self.row(), self.row('http://127.0.0.1:52554/b=/'))

    def test_real_launch_shape_and_other_apps_refused(self):
        self.assertEqual(launch_pid(BUNDLE + ': 37093\n'), 37093)
        for raw in ['other: 37093', BUNDLE + ': 0', BUNDLE + ': 12\nother: 13']:
            with self.subTest(raw=raw), self.assertRaises(ValueError):
                launch_pid(raw)

    def test_actual_cli_orchestration_attaches_once_without_rebuilding(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder).resolve()
            app = root / 'build/ios/Debug-iphonesimulator/Runner.app'
            app.mkdir(parents=True)
            driver = root / 'test_driver/synthetic.dart'
            driver.parent.mkdir()
            driver.write_text('// synthetic')
            output = root / 'artifacts/probe'
            commands = []

            def run(command, **kwargs):
                commands.append(command)
                value = BUNDLE + ': 37093\n' if 'launch' in command else (
                    json.dumps([self.row()]) if 'show' in command else '')
                return subprocess.CompletedProcess(command, 0, value, '')

            argv = ['probe', '--qa-simulator-only', '--device',
                    'AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE', '--app', str(app),
                    '--output', str(output), '--target',
                    'integration_test/system_crypto_bridge_integration_test.dart',
                    '--driver', str(driver)]
            with patch.object(attach.sys, 'argv', argv), patch.object(attach.sys, 'platform', 'darwin'), \
                    patch.object(attach.Path, 'cwd', return_value=root), \
                    patch.object(attach.subprocess, 'run', side_effect=run), \
                    patch.object(attach, 'run_bounded', return_value=0) as drive:
                self.assertEqual(attach.main(), 0)
            self.assertEqual(len(commands), 3)
            self.assertEqual(commands[0][:3], ['xcrun', 'simctl', 'install'])
            self.assertEqual(commands[1][:3], ['xcrun', 'simctl', 'launch'])
            self.assertIn('log', commands[2])
            drive.assert_called_once()
            invoked = drive.call_args.args[0]
            self.assertIn('--use-existing-app', invoked)
            self.assertNotIn('build', invoked)
            self.assertNotIn('--use-application-binary', invoked)
            receipt = (output / 'attachment-receipt.json').read_text()
            self.assertNotIn('synthetic-auth', receipt)
            self.assertEqual(json.loads(receipt)['retry_count'], 0)


if __name__ == '__main__':
    unittest.main()
