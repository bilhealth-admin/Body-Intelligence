#!/usr/bin/env python3
"""Apply bounded retries to READ-ONLY BIL admin calls; never replay finance writes.
Fails closed on unexpected Replit code, and backs up the original file.
"""
from pathlib import Path
from hashlib import sha256
from shutil import copy2
p=Path('web/main.js')
if not p.is_file() or not Path('web/server.mjs').is_file():
    raise SystemExit('STOP: Run from the existing BIL Secure Admin project root')
s=p.read_text(encoding='utf8')
start='async function adminApi(body){'
end='function adoptSession(s)'
if 'async function renewAdminReadSession(generation){' in s:
    print('Already installed: no files changed')
    raise SystemExit(0)
if s.count(start)!=1 or s.count(end)!=1:
    raise SystemExit('STOP: Unexpected code shape; no changes applied')
a=s.index(start);b=s.index(end,a)
if sha256(s[a:b].encode()).hexdigest()!='5db9a8b2d9c57d146000e53ecc0fc529aa241ea5e01bfa92f6e96c51f2cb29b2':
    raise SystemExit('STOP: Existing Replit code differs; no changes applied')
new_block=R'''async function renewAdminReadSession(generation){
  if(!state.session?.refresh_token)throw new RemoteError('invalid_session',401);
  const {data}=await authApi('POST','token?grant_type=refresh_token',
    {refresh_token:state.session.refresh_token},false);
  if(generation!==state.generation)throw new RemoteError('invalid_session',401);
  adoptSession(data);
}
async function adminApi(body){
  if(!state.session?.access_token)throw new RemoteError('authentication_required',401);
  // ONLY idempotent reads get a bounded network retry. Financial writes must
  // never auto-retry, because a network timeout can follow a committed grant.
  const readOnly=['status','list','audit','reconcile'].includes(body.operation);
  const generation=state.generation;
  let refreshed=false, retriedTransport=false;
  for(;;){
    if(generation!==state.generation)throw new RemoteError('invalid_session',401);
    try{
      const reply=await timeoutFetch(API_HOST + '/functions/v1/bil-admin-web-v1',
        'POST',body,true,18000);
      if(generation!==state.generation)throw new RemoteError('invalid_session',401);
      if(reply.data?.policy_version!==EXPECTED_ADMIN_POLICY)
        throw new RemoteError('invalid_server_response',503);
      return reply;
    }catch(e){
      if(generation!==state.generation)throw new RemoteError('invalid_session',401);
      if(readOnly&&!refreshed&&e instanceof RemoteError&&e.status===401){
        refreshed=true;
        await renewAdminReadSession(generation);
        continue;
      }
      if(readOnly&&!retriedTransport&&e instanceof RemoteError&&
        (e.message==='request_failed'||
         (e.status>=502&&e.status<=504&&
          ['backend_unavailable','service_unavailable','list_unavailable','audit_unavailable'].includes(e.message)))){
        retriedTransport=true;
        await new Promise(resolve=>setTimeout(resolve,400));
        continue;
      }
      if(readOnly&&e instanceof RemoteError&&e.message==='request_failed')
        throw new RemoteError('backend_unavailable',503);
      throw e;
    }
  }
}
'''
if sha256(new_block.encode()).hexdigest()!='9f1178443bb6438c4a06e827b8da13fa6a12479d12b17d1354f93bfd6aebdc97':
    raise SystemExit('STOP: Patch integrity mismatch')
bak=p.with_name(p.name+'.before-status-retry-20261017')
if not bak.exists():copy2(p,bak)
p.write_text(s[:a]+new_block+s[b:],encoding='utf8')
print('PATCHED: only web/main.js; READ retry and safe session renewal; no automatic finance write retry')
