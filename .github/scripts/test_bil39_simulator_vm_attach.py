import json
import unittest
from pathlib import Path
import subprocess
import tempfile
import time
import io
import os
from unittest.mock import patch

import bil39_simulator_vm_attach as attach
from bil39_simulator_vm_attach import BUNDLE, launch_pid, vm_url_from_log


class ExactSimulatorVmTests(unittest.TestCase):
    def test_queued_simulator_launch_can_finish_after_legacy_60s_within_180s_bootstrap(self):
        # Model the observed OS queue: no PID is available at60s, but the owned
        # simctl command completes at90s. It must execute once, not be retried.
        class QueuedLaunch:
            returncode = None

            def __init__(self):
                self.waits = []
                self.kills = 0

            def wait(self, timeout):
                self.waits.append(timeout)
                if self.kills:
                    self.returncode = -9
                    return self.returncode
                if timeout < 90:
                    raise subprocess.TimeoutExpired('synthetic-queued-simctl', timeout)
                self.output.write((BUNDLE + ': 37093\n').encode())
                self.output.flush()
                self.returncode = 0
                return 0

            def kill(self):
                self.kills += 1

        queued = QueuedLaunch()

        def popen(command, **kwargs):
            queued.output = kwargs['stdout']
            return queued

        with tempfile.TemporaryDirectory() as folder, \
                patch.object(attach.subprocess, 'Popen', side_effect=popen) as start:
            raw = attach.launch_to_file(['synthetic-queued-simctl'], Path(folder) / 'launch.log')
        self.assertEqual(launch_pid(raw), 37093)
        self.assertEqual(queued.waits, [180])
        self.assertEqual(queued.kills, 0)
        start.assert_called_once()

    def test_real_launch_timeout_preserves_a_failure_receipt_and_kills_the_owned_child(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            receipt = root / 'launch-result.json'
            with self.assertRaises(subprocess.TimeoutExpired):
                attach.launch_to_file(
                    [attach.sys.executable, '-E', '-c', 'import time;time.sleep(10)'],
                    root / 'launch.log', timeout=.1, receipt=receipt,
                )
            result = json.loads(receipt.read_text())
        self.assertEqual(result['reason'], 'launch_timeout')
        self.assertTrue(result['timed_out'])
        self.assertTrue(result['cleanup_attempted'])
        self.assertIsInstance(result['raw_returncode'], int)
        self.assertNotEqual(result['raw_returncode'], 0)
        self.assertEqual(result['timeout_seconds'], .1)
        self.assertGreaterEqual(result['elapsed_seconds'], .09)
        self.assertEqual(result['retry_count'], 0)
        self.assertFalse(result['app_startup_verified'])

    def test_real_nonzero_launch_is_not_hidden_by_the_bootstrap_allowance(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            receipt = root / 'launch-result.json'
            with self.assertRaises(subprocess.CalledProcessError):
                attach.launch_to_file(
                    [attach.sys.executable, '-E', '-c', 'raise SystemExit(7)'],
                    root / 'launch.log', receipt=receipt,
                )
            result = json.loads(receipt.read_text())
        self.assertEqual(result['reason'], 'launch_nonzero_exit')
        self.assertEqual(result['raw_returncode'], 7)
        self.assertFalse(result['timed_out'])
        self.assertEqual(result['retry_count'], 0)
        self.assertFalse(result['app_startup_verified'])

    def test_collector_uses_a_local_pty_without_changing_selected_app_filter(self):
        command = attach.collector_command('AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE')
        self.assertEqual(command[:4], ['/usr/bin/script', '-q', '/dev/null', 'xcrun'])
        self.assertEqual(command[-4:], ['--style', 'json', '--predicate', 'process == "Runner"'])

    def test_collector_cleanup_signals_only_its_explicitly_owned_group(self):
        from unittest.mock import Mock
        collector = Mock(pid=424242, _bil_collector_group=True)
        with patch.object(attach.os, 'name', 'posix'), \
                patch.object(attach.os, 'killpg', create=True) as kill:
            attach.stop_collector(collector)
        kill.assert_called_once_with(424242, attach.signal.SIGTERM)
        collector.wait.assert_called_once_with(timeout=5)

    def test_unresponsive_owned_collector_group_is_killed_with_bounded_waits(self):
        from unittest.mock import Mock, call
        collector = Mock(pid=424242, _bil_collector_group=True)
        collector.wait.side_effect = [subprocess.TimeoutExpired('owned', 5), 0]
        with patch.object(attach.os, 'name', 'posix'), \
                patch.object(attach.signal, 'SIGKILL', 9, create=True), \
                patch.object(attach.os, 'killpg', create=True) as kill:
            attach.stop_collector(collector)
        self.assertEqual(kill.call_args_list, [call(424242, attach.signal.SIGTERM),
            call(424242, 9)])
        self.assertEqual(collector.wait.call_args_list, [call(timeout=5), call(timeout=5)])

    def test_unmarked_collector_cannot_signal_an_unowned_group(self):
        from unittest.mock import Mock
        collector = Mock(pid=424242, _bil_collector_group=False)
        collector.wait.side_effect = [subprocess.TimeoutExpired('owned', 5), 0]
        with patch.object(attach.os, 'name', 'posix'), \
                patch.object(attach.signal, 'SIGKILL', 9, create=True), \
                patch.object(attach.os, 'killpg', create=True) as kill:
            attach.stop_collector(collector)
        kill.assert_not_called()
        collector.terminate.assert_called_once_with()
        collector.kill.assert_called_once_with()

    @unittest.skipUnless(attach.sys.platform == 'darwin', 'Actual macOS PTY regression')
    def test_real_mac_pty_exposes_buffered_readiness_before_the_app_is_launched(self):
        # The old file-only collector waits for output that remains buffered
        # until the as-yet-unlaunched Runner emits events: a circular wait.
        source = "import sys,time;print('Filtering the log data using synthetic-only');time.sleep(10)"
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / 'ready.log'
            for tty in [False, True]:
                with path.open('wb') as output:
                    command = [attach.sys.executable, '-E', '-c', source]
                    if tty:
                        command = ['/usr/bin/script', '-q', '/dev/null', *command]
                    collector = subprocess.Popen(command, stdout=output,
                        stderr=subprocess.STDOUT, start_new_session=True)
                    collector._bil_collector_group = True
                    try:
                        if tty:
                            attach.wait_for_collector(path, collector, timeout=3)
                        else:
                            with self.assertRaises(TimeoutError):
                                attach.wait_for_collector(path, collector, timeout=.3)
                    finally:
                        attach.stop_collector(collector)

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
        for target in sorted(attach.TARGETS):
            with self.subTest(target=target):
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
                            target,
                            '--driver', str(driver), '--label', 'iphone-scope-drive',
                            '--log', str(root / 'artifacts/exact-scope.log'),
                            '--receipt', str(root / 'artifacts/exact-scope-result.json')]
                    with patch.object(attach.sys, 'argv', argv), patch.object(attach.sys, 'platform', 'darwin'), \
                            patch.object(attach.Path, 'cwd', return_value=root), \
                            patch.object(attach.subprocess, 'run', side_effect=run), \
                            patch.object(attach.subprocess, 'Popen') as collector, \
                            patch.object(attach, 'launch_to_file', return_value=BUNDLE + ': 37093\n') as launch, \
                            patch.object(attach, 'wait_for_collector'), \
                            patch.object(attach, 'discover_vm_from_capture',
                                return_value='http://127.0.0.1:52553/synthetic-auth=/') as discovery, \
                            patch.object(attach, 'run_bounded', return_value=0) as drive:
                        collector.return_value.poll.return_value = None
                        self.assertEqual(attach.main(), 0)
                    self.assertEqual(len(commands), 1)
                    self.assertEqual(commands[0][:3], ['xcrun', 'simctl', 'install'])
                    launch.assert_called_once()
                    self.assertEqual(launch.call_args.kwargs['timeout'], 180)
                    self.assertEqual(launch.call_args.kwargs['receipt'], output / 'exact-app-launch-result.json')
                    discovery.assert_called_once()
                    self.assertEqual(discovery.call_args.args[1], 37093)
                    collector.return_value.terminate.assert_called_once()
                    drive.assert_called_once()
                    self.assertEqual(drive.call_args.kwargs['label'], 'iphone-scope-drive')
                    self.assertEqual(drive.call_args.kwargs['log_path'], root / 'artifacts/exact-scope.log')
                    self.assertEqual(drive.call_args.kwargs['receipt_path'], root / 'artifacts/exact-scope-result.json')
                    self.assertEqual(drive.call_args.kwargs['timeout_seconds'], 180)
                    self.assertEqual(drive.call_args.kwargs['running_timeout_seconds'], 1200)
                    self.assertEqual(drive.call_args.kwargs['summary_grace_seconds'], 60)
                    self.assertIs(drive.call_args.kwargs['fail_on_launch_error'], True)
                    invoked = drive.call_args.args[0]
                    self.assertIn('--use-existing-app', invoked)
                    self.assertNotIn('build', invoked)
                    self.assertNotIn('--use-application-binary', invoked)
                    receipt = (output / 'attachment-receipt.json').read_text()
                    self.assertNotIn('synthetic-auth', receipt)
                    self.assertEqual(json.loads(receipt)['retry_count'], 0)
                    self.assertEqual(json.loads(receipt)['launch_timeout_seconds'], 180)
                    self.assertEqual(json.loads(receipt)['launch_receipt'], 'exact-app-launch-result.json')

    def test_vm_discovery_reads_the_already_captured_stream_without_commands(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / 'events.json'
            path.write_text('Filtering the log data using "process == Runner"\n[' +
                json.dumps(self.row(processID=999)) + ',' + json.dumps(self.row()) + ']')
            from unittest.mock import Mock
            collector = Mock()
            collector.poll.return_value = None
            with patch.object(attach.subprocess, 'run') as command:
                attach.wait_for_collector(path, collector)
                self.assertEqual(attach.discover_vm_from_capture(path, 37093, collector),
                                 'http://127.0.0.1:52553/synthetic-auth=/')
                command.assert_not_called()

    def test_closed_or_unready_collector_is_not_treated_as_success(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / 'events.json'
            path.write_text('')
            from unittest.mock import Mock
            collector = Mock()
            collector.poll.return_value = 1
            with self.assertRaises(RuntimeError):
                attach.wait_for_collector(path, collector)
            with self.assertRaises(RuntimeError):
                attach.discover_vm_from_capture(path, 37093, collector)

    def test_real_inherited_pipe_eof_trap_is_avoided_by_file_wait(self):
        child = 'import time;time.sleep(2.5)'
        parent = ('import subprocess,sys;subprocess.Popen([sys.executable,"-c",' +
                  repr(child) + ']);print(' + repr(BUNDLE + ': 37093') + ',flush=True)')
        with self.assertRaises(subprocess.TimeoutExpired):
            subprocess.run([attach.sys.executable, '-c', parent], capture_output=True, timeout=.25)
        with tempfile.TemporaryDirectory() as folder:
            started = time.monotonic()
            receipt = Path(folder) / 'launch-result.json'
            raw = attach.launch_to_file([attach.sys.executable, '-c', parent],
                                        Path(folder) / 'launch.log', timeout=2, receipt=receipt)
            self.assertEqual(launch_pid(raw), 37093)
            self.assertLess(time.monotonic() - started, 2)
            result = json.loads(receipt.read_text())
            self.assertEqual(result['reason'], 'launch_command_exit_zero')
            self.assertEqual(result['raw_returncode'], 0)
            self.assertFalse(result['timed_out'])
            self.assertFalse(result['app_startup_verified'])
            # Reap the synthetic grandchild naturally before Windows removes its file.
            time.sleep(2.6)

    def test_stream_decoder_preserves_partial_objects_and_multiple_records(self):
        payload = json.dumps(self.row())
        first, tail = attach.decode_events('[\n' + payload[:20])
        self.assertEqual(first, [])
        rows, tail = attach.decode_events(tail + payload[20:] + ',\n' + payload + '\n]')
        self.assertEqual(rows, [self.row(), self.row()])
        self.assertEqual(tail, '')

    def test_relay_forwards_only_selected_app_events_and_preserves_exit(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder).resolve()
            native, driver = root / 'events.json', root / 'driver.log'
            selected = self.row(eventMessage='flutter: 00:01 +0: actual synthetic test')
            native.write_text(json.dumps(self.row(processID=999)) + '\n' + json.dumps(selected))
            stream = io.BytesIO()
            class Stdout:
                buffer = stream
            with patch.object(attach.Path, 'cwd', return_value=root), \
                    patch.object(attach.subprocess, 'Popen') as process, \
                    patch.object(attach.sys, 'stdout', Stdout()), patch.object(attach.time, 'sleep'), \
                    patch.object(attach.time, 'monotonic', side_effect=iter(range(20))):
                process.return_value.poll.return_value = 7
                process.return_value.returncode = 7
                self.assertEqual(attach.relay_driver(['--native-log', str(native),
                    '--driver-log', str(driver), '--pid', '37093', '--', 'flutter', 'drive']), 7)
            self.assertEqual(stream.getvalue().decode(), selected['eventMessage'] + '\n')


if __name__ == '__main__':
    unittest.main()
