#!/usr/bin/env python3
"""Apply a reviewed exact-byte delta, never a fuzzy or unguarded replacement."""
import hashlib
import json
from pathlib import Path

root = Path.cwd()
path = root / 'tool/sapphire/operations.json'
if not path.exists():
    print('No pending source delta; test current committed source.')
    raise SystemExit(0)
operations = json.loads(path.read_text(encoding='utf-8'))
prepared = {}
for name, spec in operations.items():
    target = root / name
    assert not Path(name).is_absolute() and '..' not in Path(name).parts
    assert name.startswith(('lib/', 'test/')) or name == 'pubspec.yaml'
    old = target.read_bytes()
    assert hashlib.sha256(old).hexdigest() == spec['before'], f'Source changed: {name}'
    lines = old.decode('utf-8').splitlines(keepends=True)
    previous = len(lines) + 1
    for start, end, replacement in sorted(spec['edits'], reverse=True):
        assert 0 <= start <= end < previous, f'Overlapping edit: {name}'
        lines[start:end] = replacement.splitlines(keepends=True)
        previous = start + 1
    new = ''.join(lines).encode('utf-8')
    assert hashlib.sha256(new).hexdigest() == spec['after'], f'Delta digest mismatch: {name}'
    prepared[target] = new
# Validate every file before writing any file.
for target, data in prepared.items():
    target.write_bytes(data)
receipt = root / 'docs/release/BIL_SAPPHIRE_DELTA_RECEIPT.json'
receipt.write_text(json.dumps({
    'base': '59839c7deb4d1cc860275b9e69578e299cc24d0a',
    'scope': 'Community presentation and health history only; native watch code unchanged',
    'files': {name: {'before': spec['before'], 'after_before_formatter': spec['after']} for name, spec in operations.items()},
    'status': 'SOURCE_APPLIED_NOT_YET_QA_ACCEPTED',
}, indent=2) + '\n')
path.unlink()
print(f'Applied {len(prepared)} exact-source edits; QA is still required.')
