import { createClient } from 'npm:@supabase/supabase-js@2.112.3';
import { handleOps } from './ops_server.mjs';

const supabaseUrl=Deno.env.get('SUPABASE_URL')||'';
const anonKey=Deno.env.get('SUPABASE_ANON_KEY')||'';
const serviceKey=Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')||'';
const preview='https://583f1411-1db3-49c7-805d-a98a45079dc6-00-jw3rzv8h1494.spock.replit.dev';
const published='https://guilty-crazy-operation--bilhealthapp.replit.app';
Deno.serve((request:Request) => {
  if(!supabaseUrl || !anonKey || !serviceKey) {
    return new Response('{"error":"service_unavailable"}',{status:503,headers:{
      'content-type':'application/json','cache-control':'no-store'}});
  }
  return handleOps(request,{
    env:(key:string)=>{
      if(key==='BIL_ADMIN_WEB_ALLOWED_ORIGINS')
        return [preview,preview+':3000',published,'https://bilhealth-secure-admin.bilhealth-app.workers.dev'].join(',');
      if(key==='BIL_ADMIN_WEB_FINANCE_OWNER_IDS')
        return 'cabcec51-9f56-4bd8-af59-ec0cc5c09e72';
      if(key==='BIL_ADMIN_OPS_ENABLED') return 'true';
      if(key==='BIL_ADMIN_OPS_WRITE_ENABLED') return 'true'; // owner-only MFA + typed high-impact confirmations
      return Deno.env.get(key)?.trim() || '';
    },
    now:()=>Date.now(),
    makeUserClient:(token:string)=>createClient(supabaseUrl,anonKey,{
      global:{headers:{Authorization:'Bearer '+token}},
      auth:{persistSession:false,autoRefreshToken:false}
    }),
    makeServiceClient:()=>createClient(supabaseUrl,serviceKey,{
      auth:{persistSession:false,autoRefreshToken:false}
    })
  });
});
