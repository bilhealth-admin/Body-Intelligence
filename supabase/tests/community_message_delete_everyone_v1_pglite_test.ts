import { PGlite } from "npm:@electric-sql/pglite@0.3.15";
// LOCAL SQL/auth-claim fixture only. Never a hosted normal-Auth client/JWT.
const S="25110000-0000-4000-8000-000000000001";
const R="25110000-0000-4000-8000-000000000002";
const O="25110000-0000-4000-8000-000000000003";
const Q="25110000-0000-4000-8000-000000000101";
const MISSING="25110000-0000-4000-8000-000000000999";
const BODY="Owned synthetic wellness reply";
function check(v:unknown,message:string):asserts v {if(!v)throw new Error(message);}
async function sqlstate(action:()=>Promise<unknown>,code:string){
 try{await action();}catch(e){if((e as {code?:string}).code===code)return;throw e;}
 throw new Error(`Expected SQLSTATE ${code}`);
}
async function fixture(){
 const db=new PGlite();
 await db.exec("create role anon;create role authenticated;create role service_role;create role supabase_auth_admin;create role dashboard_user;");
 const baseline=new URL("./fixtures/community_message_baseline/",import.meta.url);
 for(const file of ["schema.sql","functions.sql","contracts.sql"])await db.exec(await Deno.readTextFile(new URL(file,baseline)));
 await db.exec(await Deno.readTextFile(new URL("../migrations/20261013062209_community_message_delivery_v2.sql",import.meta.url)));
 // The focused message fixture omits For-me; install its actual current
 // migration and captured live EXECUTE ACL before checking it is unchanged.
 await db.exec(await Deno.readTextFile(new URL("../migrations/20261023190403_harden_bil_delete_message_search_path.sql",import.meta.url)));
 await db.exec("revoke all on function public.bil_delete_message(uuid) from public,anon; grant execute on function public.bil_delete_message(uuid) to authenticated,service_role;");
 const oldForMe=(await db.query<Record<string, unknown>>(`select pg_get_functiondef('public.bil_delete_message(uuid)'::regprocedure) as definition`)).rows[0].definition;
 const grantsBefore=(await db.query<Record<string, unknown>>(`select has_table_privilege('authenticated','public.bil_messages','DELETE') as d,has_table_privilege('authenticated','public.bil_messages','UPDATE') as u,has_table_privilege('authenticated','public.bil_messages','SELECT') as s`)).rows[0];
 await db.exec(await Deno.readTextFile(new URL("../migrations/20261119044605_community_dm_delete_for_everyone_v1.sql",import.meta.url)));
 await db.query<Record<string, unknown>>(`insert into auth.users(id,email) values($1,'sender@example.invalid'),($2,'recipient@example.invalid'),($3,'outsider@example.invalid')`,[S,R,O]);
 await db.query<Record<string, unknown>>(`insert into public.bil_public_profiles(user_id,display_name,allow_messages_from) values($1,'Sender','friends'),($2,'Recipient','friends'),($3,'Outsider','friends')`,[S,R,O]);
 await db.query<Record<string, unknown>>(`insert into public.bil_friendships(requester_id,addressee_id,status,responded_at) values($1,$2,'accepted',clock_timestamp())`,[S,R]);
 await db.exec(`insert into public.bil_content_policies(version,locale_code,document_url,effective_at,active) values('test-v1','en','https://example.invalid/community-policy',clock_timestamp()-interval '1 day',true)`);
 // Preserve the actual acceptance trigger: each fixture row needs its own
 // matching auth claim, even when the local fixture is populated as admin.
 for (const id of [S,R]) {
  await db.query<Record<string, unknown>>(`select set_config('request.jwt.claim.sub',$1,false)`,[id]);
  await db.query<Record<string, unknown>>(`insert into public.bil_content_policy_acceptances(user_id,policy_version,accepted_at) values($1,'test-v1',clock_timestamp())`,[id]);
 }
 async function actor(id:string|null){
  await db.exec("reset role");
  await db.query<Record<string, unknown>>(`select set_config('request.jwt.claim.sub',coalesce($1,''),false),set_config('request.jwt.claim.role','authenticated',false),set_config('request.jwt.claims',json_build_object('sub',$1,'role','authenticated')::text,false)`,[id]);
  await db.exec("set role authenticated");
 }
 async function admin(){await db.exec("reset role");}
 async function send(body=BODY,request=Q){
  await actor(S);const r=(await db.query<Record<string, unknown>>(`select public.bil_send_community_message_v2($1,$2,$3) as receipt`,[R,body,request])).rows[0] as {receipt:Record<string,unknown>};return r.receipt;
 }
 async function erase(id:string){await db.query<Record<string, unknown>>(`select public.bil_delete_message_for_everyone_v1($1)`,[id]);}
 async function receipt(){return (await db.query<Record<string, unknown>>(`select public.bil_get_community_message_delivery_v2($1) as receipt`,[Q])).rows[0] as {receipt:Record<string,unknown>};}
 return {db,actor,admin,send,erase,receipt,grantsBefore,oldForMe};
}
async function run(f:(x:Awaited<ReturnType<typeof fixture>>)=>Promise<void>){const x=await fixture();try{await f(x);}finally{await x.db.close();}}
Deno.test("DM everyone SQL: sender erases body; hash tombstone/replay preserve idempotency and generic notifications",()=>run(async x=>{
 const first=await x.send();await x.erase(first.message_id as string);await x.erase(first.message_id as string);await x.erase(MISSING);
 const r=(await x.receipt()).receipt;check(r.status==="removed"&&r.body===null&&r.message_id===null,"receipt not tombstoned");
 const replay=await x.send();check(replay.status==="removed"&&replay.body===null&&replay.message_id===null,"send replay resurrected text");
 await sqlstate(()=>x.send("Different owned text"),"22023");
 await x.admin();check(Number((await x.db.query<Record<string, unknown>>(`select count(*) as n from public.bil_messages`)).rows[0].n)===0,"canonical body retained/recreated");
 const rows=(await x.db.query<Record<string, unknown>>(`select octet_length(body_sha256) as n,message_id from private.bil_community_message_deliveries_v2`)).rows;
 check(rows.length===1&&rows[0].n===32&&rows[0].message_id===null,"hash/idempotency receipt removed");
 check(Number((await x.db.query<Record<string, unknown>>(`select count(*) as n from information_schema.columns where table_schema='private' and table_name='bil_community_message_deliveries_v2' and column_name='body'`)).rows[0].n)===0,"raw receipt body copy introduced");
 const pushes=(await x.db.query<Record<string, unknown>>(`select body from public.bil_push_outbox where category='message'`)).rows;
 check(pushes.length===1&&pushes[0].body==="You have a new private message.","raw push copy or duplicate notification");
 const auditColumns=(await x.db.query<Record<string, unknown>>(`select column_name from information_schema.columns where table_schema='public' and table_name='bil_community_audit_events'`)).rows.map(r=>r.column_name);
 check(!auditColumns.includes("body"),"audit raw body copy appeared");
}));
Deno.test("DM everyone SQL: recipient/outsider/null/anonymous have no sender-erasure or ownership-forgery authority",()=>run(async x=>{
 const first=await x.send();await x.actor(R);await x.erase(first.message_id as string);
 const rows=(await x.db.query<Record<string, unknown>>(`select body from public.bil_messages where id=$1`,[first.message_id])).rows;check(rows.length===1&&rows[0].body===BODY,"recipient erased sender text");
 await sqlstate(()=>x.db.query<Record<string, unknown>>(`update public.bil_messages set sender_id=$1,recipient_id=$2 where id=$3`,[R,S,first.message_id]),"42501");
 await x.actor(O);await x.erase(first.message_id as string);await x.erase(MISSING);
 check((await x.db.query<Record<string, unknown>>(`select id from public.bil_messages where id=$1`,[first.message_id])).rows.length===0,"outsider read row");
 await x.actor(null);await sqlstate(()=>x.erase(first.message_id as string),"42501");
 await x.admin();await x.db.exec("set role anon");await sqlstate(()=>x.erase(first.message_id as string),"42501");
 await x.actor(S);await sqlstate(()=>x.db.query<Record<string, unknown>>(`select public.bil_delete_message_for_everyone_v1(null)`),"22023");
 check((await x.receipt()).receipt.body===BODY,"foreign/invalid caller mutated text");
}));
Deno.test("DM everyone SQL: old For me keeps recipient copy; sender may then erase; ACLs and old definition unchanged",()=>run(async x=>{
 const first=await x.send();await x.db.query<Record<string, unknown>>(`select public.bil_delete_message($1)`,[first.message_id]);
 check((await x.db.query<Record<string, unknown>>(`select id from public.bil_messages where id=$1`,[first.message_id])).rows.length===0,"For me did not hide sender view");
 await x.actor(R);check((await x.db.query<Record<string, unknown>>(`select body from public.bil_messages where id=$1`,[first.message_id])).rows[0].body===BODY,"For me erased recipient copy");
 await x.actor(S);await x.erase(first.message_id as string);await x.actor(R);
 check((await x.db.query<Record<string, unknown>>(`select body from public.bil_messages where id=$1`,[first.message_id])).rows.length===0,"Everyone left recipient text");
 await x.admin();const r=(await x.db.query<Record<string, unknown>>(`select has_function_privilege('anon','public.bil_delete_message_for_everyone_v1(uuid)','EXECUTE') as a,has_function_privilege('authenticated','public.bil_delete_message_for_everyone_v1(uuid)','EXECUTE') as u,pg_get_functiondef('public.bil_delete_message(uuid)'::regprocedure) as old`)).rows[0];
 check(r.a===false&&r.u===true,"RPC grant widened");check(r.old===x.oldForMe,"For me definition changed");
 const after=(await x.db.query<Record<string, unknown>>(`select has_table_privilege('authenticated','public.bil_messages','DELETE') as d,has_table_privilege('authenticated','public.bil_messages','UPDATE') as u,has_table_privilege('authenticated','public.bil_messages','SELECT') as s`)).rows[0];
 check(JSON.stringify(after)===JSON.stringify(x.grantsBefore),"table grants expanded");
}));
Deno.test("DM everyone SQL: own erasure survives lost contact/publication rights without restoring them",()=>run(async x=>{
 const first=await x.send();await x.admin();
 await x.db.query<Record<string, unknown>>(`delete from public.bil_friendships where requester_id=$1 and addressee_id=$2`,[S,R]);
 await x.db.query<Record<string, unknown>>(`insert into public.bil_blocks(blocker_id,blocked_id) values($1,$2)`,[R,S]);
 await x.db.query<Record<string, unknown>>(`insert into private.bil_community_member_access(user_id,suspended,reason) values($1,true,'Owned local erasure fixture')`,[S]);
 await x.db.query<Record<string, unknown>>(`delete from public.bil_content_policy_acceptances where user_id=$1`,[S]);
 await x.actor(S);await x.erase(first.message_id as string);check((await x.receipt()).receipt.status==="removed","erasure blocked by lost contact/publish permission");
 await sqlstate(()=>x.send("New contact is still forbidden","25110000-0000-4000-8000-000000000102"),"42501");
}));
Deno.test("DM everyone SQL: recipient deletion cascade permits idempotent sender cleanup without resurrection",()=>run(async x=>{
 const first=await x.send();await x.admin();await x.db.query<Record<string, unknown>>(`delete from auth.users where id=$1`,[R]);await x.actor(S);await x.erase(first.message_id as string);await x.erase(first.message_id as string);
 await x.admin();check(Number((await x.db.query<Record<string, unknown>>(`select count(*) as n from public.bil_messages`)).rows[0].n)===0,"missing-recipient cleanup recreated text");
}));
Deno.test("DM everyone SQL: deleting loaded noncached row leaves one-row stream head unchanged but exact RLS presence detects absence",()=>run(async x=>{
 const first=await x.send();
 const second=await x.send("Second owned wellness reply","25110000-0000-4000-8000-000000000102");
 await x.admin();await x.db.query<Record<string, unknown>>(`update public.bil_messages set created_at=case when id=$1 then '2026-11-19 01:00:00Z'::timestamptz else '2026-11-19 01:01:00Z'::timestamptz end`,[first.message_id]);
 await x.actor(R);const history=(await x.db.query<Record<string, unknown>>(`select id from public.bil_messages where sender_id=$1 and recipient_id=$2 order by created_at,id`,[S,R])).rows;
 check(history.length===2,"two loaded existing messages required");
 const before=(await x.db.query<Record<string, unknown>>(`select id from public.bil_messages where sender_id=$1 order by created_at,id limit 1`,[S])).rows[0].id;
 check(before===first.message_id,"one-row cache fixture not the preserved row");
 await x.actor(S);await x.erase(second.message_id as string);await x.actor(R);
 const after=(await x.db.query<Record<string, unknown>>(`select id from public.bil_messages where sender_id=$1 order by created_at,id limit 1`,[S])).rows[0].id;
 check(after===before,"preserved stream cache row unexpectedly changed");
 const presence=(await x.db.query<Record<string, unknown>>(`select id,sender_id,recipient_id from public.bil_messages where id=any($1::uuid[]) and ((sender_id=$2 and recipient_id=$3) or (sender_id=$3 and recipient_id=$2))`,[[first.message_id,second.message_id],S,R])).rows;
 check(presence.length===1&&presence[0].id===first.message_id,"exact participant presence did not prune only erased noncached row");
}));
