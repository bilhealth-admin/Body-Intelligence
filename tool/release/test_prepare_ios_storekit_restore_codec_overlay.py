"""Actual StoreKit overlay helper regressions; standard-library Python only.

Uses an exact hash-pinned official Swift fixture, not a real PUB_CACHE or SDK.
Every prepare call executes the production helper against disposable filesystem
fixtures outside the checkout. Windows uses actual directory junctions; POSIX
uses actual directory symlinks for the equivalent raw-path guard.
"""
from __future__ import annotations
import copy,hashlib,json,os,shutil,subprocess,sys,tempfile,types,unittest
from pathlib import Path

HERE=Path(__file__).resolve().parent
HELPER=HERE/"prepare_ios_storekit_restore_codec_overlay.py"
FIXTURES=HERE/"fixtures"/"storekit_0_4_13_plus_1"
REL=Path("darwin/in_app_purchase_storekit/Sources/in_app_purchase_storekit/StoreKit2/InAppPurchasePlugin+StoreKit2.swift")
BEFORE="ee03daa8c3006114b2dc38d6c50b5730bfd89b6c849e419e26d90f2d1fc56304"
AFTER="be93cbd553c31c89d2aef0bfc021180da4bc70c43809fbf7c0e76e156b142bf2"
ARCHIVE="8e4c0523b5bbac99e87a2d4cd9ece58958166e3ef5fa5b2ed96b2de936d89c71"
PLUGIN="in_app_purchase_storekit"
def digest(value):return hashlib.sha256(value).hexdigest()
def tree(root):
 return {p.relative_to(root).as_posix():digest(p.read_bytes()) for p in root.rglob("*") if p.is_file()}
def write_json(path,value):path.write_text(json.dumps(value,indent=2)+"\n",encoding="utf-8")
# Compile the real helper unchanged; avoid importing it through a cache writer.
H=types.ModuleType("actual_storekit_overlay_helper_under_test")
H.__file__=str(HELPER)
exec(compile(HELPER.read_bytes(),str(HELPER),"exec"),H.__dict__)
SWIFT=(FIXTURES/"InAppPurchasePlugin+StoreKit2.swift").read_bytes()
FIXTURE_LICENSE=(FIXTURES/"LICENSE").read_bytes()
FIXTURE_MANIFEST=tree(FIXTURES)

class OverlayActualTests(unittest.TestCase):
 @classmethod
 def setUpClass(cls):
  if H.VERSION!="0.4.13+1" or H.BEFORE_SHA!=BEFORE or H.AFTER_SHA!=AFTER or H.LOCK_ARCHIVE_SHA!=ARCHIVE:
   raise RuntimeError("Exact official StoreKit version/hash contract drift")
  if digest(SWIFT)!=BEFORE:
   raise RuntimeError("Actual official Swift fixture preimage drift")
 def setUp(self):
  self.work_root=Path(tempfile.gettempdir()).resolve()
  self.temp=tempfile.TemporaryDirectory(prefix="storekit-actual-")
  self.base=Path(self.temp.name).resolve();self.project=self.base/"app";self.project.mkdir()
  self.source=self.base/"synthetic-pub-cache"/"in_app_purchase_storekit-0.4.13+1"
  self.make_package(self.source)
  dart=self.project/".dart_tool";dart.mkdir()
  self.config_path=dart/"package_config.json"
  self.graph_path=self.project/".flutter-plugins-dependencies"
  self.lock_path=self.project/"pubspec.lock"
  self.destination=dart/"bil_release_plugin_overrides"/PLUGIN
  self.other_paths={}
  for name in ("google_mobile_ads","mobile_scanner"):
   root=dart/"bil_release_plugin_overrides"/name;root.mkdir(parents=True)
   (root/"preserved.overlay").write_bytes(("existing-reviewed-"+name).encode())
   self.other_paths[name]=root
  self.config={"configVersion":2,"generator":"pub","packages":[
   {"name":"synthetic_app","rootUri":"../","packageUri":"lib/","languageVersion":"3.5"},
   {"name":PLUGIN,"rootUri":self.source.as_uri(),"packageUri":"lib/","languageVersion":"3.5"},
   *[{"name":name,"rootUri":"bil_release_plugin_overrides/"+name+"/","packageUri":"lib/","languageVersion":"3.5"} for name in self.other_paths]]}
  row=lambda name,path:{"name":name,"path":str(path)+os.sep,"native_build":True,"dependencies":[],"shared_darwin_source":True}
  self.graph={"info":"synthetic-no-secrets","plugins":{
   "ios":[row(PLUGIN,self.source),*[row(name,p) for name,p in self.other_paths.items()]],
   "macos":[row(PLUGIN,self.source)],"android":[{"name":"mobile_scanner","path":"synthetic-preserved-android","native_build":True}]},"dependencyGraph":[{"name":PLUGIN,"dependencies":[]}],"date_created":"synthetic-fixed"}
  write_json(self.config_path,self.config);write_json(self.graph_path,self.graph)
  self.lock="packages:\n  in_app_purchase_storekit:\n    dependency: transitive\n    description:\n      name: in_app_purchase_storekit\n      sha256: \""+ARCHIVE+"\"\n      url: \"https://pub.dev\"\n    source: hosted\n    version: \"0.4.13+1\"\n"
  self.lock_path.write_text(self.lock,encoding="utf-8")
  self.initial_config=self.config_path.read_bytes();self.initial_graph=self.graph_path.read_bytes()
  if os.name!="nt":self.make_native_graph()
  self.cache_manifest=tree(self.source)
  self.ads_manifests={name:tree(p) for name,p in self.other_paths.items()}
  self.addCleanup(self.cleanup)
 def tearDown(self):
  self.assertEqual(tree(FIXTURES),FIXTURE_MANIFEST,"Tracked official fixtures changed")
 def cleanup(self):
  assert self.base.resolve().is_relative_to(self.work_root)
  self.temp.cleanup()
 def make_package(self,path):
  (path/REL).parent.mkdir(parents=True)
  (path/REL).write_bytes(SWIFT)
  (path/"pubspec.yaml").write_text("name: in_app_purchase_storekit\nversion: 0.4.13+1\n",encoding="utf-8")
  (path/"LICENSE").write_bytes(FIXTURE_LICENSE)
  (path/"README.md").write_bytes(b"Companion bytes must remain unchanged.\n")
  (path/"darwin"/PLUGIN/"Package.swift").write_text('// swift-tools-version: 6.0\nimport PackageDescription\nlet package = Package(name: "in_app_purchase_storekit", products: [], targets: [])\n',encoding="utf-8")
 def make_native_graph(self,alias_name=PLUGIN+"-0.4.13+1",target=None):
  managed=self.project/"ios"/"Flutter"/"ephemeral"/"Packages"
  aliases=managed/".packages";aliases.mkdir(parents=True,exist_ok=True)
  self.native_manifest=managed/"FlutterGeneratedPluginSwiftPackage"/"Package.swift"
  self.native_manifest.parent.mkdir(parents=True,exist_ok=True)
  self.native_alias=aliases/alias_name
  self.junction(self.native_alias,target or self.source/"darwin"/PLUGIN)
  other=self.base/"other-native-package";other.mkdir(exist_ok=True)
  self.other_native_alias=aliases/"unrelated_plugin"
  self.junction(self.other_native_alias,other)
  self.native_manifest.write_text('// swift-tools-version: 6.0\nimport PackageDescription\nlet package = Package(name: "FlutterGeneratedPluginSwiftPackage", dependencies: [\n  .package(name: "unrelated_plugin", path: "../.packages/unrelated_plugin"),\n  .package(name: "in_app_purchase_storekit", path: "../.packages/'+alias_name+'"),\n])\n',encoding="utf-8")
 def config_obj(self):return json.loads(self.config_path.read_bytes())
 def graph_obj(self):return json.loads(self.graph_path.read_bytes())
 def set_roots(self,root):
  config=self.config_obj();next(p for p in config["packages"] if p["name"]==PLUGIN)["rootUri"]=root.as_uri();write_json(self.config_path,config)
  graph=self.graph_obj()
  for platform in ("ios","macos"):
   for row in graph["plugins"][platform]:
    if row["name"]==PLUGIN:row["path"]=str(root)+os.sep
  write_json(self.graph_path,graph)
 def prepare(self):
  before=tree(self.source)
  try:return H.prepare(self.project)
  finally:self.assertEqual(tree(self.source),before,"Helper wrote to synthetic PUB_CACHE")
 def assert_other_overlays(self):
  for name,p in self.other_paths.items():self.assertEqual(tree(p),self.ads_manifests[name])
  config=self.config_obj();other=[x for x in config["packages"] if x["name"]!=PLUGIN]
  self.assertEqual(other,[x for x in self.config["packages"] if x["name"]!=PLUGIN])
  graph=self.graph_obj();original=copy.deepcopy(self.graph)
  for platform in ("ios","macos"):
   graph["plugins"][platform]=[x for x in graph["plugins"].get(platform,[]) if x["name"]!=PLUGIN]
   original["plugins"][platform]=[x for x in original["plugins"].get(platform,[]) if x["name"]!=PLUGIN]
  self.assertEqual(graph,original)
 def assert_rejected_no_writes(self,call=None):
  source_before=tree(self.source);project_before=tree(self.project)
  with self.assertRaises(ValueError):(call or self.prepare)()
  self.assertEqual(tree(self.source),source_before,"Helper wrote to synthetic PUB_CACHE")
  self.assertEqual(tree(self.project),project_before,"A rejection changed project metadata/overlay bytes")
 def assert_bound(self):
  entry=next(x for x in self.config_obj()["packages"] if x["name"]==PLUGIN)
  self.assertEqual(entry["rootUri"],"bil_release_plugin_overrides/in_app_purchase_storekit/")
  for platform in ("ios","macos"):
   for row in self.graph_obj()["plugins"].get(platform,[]):
    if row["name"]==PLUGIN:self.assertEqual(Path(row["path"]).resolve(),self.destination.resolve())
 def junction(self,link,target):
  if os.name!="nt":
   link.symlink_to(target,target_is_directory=True)
   self.assertTrue(link.is_symlink())
   return
  quote=lambda p:"'"+str(p).replace("'","''")+"'"
  command="New-Item -ItemType Junction -Path "+quote(link)+" -Target "+quote(target)+" | Out-Null"
  result=subprocess.run(["powershell.exe","-NoProfile","-NonInteractive","-Command",command],capture_output=True,text=True,timeout=15)
  if result.returncode:self.fail("Windows junction creation unavailable; exit="+str(result.returncode))
  self.assertTrue(getattr(link.lstat(),"st_file_attributes",0)&0x400,"Actual reparse fixture was not a junction")
 def test_prepare_changes_only_exact_swift_and_owned_metadata(self):
  result=self.prepare();self.assertEqual(result["status"],"prepared")
  dst=tree(self.destination);marker=dst.pop(".bil-storekit-restore-codec.json")
  changed={p for p in self.cache_manifest if self.cache_manifest[p]!=dst.get(p)}
  self.assertEqual(set(dst),set(self.cache_manifest));self.assertEqual(changed,{REL.as_posix()})
  self.assertEqual(dst[REL.as_posix()],AFTER);self.assertEqual(tree(self.source),self.cache_manifest)
  self.assert_bound();self.assert_other_overlays()
 def test_repeat_is_byte_idempotent(self):
  self.prepare();before=tree(self.project)
  self.assertEqual(self.prepare()["status"],"already-prepared");self.assertEqual(tree(self.project),before)
 def test_actual_cli_uses_the_same_prepare_function(self):
  p=subprocess.run([sys.executable,str(HELPER),"--project-root",str(self.project)],capture_output=True,text=True,timeout=15)
  self.assertEqual(p.returncode,0,p.stderr);self.assertEqual(json.loads(p.stdout)["status"],"prepared");self.assert_bound();self.assertEqual(tree(self.source),self.cache_manifest)
 def test_pub_get_reset_rebinds_verified_existing_overlay_without_recopy(self):
  self.prepare();overlay=tree(self.destination);bound=(self.config_path.read_bytes(),self.graph_path.read_bytes())
  self.config_path.write_bytes(self.initial_config);self.graph_path.write_bytes(self.initial_graph)
  self.assertEqual(self.prepare()["status"],"rebound")
  self.assertEqual(tree(self.destination),overlay);self.assertEqual(tree(self.source),self.cache_manifest)
  self.assertEqual((self.config_path.read_bytes(),self.graph_path.read_bytes()),bound)
  self.assert_other_overlays();self.assertEqual(self.prepare()["status"],"already-prepared")
 def test_graph_only_pub_get_reset_rebinds_canonical_origin(self):
  self.prepare();overlay=tree(self.destination);self.graph_path.write_bytes(self.initial_graph)
  self.assertEqual(self.prepare()["status"],"rebound");self.assertEqual(tree(self.destination),overlay);self.assert_bound()
 def test_literal_percent_path_round_trips_once(self):
  new=self.base/"cache literal %20 directory";assert self.source.resolve().is_relative_to(self.base.resolve()) and new.parent.resolve()==self.base.resolve();self.source.rename(new);self.source=new;self.set_roots(new)
  if os.name!="nt":
   # Moving this owned fixture also moves its native package. Keep its
   # generated alias coherent; the helper must still reject a dangling link.
   self.assertTrue(self.native_alias.is_symlink())
   self.assertEqual(self.native_alias.parent,self.project/"ios/Flutter/ephemeral/Packages/.packages")
   self.assertFalse(self.native_alias.exists())
   self.assert_rejected_no_writes()
   self.native_alias.unlink()
   self.native_alias.symlink_to(new/H.NATIVE_PACKAGE,target_is_directory=True)
  self.assertEqual(self.prepare()["status"],"prepared");self.assertEqual(tree(new),self.cache_manifest)
 def test_wrong_lock_version_fails_closed(self):
  self.lock_path.write_text(self.lock.replace('version: "0.4.13+1"','version: "0.4.12"'),encoding="utf-8");self.assert_rejected_no_writes()
 def test_wrong_archive_hash_fails_closed(self):
  self.lock_path.write_text(self.lock.replace(ARCHIVE,"0"*64),encoding="utf-8");self.assert_rejected_no_writes()
 def test_wrong_version_cannot_be_hidden_by_matching_comment(self):
  value=self.lock.replace('version: "0.4.13+1"','version: "0.4.12"\n    # version: "0.4.13+1"')
  self.lock_path.write_text(value,encoding="utf-8");self.assert_rejected_no_writes()
 def test_wrong_hash_cannot_be_hidden_by_matching_comment(self):
  value=self.lock.replace(ARCHIVE,"0"*64)+"    # expected sha256: "+ARCHIVE+"\n"
  self.lock_path.write_text(value,encoding="utf-8");self.assert_rejected_no_writes()
 def test_duplicate_lock_package_block_fails_closed(self):
  self.lock_path.write_text(self.lock+self.lock.split("packages:\n",1)[1],encoding="utf-8");self.assert_rejected_no_writes()
 def test_exact_official_swift_preimage_is_required(self):
  p=self.source/REL;p.write_bytes(p.read_bytes()+b"\n// drift\n");self.assert_rejected_no_writes()
 def test_missing_config_entry_fails_closed(self):
  c=self.config_obj();c["packages"]=[p for p in c["packages"] if p["name"]!=PLUGIN];write_json(self.config_path,c);self.assert_rejected_no_writes()
 def test_duplicate_config_entry_fails_closed(self):
  c=self.config_obj();c["packages"].append(copy.deepcopy(next(p for p in c["packages"] if p["name"]==PLUGIN)));write_json(self.config_path,c);self.assert_rejected_no_writes()
 def mutate_graph(self,platform,kind):
  g=self.graph_obj();rows=g["plugins"][platform];named=[x for x in rows if x["name"]==PLUGIN]
  g["plugins"][platform]=[x for x in rows if x["name"]!=PLUGIN] if kind=="missing" else rows+[copy.deepcopy(named[0])]
  write_json(self.graph_path,g)
 def test_missing_ios_fresh_fails_closed(self):self.mutate_graph("ios","missing");self.assert_rejected_no_writes()
 def test_duplicate_ios_fresh_fails_closed(self):self.mutate_graph("ios","duplicate");self.assert_rejected_no_writes()
 def test_missing_ios_reuse_fails_closed(self):self.prepare();self.mutate_graph("ios","missing");self.assert_rejected_no_writes()
 def test_duplicate_ios_reuse_fails_closed(self):self.prepare();self.mutate_graph("ios","duplicate");self.assert_rejected_no_writes()
 def test_duplicate_macos_fresh_fails_closed(self):self.mutate_graph("macos","duplicate");self.assert_rejected_no_writes()
 def test_duplicate_macos_reuse_fails_closed(self):self.prepare();self.mutate_graph("macos","duplicate");self.assert_rejected_no_writes()
 def test_optional_macos_absence_is_valid(self):
  g=self.graph_obj();g["plugins"]["macos"]=[];write_json(self.graph_path,g);self.assertEqual(self.prepare()["status"],"prepared");self.assert_bound()
 def foreign_graph(self):
  foreign=self.base/"foreign-plugin";self.make_package(foreign)
  g=self.graph_obj();next(x for x in g["plugins"]["ios"] if x["name"]==PLUGIN)["path"]=str(foreign);write_json(self.graph_path,g)
 def test_foreign_graph_path_fresh_fails_closed(self):self.foreign_graph();self.assert_rejected_no_writes()
 def test_foreign_graph_path_reuse_fails_closed(self):self.prepare();self.foreign_graph();self.assert_rejected_no_writes()
 def test_relative_graph_path_fails_closed(self):
  g=self.graph_obj();next(x for x in g["plugins"]["ios"] if x["name"]==PLUGIN)["path"]="relative-plugin";write_json(self.graph_path,g);self.assert_rejected_no_writes()
 def test_remote_package_uri_fails_closed(self):
  c=self.config_obj();next(x for x in c["packages"] if x["name"]==PLUGIN)["rootUri"]="https://example.invalid/plugin";write_json(self.config_path,c);self.assert_rejected_no_writes()
 def test_package_uri_fragment_fails_closed(self):
  c=self.config_obj();next(x for x in c["packages"] if x["name"]==PLUGIN)["rootUri"]+="#fragment";write_json(self.config_path,c);self.assert_rejected_no_writes()
 def test_source_equal_project_is_rejected(self):self.set_roots(self.project);self.assert_rejected_no_writes()
 def test_source_inside_project_is_rejected(self):
  inside=self.project/"invalid-cache";self.make_package(inside);self.set_roots(inside);self.assert_rejected_no_writes()
 def test_source_ancestor_of_destination_is_rejected(self):
  self.set_roots(self.base);self.assert_rejected_no_writes()
 def test_source_junction_alias_cannot_be_hidden_by_resolve(self):
  alias=self.base/"cache-alias";self.junction(alias,self.source);self.set_roots(alias);self.assert_rejected_no_writes()
 def test_graph_junction_alias_cannot_be_hidden_by_resolve(self):
  alias=self.base/"graph-alias";self.junction(alias,self.source)
  g=self.graph_obj();next(x for x in g["plugins"]["ios"] if x["name"]==PLUGIN)["path"]=str(alias);write_json(self.graph_path,g);self.assert_rejected_no_writes()
 def test_destination_junction_is_rejected(self):
  self.junction(self.destination,self.source);self.assert_rejected_no_writes()
 def test_project_junction_input_is_rejected(self):
  alias=self.base/"project-alias";self.junction(alias,self.project);self.assert_rejected_no_writes(lambda:H.prepare(alias))
 def test_parent_overlay_junction_is_rejected(self):
  parent=self.destination.parent;outside=self.base/"outside-overlay";outside.mkdir()
  # Preserve all original overlays; this test uses a fresh additional project.
  p2=self.base/"second-app";shutil.copytree(self.project,p2)
  old_parent=p2/".dart_tool"/"bil_release_plugin_overrides";assert old_parent.resolve().is_relative_to(p2.resolve()) and p2.resolve().is_relative_to(self.base.resolve());shutil.rmtree(old_parent)
  self.junction(old_parent,outside);self.assert_rejected_no_writes(lambda:H.prepare(p2));self.assertEqual(list(outside.iterdir()),[])
 def test_unmarked_existing_destination_is_not_overwritten(self):
  self.destination.mkdir();(self.destination/"owned-by-someone-else").write_bytes(b"preserve");self.assert_rejected_no_writes()
 def test_overlay_swift_drift_fails_closed(self):
  self.prepare();p=self.destination/REL;p.write_bytes(p.read_bytes()+b"\n// tampered");self.assert_rejected_no_writes()
 def test_overlay_companion_and_forged_marker_cannot_self_authorize(self):
  self.prepare();p=self.destination/"README.md";p.write_bytes(b"forged")
  marker=self.destination/".bil-storekit-restore-codec.json";m=json.loads(marker.read_bytes());m["files"]["README.md"]=digest(p.read_bytes());write_json(marker,m);self.assert_rejected_no_writes()
 def test_original_cache_companion_drift_invalidates_reuse(self):
  self.prepare();(self.source/"README.md").write_bytes(b"source companion drift");self.assert_rejected_no_writes()
 def test_marker_recipe_drift_is_rejected(self):
  self.prepare();m=self.destination/".bil-storekit-restore-codec.json";v=json.loads(m.read_bytes());v["recipe"]="unapproved";write_json(m,v);self.assert_rejected_no_writes()
 def test_stale_config_atomic_temp_rejects_before_any_write(self):
  self.config_path.with_name(self.config_path.name+".bil-storekit-codec-new").write_bytes(b"preserve unknown temp");self.assert_rejected_no_writes()
 def test_stale_graph_atomic_temp_rejects_before_any_write(self):
  self.graph_path.with_name(self.graph_path.name+".bil-storekit-codec-new").write_bytes(b"preserve unknown temp");self.assert_rejected_no_writes()


def load_tests(loader,tests,pattern):
 suite=loader.loadTestsFromTestCase(OverlayActualTests)
 if suite.countTestCases()!=41:
  raise RuntimeError("Expected exactly41 actual helper regressions; refusing empty/partial discovery")
 return suite

if __name__=="__main__":
 unittest.main(verbosity=2)
