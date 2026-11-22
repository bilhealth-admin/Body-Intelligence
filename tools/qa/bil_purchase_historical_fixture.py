"""Read canonical purchase source bytes from the frozen 47–49 release fixtures."""
import hashlib
import json
from pathlib import Path

FIXTURES = Path(__file__).resolve().parent / 'fixtures' / 'protected_purchase_history'
METADATA_DIGEST = 'ab8883efd847b46d152a4691c45178be18aa2990d510fb7fab1f63e42549ccb8'


def historical_bytes(version, path):
    metadata = (FIXTURES / 'sources.json').read_bytes()
    if hashlib.sha256(metadata).hexdigest() != METADATA_DIGEST:
        raise ValueError('Historical purchase fixture provenance changed')
    manifest = json.loads(metadata)
    if str(version) not in manifest['versions']:
        raise ValueError('Unknown historical purchase version')
    spec = manifest['files'][path]
    fixture = FIXTURES / spec['fixture']
    data = fixture.read_bytes()
    if fixture.is_symlink() or len(data) != spec['bytes'] or hashlib.sha256(data).hexdigest() != spec['sha256']:
        raise ValueError('Historical purchase fixture content changed')
    return data


def historical_blobs(version, paths):
    observed = {}
    for path in paths:
        data = historical_bytes(version, path)
        observed[path] = hashlib.sha1(b'blob ' + str(len(data)).encode('ascii') + b'\0' + data).hexdigest()
    return observed


def historical_workflow(version):
    if version != 49:
        raise ValueError('Only the historical version49 Crystal workflow is archived')
    return historical_bytes(version, '.github/workflows/bil39-crystal.yml').decode('utf-8')
