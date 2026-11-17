"""Actual candidate guards/transport tests. No SDK, Bash, network or credentials."""
from pathlib import Path
import ast, base64, hashlib, importlib, json, os, re, sys, tempfile, unittest, zlib
from unittest.mock import patch
import xml.etree.ElementTree as ET

HERE=Path(__file__).resolve().parent
RUNTIME=Path(os.environ.get('BIL_EXTERNAL39_RUNTIME',str(HERE/'candidate-runtime')))
WORKFLOW=Path(os.environ.get('BIL_EXTERNAL39_WORKFLOW',str(next((HERE/'candidate').glob('*.yml'))))) if not os.environ.get('BIL_EXTERNAL39_WORKFLOW') else Path(os.environ['BIL_EXTERNAL39_WORKFLOW'])
sys.dont_write_bytecode=True
sys.path.insert(0,str(RUNTIME))
ui=importlib.import_module('reviewer_ui')
binding=importlib.import_module('artifact_binding')

def frame(*texts, package=ui.APP_ID, enabled='true', merged=False):
    root=ET.Element('hierarchy')
    texts=['\n'.join(texts)] if merged else texts
    for text in texts:
        ET.SubElement(root,'node',{'package':package,'enabled':enabled,'text':text,'content-desc':'',
             'bounds':'[0,0][100,100]','clickable':'true','class':'android.view.View'})
    return root

class ConsentTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup)
        self.j=ui.Journey.__new__(ui.Journey)
        self.j.evidence=Path(self.temp.name);self.j.phase='AUTHENTICATION_WAIT'
        self.j.rows=[];self.j.credentials_active=False
        self.j.email='synthetic@example.invalid';self.j.password='SYNTHETIC_NEVER_USED'
        self.j.capture_runner=object();self.actions=[]
        self.j.command=lambda *a,**kw:self.actions.append(a) or b''
    def stopped(self,callback):
        with self.assertRaisesRegex(ui.Stop,'^NEEDS_EXPLICIT_CONSENT$'):callback()
        self.assertEqual(self.actions,[])
        receipt=json.loads((self.j.evidence/'EXPLICIT_CONSENT_BOUNDARY.json').read_bytes())
        self.assertFalse(receipt['consent_choice_clicked'])
        self.assertFalse(receipt['actual_authenticated_owner_uuid_observed'])
        self.assertFalse(receipt['raw_ui_or_credentials_persisted'])
        self.assertNotIn('synthetic',json.dumps(receipt))
    def test_all25_exact_source_prompt_titles_and_each_action_stop(self):
        self.assertEqual(len(ui.CLOUD_CONSENT_PROMPTS),25)
        for locale,values in ui.CLOUD_CONSENT_PROMPTS.items():
            for value in values:
                with self.subTest(locale=locale,signal=values.index(value)):
                    root=frame('Home','More',value)
                    self.assertIn(locale,ui.cloud_consent_signals(root))
                    self.stopped(lambda:self.j.guard_explicit_consent(root))
    def test_all25_merged_semantics_normalized_whitespace_stop(self):
        for locale,values in ui.CLOUD_CONSENT_PROMPTS.items():
            with self.subTest(locale=locale):
                self.stopped(lambda:self.j.guard_explicit_consent(frame(*values,merged=True)))
                self.assertIn(locale,ui.cloud_consent_signals(frame('  '+values[0]+'  ')))
    def test_foreign_prompt_not_attributed_to_bil(self):
        self.assertEqual(ui.cloud_consent_signals(frame(*ui.CLOUD_CONSENT_PROMPTS['en'],package='foreign.app')), {})
    def test_disabled_nonowned_prompt_does_not_create_bil_choice(self):
        self.assertEqual(ui.cloud_consent_signals(frame(*ui.CLOUD_CONSENT_PROMPTS['en'],enabled='false')), {})
    def test_settings_progress_backup_is_not_first_use_consent(self):
        self.assertEqual(ui.cloud_consent_signals(frame('Progress backup','Privacy','Home','More')), {})
    def test_unknown_cloud_text_is_not_a_source_prompt(self):
        self.assertEqual(ui.cloud_consent_signals(frame('cloud sync unavailable','Home','More')), {})
    def test_snapshot_stops_before_observation_or_navigation_behind_modal(self):
        root=frame('Home','More',*ui.CLOUD_CONSENT_PROMPTS['en'])
        with patch.object(ui,'capture_hierarchy',return_value=root),patch.object(self.j,'observe_safe_route') as obs:
            self.stopped(self.j.snapshot);obs.assert_not_called()
    def test_nav_guard_is_not_swallowed_by_ambiguous_selector_catch(self):
        self.stopped(lambda:self.j.nav_found(frame('Home',*ui.CLOUD_CONSENT_PROMPTS['en']),'Home'))
    def test_tap_guard_stops_given_prompt_without_input(self):
        self.stopped(lambda:self.j.tap(frame('Home',*ui.CLOUD_CONSENT_PROMPTS['en']),'Home'))
    def test_tap_rechecks_fresh_prompt_after_stale_safe_tree(self):
        with patch.object(ui,'capture_hierarchy',return_value=frame(*ui.CLOUD_CONSENT_PROMPTS['en'])):
            self.stopped(lambda:self.j.tap(frame('More'),'More'))
    def test_back_does_not_dismiss_prompt(self):
        with patch.object(ui,'capture_hierarchy',return_value=frame(*ui.CLOUD_CONSENT_PROMPTS['en'])):
            self.stopped(self.j.back)
    def test_record_cannot_mark_paid_route_pass_with_prompt(self):
        self.stopped(lambda:self.j.record('ordinary_password_sign_in',frame('Home','More',*ui.CLOUD_CONSENT_PROMPTS['en'])))
        self.assertEqual(self.j.rows,[])
        self.assertFalse((self.j.evidence/'JOURNEY_PROGRESS.json').exists())
    def test_visual_guard_does_not_allow_consent_image(self):
        self.stopped(lambda:self.j.visual_guard('plans_active_continue',frame(*ui.CLOUD_CONSENT_PROMPTS['en'])))
    def test_trusted_visual_propagates_consent_stop_without_screenshot(self):
        with patch.object(ui,'capture_hierarchy',return_value=frame(*ui.CLOUD_CONSENT_PROMPTS['en'])):
            self.stopped(lambda:self.j.trusted_visual('plans_active_continue'))
        self.assertEqual(list(self.j.evidence.glob('*.png')),[])
    def test_credential_fields_and_home_behind_modal_still_stop(self):
        root=frame('Home','More',*ui.CLOUD_CONSENT_PROMPTS['ar'])
        ET.SubElement(root,'node',{'package':ui.APP_ID,'enabled':'true','class':'android.widget.EditText','password':'true','text':'synthetic@example.invalid'})
        self.j.credentials_active=True
        self.stopped(lambda:self.j.guard_explicit_consent(root))
    def test_normal_safe_tap_uses_current_observed_control(self):
        current=frame('More');node=next(current.iter('node'));node.set('bounds','[10,20][30,40]')
        with patch.object(ui,'capture_hierarchy',return_value=current),patch.object(self.j,'observe_safe_route'):
            self.j.tap(frame('More'),'More')
        self.assertEqual(self.actions,[('shell','input','tap','20','30')])

class TransportTests(unittest.TestCase):
    def setUp(self):
        self.workflow=WORKFLOW.read_text(encoding='utf8')
    def test_all22_transport_records_decode_to_exact_runtime_files(self):
        names=[]
        for m in re.finditer(r"records = json.loads\(('(?:[^'\\]|\\.)*')\)",self.workflow):
            for row in json.loads(ast.literal_eval(m[1])):
                names.append(row['name']);compressed=base64.b64decode(row['compressed_base64'],validate=True)
                raw=zlib.decompress(compressed)
                self.assertEqual(hashlib.sha256(compressed).hexdigest(),row['compressed_sha256'])
                self.assertEqual(hashlib.sha256(raw).hexdigest(),row['raw_sha256'])
                self.assertEqual(len(raw),row['raw_bytes']);self.assertEqual(raw,(RUNTIME/row['name']).read_bytes())
        self.assertEqual(len(names),22);self.assertEqual(len(set(names)),22)
        self.assertEqual(set(names),{p.name for p in RUNTIME.iterdir() if p.is_file()})
    def test_core18_and_pulse_strict_readback_are_exact(self):
        m=re.search(r"expected = json.loads\(('(?:[^'\\]|\\.)*')\)",self.workflow)
        expected=json.loads(ast.literal_eval(m[1]));self.assertEqual(len(expected),18)
        for name,pin in expected.items():
            raw=(RUNTIME/name).read_bytes();self.assertEqual(pin,{'sha256':hashlib.sha256(raw).hexdigest(),'bytes':len(raw)})
        raw=(RUNTIME/'host_libpulse_prerequisite.py').read_bytes()
        self.assertIn("if len(b)!="+str(len(raw))+" or hashlib.sha256(b).hexdigest()!='"+hashlib.sha256(raw).hexdigest()+"'",self.workflow)
    def test_pending_pins_fail_closed_before_any_api_or_credential(self):
        pins=json.loads((RUNTIME/'exact-android39-pins.json').read_bytes())
        with self.assertRaisesRegex(Exception,'PENDING_EXACT_NEW_ANDROID39_ARTIFACT_PINS'):
            binding.validate_pins(pins)
    def test_single_workflow_source39_and_no_borrowed38_runtime_pins(self):
        self.assertIn('ref: c5b610276a3bbee8a0e446300296920b5cdc9570',self.workflow)
        for path in RUNTIME.iterdir():
            s=path.read_text(encoding='utf8')
            for stale in ['f3befc6f3a13b30b5c72d72b5acb37b2d62a306b','43862278434','14224388415','df21de65a623c2db6f3fbf37a71e1a1527f868cf','0bce95f8312c8e68b9f74868b76871bbba3bfe4c2d1770879177d88bef04357b']:
                self.assertNotIn(stale,s,path.name)
    def test_no_prelaunch_clear_and_cleanup_clear_preserved(self):
        wrapper=(RUNTIME/'android39-reviewer-entrypoint.sh').read_text()
        self.assertIn('pm list packages --user 0',wrapper)
        self.assertNotIn('pm clear',wrapper);self.assertNotIn('uninstall',wrapper)
        self.assertLess(wrapper.index('pm list packages'),wrapper.index('adb install'))
        self.assertIn("('shell', 'pm', 'clear', APP_ID)",(RUNTIME/'reviewer_ui.py').read_text(encoding='utf8'))
    def test_python_runtime_parses_without_execution_or_bytecode(self):
        for path in RUNTIME.glob('*.py'):ast.parse(path.read_bytes(),filename=str(path))
    def test_each_github_run_scalar_under21k(self):
        steps=re.split(r'\n      - name:',self.workflow)
        sizes=[len(x.split('        run: |\n',1)[1]) for x in steps if '        run: |\n' in x]
        self.assertTrue(sizes);self.assertLess(max(sizes),21000)

if __name__=='__main__':
    suite=unittest.defaultTestLoader.loadTestsFromModule(sys.modules[__name__])
    if suite.countTestCases()!=23:raise RuntimeError('EXACT23_CASES_REQUIRED')
    result=unittest.TextTestRunner(verbosity=2).run(suite)
    print(json.dumps({'tests_run':result.testsRun,'failures':len(result.failures),'errors':len(result.errors),
       'skipped':len(result.skipped),'expected_failures':len(result.expectedFailures),
       'unexpected_successes':len(result.unexpectedSuccesses),'was_successful':result.wasSuccessful()}))
    raise SystemExit(0 if result.wasSuccessful() and result.testsRun==23 and not result.skipped else 1)
