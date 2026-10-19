"""Detect source/deployed ledger changes without replaying historical migrations."""
import argparse
import hashlib
import json
from pathlib import Path


def validate(policy, remote, migration_dir):
    if isinstance(remote, dict):
        remote = remote.get('rows')
    if not isinstance(remote, list) or not remote:
        raise ValueError('Live management query returned no migration ledger')
    keys = ('version', 'name', 'statements_md5')
    def indexed(rows):
        result = {}
        for row in rows:
            value = tuple(row[key] for key in keys)
            if value[0] in result:
                raise ValueError('Duplicate deployment migration version')
            result[value[0]] = value
        return result
    if indexed(remote) != indexed(policy['deployed_ledger']):
        raise ValueError('Deployed migration ledger changed; review SQL before updating baseline')
    local = {p.name: hashlib.sha256(p.read_bytes().replace(b'\r\n', b'\n')).hexdigest()
             for p in sorted(Path(migration_dir).glob('*.sql'))}
    if local != policy['local_sql_sha256_lf']:
        raise ValueError('Local migration source changed; review deployment compatibility')
    return {'status': 'PASS', 'local_files': len(local), 'deployed_rows': len(remote),
            'scope': policy['scope'], 'runtime_verified': False}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('live_json', type=Path)
    parser.add_argument('--policy', type=Path, default=Path(__file__).with_name('cloud_deployment_ledger.json'))
    parser.add_argument('--migrations', type=Path, default=Path('supabase/migrations'))
    args = parser.parse_args()
    print(json.dumps(validate(json.loads(args.policy.read_text()),
                              json.loads(args.live_json.read_text(encoding='utf-8-sig')),
                              args.migrations)))


if __name__ == '__main__':
    main()
