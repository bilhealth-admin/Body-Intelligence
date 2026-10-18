import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const {functions}=JSON.parse(readFileSync(new URL('./live_signatures.json',import.meta.url),'utf8'));
export function assertRpcArguments(name,args={}) {
  const actual=Object.keys(args??{});
  const candidates=functions.filter(row=>row.proname===name);
  assert.ok(candidates.length,`RPC missing from verified database: ${name}`);
  const matches=candidates.some(row=>{
    const parameters=row.arguments?row.arguments.split(/, (?=p_)/):[];
    const all=parameters.map(x=>x.split(' ')[0]);
    const required=parameters.filter(x=>!x.includes(' DEFAULT ')).map(x=>x.split(' ')[0]);
    return actual.every(x=>all.includes(x))&&required.every(x=>actual.includes(x));
  });
  assert.ok(matches,`RPC arguments do not match verified database: ${name} (${actual.join(', ')})`);
}
