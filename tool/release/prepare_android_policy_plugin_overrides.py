"""Prepare pinned Android plugin repairs without changing the shared pub cache.

Run after ``flutter pub get``, before native project configuration. Copies keep
the complete upstream package, including Dart, other platforms, assets and
licenses. Unsupported versions, altered anchors and unowned outputs fail closed.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import shutil
import stat
import tempfile
from pathlib import Path
from urllib.parse import urljoin, urlsplit
from urllib.request import url2pathname


RECIPE = "bil-android-policy-plugin-overrides-v1"
MARKER = ".bil-android-policy-overlay.json"
OVERLAY = Path(".dart_tool/bil-android-policy-overrides")
CAMERA = "android/src/main/java/io/flutter/plugins/camerax/CameraXLibrary.g.kt"
SCANNER = "android/src/main/kotlin/dev/steenbakker/mobile_scanner/MobileScanner.kt"
LENS = "android/src/main/kotlin/dev/steenbakker/mobile_scanner/MobileScannerCameraLensSelector.kt"
ADS = "android/build.gradle"
NOTIFICATIONS = "android/src/main/java/com/dexterous/flutterlocalnotifications/FlutterLocalNotificationsPlugin.java"
RECEIVER = "android/src/main/java/com/dexterous/flutterlocalnotifications/ScheduledNotificationReceiver.java"
JNI_CMAKE = "src/CMakeLists.txt"
SPECS = {
    "camera_android_camerax": ("0.7.4+3", {
        CAMERA: "bb8e155f855aa3689c26de50d055056c138511461f83a6f6a63c9c764397fbc9",
    }),
    "mobile_scanner": ("7.4.0", {
        SCANNER: "54f93729cc2f8fdad9e9ddb7307ea95e1a18bc10717e4f0025e52bafd0182a07",
        LENS: "42d3a542d853a2db7242c605fa56626f770188159f77222755f660b68b32b3d7",
    }),
    "google_mobile_ads": ("9.1.0", {
        ADS: "60d95a4445583268b9bd91a6b696b349e80d0e875d94097e11a707939d4386e7",
    }),
    "flutter_local_notifications": ("22.2.0", {
        NOTIFICATIONS: "bb687e972464ac40db192115aa9a2c085b292ffde29f6a64e8123209629ac7c8",
        RECEIVER: "e2037fb296aa0900a1eef65111a78b2331b3c65cddb276b3c54f78c152e3814c",
    }),
    "jni": ("1.0.0", {
        JNI_CMAKE: "0241a96defe71682561f674d5a8273a82ad45da99a4e0881c3d1dae1f19d722a",
    }),
}


class OverlayError(ValueError):
    """A prerequisite or provenance check failed; no fallback is permitted."""


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def _linked(path: Path) -> bool:
    return path.is_symlink() or getattr(path, "is_junction", lambda: False)()


def inventory(root: Path) -> dict[str, str]:
    """Hash all regular files; never follow source or destination links."""
    result = {}
    pending = [root]
    while pending:
        directory = pending.pop()
        if _linked(directory):
            raise OverlayError(f"Linked package directory is forbidden: {directory}")
        for entry in sorted(directory.iterdir()):
            if _linked(entry):
                raise OverlayError(f"Linked package entry is forbidden: {entry}")
            if entry.is_dir():
                pending.append(entry)
            elif entry.is_file():
                result[entry.relative_to(root).as_posix()] = sha256(entry.read_bytes())
            else:
                raise OverlayError(f"Non-regular package entry is forbidden: {entry}")
    return dict(sorted(result.items()))


def _once(text: str, old: str, new: str, label: str) -> str:
    if text.count(old) != 1:
        raise OverlayError(f"Expected exactly one source anchor: {label}")
    return text.replace(old, new, 1)


def patch(relative: str, data: bytes) -> bytes:
    text = data.decode("utf-8")
    interop = (
        "@androidx.annotation.OptIn(\n"
        "    markerClass = [androidx.camera.camera2.interop.ExperimentalCamera2Interop::class]\n"
        ")\n"
    )
    if relative == CAMERA:
        for declaration in (
            "private class CameraXLibraryPigeonProxyApiBaseCodec(",
            "abstract class PigeonApiCaptureRequestOptions(",
            "abstract class PigeonApiCamera2CameraControl(",
            "abstract class PigeonApiCamera2CameraInfo(",
        ):
            text = _once(text, declaration, interop + declaration, declaration)
    elif relative == SCANNER:
        annotation = (
            "@androidx.annotation.OptIn(\n"
            "    markerClass = [\n"
            "        androidx.camera.lifecycle.ExperimentalCameraProviderConfiguration::class,\n"
            "        androidx.camera.core.ExperimentalGetImage::class\n"
            "    ]\n)\n"
        )
        text = _once(text, "class MobileScanner(", annotation + "class MobileScanner(", SCANNER)
    elif relative == LENS:
        text = _once(text, "object MobileScannerCameraLensSelector {",
                     interop + "object MobileScannerCameraLensSelector {", LENS)
    elif relative == ADS:
        anchor = "        implementation 'androidx.constraintlayout:constraintlayout:2.2.1'"
        text = _once(text, anchor,
                     "        implementation 'androidx.appcompat:appcompat:1.7.1'\n" + anchor, ADS)
    elif relative == NOTIFICATIONS:
        old = """    if (notificationDetails.tag != null) {
      notificationManagerCompat.notify(
          notificationDetails.tag, notificationDetails.id, notification);
    } else {
      notificationManagerCompat.notify(notificationDetails.id, notification);
    }"""
        new = """    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU
        && ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS)
            != PackageManager.PERMISSION_GRANTED) {
      Log.w(TAG, "Notification not posted: POST_NOTIFICATIONS permission is not granted.");
      return;
    }
    try {
      if (notificationDetails.tag != null) {
        notificationManagerCompat.notify(
            notificationDetails.tag, notificationDetails.id, notification);
      } else {
        notificationManagerCompat.notify(notificationDetails.id, notification);
      }
    } catch (SecurityException exception) {
      // Permission can be withdrawn after the runtime check, before Binder delivery.
      Log.w(TAG, "Notification permission changed before delivery.", exception);
    }"""
        text = _once(text, old, new, NOTIFICATIONS)
    elif relative == RECEIVER:
        old = "      notificationManager.notify(notificationId, notification);"
        new = """      if (android.os.Build.VERSION.SDK_INT < android.os.Build.VERSION_CODES.TIRAMISU
          || androidx.core.content.ContextCompat.checkSelfPermission(
                  context, android.Manifest.permission.POST_NOTIFICATIONS)
              == android.content.pm.PackageManager.PERMISSION_GRANTED) {
        try {
          notificationManager.notify(notificationId, notification);
        } catch (SecurityException exception) {
          // Preserve cache cleanup and recurring schedules when permission changes.
          Log.w(TAG, "Notification permission changed before delivery.", exception);
        }
      } else {
        Log.w(TAG, "Notification not posted: POST_NOTIFICATIONS permission is not granted.");
      }"""
        text = _once(text, old, new, RECEIVER)
    elif relative == JNI_CMAKE:
        text = _once(
            text,
            'target_link_options(jni PRIVATE "-Wl,-z,max-page-size=16384")',
            'target_link_options(jni PRIVATE\n'
            '    "-Wl,-z,max-page-size=16384"\n'
            '    "-Wl,-z,common-page-size=16384"\n'
            ')',
            JNI_CMAKE,
        )
    else:
        raise OverlayError(f"Unknown source patch: {relative}")
    return text.encode("utf-8")


def _root_from_uri(config: Path, uri: str) -> Path:
    parsed = urlsplit(urljoin(config.as_uri(), uri))
    if parsed.scheme != "file" or parsed.netloc not in ("", "localhost") or parsed.query or parsed.fragment:
        raise OverlayError("Package root must be a local file URI without query or fragment")
    return Path(url2pathname(parsed.path)).resolve()


def _json_bytes(value: object) -> bytes:
    return (json.dumps(value, ensure_ascii=False, sort_keys=True, indent=2) + "\n").encode("utf-8")


def _read_json(path: Path) -> dict:
    try:
        if _linked(path):
            raise OverlayError(f"Linked metadata is forbidden: {path}")
        value = json.loads(path.read_bytes())
        if not isinstance(value, dict):
            raise OverlayError(f"Expected metadata object: {path}")
        return value
    except (OSError, json.JSONDecodeError) as error:
        raise OverlayError(f"Cannot read metadata {path}: {error}") from error


def _original(name: str, root: Path) -> dict[str, str]:
    version, anchors = SPECS[name]
    pubspec = (root / "pubspec.yaml").read_text(encoding="utf-8")
    for key, expected in (("name", name), ("version", version)):
        values = re.findall(rf"^{key}:\s*['\"]?([^'\"\s#]+)['\"]?\s*$", pubspec, re.MULTILINE)
        if values != [expected]:
            raise OverlayError(f"Unsupported {name} {key}: expected {expected}")
    files = inventory(root)
    if MARKER in files:
        raise OverlayError("An overlay cannot be used as its own upstream source")
    for relative, expected in anchors.items():
        if files.get(relative) != expected:
            raise OverlayError(f"Original source SHA-256 mismatch: {name}/{relative}")
        patch(relative, (root / relative).read_bytes())
    return files


def _expected_marker(name: str, source: Path, files: dict[str, str]) -> dict:
    return {
        "recipe": RECIPE, "name": name, "version": SPECS[name][0],
        "source_uri": source.as_uri() + "/", "source_files_sha256": files,
        "patched_files_sha256": {
            relative: sha256(patch(relative, (source / relative).read_bytes()))
            for relative in SPECS[name][1]
        },
    }


def _verify_copy(destination: Path, marker: dict) -> None:
    if _read_json(destination / MARKER) != marker:
        raise OverlayError(f"Overlay provenance mismatch: {destination}")
    expected = {**marker["source_files_sha256"], **marker["patched_files_sha256"]}
    actual = inventory(destination)
    actual.pop(MARKER, None)
    if actual != expected:
        raise OverlayError(f"Overlay changed or incomplete: {destination}")


def prepare(project_root: Path) -> dict:
    project = project_root.resolve()
    config = project / ".dart_tool/package_config.json"
    metadata = project / ".flutter-plugins-dependencies"
    base = project / OVERLAY
    for path in (project / ".dart_tool", base):
        if _linked(path):
            raise OverlayError(f"Linked overlay parent is forbidden: {path}")
    config_data, metadata_data = _read_json(config), _read_json(metadata)
    entries = config_data.get("packages")
    platforms = metadata_data.get("plugins")
    if not isinstance(entries, list) or not isinstance(platforms, dict):
        raise OverlayError("Malformed Flutter discovery metadata")
    plan = []
    for name, (version, _) in SPECS.items():
        matching = [entry for entry in entries if entry.get("name") == name]
        if len(matching) != 1:
            raise OverlayError(f"Expected one resolved package entry: {name}")
        destination = base / f"{name}-{version}"
        if _linked(destination):
            raise OverlayError(f"Linked overlay destination is forbidden: {destination}")
        source = _root_from_uri(config, matching[0]["rootUri"])
        if source == destination:
            saved = _read_json(destination / MARKER)
            if saved.get("recipe") != RECIPE or saved.get("name") != name:
                raise OverlayError(f"Unowned resolved overlay: {name}")
            source = _root_from_uri(config, saved["source_uri"])
        if source == base or base in source.parents:
            raise OverlayError("Upstream package must be outside managed overlays")
        files = _original(name, source)
        marker = _expected_marker(name, source, files)
        if destination.exists():
            _verify_copy(destination, marker)
        android = [entry for entry in platforms.get("android", []) if entry.get("name") == name]
        if len(android) != 1:
            raise OverlayError(f"Expected one Android plugin entry: {name}")
        # Reject stale discovery roots before rewriting either metadata file.
        for platform_entries in platforms.values():
            for entry in platform_entries:
                if entry.get("name") == name:
                    old = Path(entry["path"]).resolve()
                    if old not in (source, destination):
                        raise OverlayError(f"Flutter discovery root mismatch: {name}")
        plan.append((name, source, destination, marker, matching[0]))

    # No shared source is written. Staging directories are new and task-owned;
    # unexpected or incomplete pre-existing outputs are never removed or reset.
    base.mkdir(parents=True, exist_ok=True)
    for name, source, destination, marker, entry in plan:
        if not destination.exists():
            stage = Path(tempfile.mkdtemp(prefix=f".{name}-", dir=base))
            package = stage / "package"
            shutil.copytree(source, package, copy_function=shutil.copy2)
            if inventory(package) != marker["source_files_sha256"]:
                raise OverlayError(f"Source changed while copying: {name}")
            for relative in SPECS[name][1]:
                path = package / relative
                path.chmod(path.stat().st_mode | stat.S_IWUSR)
                path.write_bytes(patch(relative, path.read_bytes()))
            (package / MARKER).write_bytes(_json_bytes(marker))
            _verify_copy(package, marker)
            package.rename(destination)
            stage.rmdir()
        entry["rootUri"] = destination.as_uri() + "/"
        for platform_entries in platforms.values():
            for plugin in platform_entries:
                if plugin.get("name") == name:
                    plugin["path"] = str(destination) + os.sep

    # Validate all outputs once more before publishing the two discovery files.
    for _, _, destination, marker, _ in plan:
        _verify_copy(destination, marker)
    originals = {config: config.read_bytes(), metadata: metadata.read_bytes()}
    staged = {}
    try:
        for target, data in ((config, config_data), (metadata, metadata_data)):
            with tempfile.NamedTemporaryFile(dir=target.parent, delete=False) as temporary:
                temporary.write(_json_bytes(data))
                staged[target] = Path(temporary.name)
        for target, temporary in staged.items():
            os.replace(temporary, target)
    except BaseException:
        # Restore only the exact two generated discovery files owned by this call.
        for target, data in originals.items():
            target.write_bytes(data)
        raise
    finally:
        for temporary in staged.values():
            temporary.unlink(missing_ok=True)
    return {
        "recipe": RECIPE, "plugins": {
            name: {"version": SPECS[name][0], "original_files_sha256": SPECS[name][1],
                   "source_tree_sha256": sha256(_json_bytes(marker["source_files_sha256"])),
                   "destination": str(destination)}
            for name, _, destination, marker, _ in plan
        }, "shared_pub_cache_modified": False,
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project-root", type=Path, default=Path.cwd())
    args = parser.parse_args(argv)
    try:
        print(json.dumps(prepare(args.project_root), ensure_ascii=False, sort_keys=True))
    except (OverlayError, OSError, KeyError, TypeError) as error:
        parser.exit(2, f"ANDROID_POLICY_PLUGIN_OVERLAYS=FAIL: {error}\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
