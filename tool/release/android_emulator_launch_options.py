"""Emit reviewed emulator argv; only API36 replaces its deprecated GPU mode.

Android's current graphics documentation deprecates swiftshader_indirect since
36.4.9 and recommends software for a suitable software backend:
https://developer.android.com/studio/run/emulator-acceleration#accel-graphics
This is a controlled tooling change, not proof of the historical ANR's cause.
"""
import argparse


def launch_options(api_level: int) -> list[str]:
    if api_level not in (26, 29, 33, 34, 35, 36):
        raise ValueError('Only the six reviewed Android API levels may launch')
    return ['-no-window', '-gpu', 'software' if api_level == 36 else 'swiftshader_indirect',
            '-no-snapshot', '-noaudio', '-no-boot-anim']


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--api-level', type=int, choices=(26, 29, 33, 34, 35, 36), required=True)
    args = parser.parse_args()
    print('options=' + ' '.join(launch_options(args.api_level)))


if __name__ == '__main__':
    main()
