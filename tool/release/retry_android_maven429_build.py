#!/usr/bin/env python3
"""One delayed retry for the proven Gradle-plugin Maven HTTP429 failure only."""
from __future__ import annotations
import re
import subprocess
import sys
import time

MAX_ATTEMPTS = 2
RETRY_DELAY_SECONDS = 20
PLUGIN_FAILURE = "Error resolving plugin [id: 'dev.flutter.flutter-plugin-loader', version: '1.0.0']"
DOWNLOAD_FAILURE = 'Gradle threw an error while downloading artifacts from the network.'
MAVEN_429 = re.compile(r"Could not (?:GET|HEAD) 'https://(?:repo\.maven\.apache\.org/maven2|plugins\.gradle\.org/m2)/[^'\s]+'. Received status code 429 from server: Too Many Requests")
BUILD_FAILURE = re.compile(r"(?i)(?:^e: |\berror: |compilation failed|execution failed for task [^\r\n]*(?:compile|test|lint|package|sign)|keystore|signingconfig)")


class Evidence:
    def __init__(self):
        self.plugin = self.download = self.http429 = self.other_failure = False

    def observe(self, line: str):
        if 'Retrying Gradle Build:' in line:
            # An earlier internally retried HTTP429 must not classify the
            # final Gradle attempt's different failure as transport-only.
            self.plugin = self.download = self.http429 = self.other_failure = False
        if re.search(r"Could not (?:GET|HEAD) '", line) and MAVEN_429.search(line) is None:
            self.other_failure = True
        self.plugin |= PLUGIN_FAILURE in line
        self.download |= DOWNLOAD_FAILURE in line
        self.http429 |= MAVEN_429.search(line) is not None
        self.other_failure |= BUILD_FAILURE.search(line) is not None

    def retryable(self) -> bool:
        return self.plugin and self.download and self.http429 and not self.other_failure


def is_retryable(output: str) -> bool:
    evidence = Evidence()
    for line in output.splitlines():
        evidence.observe(line)
    return evidence.retryable()


def run_once(command: list[str]) -> tuple[int, bool]:
    try:
        process = subprocess.Popen(command, stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT, text=True, encoding='utf-8', errors='replace', bufsize=1)
    except OSError:
        print('Could not start the offline Android debug build command.', file=sys.stderr)
        return 127, False
    evidence = Evidence()
    assert process.stdout is not None
    try:
        for line in process.stdout:
            sys.stdout.write(line)
            sys.stdout.flush()
            evidence.observe(line)
        return process.wait(), evidence.retryable()
    finally:
        process.stdout.close()
        if process.poll() is None:
            # Only the retained child; no PID/name-wide cleanup or cache reset.
            process.terminate()
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait(timeout=5)


def main(argv: list[str], *, runner=run_once, sleeper=time.sleep) -> int:
    command = argv[1:] if argv and argv[0] == '--' else argv
    if (command[:4] != ['flutter', 'build', 'apk', '--debug']
            or '--no-pub' not in command
            or any(flag in command for flag in ['--release', '--profile'])):
        print('Only the existing offline unsigned Flutter debug APK command is supported.', file=sys.stderr)
        return 64
    for attempt in range(1, MAX_ATTEMPTS + 1):
        print(f'Android debug build invocation {attempt}/{MAX_ATTEMPTS}.', flush=True)
        status, retryable = runner(command)
        if status < 0 or status >= 128:
            return status if status > 0 else 128 - status
        if status == 0:
            return 0
        if not retryable or attempt == MAX_ATTEMPTS:
            return status if status > 0 else 128 - status
        print('Confirmed Gradle plugin download HTTP429; one delayed retry after20s. '
              'Flutter may also make its own bounded internal Gradle retry.', file=sys.stderr, flush=True)
        sleeper(RETRY_DELAY_SECONDS)
    return 1


if __name__ == '__main__':
    raise SystemExit(main(sys.argv[1:]))
