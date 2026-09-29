"""Prepare ONLY the 14 intentionally redesigned Community reference images.
This job is reference preparation, NOT QA acceptance. Original references remain
in git history. A human/model visual review and a strict subsequent test run are
required before importing these candidate images. No other master can change.
"""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

names = [
 'community_signed_out_phone', 'community_profile_phone',
 'community_connections_phone', 'community_messages_phone',
 'community_profile_authenticated_phone', 'community_hub_authenticated_phone',
 'community_navigation_menu_authenticated_phone', 'community_request_authenticated_phone',
 'community_friend_authenticated_phone', 'community_add_friends_authenticated_phone',
 'community_people_search_authenticated_phone', 'community_inbox_authenticated_phone',
 'community_sent_authenticated_phone', 'community_notifications_empty_authenticated_phone',
]
allowed = {f'test/visual_closure/goldens/visual_closure_{n}.png' for n in names}
assert len(allowed) == 14
out = Path(os.environ['RUNNER_TEMP']) / 'sapphire-community-reference'
out.mkdir(parents=True, exist_ok=True)
flutter = Path(shutil.which('flutter.bat') or shutil.which('flutter')).resolve()
dart = flutter.parent / 'cache/dart-sdk/bin' / ('dart.exe' if os.name == 'nt' else 'dart')
snapshot = flutter.parent / 'cache/flutter_tools.snapshot'
assert dart.is_file() and snapshot.is_file()
source = subprocess.check_output(['git','rev-parse','HEAD']).decode().strip()
inputs = ['lib','assets','pubspec.yaml','pubspec.lock',
 'test/visual_closure/actual_production_pages_golden_test.dart',
 'test/visual_closure/visual_evidence_font.dart']
fingerprints = {p:subprocess.check_output(['git','rev-parse',f'HEAD:{p}']).decode().strip() for p in inputs}
command = [str(dart),str(snapshot),'test','--no-pub','--concurrency','1',
 '--reporter','json','--timeout','90s','--update-goldens',
 'test/visual_closure/actual_production_pages_golden_test.dart','--name','^community ']
with (out/'events.jsonl').open('w',encoding='utf-8') as log, (out/'stderr.log').open('w',encoding='utf-8') as err:
    r = subprocess.run(command, stdout=log, stderr=err, check=False)
changed = subprocess.check_output(['git','diff','--name-only']).decode().splitlines()
assert set(changed).issubset(allowed), f'Unrelated master/source changed: {set(changed)-allowed}'
assert all(Path(p).is_file() for p in allowed)
images={}
for name in sorted(allowed):
    p=Path(name);target=out/'images'/p.name
    target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(p,target)
    images[name]=hashlib.sha256(p.read_bytes()).hexdigest()
patch=subprocess.check_output(['git','diff','--binary','--',*sorted(allowed)])
(out/'community-goldens.patch').write_bytes(patch)
(out/'manifest.json').write_text(json.dumps({'source':source,
 'status':'GENERATED_PENDING_VISUAL_REVIEW_NOT_ACCEPTANCE','exit_code':r.returncode,
 'input_git_objects':fingerprints,'allowed_paths':sorted(allowed),'changed_paths':changed,
 'image_sha256':images,'patch_sha256':hashlib.sha256(patch).hexdigest(),
 'platform':sys.platform,'autocrlf':subprocess.check_output(['git','config','--get','core.autocrlf']).decode().strip(),
 'command':command},indent=2)+'\n',encoding='utf-8')
sys.exit(r.returncode)
