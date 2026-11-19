from pathlib import Path
import unittest
from unittest.mock import Mock
import retry_android_maven429_build as h

URL = "https://repo.maven.apache.org/maven2/org/jetbrains/kotlin/kotlin-stdlib/2.2.0/kotlin-stdlib-2.2.0.pom"
FAIL = h.PLUGIN_FAILURE + "\nCould not GET '" + URL + "'. Received status code 429 from server: Too Many Requests\n[!] " + h.DOWNLOAD_FAILURE
COMMAND = ['flutter', 'build', 'apk', '--debug', '--no-pub', '--build-number', '33', '--dart-define=BIL_USE_SUPABASE=false']

class MavenRetryTest(unittest.TestCase):
    def test_exact_observed_plugin_429_with_flutter_marker_is_retryable(self):
        self.assertTrue(h.is_retryable(FAIL))

    def test_other_hosts_statuses_missing_stage_and_mixed_compile_errors_do_not_retry(self):
        for text in [FAIL.replace('repo.maven.apache.org', 'unknown.invalid'), FAIL.replace('429', '403'),
                     FAIL.replace(h.PLUGIN_FAILURE, ''), FAIL.replace(h.DOWNLOAD_FAILURE, ''),
                     FAIL+'\nlib/main.dart:12: error: invalid type', FAIL+'\nCompilation failed',
                     FAIL+"\nExecution failed for task ':app:compileDebugKotlin'."]:
            with self.subTest(text=text): self.assertFalse(h.is_retryable(text))

    def test_old_internal_429_cannot_make_final_unknown_failure_retryable(self):
        self.assertFalse(h.is_retryable(FAIL+'\nRetrying Gradle Build: #1, wait time: 100ms\nUnexpected final failure'))
        self.assertTrue(h.is_retryable(FAIL+'\nRetrying Gradle Build: #1, wait time: 100ms\n'+FAIL))

    def test_mixed_http_error_is_not_retried(self):
        self.assertFalse(h.is_retryable(FAIL+"\nCould not GET '"+URL+"'. Received status code 404 from server: Not Found"))

    def test_success_has_no_sleep_or_retry(self):
        run=Mock(return_value=(0,False));sleep=Mock()
        self.assertEqual(h.main(['--',*COMMAND],runner=run,sleeper=sleep),0)
        run.assert_called_once_with(COMMAND);sleep.assert_not_called()

    def test_delayed_recovery_preserves_exact_arguments(self):
        run=Mock(side_effect=[(1,True),(0,False)]);sleep=Mock()
        self.assertEqual(h.main(COMMAND,runner=run,sleeper=sleep),0)
        self.assertEqual([x.args[0] for x in run.call_args_list],[COMMAND,COMMAND])
        sleep.assert_called_once_with(20)

    def test_second_transport_failure_exits_nonzero_with_no_third_invocation(self):
        run=Mock(side_effect=[(1,True),(7,True)]);sleep=Mock()
        self.assertEqual(h.main(COMMAND,runner=run,sleeper=sleep),7)
        self.assertEqual(run.call_count,2);sleep.assert_called_once_with(20)

    def test_nontransport_and_cancellation_failure_propagate_without_retry(self):
        for status in [1,2,127,-15]:
            run=Mock(return_value=(status,False));sleep=Mock()
            self.assertNotEqual(h.main(COMMAND,runner=run,sleeper=sleep),0)
            self.assertEqual(run.call_count,1);sleep.assert_not_called()

    def test_signal_or_cancellation_after_transport_marker_never_restarts(self):
        for status in [-15,-2,130,143]:
            run=Mock(side_effect=[(status,True),(0,False)]);sleep=Mock()
            self.assertEqual(h.main(COMMAND,runner=run,sleeper=sleep),status if status>0 else 128-status)
            self.assertEqual(run.call_count,1);sleep.assert_not_called()

    def test_release_or_other_command_never_starts(self):
        for command in [['flutter','build','apk','--release'],['echo','hi'],[*COMMAND,'--profile']]:
            run=Mock();self.assertEqual(h.main(command,runner=run),64);run.assert_not_called()

class WorkflowBindingTest(unittest.TestCase):
    def test_offline_build_keeps_existing_payload_and_does_not_retry_tests(self):
        workflow=(Path(__file__).parents[2]/'.github/workflows/bil_android_isolated_emulator_smoke.yml').read_text()
        self.assertEqual(workflow.count('retry_android_maven429_build.py --'),1)
        for flag in ['BIL_USE_SUPABASE=false','BIL_PAYMENTS_ENABLED=false','BIL_ADS_ENABLED=false','BIL_PUSH_ENABLED=false']:
            self.assertIn('--dart-define='+flag,workflow)
        self.assertIn('Execute all eight real Android integrity lease unit tests once',workflow)
        self.assertIn('      fail-fast: false',workflow)

if __name__=='__main__': unittest.main()
