'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const directory = __dirname;
const patched = fs.readFileSync(process.argv[2], 'utf8');

async function run({guardPath='/controller/readiness.py',guardExists=true,guardFails=false}={}) {
  const calls=[];
  const exported={};
  vm.runInNewContext(patched,{
    exports:exported,
    require(name){
      if(name==='@actions/exec')return {async exec(command,args,options){
        calls.push({command,args});
        if(String(command).includes('getprop sys.boot_completed')) options.listeners.stdout(Buffer.from('1\n'));
        if(command==='python3'&&guardFails) throw new Error('readiness blocked');
        return 0;
      }};
      if(name==='fs')return {statSync(){return {isFile(){return guardExists;}}}};
      throw new Error('unexpected import');
    },
    process:{platform:'linux',env:{ANDROID_HOME:'/sdk',BIL_EMULATOR_READY_GUARD:guardPath}},
    console:{log(){}},setTimeout,Buffer,
  });
  let failed=false;
  try{await exported.launchEmulator('test',true,false,false,900,'-no-window -gpu swiftshader_indirect -no-snapshot -noaudio -no-boot-anim',false,5554);}catch{failed=true;}
  const keys=calls.filter(x=>String(x.command).includes('shell input keyevent 82'));
  return {calls,keys,failed};
}
(async()=>{
  const good=await run();assert.equal(good.failed,false);assert.equal(good.keys.length,1);
  const guardIndex=good.calls.findIndex(x=>x.command==='python3');
  const keyIndex=good.calls.findIndex(x=>String(x.command).includes('shell input keyevent 82'));
  assert(guardIndex>=0&&guardIndex<keyIndex);
  assert.deepEqual(Array.from(good.calls[guardIndex].args),['/controller/readiness.py','--port','5554']);
  for(const options of [{guardFails:true},{guardPath:undefined},{guardPath:''},{guardExists:false}]){
    // Undefined uses the function's default, so test a genuinely absent env value with null.
    if(options.guardPath===undefined&&Object.hasOwn(options,'guardPath'))options.guardPath=null;
    const blocked=await run(options);assert.equal(blocked.failed,true);assert.equal(blocked.keys.length,0);
  }
  console.log('5 actual patched-action ordering controls PASS; original key occurs once only after readiness succeeds');
})().catch(error=>{console.error(error);process.exitCode=1;});
