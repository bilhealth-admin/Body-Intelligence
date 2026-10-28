"""Execute the workflow's real ASC promotion code with isolated API fixtures.

These are negative orchestration tests, not live Apple/TestFlight evidence.
No credentials, files, network access or uploads are used by the Node harness.
"""
import json
from pathlib import Path
import re
import shutil
import subprocess
import textwrap
import unittest


WORKFLOW = Path(__file__).resolve().parents[2] / '.github/workflows/bil40_internal_testflight.yml'


class InternalTestFlightReadinessTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        if shutil.which('node') is None:
            raise RuntimeError('Node is required to execute the actual TestFlight readiness code')
        workflow = WORKFLOW.read_text(encoding='utf-8')
        match = re.search(r"cat > evidence/asc-processing.mjs <<'JS'\n(.*?)\n          JS", workflow, re.S)
        if match is None:
            raise AssertionError('The actual ASC processing program must be present')
        cls.program = textwrap.dedent(match.group(1))

    def run_fixture(self, **scenario):
        harness = r'''
const scenario=SCENARIO;
const writes={}; const calls={posts:[],details:0,processing:0,readbacks:0};
const groups=(scenario.groups??['g1','g2']).map(id=>({id,attributes:{name:id,isInternalGroup:true}}));
const associated=new Set(scenario.initialGroups??[]);
const identity={source_sha:'a'.repeat(40),ipa_sha256:'b'.repeat(64),uses_non_exempt_encryption:false};
const fs={
  readFileSync:name=>JSON.stringify(name==='evidence/identity.json'?identity:
    {previous_internal_groups:groups.map(g=>({id:g.id,name:g.id}))}),
  writeFileSync:(name,value)=>{writes[name]=JSON.parse(value);}
};
const client={
  all:async url=>{
    if(url.includes('/apps/')) return [...groups,{id:'external',attributes:{isInternalGroup:false}}];
    const id=url.match(/betaGroups\/([^/]+)\//)[1];
    if(scenario.mode==='preflight') return scenario.noPriorAssociation?[]:[{id:'build38'}];
    if(id===groups[0]?.id&&calls.posts.length>0) calls.readbacks++;
    const propagating=calls.posts.includes(id);
    const visible=associated.has(id)&&id!==scenario.missingGroup&&
      (!propagating||calls.readbacks>(scenario.groupLag??0));
    return visible?[{id:'build40'}]:[];
  },
  request:async(method,url)=>{
    if(method==='POST'){
      const id=url.match(/betaGroups\/([^/]+)\//)[1];
      calls.posts.push(id); associated.add(id); return {};
    }
    if(method==='PATCH') return {};
    if(url.includes('/buildBetaDetail')){
      const states=scenario.internalStates??['IN_BETA_TESTING'];
      const state=states[Math.min(calls.details++,states.length-1)];
      return {data:{attributes:{internalBuildState:state}}};
    }
    if(url.includes('/v1/apps/')) return {data:{attributes:{bundleId:'com.bilhealth.bodyintelligencelog'}}};
    const version=url.match(/filter\[version\]=([^&]+)/)[1];
    if(scenario.mode==='preflight'&&version==='40') return {data:[],included:[]};
    const states=scenario.processingStates??['VALID'];
    const state=states[Math.min(calls.processing++,states.length-1)];
    return {data:[{id:'build'+version,attributes:{processingState:state,usesNonExemptEncryption:false},
      relationships:{preReleaseVersion:{data:{id:'pre1'}}}}],
      included:[{id:'pre1',attributes:{version:'1.0.0',platform:'IOS'}}]};
  }
};
const setTimeout=callback=>{callback();return 0;};
process.argv[2]=scenario.mode??'processing';
let failure=null;
try { await (async()=>{ PROGRAM })(); } catch(error) { failure=error.message; }
console.log('HARNESS_RESULT='+JSON.stringify({failure,writes,calls}));
'''
        program = re.sub(r"^import .*?;\n", '', self.program, flags=re.M)
        program = program.replace('const client=clientFromEnvironment();', '')
        script = harness.replace('SCENARIO', json.dumps(scenario)).replace('PROGRAM', program)
        result = subprocess.run(['node', '--input-type=module', '-'], input=script,
                                text=True, capture_output=True, timeout=10)
        self.assertEqual(0, result.returncode, result.stderr)
        record = next(line.removeprefix('HARNESS_RESULT=') for line in result.stdout.splitlines()
                      if line.startswith('HARNESS_RESULT='))
        return json.loads(record)

    def assert_not_ready(self, result):
        self.assertIsNotNone(result['failure'])
        self.assertNotIn('evidence/testflight-ready.json', result['writes'])

    def test_no_prior_internal_group_blocks_preflight_before_upload(self):
        for scenario in ({'groups': []}, {'noPriorAssociation': True}):
            with self.subTest(scenario=scenario):
                result = self.run_fixture(mode='preflight', **scenario)
                self.assert_not_ready(result)
                self.assertEqual([], result['calls']['posts'])
                self.assertEqual([], result['writes']['evidence/asc-preflight.json']['previous_internal_groups'])

    def test_both_apple_available_states_require_all_groups_read_back(self):
        for state in ('READY_FOR_BETA_TESTING', 'IN_BETA_TESTING'):
            with self.subTest(state=state):
                result = self.run_fixture(internalStates=[state])
                self.assertIsNone(result['failure'])
                ready = result['writes']['evidence/testflight-ready.json']
                self.assertEqual('INTERNAL_TESTFLIGHT_READY', ready['status'])
                self.assertEqual([], ready['missing_internal_group_ids'])
                self.assertEqual({'g1', 'g2'}, {group['id'] for group in ready['internal_groups']})
                self.assertEqual(['g1', 'g2'], result['calls']['posts'])

    def test_group_and_internal_state_propagation_is_polled(self):
        result = self.run_fixture(groupLag=2, internalStates=['PROCESSING', 'MISSING_EXPORT_COMPLIANCE', 'IN_BETA_TESTING'])
        self.assertIsNone(result['failure'])
        self.assertEqual(3, result['calls']['details'])
        self.assertEqual(['g1', 'g2'], result['calls']['posts'])

    def test_existing_associations_are_read_back_without_duplicate_writes(self):
        for groups, expected_posts in ((['g1', 'g2'], []), (['g1'], ['g2'])):
            with self.subTest(initial_groups=groups):
                result = self.run_fixture(initialGroups=groups)
                self.assertIsNone(result['failure'])
                self.assertEqual(expected_posts, result['calls']['posts'])
                self.assertEqual([], result['writes']['evidence/testflight-ready.json']['missing_internal_group_ids'])

    def test_missing_expected_group_never_certifies_partial_assignment(self):
        result = self.run_fixture(missingGroup='g2')
        self.assert_not_ready(result)
        self.assertEqual(13, result['calls']['details'])
        pending = result['writes']['evidence/testflight-pending.json']
        self.assertEqual(['g2'], pending['missing_internal_group_ids'])
        self.assertTrue(pending['do_not_reupload'])

    def test_export_compliance_unknown_or_missing_state_is_not_availability(self):
        for state in ('MISSING_EXPORT_COMPLIANCE', 'IN_EXPORT_COMPLIANCE_REVIEW', 'UNKNOWN', None):
            with self.subTest(state=state):
                result = self.run_fixture(internalStates=[state])
                self.assert_not_ready(result)
                self.assertEqual(13, result['calls']['details'])

    def test_terminal_internal_state_fails_without_waiting_or_ready_receipt(self):
        for state in ('EXPIRED', 'PROCESSING_EXCEPTION'):
            with self.subTest(state=state):
                result = self.run_fixture(internalStates=[state])
                self.assert_not_ready(result)
                self.assertEqual(1, result['calls']['details'])

    def test_processing_timeout_is_explicit_pending_not_upload_success(self):
        result = self.run_fixture(processingStates=['PROCESSING'])
        self.assert_not_ready(result)
        self.assertEqual(31, result['calls']['processing'])
        self.assertEqual(0, result['calls']['details'])
        self.assertEqual([], result['calls']['posts'])
        self.assertEqual('APPLE_PROCESSING_PENDING', result['writes']['evidence/testflight-pending.json']['status'])

    def test_processing_failure_is_rejected_before_group_assignment(self):
        for state in ('FAILED', 'INVALID'):
            with self.subTest(state=state):
                result = self.run_fixture(processingStates=[state])
                self.assert_not_ready(result)
                self.assertEqual(1, result['calls']['processing'])
                self.assertEqual([], result['calls']['posts'])

    def test_processing_transitions_to_valid_before_internal_availability(self):
        result = self.run_fixture(processingStates=['PROCESSING', 'VALID'])
        self.assertIsNone(result['failure'])
        self.assertEqual(2, result['calls']['processing'])
        self.assertIn('evidence/testflight-ready.json', result['writes'])


if __name__ == '__main__':
    unittest.main()
