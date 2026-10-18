// BIL secure web admin: verified owner only, writes ENABLED for the allowlisted MFA-verified owner; commands remain separately validated.
// Supabase service-role key never leaves the Edge runtime.
import { createClient } from 'npm:@supabase/supabase-js@2.112.3';
import { handleWebAdmin } from './server.mjs';
const url=Deno.env.get('SUPABASE_URL')||'';
const anon=Deno.env.get('SUPABASE_ANON_KEY')||'';
const serviceRole=Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')||'';
const origin='https://583f1411-1db3-49c7-805d-a98a45079dc6-00-jw3rzv8h1494.spock.replit.dev';
Deno.serve((req:Request)=>{
  if(!url||!anon||!serviceRole) return new Response('{"error":"service_unavailable"}',{
    status:503,headers:{'content-type':'application/json','cache-control':'no-store'}});
  return handleWebAdmin(req,{
    env:(name:string)=>{
      if(name==='BIL_ADMIN_WEB_ALLOWED_ORIGINS') return [origin,origin+':3000','https://guilty-crazy-operation--bilhealthapp.replit.app','https://bilhealth-secure-admin.bilhealth-app.workers.dev'].join(',');
      if(name==='BIL_ADMIN_WEB_ENABLED') return 'true';
      if(name==='BIL_ADMIN_WEB_WRITE_ENABLED') return 'true';
      if(name==='BIL_ADMIN_WEB_FINANCE_OWNER_IDS') return 'cabcec51-9f56-4bd8-af59-ec0cc5c09e72';
      return Deno.env.get(name)?.trim()||'';
    },
    now:()=>Date.now(),
    makeUserClient:(token:string)=>createClient(url,anon,{
      global:{headers:{Authorization:'Bearer '+token}},
      auth:{persistSession:false,autoRefreshToken:false}
    }),
    makeServiceClient:()=>createClient(url,serviceRole,{auth:{persistSession:false,autoRefreshToken:false}})
  });
});
