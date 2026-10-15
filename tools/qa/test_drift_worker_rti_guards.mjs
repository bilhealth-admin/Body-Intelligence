import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { readFileSync } from 'node:fs';
import test from 'node:test';
import { fileURLToPath } from 'node:url';
import vm from 'node:vm';

// Matching-source regression evidence for CodeQL alert48, not a general browser
// injection certificate. No dependencies, network, SQL, storage, or Dart build.
// The production bundle stays unchanged: only a temporary in-memory copy exports
// its closure for inspection. The real RTI function and message parsers execute;
// a Proxy observes metadata writes, and handlers stop before any database work.
// ServeDriftDatabase parser cases use inert port placeholders, not native ports.
//
// Existing SARIF analysis1959431365 on bb5611d58c7f3b5097a3c27fbb754019ef7799c0
// has four paths (68,76,187,135 locations), all381 self.location.href ->1226.
// Read-only evidence: build/qa/policy-gate-20261015/codeql48-reachability.json.
// This test neither scans CodeQL nor changes/dismisses the still-open alert.
//
// Run: node --test tools/qa/test_drift_worker_rti_guards.mjs
// Compiler regeneration requires reviewing the source identity, key initializer,
// and these cases again; do not replace this pin to silence an unexplained diff.
const expectedWorkerSha256 =
  'e18724169edf818cd2289268b41adf6bc8a501bcedc55938e222ab0546540f8f';
const workerPath = fileURLToPath(new URL('../../web/drift_worker.dart.js', import.meta.url));
const workerBytes = readFileSync(workerPath);
assert.equal(createHash('sha256').update(workerBytes).digest('hex'), expectedWorkerSha256,
  'Worker differs from the reviewed CodeQL48 artifact; review RTI reachability before updating this pin.');
const workerSource = workerBytes.toString('utf8');

const runProbeSuite = function runProbeSuite(source, cases) {
  const marker = 'var s=A.y_\nif(typeof dartMainRunner';
  if (source.split(marker).length !== 2) throw new Error('Diagnostic export marker is not unique.');
  const result = [];
  for (const spec of cases) {
    const sandbox = { dartMainRunner() {} };
    sandbox.self = sandbox;
    sandbox.location = { href: 'https://bil-audit.invalid/drift_worker.dart.js' };
    vm.createContext(sandbox);
    vm.runInContext(source.replace(marker, 'globalThis.__bilAudit={A:A,J:J,B:B,v:v};'+marker), sandbox, { timeout: 2000 });
    sandbox.__caseJson = JSON.stringify(spec);
    result.push(vm.runInContext(`(() => {
      const {A,v}=__bilAudit, spec=JSON.parse(__caseJson);
      const metadata=v.typeUniverse.eT;
      const allowed=Object.keys(metadata).filter(k=>typeof metadata[k]==='number');
      const objectBefore=Object.getOwnPropertyDescriptors(Object.prototype);
      const metadataPrototype=Object.getPrototypeOf(metadata);
      const writes=[], calls=[];
      v.typeUniverse.eT=new Proxy(metadata,{set(target,key,value){
        writes.push({key:String(key),previousType:typeof target[key],nextType:typeof value});
        return Reflect.set(target,key,value);
      }});
      const original=A.w0;
      A.w0=function(universe,key){calls.push(String(key));return original(universe,key)};
      let value=null, rejected=false, error=null;
      const recordType=message => { value=A.aY(A.aJ(message),null); };
      try {
        const payload=spec.valueJson===undefined?null:JSON.parse(spec.valueJson);
        if(spec.kind==='sink') { A.w0(v.typeUniverse,spec.key);value='internal branch precondition'; }
        else if(spec.kind==='uri') { self.location.href=spec.uri;const uri=A.iR();recordType(uri);value=uri.i(0); }
        else if(spec.kind==='init') { A.kw.prototype.$1.call({a:{ak:recordType}},{data:payload}); }
        else if(spec.kind==='legacyRpc'||spec.kind==='modernRpc') {
          const receiver={a:false,c:spec.kind==='modernRpc',b:{a:{a:{l(_unused,message){recordType(message)}}}},d:new A.j1(A.oO(3))};
          A.mn.prototype.$1.call(receiver,{data:payload});
        } else if(spec.kind==='externalType') { recordType(payload); }
        else throw new Error('Unknown probe kind');
      } catch(e) { rejected=true;error=String(e).slice(0,180); }
      const objectAfter=Object.getOwnPropertyDescriptors(Object.prototype);
      const beforeKeys=Reflect.ownKeys(objectBefore),afterKeys=Reflect.ownKeys(objectAfter);
      const objectPrototypeUnchanged=beforeKeys.length===afterKeys.length&&beforeKeys.every(k=>{
        const a=objectBefore[k],b=objectAfter[k];
        return b&&['value','get','set','enumerable','configurable','writable'].every(p=>a[p]===b[p]);
      });
      const metadataPrototypeUnchanged=Object.getPrototypeOf(metadata)===metadataPrototype;
      const writesOnlyCompilerKeys=writes.every(w=>allowed.includes(w.key)&&w.previousType==='number');
      const operationAsExpected=rejected===Boolean(spec.expectReject);
      const controlAsExpected=spec.control==='positive'?writes.length===1&&writes[0].key===spec.key:
        spec.kind==='sink'?writes.length===0:true;
      return {id:spec.id,kind:spec.kind,rejected,error,value,constructorKeys:[...new Set(calls)],writes,
        allowedCompilerKeys:allowed,objectPrototypeUnchanged,metadataPrototypeUnchanged,writesOnlyCompilerKeys,
        operationAsExpected,controlAsExpected,
        passed:objectPrototypeUnchanged&&metadataPrototypeUnchanged&&writesOnlyCompilerKeys&&operationAsExpected&&controlAsExpected};
    })()`, sandbox, { timeout: 1000 }));
  }
  return {cases:result.length,passed:result.filter(x=>x.passed).length,failed:result.filter(x=>!x.passed).length,results:result};
};

const cases = [
  {
    "id": "positive-compiler-e8",
    "kind": "sink",
    "key": "e8",
    "control": "positive"
  },
  {
    "id": "positive-compiler-ho",
    "kind": "sink",
    "key": "ho",
    "control": "positive"
  },
  {
    "id": "positive-compiler-aG",
    "kind": "sink",
    "key": "aG",
    "control": "positive"
  },
  {
    "id": "positive-compiler-fx",
    "kind": "sink",
    "key": "fx",
    "control": "positive"
  },
  {
    "id": "positive-compiler-cj",
    "kind": "sink",
    "key": "cj",
    "control": "positive"
  },
  {
    "id": "positive-compiler-u9",
    "kind": "sink",
    "key": "u9",
    "control": "positive"
  },
  {
    "id": "reserved-key-__proto__",
    "kind": "sink",
    "key": "__proto__"
  },
  {
    "id": "reserved-key-constructor",
    "kind": "sink",
    "key": "constructor"
  },
  {
    "id": "reserved-key-prototype",
    "kind": "sink",
    "key": "prototype"
  },
  {
    "id": "reserved-key-toString",
    "kind": "sink",
    "key": "toString"
  },
  {
    "id": "reserved-key-hasOwnProperty",
    "kind": "sink",
    "key": "hasOwnProperty"
  },
  {
    "id": "reserved-key-__defineGetter__",
    "kind": "sink",
    "key": "__defineGetter__"
  },
  {
    "id": "reported-url-source-0",
    "kind": "uri",
    "uri": "https://bil-audit.invalid/__proto__/drift_worker.dart.js"
  },
  {
    "id": "reported-url-source-1",
    "kind": "uri",
    "uri": "https://bil-audit.invalid/drift_worker.dart.js?__proto__[bil_probe]=1"
  },
  {
    "id": "reported-url-source-2",
    "kind": "uri",
    "uri": "https://bil-audit.invalid/drift_worker.dart.js?constructor[prototype][bil_probe]=1"
  },
  {
    "id": "reported-url-source-3",
    "kind": "uri",
    "uri": "https://bil-audit.invalid/a/../__proto__/./drift_worker.dart.js"
  },
  {
    "id": "reported-url-source-4",
    "kind": "uri",
    "uri": "https://bil-audit.invalid/drift_worker.dart.js#constructor.prototype.bil_probe"
  },
  {
    "id": "reported-url-source-5",
    "kind": "uri",
    "uri": "https://bil-audit.invalid/%5F%5Fproto%5F%5F/drift_worker.dart.js"
  },
  {
    "id": "reported-url-source-6",
    "kind": "uri",
    "uri": "https://bil-audit.invalid/drift_worker.dart.js?e8=__proto__&ho=constructor"
  },
  {
    "id": "reported-url-source-7",
    "kind": "uri",
    "uri": "https://bil-audit.invalid/a//b/../../__proto__?x=prototype"
  },
  {
    "id": "reported-url-source-8",
    "kind": "uri",
    "uri": "https://bil-audit.invalid/drift_worker.dart.js?name=%7B%22constructor%22%3A%7B%22name%22%3A%22__proto__%22%7D%7D"
  },
  {
    "id": "reported-url-source-9",
    "kind": "uri",
    "uri": "file:///bil-audit/__proto__/drift_worker.dart.js"
  },
  {
    "id": "public-init-database-__proto__",
    "kind": "init",
    "valueJson": "{\"type\":\"RequestCompatibilityCheck\",\"payload\":\"__proto__\"}"
  },
  {
    "id": "public-init-serve-parser-__proto__",
    "kind": "init",
    "valueJson": "{\"type\":\"ServeDriftDatabase\",\"payload\":{\"v\":3,\"sqlite\":\"https://bil-audit.invalid/__proto__/sqlite3.wasm\",\"port\":{},\"storage\":\"inMemory\",\"database\":\"__proto__\",\"initPort\":null,\"migrations\":true,\"new_serialization\":true,\"constructor\":{\"name\":\"__proto__\"}}}"
  },
  {
    "id": "public-init-database-constructor",
    "kind": "init",
    "valueJson": "{\"type\":\"RequestCompatibilityCheck\",\"payload\":\"constructor\"}"
  },
  {
    "id": "public-init-serve-parser-constructor",
    "kind": "init",
    "valueJson": "{\"type\":\"ServeDriftDatabase\",\"payload\":{\"v\":3,\"sqlite\":\"https://bil-audit.invalid/constructor/sqlite3.wasm\",\"port\":{},\"storage\":\"inMemory\",\"database\":\"constructor\",\"initPort\":null,\"migrations\":true,\"new_serialization\":true,\"constructor\":{\"name\":\"__proto__\"}}}"
  },
  {
    "id": "public-init-database-prototype",
    "kind": "init",
    "valueJson": "{\"type\":\"RequestCompatibilityCheck\",\"payload\":\"prototype\"}"
  },
  {
    "id": "public-init-serve-parser-prototype",
    "kind": "init",
    "valueJson": "{\"type\":\"ServeDriftDatabase\",\"payload\":{\"v\":3,\"sqlite\":\"https://bil-audit.invalid/prototype/sqlite3.wasm\",\"port\":{},\"storage\":\"inMemory\",\"database\":\"prototype\",\"initPort\":null,\"migrations\":true,\"new_serialization\":true,\"constructor\":{\"name\":\"__proto__\"}}}"
  },
  {
    "id": "public-init-database-constructor.prototype.bil_probe",
    "kind": "init",
    "valueJson": "{\"type\":\"RequestCompatibilityCheck\",\"payload\":\"constructor.prototype.bil_probe\"}"
  },
  {
    "id": "public-init-serve-parser-constructor.prototype.bil_probe",
    "kind": "init",
    "valueJson": "{\"type\":\"ServeDriftDatabase\",\"payload\":{\"v\":3,\"sqlite\":\"https://bil-audit.invalid/constructor.prototype.bil_probe/sqlite3.wasm\",\"port\":{},\"storage\":\"inMemory\",\"database\":\"constructor.prototype.bil_probe\",\"initPort\":null,\"migrations\":true,\"new_serialization\":true,\"constructor\":{\"name\":\"__proto__\"}}}"
  },
  {
    "id": "public-init-unknown-rejected",
    "kind": "init",
    "valueJson": "{\"type\":\"__proto__\",\"payload\":{}}",
    "expectReject": true
  },
  {
    "id": "public-init-object-database-rejected",
    "kind": "init",
    "valueJson": "{\"type\":\"RequestCompatibilityCheck\",\"payload\":{\"constructor\":{\"name\":\"__proto__\"}}}",
    "expectReject": true
  },
  {
    "id": "public-init-invalid-sqlite-rejected",
    "kind": "init",
    "valueJson": "{\"type\":\"ServeDriftDatabase\",\"payload\":{\"v\":3,\"sqlite\":{\"constructor\":{\"name\":\"__proto__\"}}}}",
    "expectReject": true
  },
  {
    "id": "legacy-rpc-data-0",
    "kind": "legacyRpc",
    "valueJson": "{\"__proto__\":{\"bil_probe\":true},\"constructor\":{\"prototype\":{\"bil_probe\":true},\"name\":\"__proto__\"},\"fat\":20}"
  },
  {
    "id": "legacy-rpc-data-1",
    "kind": "legacyRpc",
    "valueJson": "[{\"name\":\"__proto__\",\"value\":\"constructor.prototype\"},0,null,40]"
  },
  {
    "id": "legacy-rpc-data-2",
    "kind": "legacyRpc",
    "valueJson": "{\"query\":\"select ?\",\"arguments\":[\"__proto__\",\"constructor\",\"prototype\"],\"database\":\"__proto__\"}"
  },
  {
    "id": "modern-rpc-error-text-__proto__",
    "kind": "modernRpc",
    "valueJson": "[2,[17,\"__proto__\",null]]"
  },
  {
    "id": "modern-rpc-error-text-constructor",
    "kind": "modernRpc",
    "valueJson": "[2,[17,\"constructor\",null]]"
  },
  {
    "id": "modern-rpc-error-text-prototype",
    "kind": "modernRpc",
    "valueJson": "[2,[17,\"prototype\",null]]"
  },
  {
    "id": "modern-rpc-cancel-id",
    "kind": "modernRpc",
    "valueJson": "[3,17]"
  },
  {
    "id": "external-clone-shape-runtime-type-0",
    "kind": "externalType",
    "valueJson": "{\"constructor\":{\"name\":\"__proto__\"}}"
  },
  {
    "id": "external-clone-shape-runtime-type-1",
    "kind": "externalType",
    "valueJson": "{\"__proto__\":{\"bil_probe\":true}}"
  },
  {
    "id": "external-clone-shape-runtime-type-2",
    "kind": "externalType",
    "valueJson": "{\"constructor\":{\"name\":\"e8\"}}"
  },
  {
    "id": "external-clone-shape-runtime-type-3",
    "kind": "externalType",
    "valueJson": "[\"__proto__\",\"constructor\"]"
  },
  {
    "id": "external-clone-shape-runtime-type-4",
    "kind": "externalType",
    "valueJson": "\"__proto__\""
  }
];
assert.equal(cases.length, 45, 'Preserve all matching-source regression cases.');
assert.deepEqual(cases.filter(spec => spec.control === 'positive').map(spec => spec.key),
  ['e8', 'ho', 'aG', 'fx', 'cj', 'u9'], 'Keep all six real numeric metadata-entry controls.');

for (const spec of cases) {
  test(spec.id, t => {
    const suite = runProbeSuite(workerSource, [spec]);
    const result = suite.results[0];
    t.diagnostic(JSON.stringify({
      workerSha256: expectedWorkerSha256,
      kind: result.kind,
      constructorKeys: result.constructorKeys,
      writes: result.writes,
      rejected: result.rejected,
      objectPrototypeUnchanged: result.objectPrototypeUnchanged,
      metadataPrototypeUnchanged: result.metadataPrototypeUnchanged,
    }));
    assert.equal(result.operationAsExpected, true, JSON.stringify(result));
    assert.equal(result.objectPrototypeUnchanged, true, JSON.stringify(result));
    assert.equal(result.metadataPrototypeUnchanged, true, JSON.stringify(result));
    assert.equal(result.writesOnlyCompilerKeys, true, JSON.stringify(result));
    assert.equal(result.controlAsExpected, true, JSON.stringify(result));
    assert.equal(result.passed, true, JSON.stringify(result));
    if (spec.control === 'positive') {
      assert.deepEqual(JSON.parse(JSON.stringify(result.writes)),
        [{ key: spec.key, previousType: 'number', nextType: 'object' }]);
    }
    assert.equal(createHash('sha256').update(readFileSync(workerPath)).digest('hex'),
      expectedWorkerSha256, 'The production worker must remain unchanged.');
  });
}
