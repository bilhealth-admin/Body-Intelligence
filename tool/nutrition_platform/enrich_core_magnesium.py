"""Add evidenced USDA magnesium without changing existing catalog food values.

Download the exact official archives in the provenance manifest separately.
This command writes a new output file and never overwrites its source catalog.
"""
import argparse
from contextlib import closing
import csv
import hashlib
import io
import json
import math
from pathlib import Path
import shutil
import sqlite3
import zipfile


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def csv_rows(archive, leaf):
    names = [name for name in archive.namelist() if name.split('/')[-1] == leaf]
    if len(names) != 1:
        raise ValueError(f'Expected one {leaf}')
    with archive.open(names[0]) as stream:
        yield from csv.DictReader(io.TextIOWrapper(stream, encoding='utf-8-sig'))


def observations(path, dataset):
    with zipfile.ZipFile(path) as archive:
        if dataset == 'fndds':
            foods = json.loads(archive.read('surveyDownload.json'))['SurveyFoods']
            for food in foods:
                for entry in food.get('foodNutrients', []):
                    nutrient = entry['nutrient']
                    if nutrient['id'] == 1090:
                        if nutrient['unitName'].upper() != 'MG':
                            raise ValueError('Magnesium unit must be mg')
                        yield int(food['fdcId']), food['description'], entry.get('amount')
        else:
            names = {int(row['fdc_id']): row['description']
                     for row in csv_rows(archive, 'food.csv')}
            for row in csv_rows(archive, 'food_nutrient.csv'):
                if row['nutrient_id'] == '1090':
                    yield int(row['fdc_id']), names[int(row['fdc_id'])], row['amount']


def food_digest(connection, columns):
    digest = hashlib.sha256()
    selected = ','.join('"' + name + '"' for name in columns)
    for row in connection.execute(f'SELECT {selected} FROM foods ORDER BY rowid'):
        digest.update(json.dumps(row, ensure_ascii=True, separators=(',', ':')).encode())
        digest.update(b'\n')
    return digest.hexdigest()


def enrich(catalog, source_dir, output, manifest):
    catalog, source_dir, output = map(Path, (catalog, source_dir, output))
    if output.exists() or catalog.resolve() == output.resolve():
        raise ValueError('Output must be a new file separate from the source')
    if sha(catalog) != manifest['base_catalog_sha256']:
        raise ValueError('Original catalog fingerprint mismatch')
    with closing(sqlite3.connect(f'file:{catalog.as_posix()}?mode=ro', uri=True)) as base:
        columns = [row[1] for row in base.execute('PRAGMA table_info(foods)')]
        original = food_digest(base, columns)
        existing = {int(row[0]): (row[1], row[2]) for row in base.execute(
            'SELECT fdc_id,description,source_dataset FROM foods')}
    values = {}
    for source in manifest['sources']:
        path = source_dir / source['file']
        if sha(path) != source['sha256'] or path.stat().st_size != source['bytes']:
            raise ValueError('USDA archive fingerprint mismatch')
        for identifier, description, raw in observations(path, source['dataset']):
            if identifier not in existing:
                continue
            if existing[identifier] != (description.strip(), source['dataset']):
                raise ValueError(f'Food identity mismatch: {identifier}')
            if raw is None or raw == '':
                continue
            amount = float(raw)
            if not math.isfinite(amount) or amount < 0:
                raise ValueError('Invalid magnesium amount')
            if identifier in values and values[identifier] != amount:
                raise ValueError(f'Conflicting magnesium observations: {identifier}')
            values[identifier] = amount
    if not values:
        raise ValueError('No evidenced magnesium values found')
    shutil.copyfile(catalog, output)
    with closing(sqlite3.connect(output)) as target:
        target.execute('ALTER TABLE foods ADD COLUMN magnesium_mg REAL')
        target.executemany('UPDATE foods SET magnesium_mg=? WHERE fdc_id=?',
                           [(amount, identifier) for identifier, amount in sorted(values.items())])
        target.execute('UPDATE catalog_metadata SET value=? WHERE key=?',
                       (manifest['version'], 'catalog_version'))
        target.execute('INSERT INTO catalog_metadata VALUES(?,?)',
                       ('magnesium_provenance', json.dumps(manifest, sort_keys=True)))
        if food_digest(target, columns) != original:
            raise ValueError('An existing catalog value changed')
        if target.execute('PRAGMA integrity_check').fetchone()[0] != 'ok':
            raise ValueError('Enriched catalog integrity failed')
        count = target.execute('SELECT count(*) FROM foods').fetchone()[0]
        target.commit()
    return {'preserved_food_rows': count, 'preserved_original_columns': columns,
            'preserved_original_values_sha256': original,
            'magnesium_rows': len(values), 'unknown_magnesium_rows': count - len(values),
            'output_sha256': sha(output), 'output_bytes': output.stat().st_size,
            'source_catalog_sha256': sha(catalog), 'source_manifest': manifest}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ('catalog', 'source-dir', 'output', 'manifest', 'report'):
        parser.add_argument('--' + name, type=Path, required=True)
    args = parser.parse_args()
    report = enrich(args.catalog, args.source_dir, args.output,
                    json.loads(args.manifest.read_text(encoding='utf-8')))
    args.report.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({key: value for key, value in report.items()
                      if key not in ('preserved_original_columns', 'source_manifest')}))


if __name__ == '__main__':
    main()
