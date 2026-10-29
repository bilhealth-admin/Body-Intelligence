"""Exercise the exact CLI whose output supplies the emulator action's argv."""
from pathlib import Path
import shlex
import subprocess
import sys
import unittest


ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / 'tool/release/android_emulator_launch_options.py'


class AndroidEmulatorLaunchOptionsTest(unittest.TestCase):
    def options(self, api):
        result = subprocess.run([sys.executable, str(SCRIPT), '--api-level', str(api)],
                                capture_output=True, text=True, check=False, timeout=10)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(len(result.stdout.splitlines()), 1)
        self.assertTrue(result.stdout.startswith('options='))
        return shlex.split(result.stdout.strip().removeprefix('options='))

    def test_api36_uses_current_software_renderer_without_changing_other_options(self):
        self.assertEqual(self.options(36), [
            '-no-window', '-gpu', 'software', '-no-snapshot', '-noaudio', '-no-boot-anim'])

    def test_five_successful_api_configurations_keep_the_exact_previous_argv(self):
        previous = ['-no-window', '-gpu', 'swiftshader_indirect',
                    '-no-snapshot', '-noaudio', '-no-boot-anim']
        for api in (26, 29, 33, 34, 35):
            with self.subTest(api=api):
                self.assertEqual(self.options(api), previous)

    def test_unsupported_api_or_missing_selection_cannot_emit_launch_arguments(self):
        for arguments in ([], ['--api-level', '37'], ['--api-level', '36;echo injected']):
            result = subprocess.run([sys.executable, str(SCRIPT), *arguments],
                                    capture_output=True, text=True, check=False, timeout=10)
            with self.subTest(arguments=arguments):
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(result.stdout, '')

    def test_workflow_consumes_real_cli_output_instead_of_the_action_deprecated_default(self):
        source = (ROOT / '.github/workflows/bil_android_isolated_emulator_smoke.yml').read_text()
        self.assertIn('id: emulator-options', source)
        self.assertIn('python3 tool/release/android_emulator_launch_options.py', source)
        self.assertIn('--api-level "$BIL_ANDROID_API" >> "$GITHUB_OUTPUT"', source)
        self.assertIn('emulator-options: ${{ steps.emulator-options.outputs.options }}', source)


if __name__ == '__main__':
    unittest.main()
