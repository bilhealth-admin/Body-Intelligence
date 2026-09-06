from __future__ import annotations

import contextlib
import copy
import io
import pathlib
import plistlib
import tempfile
import unittest
import xml.etree.ElementTree as element_tree

import configure_deferred_admob as deferred


ANDROID = deferred.ANDROID_NAMESPACE
TOOLS = deferred.TOOLS_NAMESPACE
ANDROID_NAME = deferred.ANDROID_NAME
TOOLS_NODE = deferred.TOOLS_NODE


def android_source_manifest(*, integration_manager: bool = False) -> str:
    integration = (
        f'<meta-data android:name="{deferred.ANDROID_INTEGRATION_MANAGER}" '
        'android:value="webview" />'
        if integration_manager
        else ""
    )
    return f"""<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="{ANDROID}" xmlns:tools="{TOOLS}">
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="com.google.android.gms.permission.AD_ID"
        tools:node="remove" />
    <application android:label="Body Intelligence Log" android:allowBackup="false">
        <!-- Preserve this application comment. -->
        <meta-data android:name="{deferred.ANDROID_APPLICATION_ID}"
            android:value="${{bilAdMobAndroidAppId}}" />
        {integration}
        <activity android:name=".MainActivity" android:exported="true" />
        <service android:name=".PrivateSyncService" android:exported="false" />
    </application>
</manifest>
"""


def android_final_manifest(*, application_children: str = "", permissions: str = "") -> str:
    return f"""<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="{ANDROID}">
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
    {permissions}
    <application android:label="Body Intelligence Log">
        <activity android:name=".MainActivity" android:exported="true" />
        <activity android:name="com.google.android.gms.ads.AdActivity"
            android:exported="false" />
        <service android:name="com.google.android.gms.ads.AdService"
            android:enabled="true" android:exported="false" />
        <meta-data android:name="com.google.android.gms.ads.flag.OPTIMIZE_INITIALIZATION"
            android:value="true" />
        {application_children}
    </application>
</manifest>
"""


def parse_application(path: pathlib.Path) -> element_tree.Element:
    root = element_tree.parse(path).getroot()
    return next(child for child in root if child.tag.endswith("application"))


class DeferredAndroidPrepareTest(unittest.TestCase):
    def test_removes_app_id_and_adds_one_provider_removal_marker(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            path = pathlib.Path(temporary) / "AndroidManifest.xml"
            path.write_text(android_source_manifest(), encoding="utf-8")

            deferred.prepare_android_source_manifest(path)
            application = parse_application(path)

            metadata_names = {
                child.get(ANDROID_NAME)
                for child in application
                if child.tag.endswith("meta-data")
            }
            self.assertNotIn(deferred.ANDROID_APPLICATION_ID, metadata_names)
            providers = [
                child
                for child in application
                if child.tag.endswith("provider")
                and child.get(ANDROID_NAME) == deferred.ANDROID_INIT_PROVIDER
            ]
            self.assertEqual(len(providers), 1)
            self.assertEqual(providers[0].get(TOOLS_NODE), "remove")

            self.assertEqual(application.get(f"{{{ANDROID}}}label"), "Body Intelligence Log")
            self.assertEqual(application.get(f"{{{ANDROID}}}allowBackup"), "false")
            self.assertEqual(
                [
                    child.get(ANDROID_NAME)
                    for child in application
                    if child.tag.endswith("activity")
                ],
                [".MainActivity"],
            )
            self.assertEqual(
                [
                    child.get(ANDROID_NAME)
                    for child in application
                    if child.tag.endswith("service")
                ],
                [".PrivateSyncService"],
            )

    def test_prepare_is_byte_idempotent(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            path = pathlib.Path(temporary) / "AndroidManifest.xml"
            path.write_text(android_source_manifest(), encoding="utf-8")
            deferred.prepare_android_source_manifest(path)
            once = path.read_bytes()
            deferred.prepare_android_source_manifest(path)
            self.assertEqual(path.read_bytes(), once)

    def test_rejects_integration_manager_without_changing_file(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            path = pathlib.Path(temporary) / "AndroidManifest.xml"
            path.write_text(
                android_source_manifest(integration_manager=True),
                encoding="utf-8",
            )
            before = path.read_bytes()
            with self.assertRaisesRegex(
                deferred.DeferredAdMobError,
                "INTEGRATION_MANAGER bypass is forbidden",
            ):
                deferred.prepare_android_source_manifest(path)
            self.assertEqual(path.read_bytes(), before)


class DeferredAndroidVerifyTest(unittest.TestCase):
    def write_and_verify(self, body: str) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            path = pathlib.Path(temporary) / "merged.xml"
            path.write_text(body, encoding="utf-8")
            deferred.verify_android_merged_manifest(path)

    def test_accepts_dormant_nonexported_ads_components(self) -> None:
        self.write_and_verify(android_final_manifest())

    def test_rejects_app_id_metadata(self) -> None:
        child = (
            f'<meta-data android:name="{deferred.ANDROID_APPLICATION_ID}" '
            'android:value="ca-app-pub-1234567890123456~1234567890" />'
        )
        with self.assertRaisesRegex(deferred.DeferredAdMobError, "APPLICATION_ID"):
            self.write_and_verify(android_final_manifest(application_children=child))

    def test_rejects_legacy_and_next_generation_init_providers(self) -> None:
        for provider in (
            deferred.ANDROID_INIT_PROVIDER,
            "com.google.android.libraries.ads.mobile.sdk.MobileAdsInitProvider",
        ):
            with self.subTest(provider=provider):
                child = (
                    f'<provider android:name="{provider}" '
                    'android:exported="false" />'
                )
                with self.assertRaisesRegex(
                    deferred.DeferredAdMobError,
                    "MobileAdsInitProvider",
                ):
                    self.write_and_verify(
                        android_final_manifest(application_children=child)
                    )

    def test_rejects_each_advertising_permission(self) -> None:
        for permission in sorted(deferred.FORBIDDEN_ANDROID_PERMISSIONS):
            with self.subTest(permission=permission):
                declaration = f'<uses-permission android:name="{permission}" />'
                with self.assertRaisesRegex(
                    deferred.DeferredAdMobError,
                    "deferred-advertising permissions",
                ):
                    self.write_and_verify(
                        android_final_manifest(permissions=declaration)
                    )

    def test_rejects_integration_manager_and_hidden_admob_identifiers(self) -> None:
        integration = (
            f'<meta-data android:name="{deferred.ANDROID_INTEGRATION_MANAGER}" '
            'android:value="webview" />'
        )
        with self.assertRaisesRegex(deferred.DeferredAdMobError, "INTEGRATION_MANAGER"):
            self.write_and_verify(
                android_final_manifest(application_children=integration)
            )

        hidden_identifier = (
            '<meta-data android:name="fixture" '
            'android:value="ca-app-pub-1234567890123456/1234567890" />'
        )
        with self.assertRaisesRegex(deferred.DeferredAdMobError, "AdMob identifier"):
            self.write_and_verify(
                android_final_manifest(application_children=hidden_identifier)
            )


class DeferredIosPrepareAndVerifyTest(unittest.TestCase):
    def payload(self) -> dict[str, object]:
        return {
            "GADApplicationIdentifier": "$(BIL_ADMOB_IOS_APP_ID)",
            "SKAdNetworkItems": [
                {"SKAdNetworkIdentifier": "cstr6suwn9.skadnetwork"}
            ],
            "CFBundleDisplayName": "Body Intelligence Log",
            "CFBundleURLTypes": [
                {"CFBundleURLSchemes": ["bil"]}
            ],
            "UIBackgroundModes": ["processing"],
        }

    def test_prepare_removes_only_app_id_and_is_byte_idempotent(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            path = pathlib.Path(temporary) / "Info.plist"
            original = self.payload()
            path.write_bytes(plistlib.dumps(original, sort_keys=False))

            deferred.prepare_ios_source_plist(path)
            prepared = plistlib.loads(path.read_bytes())
            expected = copy.deepcopy(original)
            expected.pop(deferred.IOS_APPLICATION_ID)
            self.assertEqual(prepared, expected)

            once = path.read_bytes()
            deferred.prepare_ios_source_plist(path)
            self.assertEqual(path.read_bytes(), once)

    def test_prepare_preserves_binary_plist_format(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            path = pathlib.Path(temporary) / "Info.plist"
            path.write_bytes(
                plistlib.dumps(
                    self.payload(),
                    fmt=plistlib.FMT_BINARY,
                    sort_keys=False,
                )
            )
            deferred.prepare_ios_source_plist(path)
            self.assertTrue(path.read_bytes().startswith(b"bplist00"))
            self.assertNotIn(
                deferred.IOS_APPLICATION_ID,
                plistlib.loads(path.read_bytes()),
            )

    def test_prepare_rejects_integration_manager_without_mutation(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            path = pathlib.Path(temporary) / "Info.plist"
            payload = self.payload()
            payload[deferred.IOS_INTEGRATION_MANAGER] = "webview"
            path.write_bytes(plistlib.dumps(payload, sort_keys=False))
            before = path.read_bytes()
            with self.assertRaisesRegex(
                deferred.DeferredAdMobError,
                "GADIntegrationManager bypass is forbidden",
            ):
                deferred.prepare_ios_source_plist(path)
            self.assertEqual(path.read_bytes(), before)

    def test_final_verifier_accepts_absence_and_rejects_bypasses(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            path = pathlib.Path(temporary) / "Info.plist"
            payload = self.payload()
            payload.pop(deferred.IOS_APPLICATION_ID)
            path.write_bytes(plistlib.dumps(payload, sort_keys=False))
            deferred.verify_ios_final_plist(path)

            for key, value in (
                (
                    deferred.IOS_APPLICATION_ID,
                    "ca-app-pub-1234567890123456~1234567890",
                ),
                (deferred.IOS_INTEGRATION_MANAGER, "webview"),
            ):
                with self.subTest(key=key):
                    invalid = copy.deepcopy(payload)
                    invalid[key] = value
                    path.write_bytes(plistlib.dumps(invalid, sort_keys=False))
                    with self.assertRaises(deferred.DeferredAdMobError):
                        deferred.verify_ios_final_plist(path)

            hidden_identifier = copy.deepcopy(payload)
            hidden_identifier["UnrelatedNestedFixture"] = {
                "value": "ca-app-pub-1234567890123456/1234567890"
            }
            path.write_bytes(
                plistlib.dumps(hidden_identifier, sort_keys=False)
            )
            with self.assertRaisesRegex(
                deferred.DeferredAdMobError,
                "AdMob identifier",
            ):
                deferred.verify_ios_final_plist(path)


class DeferredCliTest(unittest.TestCase):
    def test_one_explicit_path_prints_truthful_markers(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            path = pathlib.Path(temporary) / "Info.plist"
            path.write_bytes(plistlib.dumps({"CFBundleName": "BIL"}))
            output = io.StringIO()
            with contextlib.redirect_stdout(output):
                code = deferred.main(["--verify-ios-final-plist", str(path)])
            self.assertEqual(code, 0)
            self.assertEqual(
                output.getvalue().splitlines(),
                [
                    "ADMOB_DEFERRED_IOS_FINAL_PLIST_GATE=PASS",
                    "ADMOB_DEFERRED_IOS_APPLICATION_ID=ABSENT",
                ],
            )

    def test_path_operations_are_mutually_exclusive(self) -> None:
        parser = deferred._parser()
        with contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit):
            parser.parse_args([])
        with contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit):
            parser.parse_args(
                [
                    "--verify-ios-final-plist",
                    "Info.plist",
                    "--verify-android-merged-manifest",
                    "AndroidManifest.xml",
                ]
            )


if __name__ == "__main__":
    unittest.main()
