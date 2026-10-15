"""Real resolved-package fixtures and host-JVM notification body regressions.

These tests do not build Android, run Lint, contact a service or change pub cache.
"""

import contextlib
import io
import json
import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

import prepare_android_policy_plugin_overrides as overlay


PROJECT = Path(__file__).resolve().parents[2]


def java_method(source, signature):
    start = source.index(signature)
    opening = source.index("{", start)
    depth = 1
    index = opening + 1
    while depth:
        depth += (source[index] == "{") - (source[index] == "}")
        index += 1
    return source[start:index]


class PluginOverlayTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        config = PROJECT / ".dart_tool/package_config.json"
        resolved = json.loads(config.read_bytes())["packages"]
        cls.sources = {}
        cls.source_hashes = {}
        for name in overlay.SPECS:
            entry = next(item for item in resolved if item["name"] == name)
            source = overlay._root_from_uri(config, entry["rootUri"])
            if source.name == f"{name}-{overlay.SPECS[name][0]}" and (source / overlay.MARKER).exists():
                marker = json.loads((source / overlay.MARKER).read_bytes())
                source = overlay._root_from_uri(config, marker["source_uri"])
            cls.sources[name] = source
            cls.source_hashes[name] = overlay._original(name, source)

    @classmethod
    def tearDownClass(cls):
        for name, root in cls.sources.items():
            if overlay.inventory(root) != cls.source_hashes[name]:
                raise AssertionError(f"Shared resolved source changed: {name}")

    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="bil-policy-overlay-")
        self.addCleanup(self.temporary.cleanup)
        self.project = Path(self.temporary.name) / "project with spaces %20 العربية"
        (self.project / ".dart_tool").mkdir(parents=True)
        self.config = self.project / ".dart_tool/package_config.json"
        self.metadata = self.project / ".flutter-plugins-dependencies"
        self.write_fixture()

    def write_fixture(self, overrides=None):
        sources = {**self.sources, **(overrides or {})}
        packages = [{"name": name, "rootUri": root.as_uri() + "/", "packageUri": "lib/",
                     "languageVersion": "3.8"} for name, root in sources.items()]
        packages.append({"name": "unrelated", "rootUri": "../untouched/"})
        self.config.write_bytes(overlay._json_bytes({"configVersion": 2, "packages": packages}))
        entries = [{"name": name, "path": str(root) + os.sep, "native_build": True,
                    "dependencies": [], "dev_dependency": False} for name, root in sources.items()]
        entries.append({"name": "unrelated", "path": str(self.project / "untouched")})
        self.metadata.write_bytes(overlay._json_bytes({
            "plugins": {"android": entries, "ios": json.loads(json.dumps(entries))},
            "dependencyGraph": [{"name": name, "dependencies": ["unchanged"]} for name in sources],
            "date_created": "synthetic fixture metadata",
        }))

    def clone_source(self, name):
        destination = Path(self.temporary.name) / f"{name}-{overlay.SPECS[name][0]}"
        shutil.copytree(self.sources[name], destination)
        return destination

    def assert_discovery_unchanged_on_failure(self):
        originals = self.config.read_bytes(), self.metadata.read_bytes()
        with self.assertRaises(overlay.OverlayError):
            overlay.prepare(self.project)
        self.assertEqual((self.config.read_bytes(), self.metadata.read_bytes()), originals)

    def test_real_packages_complete_copy_provenance_discovery_and_idempotence(self):
        original_metadata = json.loads(self.metadata.read_bytes())
        result = overlay.prepare(self.project)
        self.assertFalse(result["shared_pub_cache_modified"])
        packages = json.loads(self.config.read_bytes())["packages"]
        metadata = json.loads(self.metadata.read_bytes())
        self.assertEqual(metadata["dependencyGraph"], original_metadata["dependencyGraph"])
        self.assertEqual(metadata["date_created"], original_metadata["date_created"])
        for name, (version, anchors) in overlay.SPECS.items():
            destination = self.project / overlay.OVERLAY / f"{name}-{version}"
            marker = json.loads((destination / overlay.MARKER).read_bytes())
            self.assertEqual(marker["source_files_sha256"], self.source_hashes[name])
            self.assertEqual(result["plugins"][name]["original_files_sha256"], anchors)
            overlay._verify_copy(destination, marker)
            entry = next(item for item in packages if item["name"] == name)
            self.assertEqual(overlay._root_from_uri(self.config, entry["rootUri"]), destination.resolve())
            self.assertEqual(entry["packageUri"], "lib/")
            for entries in metadata["plugins"].values():
                plugin = next(item for item in entries if item["name"] == name)
                self.assertEqual(Path(plugin["path"]).resolve(), destination.resolve())
            # Every upstream license, asset, test and non-Android file remains byte-identical.
            for relative, digest in marker["source_files_sha256"].items():
                if relative not in anchors:
                    self.assertEqual(overlay.sha256((destination / relative).read_bytes()), digest)
        once = self.config.read_bytes(), self.metadata.read_bytes()
        self.assertEqual(overlay.prepare(self.project), result)
        self.assertEqual((self.config.read_bytes(), self.metadata.read_bytes()), once)

    def test_rejects_changed_original_hash_before_creating_any_overlay(self):
        name = "camera_android_camerax"
        source = self.clone_source(name)
        target = source / overlay.CAMERA
        target.write_bytes(target.read_bytes() + b"\n// altered source\n")
        self.write_fixture({name: source})
        self.assert_discovery_unchanged_on_failure()
        self.assertFalse((self.project / overlay.OVERLAY).exists())

    def test_rejects_unpinned_version_even_when_java_anchors_match(self):
        name = "mobile_scanner"
        source = self.clone_source(name)
        pubspec = source / "pubspec.yaml"
        pubspec.write_bytes(pubspec.read_bytes().replace(b"version: 7.4.0", b"version: 7.4.1"))
        self.write_fixture({name: source})
        self.assert_discovery_unchanged_on_failure()

    def test_rejects_missing_or_duplicate_package_and_android_discovery(self):
        for kind in ("missing", "duplicate", "android_missing", "android_stale"):
            with self.subTest(kind=kind):
                self.write_fixture()
                if kind in ("missing", "duplicate"):
                    data = json.loads(self.config.read_bytes())
                    item = data["packages"][0]
                    if kind == "missing":
                        data["packages"].remove(item)
                    else:
                        data["packages"].append(dict(item))
                    self.config.write_bytes(overlay._json_bytes(data))
                else:
                    data = json.loads(self.metadata.read_bytes())
                    if kind == "android_missing":
                        data["plugins"]["android"].pop(0)
                    else:
                        data["plugins"]["android"][0]["path"] = str(self.project / "wrong")
                    self.metadata.write_bytes(overlay._json_bytes(data))
                self.assert_discovery_unchanged_on_failure()

    def test_preexisting_unowned_destination_is_never_reset(self):
        name = "camera_android_camerax"
        destination = self.project / overlay.OVERLAY / f"{name}-{overlay.SPECS[name][0]}"
        destination.mkdir(parents=True)
        sentinel = destination / "owner-sentinel.txt"
        sentinel.write_bytes(b"preserve unrelated local work")
        self.assert_discovery_unchanged_on_failure()
        self.assertEqual(sentinel.read_bytes(), b"preserve unrelated local work")

    def test_rejects_changed_overlay_instead_of_repatching_or_overwriting(self):
        overlay.prepare(self.project)
        name = "mobile_scanner"
        destination = self.project / overlay.OVERLAY / f"{name}-{overlay.SPECS[name][0]}"
        extra = destination / "owner-work.txt"
        extra.write_bytes(b"do not delete")
        self.assert_discovery_unchanged_on_failure()
        self.assertEqual(extra.read_bytes(), b"do not delete")

    def test_fail_closed_anchor_counts_unknown_patch_and_nonfile_uri(self):
        with self.assertRaises(overlay.OverlayError):
            overlay._once("x x", "x", "patched", "duplicate")
        with self.assertRaises(overlay.OverlayError):
            overlay.patch("unknown.kt", b"class Unknown")
        for uri in ("https://pub.dev/package", "file://remote-host/package", "file:///tmp/x?y=1"):
            with self.subTest(uri=uri), self.assertRaises(overlay.OverlayError):
                overlay._root_from_uri(self.config, uri)

    def test_cli_bad_root_fails_without_writing_outputs(self):
        with contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit) as error:
            overlay.main(["--project-root", str(self.project / "missing")])
        self.assertEqual(error.exception.code, 2)

    def test_patches_are_opt_in_dependency_and_permission_repairs_not_suppressions(self):
        for name, (_, anchors) in overlay.SPECS.items():
            for relative in anchors:
                before = (self.sources[name] / relative).read_bytes()
                after = overlay.patch(relative, before)
                self.assertEqual(after.count(b"SuppressLint"), before.count(b"SuppressLint"))
                self.assertEqual(after.count(b"@Suppress("), before.count(b"@Suppress("))
        camera = overlay.patch(overlay.CAMERA, (self.sources["camera_android_camerax"] / overlay.CAMERA).read_bytes())
        self.assertEqual(camera.count(b"@androidx.annotation.OptIn("), 4)
        ads = overlay.patch(overlay.ADS, (self.sources["google_mobile_ads"] / overlay.ADS).read_bytes())
        self.assertEqual(ads.count(b"implementation 'androidx.appcompat:appcompat:1.7.1'"), 1)

    def test_actual_notification_bodies_on_host_jvm_preserve_delivery_cleanup_and_reschedule(self):
        plugin = overlay.patch(overlay.NOTIFICATIONS,
                               (self.sources["flutter_local_notifications"] / overlay.NOTIFICATIONS).read_bytes()).decode()
        receiver = overlay.patch(overlay.RECEIVER,
                                 (self.sources["flutter_local_notifications"] / overlay.RECEIVER).read_bytes()).decode()
        show = java_method(plugin, "static void showNotification(")
        receive = java_method(receiver, "public void onReceive(")
        # Keep Unicode/percent URI coverage above. Windows javac's launcher can
        # narrow non-ASCII argv before Java starts; the host-body test is not a
        # test of that launcher. Use the separate ASCII temporary sibling here.
        root = Path(self.temporary.name) / "host-java"
        root.mkdir()
        files = {
            "android/content/Context.java": "package android.content; public class Context { public boolean granted, race; }",
            "android/Manifest.java": 'package android; public class Manifest { public static class permission { public static final String POST_NOTIFICATIONS="notification"; } }',
            "android/os/Build.java": "package android.os; public class Build { public static class VERSION { public static int SDK_INT; } public static class VERSION_CODES { public static final int TIRAMISU=33; } }",
            "android/content/pm/PackageManager.java": "package android.content.pm; public class PackageManager { public static final int PERMISSION_GRANTED=0; }",
            "androidx/core/content/ContextCompat.java": "package androidx.core.content; public class ContextCompat { public static int checkSelfPermission(android.content.Context c,String p){ return c.granted?0:-1; } }",
            "Harness.java": JAVA_HARNESS.replace("@@SHOW@@", show).replace("@@RECEIVE@@", receive),
        }
        for relative, body in files.items():
            path = root / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(body.encode("utf-8"))
        javac = shutil.which("javac")
        java = shutil.which("java")
        if os.environ.get("JAVA_HOME"):
            suffix = ".exe" if os.name == "nt" else ""
            javac = str(Path(os.environ["JAVA_HOME"]) / "bin" / f"javac{suffix}")
            java = str(Path(os.environ["JAVA_HOME"]) / "bin" / f"java{suffix}")
        self.assertTrue(javac and java, "Host-JVM regression requires the existing JDK on PATH or JAVA_HOME")
        compile_result = subprocess.run([javac, "-encoding", "UTF-8", "-d", str(root),
                                         *[str(root / path) for path in files]],
                                        capture_output=True, text=True, timeout=60)
        self.assertEqual(compile_result.returncode, 0, compile_result.stderr)
        result = subprocess.run([java, "-cp", str(root), "Harness"],
                                capture_output=True, text=True, timeout=30)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("notification delivery cases=40", result.stdout)


JAVA_HARNESS = r'''
import android.content.Context;
import android.os.Build;
import android.Manifest;
import android.content.pm.PackageManager;
import androidx.core.content.ContextCompat;
import java.lang.reflect.Type;

public class Harness {
  static final String TAG="host-test";
  static int attempted, posted, cache, next, tagged, cases;
  static class Notification { long when; }
  static class NotificationDetails { String tag; int id=17; }
  static class Log {
    static void w(String t,String m) {}
    static void w(String t,String m,Throwable e) {}
    static void e(String t,String m) {}
  }
  static class NotificationManagerCompat {
    Context context;
    NotificationManagerCompat(Context c) {context=c;}
    static NotificationManagerCompat from(Context c){return new NotificationManagerCompat(c);}
    void notify(int id,Notification n){attempted++;if(context.race)throw new SecurityException();posted++;}
    void notify(String tag,int id,Notification n){tagged++;notify(id,n);}
  }
  static class Intent {
    boolean modern, repeat;
    String getStringExtra(String key){return modern?"synthetic-json":null;}
    int getIntExtra(String key,int fallback){return 17;}
    boolean getBooleanExtra(String key,boolean fallback){return repeat;}
    Notification getParcelableExtra(String key){return new Notification();}
    Notification getParcelableExtra(String key,Class<Notification> type){return new Notification();}
  }
  static class StringUtils {static boolean isNullOrEmpty(String s){return s==null||s.isEmpty();}}
  static class Gson {NotificationDetails fromJson(String s,Type t){return new NotificationDetails();}}
  static class TypeToken<T> {Type getType(){return null;}}
  static class FlutterLocalNotificationsPlugin {
    static final String NOTIFICATION_DETAILS="details";
    static Notification createNotification(Context c,NotificationDetails n){return new Notification();}
    static NotificationManagerCompat getNotificationManager(Context c){return NotificationManagerCompat.from(c);}
    static void removeNotificationFromCache(Context c,int id){cache++;}
    static void scheduleNextNotification(Context c,NotificationDetails n){next++;}
    static Gson buildGson(){return new Gson();}
    @@SHOW@@
  }
  @@RECEIVE@@
  static void reset(){attempted=posted=cache=next=tagged=0;}
  static void check(boolean condition,String message){if(!condition)throw new AssertionError(message);}
  public static void main(String[] arguments){
    for(int api:new int[]{32,33}) for(boolean granted:new boolean[]{false,true})
      for(boolean race:new boolean[]{false,true}) {
        Context context=new Context();context.granted=granted;context.race=race;Build.VERSION.SDK_INT=api;
        boolean allowed=api<33||granted;
        for(boolean tag:new boolean[]{false,true}) {
          reset();NotificationDetails detail=new NotificationDetails();detail.tag=tag?"tag":null;
          FlutterLocalNotificationsPlugin.showNotification(context,detail);
          check(attempted==(allowed?1:0),"permission guard");
          check(posted==((allowed&&!race)?1:0),"security race");
          check(tagged==((allowed&&tag)?1:0),"tag dispatch");cases++;
        }
        for(boolean repeat:new boolean[]{false,true}) {
          reset();Intent intent=new Intent();intent.repeat=repeat;new Harness().onReceive(context,intent);
          check(attempted==(allowed?1:0),"legacy permission guard");
          check(posted==((allowed&&!race)?1:0),"legacy security race");
          check(cache==(repeat?0:1),"legacy cleanup survives denial/race");cases++;
        }
        reset();Intent intent=new Intent();intent.modern=true;new Harness().onReceive(context,intent);
        check(attempted==(allowed?1:0),"modern permission guard");
        check(posted==((allowed&&!race)?1:0),"modern security race");
        check(next==1,"modern recurring schedule survives denial/race");cases++;
      }
    System.out.println("notification delivery cases="+cases);
  }
}
'''


if __name__ == "__main__":
    unittest.main()
