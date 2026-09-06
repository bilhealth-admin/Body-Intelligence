#!/usr/bin/env python3

from __future__ import annotations

import os
import pathlib
import plistlib
import tempfile
import unittest
import xml.etree.ElementTree as element_tree
from unittest import mock

import validate_admob_production_configuration as validator


ANDROID_NAMESPACE = "http://schemas.android.com/apk/res/android"
ANDROID_ADMOB_APPLICATION_ID_NAME = "com.google.android.gms.ads.APPLICATION_ID"


def valid_environment() -> dict[str, str]:
    publisher = "1234567890123456"
    return {
        validator.READY_VARIABLE: "true",
        validator.PUBLISHER_VARIABLE: f"pub-{publisher}",
        validator.ANDROID_APP_VARIABLE: f"ca-app-pub-{publisher}~1234567890",
        validator.ANDROID_BANNER_VARIABLE: f"ca-app-pub-{publisher}/1234567890",
        validator.IOS_APP_VARIABLE: f"ca-app-pub-{publisher}~0987654321",
        validator.IOS_BANNER_VARIABLE: f"ca-app-pub-{publisher}/0987654321",
    }


def write_android_manifest(path: pathlib.Path, app_ids: list[str]) -> None:
    element_tree.register_namespace("android", ANDROID_NAMESPACE)
    manifest = element_tree.Element("manifest")
    application = element_tree.SubElement(manifest, "application")
    for app_id in app_ids:
        element_tree.SubElement(
            application,
            "meta-data",
            {
                f"{{{ANDROID_NAMESPACE}}}name": ANDROID_ADMOB_APPLICATION_ID_NAME,
                f"{{{ANDROID_NAMESPACE}}}value": app_id,
            },
        )
    element_tree.ElementTree(manifest).write(
        path,
        encoding="utf-8",
        xml_declaration=True,
    )


class ValidateAdMobProductionConfigurationTest(unittest.TestCase):
    def test_missing_identifier_fails_closed(self) -> None:
        environment = valid_environment()
        del environment[validator.IOS_BANNER_VARIABLE]
        with self.assertRaisesRegex(
            validator.GateError,
            validator.IOS_BANNER_VARIABLE,
        ):
            validator.validate_configuration(environment)

    def test_google_demo_and_zero_identifiers_fail_closed(self) -> None:
        for publisher in ("3940256099942544", "0000000000000000"):
            with self.subTest(publisher=publisher):
                environment = valid_environment()
                environment[validator.PUBLISHER_VARIABLE] = f"pub-{publisher}"
                environment[validator.ANDROID_APP_VARIABLE] = (
                    f"ca-app-pub-{publisher}~1234567890"
                )
                environment[validator.ANDROID_BANNER_VARIABLE] = (
                    f"ca-app-pub-{publisher}/1234567890"
                )
                environment[validator.IOS_APP_VARIABLE] = (
                    f"ca-app-pub-{publisher}~0987654321"
                )
                environment[validator.IOS_BANNER_VARIABLE] = (
                    f"ca-app-pub-{publisher}/0987654321"
                )
                with self.assertRaisesRegex(
                    validator.GateError,
                    "zero or Google sample",
                ):
                    validator.validate_configuration(environment)

    def test_zero_unit_suffix_fails_closed(self) -> None:
        environment = valid_environment()
        environment[validator.IOS_APP_VARIABLE] = (
            "ca-app-pub-1234567890123456~0000000000"
        )
        with self.assertRaisesRegex(validator.GateError, "zero identifier suffix"):
            validator.validate_configuration(environment)

    def test_unicode_digits_fail_exact_ascii_format(self) -> None:
        unicode_digits = "١" * 10
        cases = {
            validator.PUBLISHER_VARIABLE: f"pub-{'١' * 16}",
            validator.ANDROID_APP_VARIABLE: (
                f"ca-app-pub-1234567890123456~{unicode_digits}"
            ),
            validator.ANDROID_BANNER_VARIABLE: (
                f"ca-app-pub-1234567890123456/{unicode_digits}"
            ),
            validator.IOS_APP_VARIABLE: (
                f"ca-app-pub-1234567890123456~{unicode_digits}"
            ),
            validator.IOS_BANNER_VARIABLE: (
                f"ca-app-pub-1234567890123456/{unicode_digits}"
            ),
        }
        for name, value in cases.items():
            with self.subTest(name=name):
                environment = valid_environment()
                environment[name] = value
                with self.assertRaisesRegex(validator.GateError, name):
                    validator.validate_configuration(environment)

    def test_mixed_publishers_fail_closed(self) -> None:
        environment = valid_environment()
        environment[validator.ANDROID_BANNER_VARIABLE] = (
            "ca-app-pub-1111111111111111/1234567890"
        )
        with self.assertRaisesRegex(
            validator.GateError,
            validator.ANDROID_BANNER_VARIABLE,
        ):
            validator.validate_configuration(environment)

    def test_false_readiness_fails_closed(self) -> None:
        environment = valid_environment()
        for value in ("", "false", "TRUE", " true"):
            with self.subTest(value=value):
                environment[validator.READY_VARIABLE] = value
                with self.assertRaisesRegex(
                    validator.GateError,
                    "must be exactly 'true'",
                ):
                    validator.validate_configuration(environment)

    def test_valid_configuration_passes(self) -> None:
        configuration = validator.validate_configuration(valid_environment())
        self.assertEqual(
            configuration.ios_app_id,
            valid_environment()[validator.IOS_APP_VARIABLE],
        )

    def test_final_ios_plist_must_match_validated_app_id(self) -> None:
        configuration = validator.validate_configuration(valid_environment())
        with tempfile.TemporaryDirectory() as directory:
            info_plist = pathlib.Path(directory) / "Info.plist"
            with info_plist.open("wb") as handle:
                plistlib.dump(
                    {"GADApplicationIdentifier": configuration.ios_app_id},
                    handle,
                )
            validator.validate_ios_info_plist(info_plist, configuration)

            with info_plist.open("wb") as handle:
                plistlib.dump(
                    {
                        "GADApplicationIdentifier":
                            "ca-app-pub-1234567890123456~1111111111"
                    },
                    handle,
                )
            with self.assertRaisesRegex(
                validator.GateError,
                "final iOS Info.plist".replace("final", "Final"),
            ):
                validator.validate_ios_info_plist(info_plist, configuration)

    def test_final_android_manifest_matches_validated_app_id(self) -> None:
        configuration = validator.validate_configuration(valid_environment())
        with tempfile.TemporaryDirectory() as directory:
            manifest = pathlib.Path(directory) / "AndroidManifest.xml"
            write_android_manifest(manifest, [configuration.android_app_id])
            validator.validate_android_manifest(manifest, configuration)

    def test_final_android_manifest_rejects_mismatched_app_id(self) -> None:
        configuration = validator.validate_configuration(valid_environment())
        with tempfile.TemporaryDirectory() as directory:
            manifest = pathlib.Path(directory) / "AndroidManifest.xml"
            write_android_manifest(
                manifest,
                ["ca-app-pub-1234567890123456~1111111111"],
            )
            with self.assertRaisesRegex(validator.GateError, "does not match"):
                validator.validate_android_manifest(manifest, configuration)

    def test_final_android_manifest_rejects_missing_metadata(self) -> None:
        configuration = validator.validate_configuration(valid_environment())
        with tempfile.TemporaryDirectory() as directory:
            manifest = pathlib.Path(directory) / "AndroidManifest.xml"
            write_android_manifest(manifest, [])
            with self.assertRaisesRegex(validator.GateError, "exactly one"):
                validator.validate_android_manifest(manifest, configuration)

    def test_final_android_manifest_rejects_duplicate_metadata(self) -> None:
        configuration = validator.validate_configuration(valid_environment())
        with tempfile.TemporaryDirectory() as directory:
            manifest = pathlib.Path(directory) / "AndroidManifest.xml"
            write_android_manifest(
                manifest,
                [configuration.android_app_id, configuration.android_app_id],
            )
            with self.assertRaisesRegex(validator.GateError, "exactly one"):
                validator.validate_android_manifest(manifest, configuration)

    def test_cli_pass_labels_do_not_echo_identifiers(self) -> None:
        environment = valid_environment()
        with mock.patch.dict(os.environ, environment, clear=True):
            with mock.patch("builtins.print") as print_mock:
                self.assertEqual(validator.main([]), 0)
        output = "\n".join(str(call.args[0]) for call in print_mock.call_args_list)
        self.assertIn("ADMOB_RELEASE_INPUT_FORMAT_GATE=PASS", output)
        for value in environment.values():
            self.assertNotIn(value, output)


if __name__ == "__main__":
    unittest.main()
