"""Import/reverify only visually reviewed Community PNG references.
Already committed matching images never depend on the temporary artifact.
No font, other image, application source or test assertion is imported.
"""
import hashlib
import io
import json
from pathlib import Path
import subprocess
import zipfile

record=Path('tool/sapphire/reviewed_community_goldens.json')
if not record.exists():
    raise SystemExit('Reviewed Community reference record is missing')
r=json.loads(record.read_text(encoding='utf-8'))
assert r['status']=='VISUALLY_REVIEWED_REFERENCE_CANDIDATE'
inputs=r['input_git_objects']
assert set(inputs)=={'lib','assets','pubspec.yaml','pubspec.lock',
 'test/visual_closure/actual_production_pages_golden_test.dart',
 'test/visual_closure/visual_evidence_font.dart'}
subprocess.run(['git','diff','--exit-code','HEAD','--',*inputs],check=True)
for path,oid in inputs.items():
    actual=subprocess.check_output(['git','rev-parse',f'HEAD:{path}']).decode().strip()
    assert actual==oid,f'Visual source changed after review: {path}'
images=r['image_sha256']
assert len(images)==14
for path in images:
    p=Path(path)
    assert p.parent.as_posix()=='test/visual_closure/goldens'
    assert p.name.startswith('visual_closure_community_') and p.suffix=='.png'
    assert '..' not in p.parts and not p.is_absolute()
def digest(data):return hashlib.sha256(data).hexdigest()
if all(Path(p).is_file() and digest(Path(p).read_bytes())==h for p,h in images.items()):
    print('REVIEWED_COMMUNITY_REFERENCES=VERIFIED_ALREADY_COMMITTED')
    raise SystemExit(0)
artifact=int(r['artifact_id'])
blob=subprocess.check_output(['gh','api',f'repos/bilhealth-admin/Body-Intelligence/actions/artifacts/{artifact}/zip'])
assert digest(blob)==r['archive_sha256'],'Reference artifact digest mismatch'
prepared={}
with zipfile.ZipFile(io.BytesIO(blob)) as z:
    for path,expected in images.items():
        info=z.getinfo('images/'+Path(path).name)
        assert 0<info.file_size<8000000
        data=z.read(info)
        assert data.startswith(b'\x89PNG\r\n\x1a\n')
        assert digest(data)==expected,f'Reference image changed: {path}'
        prepared[Path(path)]=data
for path,data in prepared.items():path.write_bytes(data)
print(f'REVIEWED_COMMUNITY_REFERENCES=IMPORTED_{len(prepared)}')
print('STRICT_FULL_SUITE_STILL_REQUIRED')
