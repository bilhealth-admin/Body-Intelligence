"""Promote one exact, visually approved PNG. No loop or update-goldens."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import time

ROOT = Path(__file__).resolve().parents[2]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('id', help='exactly one individually reviewed ID')
    args = parser.parse_args()
    review = ROOT / 'build/stage1-closure/all-golden-individual-review'
    index = json.loads((review / 'index.json').read_text(encoding='utf-8'))
    entries = [row for row in index if row['id'] == args.id]
    if len(entries) != 1:
        parser.error('one exact ID required')
    row = entries[0]
    if not row.get('reviewed') or not row.get('decision', '').startswith('accept') or not row.get('review_reason'):
        parser.error('explicit visual approval required')
    target = (ROOT / row['reference']).resolve()
    actual = review / 'cases' / args.id / 'actual.png'
    if not target.is_relative_to(ROOT / 'test') or target.suffix != '.png':
        parser.error('test Golden PNG only')
    if sha(actual) != row['actual_sha256']:
        parser.error('actual raster changed; review again')
    approved_hashes = {row['master_sha256'], row['actual_sha256']}
    approved_hashes.update(p['new_sha256'] for p in row.get('promotion_history', []))
    if sha(target) not in approved_hashes:
        parser.error('unexpected reference change; preserve it')
    if not row.get('promotion'):
        old = sha(target)
        shutil.copyfile(actual, target)
        row['promotion'] = {'timestamp': time.time(), 'old_sha256': old,
                            'new_sha256': sha(target), 'method': 'one explicitly reviewed ID'}
        (review / 'index.json').write_text(json.dumps(index, ensure_ascii=False, indent=2), encoding='utf-8')
    print(json.dumps({'id': args.id, 'reference': row['reference'], 'sha256': sha(target)}, ensure_ascii=True))


if __name__ == '__main__':
    main()
