import hashlib
import importlib.util
import io
import json
import queue
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import unittest
from unittest import mock


SCRIPT = Path(__file__).with_name("bil_native_bounded_command.py")
queue_type = queue.Queue


def load_supervisor():
    spec = importlib.util.spec_from_file_location("bil_bounded_fixture", SCRIPT)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def owned_process(*, returncode=None, owned_group=True):
    process = mock.Mock(pid=424242, returncode=returncode)
    process._bil_owned_process_group = owned_group
    process.stdout = io.BytesIO(b"")
    process.poll.side_effect = lambda: process.returncode

    def wait(timeout):
        if process.returncode is None:
            raise subprocess.TimeoutExpired("owned synthetic child", timeout)
        return process.returncode

    process.wait.side_effect = wait
    process.kill.side_effect = lambda: setattr(process, "returncode", -9)
    process.send_signal.side_effect = OSError("synthetic console unavailable")
    return process


def taskkill_helper(returncode=None):
    helper = owned_process(returncode=returncode, owned_group=False)
    helper.pid = 424243
    return helper


class BoundedNativeCommandTests(unittest.TestCase):
    def test_posix_cleanup_targets_only_the_owned_session_even_after_parent_exit(self):
        spec = importlib.util.spec_from_file_location("bil_bounded_fixture", SCRIPT)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        process = mock.Mock(pid=424242)
        process.wait.return_value = 0
        with mock.patch.object(module.os, "name", "posix"), \
             mock.patch.object(module.os, "killpg", create=True) as kill_group, \
             mock.patch.object(module.signal, "SIGKILL", 9, create=True):
            module._stop_owned_tree(process, .1)
        self.assertEqual(kill_group.call_args_list, [
            mock.call(424242, module.signal.SIGTERM), mock.call(424242, 9),
        ])

    def run_fixture(self, source, *, timeout=4, running=None, grace=.2, capture_progress=False):
        temporary = tempfile.TemporaryDirectory(prefix="bil-owned-command-")
        self.addCleanup(temporary.cleanup)
        root = Path(temporary.name)
        command = [
            sys.executable, str(SCRIPT), "--label", "synthetic-native-only",
            "--log", str(root / "raw.log"),
            "--receipt", str(root / "result.json"),
            "--timeout-seconds", str(timeout),
            "--summary-grace-seconds", str(grace),
            "--kill-grace-seconds", ".1",
        ]
        if running is not None:
            command.extend(["--running-timeout-seconds", str(running)])
        if capture_progress:
            command.append("--allow-capture-progress")
        result = subprocess.run(
            command + ["--", sys.executable, "-u", "-c", source],
            capture_output=True, timeout=15, check=False,
        )
        return result, json.loads((root / "result.json").read_bytes()), root

    def test_exit_zero_requires_actual_command_completion_and_keeps_raw_log(self):
        result, receipt, root = self.run_fixture("print('synthetic output')")
        self.assertEqual(result.returncode, 0)
        self.assertEqual(receipt["raw_returncode"], 0)
        self.assertFalse(receipt["timed_out"])
        self.assertEqual(receipt["output_sha256"], hashlib.sha256(
            (root / "raw.log").read_bytes()).hexdigest())
        self.assertIn(b"synthetic output", (root / "raw.log").read_bytes())

    def test_nonzero_exit_is_not_changed_to_success(self):
        result, receipt, _ = self.run_fixture("raise SystemExit(7)")
        self.assertEqual(result.returncode, 7)
        self.assertEqual(receipt["raw_returncode"], 7)
        self.assertEqual(receipt["reason"], "process_exit")

    def test_verified_advancing_capture_work_keeps_original_idle_and_absolute_bounds(self):
        source = ("import time; print('00:01 +41: All tests passed!'); "
                  "[(time.sleep(.15), print('BIL_NATIVE_CAPTURE_PROGRESS '+str(i)+'/4')) "
                  "for i in range(1,5)]")
        result, receipt, _ = self.run_fixture(source, running=2, grace=.3, capture_progress=True)
        self.assertEqual(result.returncode, 0)
        self.assertGreater(receipt['elapsed_seconds'], .3)
        self.assertEqual(receipt['capture_progress']['verified_count'], 4)
        self.assertEqual(receipt['capture_progress']['advancing_checkpoints'], 4)

    def test_capture_progress_is_opt_in_and_never_overrides_a_failed_test(self):
        source = ("import time; print('00:01 +40 -1: Some tests failed.'); "
                  "[(time.sleep(.15), print('BIL_NATIVE_CAPTURE_PROGRESS '+str(i)+'/4')) "
                  "for i in range(1,5)]")
        result, receipt, _ = self.run_fixture(source, running=2, grace=.3, capture_progress=True)
        self.assertEqual(result.returncode, 1)
        self.assertTrue(receipt['native_failure_summary_seen'])
        result, receipt, _ = self.run_fixture(source, running=2, grace=.3)
        self.assertEqual(result.returncode, 124)
        self.assertEqual(receipt['capture_progress']['verified_count'], 0)

    def test_actual_flutter_verbose_prefix_preserves_advancing_capture_checkpoints(self):
        source = ("import time; print('flutter: 00:01 +41: All tests passed!'); "
                  "[(time.sleep(.15), print(prefix+'BIL_NATIVE_CAPTURE_PROGRESS '+str(i)+'/4')) "
                  "for i,prefix in enumerate(['[        ] ', '[ +157 ms] ', '[-1 ms] ', ''],1)]")
        result, receipt, _ = self.run_fixture(source, running=2, grace=.3, capture_progress=True)
        self.assertEqual(result.returncode, 0)
        self.assertEqual(receipt['capture_progress']['advancing_checkpoints'], 4)

    def test_repeated_capture_count_cannot_keep_a_stalled_driver_alive(self):
        source = ("import time; print('00:01 +41: All tests passed!'); "
                  "[(print('BIL_NATIVE_CAPTURE_PROGRESS 1/4'), time.sleep(.1)) for _ in range(20)]")
        result, receipt, _ = self.run_fixture(source, running=3, grace=.3, capture_progress=True)
        self.assertEqual(result.returncode, 124)
        self.assertEqual(receipt['capture_progress']['advancing_checkpoints'], 1)
        self.assertEqual(receipt['reason'], 'result_delivery_timeout')

    def test_capture_progress_never_extends_the_absolute_native_budget(self):
        source = ("import time; print('00:01 +41: All tests passed!'); "
                  "[(print('BIL_NATIVE_CAPTURE_PROGRESS '+str(i)+'/100'), time.sleep(.1)) for i in range(1,50)]")
        result, receipt, _ = self.run_fixture(source, running=.45, grace=.3, capture_progress=True)
        self.assertEqual(result.returncode, 124)
        self.assertLess(receipt['elapsed_seconds'], 2)

    def test_invalid_capture_totals_and_changing_manifests_do_not_renew_grace(self):
        for markers in [('1/125', '2/125', '3/125'), ('1/4', '2/5', '3/6'),
                        ('3/4', '2/4', '1/4'), ('5/4', '6/4', '7/4')]:
            with self.subTest(markers=markers):
                source = ("import time; print('00:01 +41: All tests passed!'); "
                          f"[(time.sleep(.13), print('BIL_NATIVE_CAPTURE_PROGRESS '+s)) for s in {markers!r}]; time.sleep(10)")
                result, receipt, _ = self.run_fixture(source, running=3, grace=.25, capture_progress=True)
                self.assertEqual(result.returncode, 124)
                self.assertLessEqual(receipt['capture_progress']['advancing_checkpoints'], 1)

    def test_capture_markers_before_terminal_summary_do_not_extend_bootstrap(self):
        source = ("import time; [(print('BIL_NATIVE_CAPTURE_PROGRESS '+str(i)+'/100'), "
                  "time.sleep(.1)) for i in range(1,50)]")
        result, receipt, _ = self.run_fixture(source, timeout=.3, running=2, capture_progress=True)
        self.assertEqual(result.returncode, 124)
        self.assertEqual(receipt['reason'], 'bootstrap_timeout')

    def test_silent_bootstrap_has_a_real_os_deadline(self):
        result, receipt, _ = self.run_fixture("import time; time.sleep(60)", timeout=.3)
        self.assertEqual(result.returncode, 124)
        self.assertEqual(receipt["reason"], "bootstrap_timeout")
        self.assertTrue(receipt["timed_out"])

    def test_failed_native_summary_does_not_wait_for_job_deadline(self):
        result, receipt, root = self.run_fixture(
            "import time; print('I/flutter: 03:00 +11 -2: Some tests failed.'); time.sleep(60)",
            running=10,
        )
        self.assertEqual(result.returncode, 124)
        self.assertTrue(receipt["native_failure_summary_seen"])
        self.assertEqual(receipt["reason"], "result_delivery_timeout")
        self.assertIn(b"+11 -2", (root / "raw.log").read_bytes())

    def test_pass_summary_alone_never_produces_a_pass(self):
        result, receipt, _ = self.run_fixture(
            "import time; print('I/flutter: 00:01 +2: All tests passed.'); time.sleep(60)",
        )
        self.assertEqual(result.returncode, 124)
        self.assertEqual(receipt["reason"], "result_delivery_timeout")

    def test_failure_summary_cannot_be_hidden_by_a_zero_process_exit(self):
        result, receipt, _ = self.run_fixture("print('03:00 +11 -2: Some tests failed.')")
        self.assertEqual(result.returncode, 1)
        self.assertEqual(receipt["raw_returncode"], 0)
        self.assertEqual(receipt["reason"], "native_failure_summary_with_zero_process_exit")

    def test_running_native_case_has_its_own_deadline(self):
        result, receipt, _ = self.run_fixture(
            "import time; print('00:00 +0: native synthetic case'); time.sleep(60)",
            running=.3,
        )
        self.assertEqual(result.returncode, 124)
        self.assertEqual(receipt["reason"], "native_test_timeout")
        self.assertIsNotNone(receipt["first_test_after_seconds"])

    def test_loading_banner_does_not_claim_native_tests_started(self):
        result, receipt, _ = self.run_fixture(
            "import time; print('00:00 +0: loading synthetic test'); time.sleep(60)",
            timeout=.3, running=10,
        )
        self.assertEqual(result.returncode, 124)
        self.assertEqual(receipt["reason"], "bootstrap_timeout")
        self.assertIsNone(receipt["first_test_after_seconds"])

    def test_native_budget_starts_after_the_bootstrap_counter(self):
        result, receipt, _ = self.run_fixture(
            "import time; time.sleep(.1); print('00:00 +0: native synthetic case'); time.sleep(.5)",
            timeout=.4, running=2,
        )
        self.assertEqual(result.returncode, 0)
        self.assertGreater(receipt["elapsed_seconds"], .4)
        self.assertIsNotNone(receipt["first_test_after_seconds"])

    def test_windows_taskkill_timeout_falls_back_only_to_owned_group_and_handle(self):
        module, process = load_supervisor(), owned_process()
        helper = taskkill_helper()
        with mock.patch.object(module.subprocess, "Popen", return_value=helper) as taskkill, \
             mock.patch.object(module.signal, "CTRL_BREAK_EVENT", 1, create=True):
            result = module._stop_windows_owned_tree(process, .1)
        self.assertTrue(result["parent_reaped"])
        self.assertIsNone(result["descendants_reaped"])
        self.assertIn({"action": "taskkill_owned_tree", "type": "TimeoutExpired"}, result["errors"])
        self.assertEqual(taskkill.call_args.args[0], ["taskkill", "/PID", "424242", "/T", "/F"])
        self.assertEqual(helper.wait.call_args_list, [mock.call(timeout=1), mock.call(timeout=.1)])
        self.assertEqual(taskkill.call_args.kwargs["stdout"], subprocess.DEVNULL)
        helper.kill.assert_called_once_with()
        process.send_signal.assert_called_once_with(1)
        process.kill.assert_called_once_with()

    def test_windows_taskkill_failure_cannot_claim_a_reaped_tree(self):
        module, process = load_supervisor(), owned_process()
        with mock.patch.object(module.subprocess, "Popen", return_value=taskkill_helper(5)), \
             mock.patch.object(module.signal, "CTRL_BREAK_EVENT", 1, create=True):
            result = module._stop_windows_owned_tree(process, .1)
        self.assertFalse(result["tree_kill_succeeded"])
        self.assertTrue(result["parent_reaped"])
        self.assertIsNone(result["descendants_reaped"])
        process.kill.assert_called_once_with()

    def test_windows_group_fallback_requires_the_owned_creation_marker(self):
        module, process = load_supervisor(), owned_process(owned_group=False)
        with mock.patch.object(module.subprocess, "Popen", side_effect=OSError("synthetic missing helper")):
            result = module._stop_windows_owned_tree(process, .1)
        process.send_signal.assert_not_called()
        process.kill.assert_called_once_with()
        self.assertTrue(result["parent_reaped"])
        self.assertIsNone(result["descendants_reaped"])

    def test_windows_already_exited_parent_never_uses_a_new_pid_lookup(self):
        module, process = load_supervisor(), owned_process(returncode=7)
        with mock.patch.object(module.subprocess, "Popen") as taskkill:
            result = module._stop_windows_owned_tree(process, .1)
        taskkill.assert_not_called()
        process.send_signal.assert_not_called()
        process.kill.assert_not_called()
        self.assertEqual(result["parent_returncode"], 7)
        self.assertIsNone(result["descendants_reaped"])

    def test_windows_failed_fallbacks_are_bounded_and_recorded_not_raised(self):
        module, process = load_supervisor(), owned_process()
        process.kill.side_effect = OSError("synthetic handle failure")
        with mock.patch.object(module.subprocess, "Popen", return_value=taskkill_helper()), \
             mock.patch.object(module.signal, "CTRL_BREAK_EVENT", 1, create=True):
            result = module._stop_windows_owned_tree(process, .1)
        self.assertFalse(result["parent_reaped"])
        self.assertIsNone(result["descendants_reaped"])
        self.assertIn({"action": "kill_owned_parent_handle", "type": "OSError"}, result["errors"])
        self.assertEqual(process.wait.call_args_list, [mock.call(timeout=.1), mock.call(timeout=.1)])

    def test_windows_helper_kill_failure_has_no_implicit_unbounded_wait(self):
        module, process = load_supervisor(), owned_process()
        helper = taskkill_helper()
        helper.kill.side_effect = OSError("synthetic helper handle failure")
        with mock.patch.object(module.subprocess, "Popen", return_value=helper), \
             mock.patch.object(module.signal, "CTRL_BREAK_EVENT", 1, create=True):
            result = module._stop_windows_owned_tree(process, .1)
        self.assertFalse(result["taskkill_helper_reaped"])
        self.assertIn({"action": "kill_taskkill_helper_handle", "type": "OSError"}, result["errors"])
        self.assertIn({"action": "wait_taskkill_helper", "type": "TimeoutExpired"}, result["errors"])
        self.assertEqual(helper.wait.call_args_list, [mock.call(timeout=1), mock.call(timeout=.1)])
        self.assertTrue(result["parent_reaped"])

    def run_mocked_timeout(self, *, stop=None, fail_fallbacks=False, output_queue=None):
        module, process = load_supervisor(), owned_process()
        process.stdout = io.BytesIO(b"00:00 +0: synthetic native case\n")
        if fail_fallbacks:
            process.kill.side_effect = OSError("synthetic handle failure")
        helper = taskkill_helper()
        if fail_fallbacks:
            helper.kill.side_effect = OSError("synthetic helper handle failure")
        with tempfile.TemporaryDirectory(prefix="bil-receipt-fixture-") as directory:
            root = Path(directory)

            def windows_cleanup(child, grace):
                # The mock owns no real OS process; explicitly exercise Windows
                # cleanup even when this unit suite runs on a POSIX CI host.
                child._bil_owned_process_group = True
                return module._stop_windows_owned_tree(child, grace)

            def launch(command, **_options):
                return helper if command[0] == "taskkill" else process

            with mock.patch.object(module.subprocess, "Popen", side_effect=launch) as launch_process, \
                 mock.patch.object(module.queue, "Queue", side_effect=lambda: output_queue
                                   if output_queue is not None else queue_type()), \
                 mock.patch.object(module, "_stop_owned_tree", side_effect=stop or windows_cleanup) as cleanup, \
                 mock.patch.object(module.signal, "CTRL_BREAK_EVENT", 1, create=True):
                code = module.run_bounded(
                    ["owned-synthetic-command"], label="mocked-native-timeout",
                    log_path=root / "raw.log", receipt_path=root / "receipt.json",
                    timeout_seconds=1, running_timeout_seconds=.01,
                    kill_grace_seconds=.1,
                )
            receipt = json.loads((root / "receipt.json").read_bytes())
            self.assertEqual(receipt["output_sha256"], hashlib.sha256(
                (root / "raw.log").read_bytes()).hexdigest())
        taskkills = sum(call.args[0][0] == "taskkill" for call in launch_process.call_args_list)
        return code, receipt, cleanup.call_count, taskkills

    def test_receipt_is_not_prevented_by_output_after_all_kill_methods_fail(self):
        class ContinuingOutput(queue_type):
            def get_nowait(self):
                return b""

        code, receipt, _, _ = self.run_mocked_timeout(
            fail_fallbacks=True, output_queue=ContinuingOutput())
        self.assertEqual(code, 124)
        self.assertTrue(receipt["output_drain_limited"])
        self.assertFalse(receipt["output_complete"])

    def test_receipt_and_original_timeout_survive_taskkill_and_all_fallback_failures(self):
        code, receipt, cleanups, taskkills = self.run_mocked_timeout(fail_fallbacks=True)
        self.assertEqual(code, 124)
        self.assertEqual(receipt["effective_returncode"], 124)
        self.assertEqual(receipt["reason"], "native_test_timeout")
        self.assertTrue(receipt["timed_out"])
        self.assertFalse(receipt["cleanup"]["parent_reaped"])
        self.assertIsNone(receipt["cleanup"]["descendants_reaped"])
        self.assertEqual((cleanups, taskkills), (1, 1))

    def test_receipt_survives_unexpected_cleanup_exception_without_a_second_cleanup(self):
        code, receipt, cleanups, _ = self.run_mocked_timeout(
            stop=RuntimeError("synthetic cleanup defect"))
        self.assertEqual(code, 124)
        self.assertEqual(receipt["reason"], "native_test_timeout")
        self.assertEqual(cleanups, 1)
        self.assertEqual(receipt["cleanup"]["errors"], [
            {"action": "stop_owned_tree", "type": "RuntimeError"},
        ])

    def test_receipt_preserves_original_nonzero_exit_when_final_wait_fails(self):
        module, process = load_supervisor(), owned_process(returncode=7)
        process.wait.side_effect = OSError("synthetic wait failure")
        with tempfile.TemporaryDirectory(prefix="bil-exit-receipt-") as directory:
            root = Path(directory)
            with mock.patch.object(module.subprocess, "Popen", return_value=process):
                code = module.run_bounded(
                    ["owned-synthetic-command"], label="mocked-exit",
                    log_path=root / "raw.log", receipt_path=root / "receipt.json",
                    timeout_seconds=1,
                )
            receipt = json.loads((root / "receipt.json").read_bytes())
        self.assertEqual(code, 7)
        self.assertEqual(receipt["raw_returncode"], 7)
        self.assertEqual(receipt["effective_returncode"], 7)
        self.assertEqual(receipt["supervisor_error"], "OSError")


class StdoutBackpressureTests(unittest.TestCase):
    def run_without_stdout_reader(self, source, *, timeout=2, grace=.2):
        with tempfile.TemporaryDirectory(prefix="bil-backpressure-") as directory:
            root = Path(directory)
            process = subprocess.Popen([
                sys.executable, str(SCRIPT), "--label", "backpressure-fixture",
                "--log", str(root / "raw.log"), "--receipt", str(root / "receipt.json"),
                "--timeout-seconds", str(timeout), "--kill-grace-seconds", ".1",
                "--summary-grace-seconds", str(grace), "--",
                sys.executable, "-u", "-c", source,
            ], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            exited_without_reader = True
            try:
                process.wait(timeout=7)
            except subprocess.TimeoutExpired:
                exited_without_reader = False
            # Drain only after the bounded-exit assertion has been observed.
            # This also lets the old faulty supervisor clean up its own child
            # when the regression is deliberately run against that version.
            stdout, stderr = process.communicate(timeout=8)
            receipt = json.loads((root / "receipt.json").read_bytes())
            raw = (root / "raw.log").read_bytes()
        self.assertTrue(exited_without_reader, "stdout backpressure delayed the OS deadline or process exit")
        self.assertEqual(receipt["output_bytes"], len(raw))
        self.assertEqual(receipt["output_sha256"], hashlib.sha256(raw).hexdigest())
        self.assertTrue(receipt["output_complete"])
        self.assertGreater(receipt["console_forwarding"]["omitted_display_bytes"], 0)
        self.assertEqual(receipt["console_forwarding"]["mode"], "nonblocking_no_queue")
        self.assertIsNone(receipt["console_forwarding"]["unavailable_reason"])
        self.assertEqual(stderr, b"")
        return process.returncode, receipt, raw, stdout

    def test_unread_stdout_cannot_block_timeout_and_raw_output_is_complete(self):
        code, receipt, raw, _ = self.run_without_stdout_reader(
            "import sys,time; sys.stdout.buffer.write(b'x'*1048576+b'\\n'); sys.stdout.flush(); time.sleep(30)")
        self.assertEqual(code, 124)
        self.assertEqual(receipt["reason"], "bootstrap_timeout")
        self.assertLess(receipt["elapsed_seconds"], 6)
        self.assertEqual(raw, b"x" * 1048576 + b"\n")

    def test_hidden_console_failure_summary_still_fails_zero_exit(self):
        code, receipt, raw, _ = self.run_without_stdout_reader(
            "import sys; sys.stdout.buffer.write(b'x'*1048576+b'\\n00:01 +1 -1: Some tests failed.\\n'); sys.stdout.flush()")
        self.assertEqual(code, 1)
        self.assertEqual(receipt["raw_returncode"], 0)
        self.assertTrue(receipt["native_failure_summary_seen"])
        self.assertIn(b"Some tests failed.", raw)

    def test_hidden_console_pass_summary_does_not_pass_a_hung_process(self):
        code, receipt, raw, _ = self.run_without_stdout_reader(
            "import sys,time; sys.stdout.buffer.write(b'x'*1048576+b'\\n00:01 +2: All tests passed.\\n'); sys.stdout.flush(); time.sleep(30)")
        self.assertEqual(code, 124)
        self.assertEqual(receipt["reason"], "result_delivery_timeout")
        self.assertIn(b"All tests passed.", raw)

    def test_native_failure_split_at_chunk_boundary_cannot_be_hidden(self):
        code, receipt, raw, _ = self.run_without_stdout_reader(
            "import sys; sys.stdout.buffer.write(b'x'*65515+b' 00:01 +1 -1: Some tests failed.\\n'); sys.stdout.flush()")
        self.assertEqual(code, 1)
        self.assertTrue(receipt["native_failure_summary_seen"])
        self.assertEqual(raw, b"x" * 65515 + b" 00:01 +1 -1: Some tests failed.\n")

    def test_large_output_uses_bounded_chunks_and_queue_without_losing_raw_bytes(self):
        code, receipt, raw, _ = self.run_without_stdout_reader(
            "import sys; sys.stdout.buffer.write(b'x'*8388608+b'\\n'); sys.stdout.flush()", timeout=10)
        self.assertEqual(code, 0)
        self.assertEqual(raw, b"x" * 8388608 + b"\n")
        self.assertEqual(receipt["reader_chunk_max_bytes"], 65536)
        self.assertEqual(receipt["reader_queue_capacity_chunks"], 64)
        self.assertGreater(receipt["reader_queue_peak_chunks"], 0)
        self.assertLessEqual(receipt["reader_queue_peak_chunks"], 64)


if __name__ == "__main__":
    unittest.main()
