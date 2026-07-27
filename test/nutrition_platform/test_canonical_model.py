from __future__ import annotations
import sqlite3
import tempfile
import unittest
from contextlib import closing
from pathlib import Path
from tool.nutrition_platform.canonical_model import CanonicalFoodStore, SourceLink, create_canonical_database, stable_bil_food_id

class CanonicalModelTest(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory()
        self.db=Path(self.temp.name)/'canonical.sqlite'
        self.store=CanonicalFoodStore(self.db)
    def tearDown(self): self.temp.cleanup()

    def test_identity_is_stable_and_source_independent(self):
        a=stable_bil_food_id('generic|apple|raw')
        b=stable_bil_food_id('  GENERIC|APPLE|RAW  ')
        self.assertEqual(a,b)
        self.assertNotIn('usda',a.lower())
        self.assertNotEqual(a,'171688')

    def test_multiple_sources_link_to_one_food_without_changing_identity(self):
        food=self.store.create_food('generic|apple|raw','generic','Apple, raw')
        self.store.link_source(food, SourceLink('USDA_FOUNDATION','2026-04-30','171688','a'*64))
        self.store.link_source(food, SourceLink('USDA_SR_LEGACY','2018-04','09003','b'*64))
        with closing(sqlite3.connect(self.db)) as conn:
            rows=conn.execute('select distinct bil_food_id from source_record').fetchall()
            self.assertEqual(rows,[(food,)])

    def test_barcode_is_reference_not_identity(self):
        food=self.store.create_food('branded|maker|product','branded','Product')
        src=self.store.link_source(food, SourceLink('USDA_BRANDED','2026-04-30','999','c'*64))
        with closing(sqlite3.connect(self.db)) as conn:
            conn.execute("insert into barcode_claim(normalized_gtin,bil_food_id,source_record_id,claim_status,confidence) values(?,?,?,?,?)",('00012345678905',food,src,'active',0.9))
            conn.commit()
            pk=[r[1] for r in conn.execute('pragma table_info(barcode_claim)') if r[5]]
            self.assertEqual(pk,['barcode_claim_id'])

    def test_missing_nutrient_is_not_zero_and_evidence_requires_source(self):
        food=self.store.create_food('generic|water','generic','Water')
        src=self.store.link_source(food, SourceLink('USDA_FOUNDATION','2026','1','d'*64))
        with closing(sqlite3.connect(self.db)) as conn:
            conn.execute("PRAGMA foreign_keys=ON")
            conn.execute("insert into nutrient_definition values(?,?,?,?,?)",('bil:nutrient:energy','Energy','kcal','energy','now'))
            count=conn.execute('select count(*) from nutrient_evidence').fetchone()[0]
            self.assertEqual(count,0)
            with self.assertRaises(sqlite3.IntegrityError):
                conn.execute("insert into nutrient_evidence(bil_food_id,bil_nutrient_id,amount,basis,source_record_id,derivation_method,confidence,created_at) values(?,?,?,?,?,?,?,?)",(food,'bil:nutrient:energy',1,'per_100g',999,'measured',1,'now'))

    def test_merge_preserves_lineage(self):
        a=self.store.create_food('a','generic','A')
        b=self.store.create_food('b','generic','B')
        self.store.merge_foods(a,b,'duplicate','{}','v1')
        with closing(sqlite3.connect(self.db)) as conn:
            status=conn.execute('select status,merged_into_bil_food_id from canonical_food where bil_food_id=?',(a,)).fetchone()
            self.assertEqual(status,('merged',b))
            self.assertEqual(conn.execute('select count(*) from merge_event').fetchone()[0],1)

    def test_schema_integrity_and_required_tables(self):
        create_canonical_database(self.db)
        with closing(sqlite3.connect(self.db)) as conn:
            self.assertEqual(conn.execute('pragma integrity_check').fetchone()[0],'ok')
            tables={r[0] for r in conn.execute("select name from sqlite_master where type='table'")}
            required={'canonical_food','source_record','food_name','brand','barcode_claim','nutrient_definition','nutrient_source_mapping','nutrient_evidence','portion','merge_event'}
            self.assertTrue(required.issubset(tables))

if __name__=='__main__': unittest.main()
