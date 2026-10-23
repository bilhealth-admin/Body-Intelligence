import { PGlite } from "npm:@electric-sql/pglite@0.3.15";

const a = "38000000-0000-4000-8000-000000000001";
const b = "38000000-0000-4000-8000-000000000002";
function assert(value: unknown, message: string): asserts value {
  if (!value) throw new Error(message);
}
async function rejects(work: () => Promise<unknown>, code: string) {
  try { await work(); } catch (e) {
    assert((e as {code?: string}).code === code, `Expected ${code}`);
    return;
  }
  throw new Error(`Expected rejection ${code}`);
}

Deno.test("Smart Plan real SQL: owner isolation, CAS, consent, entitlement, deletion and malformed payloads", async () => {
  const db = new PGlite();
  try {
    await db.exec(`create role anon; create role authenticated;
      create schema auth; create table auth.users(id uuid primary key);
      create function auth.uid() returns uuid language sql stable as
        $$select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;
      grant usage on schema auth to authenticated,anon;
      create function public.bil_has_active_premium(uuid) returns boolean language sql stable as
        $$select current_setting('test.premium',true)='true'$$;`);
    await db.exec(await Deno.readTextFile(new URL(
      "../migrations/20261022213149_bil_smart_plan_sync_v1.sql", import.meta.url)));
    await db.exec(await Deno.readTextFile(new URL(
      "../migrations/20261023030934_bil_smart_plan_revision_history.sql", import.meta.url)));
    await db.exec(await Deno.readTextFile(new URL(
      "../migrations/20261023042955_bil_smart_plan_conflict_http409.sql", import.meta.url)));
    await db.query("insert into auth.users values($1),($2)", [a,b]);
    const actor = async (owner: string) => {
      await db.query("select set_config('request.jwt.claim.sub',$1,false)",[owner]);
      await db.exec("set role authenticated");
    };
    await actor(a);
    await db.exec("select set_config('test.premium','true',false)");
    await rejects(() => db.query("select public.bil_smart_plan_read_v1()"),"42501");
    await db.query("select public.bil_smart_plan_consent_v1(true)");
    const payload = {
      ownerId:a,schema:1,id:'plan-a',revision:1,status:'draft',horizon:'week',focus:'training',
      startDate:'2026-10-22',createdAt:'2026-10-22T00:00:00Z',updatedAt:'2026-10-22T00:00:00Z',
      days:Array.from({length:7},(_,i)=>({date:`2026-10-${22+i}`,phase:'foundation',workout:null,meals:[]})),
    };
    const first = await db.query<{result: {revision:number}}>(
      "select public.bil_smart_plan_cas_v1(0,$1::jsonb) as result",[JSON.stringify(payload)]);
    assert(first.rows[0].result.revision===1,"first saved revision");
    await rejects(() => db.query("select public.bil_smart_plan_cas_v1(0,$1::jsonb)",[JSON.stringify(payload)]),"PT409");
    await rejects(() => db.query("select public.bil_smart_plan_cas_v1(1,$1::jsonb)",[JSON.stringify({...payload,ownerId:b})]),"23514");
    for (const bad of [{}, {...payload,schema:2}, {...payload,days:[]}, {...payload,ownerId:null}, {...payload,revision:1.5}, {...payload,startDate:'2026-02-30'},
      {...payload,days:payload.days.map(d=>({...d,date:'2026-10-22'}))},
      {...payload,createdAt:'yesterday'}, {...payload,extraHealthProfile:'forbidden'},
      {...payload,days:payload.days.map((d,i)=>i===0?{...d,workout:{templateId:'push-a',exerciseIds:['squat'],minutes:35,completed:'true'}}:d)},
      {...payload,days:payload.days.map((d,i)=>i===0?{...d,workout:{templateId:'push-a',exerciseIds:['squat','squat'],minutes:35,completed:false}}:d)},
    ]) {
      await rejects(() => db.query("select public.bil_smart_plan_cas_v1(1,$1::jsonb)",[JSON.stringify(bad)]),"23514");
    }
    await rejects(() => db.query("update public.bil_smart_plan_sync_state set revision=500"),"42501");
    const setup={environment:'home',experience:'beginner',sessionMinutes:30,equipment:['none'],preferredTime:'18:00',goalId:'goal-a'};
    for(const badSetup of [{...setup,sessionMinutes:1},{...setup,sessionMinutes:30.5},
      {...setup,environment:'admin'},{...setup,experience:'diagnosed-fit'},
      {...setup,equipment:['none','none']},{...setup,equipment:['injected-equipment']},
      {...setup,preferredTime:'24:00'},{...setup,preferredTime:null},{...setup,goalId:'foreign/goal'},
      {...setup,ownerId:b},null]) {
      await rejects(() => db.query("select public.bil_smart_plan_cas_v1(1,$1::jsonb)",[JSON.stringify({...payload,setup:badSetup})]),"23514");
    }
    const active = {...payload,setup,revision:2,status:'active',changes:[{
      revision:2,at:payload.updatedAt,previousUpdatedAt:payload.updatedAt,
      reason:'status',previousStatus:'draft',beforeDays:[],
    }]};
    for (const change of [
      {...active.changes[0],revision:1}, {...active.changes[0],revision:2.5},
      {...active.changes[0],reason:'skip_security'}, {...active.changes[0],ownerId:b},
      {...active.changes[0],previousUpdatedAt:'2027-01-01T00:00:00Z'},
      {...active.changes[0],beforeDays:[{...payload.days[0],date:'2027-01-01'}]},
      {...active.changes[0],beforeDays:[{...payload.days[0],meals:[{slot:'breakfast',recipeId:'forbidden'}]}]},
      {...active.changes[0],beforeDays:[payload.days[0],payload.days[0]]},
    ]) {
      await rejects(() => db.query("select public.bil_smart_plan_cas_v1(1,$1::jsonb)",[JSON.stringify({...active,changes:[change]})]),"23514");
    }
    await rejects(() => db.query("select public.bil_smart_plan_cas_v1(1,$1::jsonb)",[JSON.stringify({...active,changes:Array(33).fill(active.changes[0])})]),"23514");
    const historyWrite = await db.query<{result:{revision:number,payload:unknown}}>("select public.bil_smart_plan_cas_v1(1,$1::jsonb) as result",[JSON.stringify(active)]);
    assert(historyWrite.rows[0].result.revision===2,"history is actually written");
    assert(JSON.stringify(historyWrite.rows[0].result.payload).includes('previousStatus'),"journal returned by real RPC");
    await actor(b);
    const foreign = await db.query("select * from public.bil_smart_plan_sync_state");
    assert(foreign.rows.length===0,"RLS hides other owner's data");
    await db.query("select public.bil_smart_plan_consent_v1(true)");
    const empty = await db.query<{result:{revision:number}}>("select public.bil_smart_plan_read_v1() as result");
    assert(empty.rows[0].result.revision===0,"RPC owner is token-derived");
    await actor(a);
    await db.exec("select set_config('test.premium','false',false)");
    await rejects(() => db.query("select public.bil_smart_plan_cas_v1(2,$1::jsonb)",[JSON.stringify(payload)]),"42501");
    // Privacy deletion stays available when paid access expires.
    await db.query("select public.bil_smart_plan_cas_v1(2,null)");
    await db.query("select public.bil_smart_plan_consent_v1(false)");
    await rejects(() => db.query("select public.bil_smart_plan_read_v1()"),"42501");
    await db.exec("reset role; set role anon");
    await rejects(() => db.query("select public.bil_smart_plan_read_v1()"),"42501");
    await db.exec("reset role");
    await db.query("delete from auth.users where id=$1",[a]);
    const removed = await db.query("select * from public.bil_smart_plan_sync_state");
    assert(removed.rows.length===0,"account deletion cascades plan state");
  } finally { await db.close(); }
});
