from __future__ import annotations
import sqlite3, tempfile, unittest
from contextlib import closing
from pathlib import Path
from tool.nutrition_platform.canonical_model import create_canonical_database, utc_now
from tool.nutrition_platform.mobile_catalog_builder import CatalogProfile, build_mobile_catalog
from tool.nutrition_platform.catalog_activation_manager import CatalogActivationManager, CatalogManifest, CatalogActivationError

class EndToEndNutritionClosureTest(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory(); self.root=Path(self.temp.name)
    def tearDown(self): self.temp.cleanup()
    def _master(self):
        path=self.root/'master.sqlite'; create_canonical_database(path); now=utc_now()
        with closing(sqlite3.connect(path)) as db:
            db.executescript('CREATE TABLE source_normalization(source_record_id INTEGER PRIMARY KEY, normalized_name TEXT); CREATE TABLE quality_assessment(source_record_id INTEGER PRIMARY KEY, overall_score REAL, validation_status TEXT, delivery_eligibility TEXT);')
            db.execute('INSERT INTO canonical_food VALUES(?,?,?,?,?,?,?,?)',('bil-1','generic','Apple','تفاح','active',None,now,now))
            db.execute("INSERT INTO source_record(source_system,source_version,external_id,bil_food_id,source_payload_hash,imported_at,record_status) VALUES(?,?,?,?,?,?,?)",('USDA_FOUNDATION','v1','1','bil-1','x',now,'active'))
            sid=db.execute('SELECT source_record_id FROM source_record').fetchone()[0]
            db.execute('INSERT INTO source_normalization VALUES(?,?)',(sid,'apple'))
            db.execute('INSERT INTO quality_assessment VALUES(?,?,?,?)',(sid,95,'accepted','mobile_candidate'))
            db.execute('INSERT INTO food_name(bil_food_id,language,name,normalized_name,name_type,source_record_id,confidence) VALUES(?,?,?,?,?,?,?)',('bil-1','en','Apple','apple','primary',sid,1))
            db.execute('INSERT INTO nutrient_definition VALUES(?,?,?,?,?)',('protein','Protein','g','macro',now))
            db.execute('INSERT INTO nutrient_evidence(bil_food_id,bil_nutrient_id,amount,basis,source_record_id,derivation_method,confidence,created_at) VALUES(?,?,?,?,?,?,?,?)',('bil-1','protein',1.0,'per_100g',sid,'lab',0.5,now))
            db.execute('INSERT INTO nutrient_evidence(bil_food_id,bil_nutrient_id,amount,basis,source_record_id,derivation_method,confidence,created_at) VALUES(?,?,?,?,?,?,?,?)',('bil-1','protein',2.0,'per_100g',sid,'lab',0.9,now)); db.commit()
        return path
    def test_builder_activation_contract_and_evidence_selection(self):
        master=self._master(); catalog=self.root/'catalog.sqlite'; report=build_mobile_catalog(master,catalog,CatalogProfile(profile_id='test',minimum_quality_score=0)); self.assertEqual(report['rows'],1)
        with closing(sqlite3.connect(catalog)) as db:
            tables={r[0] for r in db.execute("SELECT name FROM sqlite_master WHERE type='table'")}; self.assertIn('food',tables); self.assertIn('food_fts',tables)
            self.assertEqual(db.execute("SELECT amount,confidence FROM nutrient WHERE bil_nutrient_id='protein'").fetchone(),(2.0,0.9))
        manifest=CatalogManifest.from_path(catalog,catalog_id='core',version='1.0.0',schema_version=1); manager=CatalogActivationManager(self.root/'runtime'); self.assertTrue(manager.activate(catalog,manifest).is_file())
    def test_catalog_version_is_immutable(self):
        master=self._master(); catalog=self.root/'catalog.sqlite'; build_mobile_catalog(master,catalog,CatalogProfile(profile_id='test',minimum_quality_score=0)); manager=CatalogActivationManager(self.root/'runtime'); manifest=CatalogManifest.from_path(catalog,catalog_id='core',version='1.0.0',schema_version=1); manager.activate(catalog,manifest)
        other=self.root/'other.sqlite'; other.write_bytes(catalog.read_bytes()+b'changed'); other_manifest=CatalogManifest.from_path(other,catalog_id='core',version='1.0.0',schema_version=1)
        with self.assertRaises(CatalogActivationError): manager.activate(other,other_manifest)
if __name__=='__main__': unittest.main()
