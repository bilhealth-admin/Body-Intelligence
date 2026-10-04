#!/usr/bin/env python3
"""Read-only, dependency-free validation of recipe content in all 25 locales.

This checks content structure and release hashes, NOT translation accuracy,
culinary authenticity, nutrition accuracy, images, or native UI behaviour.
"""
from __future__ import annotations

import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
from typing import Any

LOCALES = (
    'ar', 'en', 'fr', 'es', 'tr', 'de', 'it', 'pt-BR', 'pt-PT', 'ur',
    'fa', 'hi', 'id', 'ms', 'ja', 'ko', 'zh-Hans', 'zh-Hant', 'ru',
    'bn', 'vi', 'th', 'pl', 'nl', 'uk',
)
MANIFEST = 'assets/catalogs/recipes/v1/release-manifest.json'


def _object(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise ValueError(f'Duplicate JSON key: {key}')
        result[key] = value
    return result


def _read(root: Path, relative: str, size: int | None = None,
          sha256: str | None = None) -> Any:
    target = (root / relative).resolve()
    if not target.is_relative_to(root.resolve()):
        raise ValueError('Catalog path escapes repository root')
    data = target.read_bytes()
    if len(data) > 32 * 1024 * 1024:
        raise ValueError(f'Catalog object too large: {relative}')
    if size is not None and len(data) != size:
        raise ValueError(f'Size mismatch: {relative}')
    if sha256 is not None and hashlib.sha256(data).hexdigest() != sha256:
        raise ValueError(f'SHA256 mismatch: {relative}')
    return json.loads(data, object_pairs_hook=_object,
                      parse_constant=lambda value: (_ for _ in ()).throw(
                          ValueError(f'Invalid JSON number: {value}')))


def validate_record(record: dict[str, Any], entry: dict[str, Any]) -> None:
    identity = record.get('canonicalId')
    if not isinstance(identity, str) or not identity:
        raise ValueError('Missing canonicalId')
    if entry.get('canonical_id') != identity:
        raise ValueError(f'Index identity mismatch: {identity}')
    if record.get('contentFingerprint') != entry.get('content_fingerprint'):
        raise ValueError(f'Index fingerprint mismatch: {identity}')
    localizations = record.get('localizations')
    if not isinstance(localizations, dict):
        raise ValueError(f'Missing localizations: {identity}')
    if not set(LOCALES).issubset(localizations):
        raise ValueError(f'Missing locale: {identity}')
    if record.get('primaryLocale') not in LOCALES:
        raise ValueError(f'Unsupported primary locale: {identity}')
    ingredients, method = record.get('ingredients'), record.get('method')
    if not isinstance(ingredients, list) or not ingredients:
        raise ValueError(f'Missing ingredients: {identity}')
    if not isinstance(method, list) or not method:
        raise ValueError(f'Missing method: {identity}')
    titles = entry.get('localized_titles')
    if not isinstance(titles, dict):
        raise ValueError(f'Missing index titles: {identity}')
    for locale in LOCALES:
        value = localizations[locale]
        if not isinstance(value, dict):
            raise ValueError(f'Invalid localization: {identity}/{locale}')
        title = value.get('title')
        if not isinstance(title, str) or not title.strip():
            raise ValueError(f'Empty title: {identity}/{locale}')
        if titles.get(locale) != title:
            raise ValueError(f'Index title mismatch: {identity}/{locale}')
        for key, count in [('ingredients', len(ingredients)), ('steps', len(method))]:
            texts = value.get(key)
            if (not isinstance(texts, list) or len(texts) != count or
                    any(not isinstance(text, str) or not text.strip() for text in texts)):
                raise ValueError(f'Incomplete {key}: {identity}/{locale}')
        status = value.get('translationStatus')
        if not isinstance(status, str) or not status.strip():
            raise ValueError(f'Missing translation provenance: {identity}/{locale}')


def audit(root: Path) -> dict[str, Any]:
    manifest = _read(root, MANIFEST)
    index = _read(root, manifest['index_path'], manifest['index_size_bytes'],
                  manifest['index_sha256'])
    entries = index['entries']
    by_id = {entry['canonical_id']: entry for entry in entries}
    if len(by_id) != len(entries):
        raise ValueError('Duplicate recipe index ID')
    seen: set[str] = set()
    primary: Counter[str] = Counter()
    statuses: Counter[str] = Counter()
    coverage: Counter[str] = Counter()
    for shard in manifest['shards']:
        records = _read(root, shard['path'], shard['size_bytes'], shard['sha256'])['records']
        if len(records) != shard['count']:
            raise ValueError(f'Shard count mismatch: {shard["path"]}')
        for record in records:
            identity = record['canonicalId']
            if identity in seen:
                raise ValueError(f'Duplicate recipe: {identity}')
            entry = by_id.get(identity)
            if entry is None or entry['shard'] != shard['ordinal']:
                raise ValueError(f'Missing/wrong shard index: {identity}')
            validate_record(record, entry)
            seen.add(identity)
            primary[record['primaryLocale']] += 1
            for locale in LOCALES:
                coverage[locale] += 1
                statuses[record['localizations'][locale]['translationStatus']] += 1
    if len(seen) != manifest['record_count'] or seen != set(by_id):
        raise ValueError('Release record count/index membership mismatch')
    return {
        'check': 'recipe_25_locale_content_structure',
        'status': 'PASS',
        'recipes': len(seen),
        'locale_count': len(LOCALES),
        'localized_records': sum(coverage.values()),
        'recipes_per_locale': dict(sorted(coverage.items())),
        'primary_locale_counts': dict(sorted(primary.items())),
        'declared_translation_status_counts': dict(sorted(statuses.items())),
        'index_sha256': manifest['index_sha256'],
        'shards_checked': len(manifest['shards']),
        'translation_accuracy_certified': False,
        'nutrition_accuracy_certified': False,
        'native_ui_tested': False,
        'catalog_modified': False,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=Path('.'))
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    try:
        report = audit(args.root)
    except (ValueError, OSError, KeyError, TypeError) as error:
        print(json.dumps({'status': 'FAIL', 'error': str(error)}, ensure_ascii=False))
        return 1
    text = json.dumps(report, ensure_ascii=False, indent=2) + '\n'
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(text, encoding='utf-8')
    print(text, end='')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
