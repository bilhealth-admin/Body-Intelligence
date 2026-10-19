"""Audit launcher process behavior; never replace an official detector test."""
from pathlib import Path
import os
import shutil
import subprocess
import tempfile
import unittest


class LintLauncherExitTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        executable = 'java.exe' if os.name == 'nt' else 'java'
        java_home = os.environ.get('JAVA_HOME')
        cls.java = str(Path(java_home, 'bin', executable)) if java_home else shutil.which(executable)
        if not cls.java:
            raise RuntimeError('A JDK is required to validate the Lint audit launcher')
        cls.javac = str(Path(cls.java).with_name('javac.exe' if os.name == 'nt' else 'javac'))
        cls.temporary = tempfile.TemporaryDirectory(prefix='bil-lint-exit-')
        cls.output = Path(cls.temporary.name)
        stub = cls.output / 'com/android/tools/lint/Main.java'
        stub.parent.mkdir(parents=True)
        stub.write_text('''package com.android.tools.lint;
public final class Main {
  public int run(String[] args) {
    if (args[0].equals("crash")) throw new IllegalStateException("synthetic-detector-crash");
    Thread thread = new Thread(() -> { try { Thread.sleep(60000); }
      catch (InterruptedException ignored) {} });
    thread.setDaemon(false);
    thread.start();
    return Integer.parseInt(args[0]);
  }
}''', encoding='utf-8')
        launcher = Path(__file__).parent / 'lint_compat/BilBoundedLintMain.java'
        subprocess.run([cls.javac, '-encoding', 'UTF-8', '-d', str(cls.output),
                        str(stub), str(launcher)], check=True, capture_output=True)

    @classmethod
    def tearDownClass(cls):
        cls.temporary.cleanup()

    def launch(self, argument):
        return subprocess.run([self.java, '-cp', str(self.output),
                               'BilBoundedLintMain', argument],
                              capture_output=True, text=True, timeout=8)

    def test_success_exits_despite_a_non_daemon_runtime_thread(self):
        self.assertEqual(self.launch('0').returncode, 0)

    def test_real_lint_failure_code_is_preserved(self):
        self.assertEqual(self.launch('7').returncode, 7)

    def test_uncaught_detector_failure_is_nonzero_and_keeps_raw_diagnostic(self):
        result = self.launch('crash')
        self.assertEqual(result.returncode, 2)
        self.assertIn('synthetic-detector-crash', result.stderr)
        self.assertIn('IllegalStateException', result.stderr)


if __name__ == '__main__':
    unittest.main()
