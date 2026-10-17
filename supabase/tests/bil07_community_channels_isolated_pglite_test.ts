import { PGlite } from "npm:@electric-sql/pglite@0.3.15";
const A="35000000-0000-4000-8000-000000000001";
const B="35000000-0000-4000-8000-000000000002";
const C="35000000-0000-4000-8000-000000000003";
const PUBLIC="35000000-0000-4000-8000-000000000010";
const PRIVATE="35000000-0000-4000-8000-000000000011";
const KEY="35000000-0000-4000-8000-000000000111";
function assert(value: unknown, label:string): asserts value {
  if(!value) throw new Error(label);
}
async function denied(action:()=>Promise<unknown>, expected:string) {
  try {await action();} catch(e) {
    if((e as {code?:string}).code===expected) return;
    throw e;
  }
  throw new Error("Missing SQLSTATE "+expected);
}
async function rpc(db:PGlite,sql:string,params:unknown[]=[]){
  const rows=(await db.query(sql,params)).rows as Record<string,unknown>[];
  const value=rows[0].result;
  return (typeof value==="string"?JSON.parse(value):value) as Record<string,unknown>;
}
async function actor(db:PGlite,id:string|null,accepted=true) {
  await db.query(
    "select set_config('request.jwt.claim.sub',$1,false),set_config('bil07.accepted',$2,false)",
    [id??"",accepted?"yes":"no"]);
}
async function setup(db:PGlite) {
  await db.exec("create role anon;create role authenticated;create role service_role;create schema auth;create schema private;");
  await db.exec(
    "create table auth.users(id uuid primary key);"+
    "create table public.bil_public_profiles(user_id uuid primary key references auth.users(id),display_name text not null);"+
    "create table public.bil_blocks(blocker_id uuid not null references auth.users(id),blocked_id uuid not null references auth.users(id),primary key(blocker_id,blocked_id));"+
    "create function auth.uid() returns uuid language sql stable as $$ select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;"+
    "create function public.bil_can_use_community() returns boolean language sql stable as $$ select auth.uid() is not null $$;"+
    "create function private.bil_assert_current_community_policy() returns text language plpgsql stable security definer set search_path='' as $$ begin if coalesce(pg_catalog.current_setting('bil07.accepted',true),'')<>'yes' then raise exception 'community_policy_acceptance_required' using errcode='42501'; end if; return 'test-policy'; end $$;"+
    "create function private.bil_is_blocked_with(p_other uuid) returns boolean language sql stable security definer set search_path='' as $$ select auth.uid() is null or p_other is null or exists(select 1 from public.bil_blocks b where (b.blocker_id=auth.uid() and b.blocked_id=p_other) or (b.blocked_id=auth.uid() and b.blocker_id=p_other)) $$;"
  );
  await db.exec(await Deno.readTextFile(new URL(
    "../migrations/20261017210000_bil07_community_channels_isolated.sql",import.meta.url)));
  await db.query("insert into auth.users(id) values ($1),($2),($3)",[A,B,C]);
  await db.query(
    "insert into public.bil_public_profiles(user_id,display_name) values ($1,'A'),($2,'B'),($3,'C')",[A,B,C]);
}
async function rooms(db:PGlite){
  await db.query(
    "insert into public.bil07_channels_v1(id,slug,title,description,visibility,enabled) values ($1,'general-test','General fixture','','public',true),($2,'private-test','Members fixture','','members',true)",
    [PUBLIC,PRIVATE]);
  await db.query(
    "insert into public.bil07_channel_memberships_v1(channel_id,owner_id,status) values ($1,$2,'active')",
    [PRIVATE,B]);
}
Deno.test("isolated BIL07 schema: empty by default, authenticated owner, no private room leak",async()=>{
  const db=new PGlite();
  try{
    await setup(db);await db.exec("set role authenticated");await actor(db,A);
    const cap=await rpc(db,"select public.bil07_channel_capabilities_v1() result");
    assert(cap.owner_id===A && cap.contract_version===1,"cap owner/version");
    assert(cap.max_page_size===100 && cap.max_text_code_points===2000
      && cap.realtime_available===false,"mobile capability drift");
    const empty=await rpc(db,"select public.bil07_channel_directory_v1(null,50) result");
    assert((empty.channels as unknown[]).length===0,"invented channels");
    await denied(()=>db.query("select * from public.bil07_channels_v1"),"42501");
    await db.exec("reset role");await rooms(db);
    await db.exec("set role authenticated");await actor(db,A);
    const response=await rpc(db,"select public.bil07_channel_directory_v1(null,50) result");
    const list=response.channels as Record<string,unknown>[];
    assert(list.length===1 && list[0].id===PUBLIC,"private channel leaked");
    assert(list[0].membership==="active" && list[0].can_send===true,"public send disabled");
    await denied(()=>db.query(
      "select public.bil07_channel_messages_v1($1,null,null,50)",[PRIVATE]),"42501");
  }finally{await db.close();}
});
Deno.test("isolated BIL07 send is exactly-once; receipts, blocks and presence are owner-scoped",async()=>{
  const db=new PGlite();
  try{
    await setup(db);await rooms(db);await db.exec("set role authenticated");await actor(db,A);
    const sent=await rpc(db,"select public.bil07_channel_send_v1($1,$2,$3) result",
      [PUBLIC,KEY,"مرحبا\nTwo lines"]);
    const msg=sent.message as Record<string,unknown>;
    assert(sent.idempotent_replay===false && msg.sequence===1 && msg.author_id===A,"original send");
    const retry=await rpc(db,"select public.bil07_channel_send_v1($1,$2,$3) result",
      [PUBLIC,KEY,"مرحبا\nTwo lines"]);
    assert(retry.idempotent_replay===true &&
      (retry.message as Record<string,unknown>).id===msg.id,"duplicate created");
    await denied(()=>db.query("select public.bil07_channel_send_v1($1,$2,$3)",
      [PUBLIC,KEY,"changed payload"]),"22023");
    const page=await rpc(db,"select public.bil07_channel_messages_v1($1,null,null,50) result",[PUBLIC]);
    assert((page.messages as unknown[]).length===1
      && page.next_before_sequence===1 && page.next_after_sequence===1,"page cursor");
    const presence=await rpc(db,"select public.bil07_channel_presence_v1($1,true) result",[PUBLIC]);
    assert(presence.ttl_seconds===90 && presence.online_count===1,"presence missing");
    await actor(db,B);
    const directory=await rpc(db,"select public.bil07_channel_directory_v1(null,50) result");
    const cards=directory.channels as Record<string,unknown>[];
    assert(cards.length===2 && cards.find(c=>c.id===PUBLIC)?.unread_count===1,"member/unread count");
    await rpc(db,"select public.bil07_channel_read_v1($1,$2::uuid[]) result",[PUBLIC,[msg.id]]);
    const readback=await rpc(db,
      "select public.bil07_channel_readback_v1($1,$2::uuid[]) result",[PUBLIC,[msg.id]]);
    assert(readback.unread_count===0 &&
      (readback.acknowledged_message_ids as string[]).includes(String(msg.id)),"readback");
    await denied(()=>db.query("select public.bil07_channel_read_v1($1,$2::uuid[])",
      [PRIVATE,[msg.id]]),"42501");
    await db.exec("reset role");
    const rows=await db.query("select count(*)::int as n from public.bil07_channel_messages_v1");
    assert((rows.rows[0] as {n:number}).n===1,"duplicate persisted");
    await db.query("insert into public.bil_blocks(blocker_id,blocked_id) values ($1,$2)",[B,A]);
    await db.exec("set role authenticated");await actor(db,B);
    const filtered=await rpc(db,
      "select public.bil07_channel_messages_v1($1,null,null,50) result",[PUBLIC]);
    assert((filtered.messages as unknown[]).length===0,"blocked user visible");
  }finally{await db.close();}
});
Deno.test("isolated BIL07 deny consent, explicit ban and unauthenticated access",async()=>{
  const db=new PGlite();
  try{
    await setup(db);await rooms(db);await db.exec("set role authenticated");await actor(db,C,false);
    await denied(()=>db.query("select public.bil07_channel_send_v1($1,$2,$3)",
      [PUBLIC,KEY,"no consent"]),"42501");
    await actor(db,C,true);await db.exec("reset role");
    await db.query("insert into public.bil07_channel_memberships_v1(channel_id,owner_id,status) values ($1,$2,'banned')",[PUBLIC,C]);
    await db.exec("set role authenticated");await actor(db,C);
    const v=await rpc(db,"select public.bil07_channel_directory_v1(null,50) result");
    const blocked=(v.channels as Record<string,unknown>[]).find(x=>x.id===PUBLIC);
    assert(blocked?.membership==="banned" && blocked.can_read===false &&
      blocked.can_send===false && blocked.unread_count===null,"ban bypass");
    await denied(()=>db.query("select public.bil07_channel_send_v1($1,$2,$3)",
      [PUBLIC,KEY,"banned"]),"42501");
    await denied(()=>db.query("select * from private.bil07_channel_presence_v1"),"42501");
    await db.exec("reset role");await actor(db,null);await db.exec("set role anon");
    await denied(()=>db.query("select public.bil07_channel_capabilities_v1()"),"42501");
  }finally{await db.close();}
});
