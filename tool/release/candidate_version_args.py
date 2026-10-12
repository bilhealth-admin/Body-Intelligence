"""Resolve per-platform Flutter build arguments. Never build, sign or upload."""
import argparse
import json
from pathlib import Path


def build_arguments(platform: str) -> list[str]:
    candidate = json.loads(
        Path(__file__).with_name("candidate_versions.json").read_text(encoding="utf-8")
    )
    key = {"ios": "ios_build_number", "android": "android_version_code"}[platform]
    number = candidate[key]
    if type(number) is not int or number <= 0:
        raise ValueError("Candidate build number must be a positive integer")
    return [f"--build-name={candidate['version_name']}", f"--build-number={number}"]


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--platform", choices=("ios", "android"), required=True)
    args = parser.parse_args()
    print(json.dumps(build_arguments(args.platform)))
