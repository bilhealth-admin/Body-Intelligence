"""Execute existing guarded SQL audits with independent residue readback.

Only the seven checked-in synthetic rollback programs are accepted. No DDL,
consent for real users, migration replay or policy bypass is introduced here.
Their existing production body/ACL/trigger prerequisites remain authoritative.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[2]
SQL_FILES = tuple(f'tool/release/{name}_production_rollback_e2e.sql' for name in (
    'ai_consent_receipt', 'cloud_sync_consent', 'community_collaborator_privacy',
    'community_policy_20261019', 'community_prebuild', 'smart_plan_sync', 'coach_memory_sync'))


def segments(source):
    result = {}
    for name in ('PRECHECK', 'TRANSACTION', 'RESIDUE'):
        matches = re.findall(rf'^-- BEGIN SEGMENT {name}\s*\n(.*?)^-- END SEGMENT {name}\s*$',
                             source, re.MULTILINE | re.DOTALL)
        if len(matches) != 1:
            raise ValueError('Missing or duplicated SQL segment: ' + name)
        result[name] = matches[0].strip()
    transaction = result['TRANSACTION']
    without_comments = re.sub(r'--[^\n]*', '', transaction)
    if (not re.match(r'(?i)^begin\s*;', transaction)
            or not re.search(r'(?i)rollback\s*;\s*$', transaction)
            or re.search(r'(?im)^\s*(commit|create|alter|drop|grant|revoke)\s', without_comments)):
        raise ValueError('SQL audit must preserve its rollback-only/no-DDL boundary')
    return result


def one_row(raw):
    value = json.loads(raw)
    rows = value.get('rows') if isinstance(value, dict) else value
    if not isinstance(rows, list) or len(rows) != 1 or not isinstance(rows[0], dict):
        raise ValueError('CLI did not return exactly one actual SQL result row')
    return rows[0]


def inventory(row):
    values = row.get('table_counts', row.get('table_inventory'))
    if isinstance(values, str):
        values = json.loads(values)
    count = row.get('inventoried_table_count')
    if (type(count) is not int or count <= 0 or not isinstance(values, list)
            or len(values) != count or row.get('zero_synthetic_rows') is not True
            or len({v.get('table_name') for v in values}) != count
            or any(type(v.get('synthetic_rows')) is not int or v['synthetic_rows'] != 0 for v in values)):
        raise ValueError('Synthetic residue is nonzero or inventory is incomplete')
    return {v['table_name'] for v in values}


def assertions(row):
    values, count = row.get('completed_assertions'), row.get('completed_assertion_count')
    if isinstance(values, str):
        values = json.loads(values)
    if (row.get('transaction_result') != 'PASS' or row.get('exact_failure') is not None
            or not isinstance(values, dict) or not values or type(count) is not int
            or len(values) != count or any(v is not True for v in values.values())):
        raise ValueError('SQL audit is not a complete assertion PASS')
    return count


def execute(source, query):
    parts = segments(source)
    result = {'status': 'FAIL', 'stage': 'precheck'}
    before = None
    try:
        before = inventory(one_row(query(parts['PRECHECK'])))
        result['stage'] = 'transaction'
        result['assertions'] = assertions(one_row(query(parts['TRANSACTION'])))
        result['status'] = 'PASS'
    finally:
        # A failed/malformed/timeout transaction never suppresses cleanup readback.
        after = inventory(one_row(query(parts['RESIDUE'])))
        if before is not None and before != after:
            raise ValueError('Precheck and independent residue inventories differ')
        result['residue_verified'] = True
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    if not os.environ.get('SUPABASE_ACCESS_TOKEN') or not re.fullmatch('[0-9a-f]{40}', os.environ.get('GITHUB_SHA', '')):
        raise SystemExit('Actual source and Supabase CI credentials are required')
    args.output.mkdir(parents=True, exist_ok=True)
    cli = shutil.which('npx')
    if not cli:
        raise SystemExit('Pinned Supabase CLI bootstrap is unavailable')
    def query(sql):
        completed = subprocess.run([cli, '--yes', 'supabase@2.121.0', 'db', 'query',
            '--project-ref', 'tgmanzhqulksykhslrzb', '--linked', '--output', 'json'],
            input=sql, text=True, encoding='utf8', stdout=subprocess.PIPE,
            stderr=subprocess.PIPE, timeout=120, cwd=ROOT)
        if completed.returncode:
            raise RuntimeError('Guarded SQL CLI failed; no result is inferred from process output')
        return completed.stdout
    failed = False
    for name in SQL_FILES:
        source = (ROOT / name).read_text(encoding='utf-8-sig').replace('\r\n', '\n')
        report = dict(source_sha=os.environ['GITHUB_SHA'], sql_file=name,
                      sql_sha256_lf=hashlib.sha256(source.encode()).hexdigest(), status='FAIL')
        try:
            report.update(execute(source, query))
        except Exception as exc:
            failed = True
            report['error_type'] = type(exc).__name__
            report['error'] = str(exc)  # Only local validator messages; never raw SQL/CLI credentials.
        (args.output / (Path(name).stem + '.json')).write_text(json.dumps(report, indent=2) + '\n', encoding='utf8')
        print(name, report['status'])
    if failed:
        raise SystemExit('At least one guarded SQL E2E did not pass; signing is blocked')
    print('GUARDED_POLICY_CLOUD_E2E=PASS;INDEPENDENT_RESIDUE=PASS')


if __name__ == '__main__':
    main()
