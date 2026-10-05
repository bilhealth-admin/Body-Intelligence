#!/usr/bin/env python3
"""Build an isolated ODbL review catalog; never write to BIL Production.

--input streams a local OFF JSONL daily export. --sample makes two bounded
reads for Iraq/Jordan. Country tags identify markets, not manufacturing origin.
"""
from __future__ import annotations
import argparse
from collections import Counter
from datetime import datetime, timezone
import gzip
import hashlib
import json
import math
from pathlib import Path
import re
import sqlite3
import time
import urllib.error
import urllib.parse
import urllib.request

MARKETS = {'en:iraq', 'en:jordan'}
SOURCE = 'https://world.openfoodfacts.org'
UA = 'BIL/1.0 (support@bilhealth.com; regional-catalog-review)'
MAX_LINE = 2 * 1024 * 1024
CORE = {'calories': 'energy-kcal', 'protein': 'proteins', 'carbohydrates': 'carbohydrates', 'fat': 'fat'}
MICRO = {'fiber': ('fiber', 1), 'sugar': ('sugars', 1), 'sodium': ('sodium', 1000),
         'potassium': ('potassium', 1000), 'calcium': ('calcium', 1000),
         'magnesium': ('magnesium', 1000), 'phosphorus': ('phosphorus', 1000),
         'iron': ('iron', 1000), 'vitaminc': ('vitamin-c', 1000)}


def gtin(value):
    if not isinstance(value, str) or not re.fullmatch(r'(?:[0-9]{8}|[0-9]{12}|[0-9]{13}|[0-9]{14})', value) or set(value) == {'0'}:
        return None
    total = sum(int(c) * (3 if i % 2 == 0 else 1) for i, c in enumerate(value[-2::-1]))
    return value.zfill(14) if (10 - total % 10) % 10 == int(value[-1]) else None


def amount(value):
    if isinstance(value, bool) or not isinstance(value, (int, float, str)):
        return None
    try:
        result = float(value)
        return result if math.isfinite(result) and result >= 0 else None
    except (ValueError, OverflowError):
        return None


def normalize(product):
    if not isinstance(product, dict):
        return None, 'invalid_object'
    key = gtin(product.get('code'))
    if key is None:
        return None, 'invalid_gtin'
    tags = product.get('countries_tags')
    markets = sorted(MARKETS.intersection(x for x in (tags if isinstance(tags, list) else []) if isinstance(x, str)))
    if not markets:
        return None, 'outside_target_markets'
    if product.get('product_type', 'food') not in ('food', 'product'):
        return None, 'non_food'
    names = {k[len('product_name_'):]: v.strip() for k, v in product.items()
             if k.startswith('product_name_') and isinstance(v, str) and v.strip()}
    name = str(product.get('product_name') or names.get('en') or names.get('ar') or '').strip()
    if not name:
        return None, 'missing_name'
    nutrients = product.get('nutriments')
    nutrients = nutrients if isinstance(nutrients, dict) else {}
    values = {k: amount(nutrients.get(v + '_100g')) for k, v in CORE.items()}
    if values['calories'] is None:
        kj = amount(nutrients.get('energy-kj_100g'))
        if kj is None:
            kj = amount(nutrients.get('energy_100g'))
        values['calories'] = kj / 4.184 if kj is not None else None
    for k, (v, factor) in MICRO.items():
        value = amount(nutrients.get(v + '_100g'))
        values[k] = None if value is None else value * factor
    quantity = str(product.get('quantity') or '').lower()
    unit = str(product.get('product_quantity_unit') or product.get('serving_quantity_unit') or '').lower()
    categories = product.get('categories_tags')
    categories = categories if isinstance(categories, list) else []
    volume = (unit in {'ml', 'cl', 'dl', 'l'} or bool(re.search(r'\d\s*(?:ml|cl|dl|l|مل|لتر)\b', quantity))
              or 'en:beverages' in categories)
    mass = unit in {'g', 'kg'} or bool(re.search(r'\d\s*(?:kg|g|غ|غرام|جم|كغ)\b', quantity))
    status = 'accepted_for_review'
    if volume:
        status = 'volume_basis_needs_review'
    elif not mass:
        status = 'nutrition_basis_unproven'
    elif any(values[k] is None for k in CORE):
        status = 'incomplete_core'
    elif values['calories'] > 1000 or any(values[k] > 100 for k in ('protein', 'carbohydrates', 'fat')):
        status = 'implausible_core'
    elif sum(values[k] for k in ('protein', 'carbohydrates', 'fat')) > 110:
        status = 'implausible_core'
    fingerprint = hashlib.sha256(json.dumps(product, ensure_ascii=False, sort_keys=True, separators=(',', ':')).encode()).hexdigest()
    return {'canonical_gtin': key, 'provider_gtin': product['code'], 'name': name,
            'names': names, 'brand': str(product.get('brands') or ''), 'markets': markets,
            'nutrients': values, 'nutrition_basis': '100g' if mass and not volume else 'unresolved',
            'source': 'open_food_facts', 'source_url': SOURCE + '/product/' + product['code'],
            'license': 'ODbL-1.0', 'verified': False, 'review_status': status,
            'source_sha256': fingerprint,
            'last_modified_t': amount(product.get('last_modified_t')) or 0}, status


SCHEMA = '''
CREATE TABLE catalog_metadata (key TEXT PRIMARY KEY, value TEXT NOT NULL);
CREATE TABLE food (bil_food_id TEXT PRIMARY KEY, name_en TEXT, name_ar TEXT,
  food_kind TEXT NOT NULL, quality_score REAL NOT NULL, updated_at TEXT NOT NULL);
CREATE TABLE alias (alias_id INTEGER PRIMARY KEY, bil_food_id TEXT, language TEXT, name TEXT);
CREATE TABLE nutrient (bil_food_id TEXT, bil_nutrient_id TEXT, amount REAL,
  PRIMARY KEY(bil_food_id,bil_nutrient_id));
CREATE TABLE portion (portion_id INTEGER PRIMARY KEY, bil_food_id TEXT, amount REAL,
  unit_code TEXT, gram_weight REAL);
CREATE TABLE barcode (normalized_gtin TEXT PRIMARY KEY, bil_food_id TEXT, confidence REAL);
CREATE VIRTUAL TABLE food_fts USING fts5(bil_food_id UNINDEXED, name);
CREATE TABLE source_evidence (canonical_gtin TEXT PRIMARY KEY, modified REAL NOT NULL,
  status TEXT NOT NULL, payload TEXT NOT NULL);
CREATE INDEX alias_food ON alias(bil_food_id);
CREATE INDEX portion_food ON portion(bil_food_id);
'''


def sha_file(path):
    digest = hashlib.sha256()
    with path.open('rb') as file:
        for chunk in iter(lambda: file.read(1024 * 1024), b''):
            digest.update(chunk)
    return digest.hexdigest()


def build_catalog(records, output):
    output.mkdir(parents=True, exist_ok=True)
    db_path = output / 'off-iraq-jordan-review.sqlite'
    if db_path.exists():
        raise ValueError('Refusing to overwrite an existing review catalog')
    db = sqlite3.connect(db_path)
    counts = Counter()
    try:
        db.executescript(SCHEMA)
        for product in records:
            normalized, status = normalize(product)
            counts['input_rows'] += 1
            counts[status] += 1
            if normalized is None:
                continue
            db.execute('INSERT INTO source_evidence VALUES (?,?,?,?) ON CONFLICT(canonical_gtin) DO UPDATE SET '
                       'modified=excluded.modified,status=excluded.status,payload=excluded.payload WHERE excluded.modified > source_evidence.modified',
                       (normalized['canonical_gtin'], normalized['last_modified_t'], status,
                        json.dumps(normalized, ensure_ascii=False, allow_nan=False)))
            if counts['input_rows'] % 1000 == 0:
                db.commit()
        now = datetime.now(timezone.utc).isoformat()
        source_rows = db.execute("SELECT canonical_gtin,payload FROM source_evidence WHERE status='accepted_for_review'")
        for key, payload in source_rows:
            p = json.loads(payload)
            identity = 'off:' + key
            # The existing adapter treats >=75 as verified; community data is not.
            db.execute('INSERT INTO food VALUES (?,?,?,?,?,?)',
                       (identity, p['names'].get('en') or p['name'], p['names'].get('ar'), 'branded', 60, now))
            aliases = set(p['names'].items()) | {('und', p['name'])}
            if p['brand']:
                aliases.add(('und', p['brand'] + ' ' + p['name']))
            db.executemany('INSERT INTO alias(bil_food_id,language,name) VALUES (?,?,?)',
                           [(identity, lang, name) for lang, name in sorted(aliases)])
            db.executemany('INSERT INTO nutrient VALUES (?,?,?)',
                           [(identity, k, v) for k, v in p['nutrients'].items() if v is not None])
            db.execute('INSERT INTO portion(bil_food_id,amount,unit_code,gram_weight) VALUES (?,100,\'g\',100)', (identity,))
            for length in (8, 12, 13, 14):
                candidate = key[-length:]
                if key[:-length].strip('0') == '' and gtin(candidate) == key:
                    db.execute('INSERT INTO barcode VALUES (?,?,?)', (candidate, identity, 0.6))
            db.execute('INSERT INTO food_fts VALUES (?,?)', (identity, ' '.join(sorted({n for _, n in aliases}))))
        metadata = {'profile': json.dumps({'profile_id': 'off-iraq-jordan-review'}),
                    'source': 'Open Food Facts contributors', 'license': 'ODbL-1.0',
                    'publication_status': 'REVIEW_ONLY', 'verified': 'false',
                    'market_scope': 'Iraq and Jordan; not country of manufacture', 'created_at': now}
        db.executemany('INSERT INTO catalog_metadata VALUES (?,?)', metadata.items())
        db.commit()
        unique = db.execute('SELECT count(*) FROM source_evidence').fetchone()[0]
        accepted = db.execute('SELECT count(*) FROM food').fetchone()[0]
        aliases_count = db.execute('SELECT count(*) FROM barcode').fetchone()[0]
        assert db.execute('PRAGMA integrity_check').fetchone()[0] == 'ok'
    finally:
        db.close()
    report = {'status': 'REVIEW_ONLY', 'input_outcomes': dict(counts), 'unique_products': unique,
              'nutrition_complete_mass_basis_products': accepted, 'barcode_forms': aliases_count,
              'published_to_app': False, 'complete_market_coverage': False,
              'translation_quality_certified': False, 'database_sha256': sha_file(db_path)}
    (output / 'import-report.json').write_text(json.dumps(report, indent=2, ensure_ascii=False) + '\n')
    (output / 'LICENSE-AND-ATTRIBUTION.txt').write_text(
        'Contains data from Open Food Facts contributors: https://world.openfoodfacts.org/\n'
        'Database license: ODbL 1.0 https://opendatacommons.org/licenses/odbl/1-0/\n'
        'Database contents: https://opendatacommons.org/licenses/dbcl/1-0/\n'
        'This separate derivative review database requires attribution and ODbL share-alike on redistribution.\n'
        'No images or private BIL data. Do not merge into proprietary datasets without licence review.\n'
        'No nutrition or translation is independently verified.\n'
        'Do not publish before source attribution is visible in the app and sample labels are reviewed.\n')
    return report


def read_jsonl(path):
    opener = gzip.open if path.suffix == '.gz' else open
    with opener(path, 'rb') as stream:
        while True:
            line = stream.readline(MAX_LINE + 1)
            if not line:
                break
            if len(line) > MAX_LINE:
                raise ValueError('Export record exceeds safety limit')
            if line.strip():
                yield json.loads(line)


def collect_sample(output):
    """Two data-acquisition reads, not load tests; no writes or retry storms."""
    output.mkdir(parents=True, exist_ok=True)
    fields = ('code,product_name,product_name_ar,product_name_en,brands,countries_tags,categories_tags,'
              'product_type,nutriments,quantity,product_quantity_unit,serving_quantity_unit,last_modified_t')
    collection = []
    products = []
    for index, market in enumerate(('iraq', 'jordan')):
        if index:
            time.sleep(6.5)
        url = SOURCE + '/api/v2/search?' + urllib.parse.urlencode({
            'countries_tags_en': market, 'page_size': 50, 'page': 1, 'fields': fields})
        item = {'market': market, 'url': url, 'complete': False}
        try:
            req = urllib.request.Request(url, headers={'User-Agent': UA, 'Accept': 'application/json'})
            with urllib.request.urlopen(req, timeout=35) as response:
                data = response.read(8 * 1024 * 1024 + 1)
            if len(data) > 8 * 1024 * 1024:
                raise ValueError('Provider response too large')
            root = json.loads(data)
            rows = root.get('products')
            if not isinstance(rows, list) or len(rows) > 50:
                raise ValueError('Invalid provider list')
            item.update(status='retrieved', rows=len(rows), total_provider_matches=root.get('count'),
                        response_sha256=hashlib.sha256(data).hexdigest())
            products.extend(rows)
        except (urllib.error.URLError, TimeoutError, ValueError, OSError) as error:
            item.update(status='unavailable', error_type=type(error).__name__)
        collection.append(item)
    (output / 'source-collection.json').write_text(json.dumps(collection, indent=2) + '\n')
    path = output / 'off-regional-source.jsonl'
    with path.open('w', encoding='utf-8') as file:
        for product in products:
            file.write(json.dumps(product, ensure_ascii=False, allow_nan=False) + '\n')
    return path, all(row['status'] == 'retrieved' for row in collection)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    source = parser.add_mutually_exclusive_group(required=True)
    source.add_argument('--input', type=Path)
    source.add_argument('--sample', action='store_true')
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    available = True
    path = args.input
    if args.sample:
        path, available = collect_sample(args.output)
    report = build_catalog(read_jsonl(path), args.output)
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 0 if available else 2


if __name__ == '__main__':
    raise SystemExit(main())
