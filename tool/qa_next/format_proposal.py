"""Emit a formatter proposal without editing any file under test."""
import difflib
from pathlib import Path
import subprocess
import tempfile

BASE = '3f0085e6e6686f2e87e9cf14789e9e578ea64159'
root = Path.cwd()
out = Path('/tmp/bil-next-qa')
out.mkdir(parents=True, exist_ok=True)
names = subprocess.check_output(
    ['git', 'diff', '--name-only', '-z', BASE, 'HEAD', '--', '*.dart']
).decode().strip('\0').split('\0')
proposal = []
with tempfile.TemporaryDirectory(prefix='bil-format-proposal-') as tmp:
    scratch = Path(tmp)
    for config in ('pubspec.yaml', 'analysis_options.yaml'):
        if (root / config).exists():
            (scratch / config).write_bytes((root / config).read_bytes())
    paths = []
    for name in filter(None, names):
        rel = Path(name)
        if (rel.is_absolute() or '..' in rel.parts or
                not any(rel.is_relative_to(root) for root in ('lib', 'test', 'tool'))):
            raise ValueError('Unexpected formatter path')
        source = root / rel
        if source.is_symlink() or not source.is_file():
            raise ValueError('Formatter accepts existing regular source only')
        dest = scratch / rel
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_bytes(source.read_bytes())
        paths.append(name)
    if paths:
        subprocess.run(['dart', 'format', *paths], cwd=scratch, check=True)
    for name in paths:
        old = (root / name).read_text().splitlines(keepends=True)
        new = (scratch / name).read_text().splitlines(keepends=True)
        if old != new:
            proposal.extend(difflib.unified_diff(old, new, fromfile='a/' + name,
                                               tofile='b/' + name))
(out / 'formatter-proposal.patch').write_text(''.join(proposal))
print('Formatter proposal only; tested source unchanged.')
print(''.join(proposal), end='')
