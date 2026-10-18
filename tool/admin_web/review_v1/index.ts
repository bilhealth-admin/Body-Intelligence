import { createClient } from 'npm:@supabase/supabase-js@2.112.3';
import { handleReview } from './review_server.mjs';

const url = Deno.env.get('SUPABASE_URL') || '';
const publishable = Deno.env.get('SUPABASE_ANON_KEY') || '';
const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || '';
// Exact HTTPS production host, never a wildcard. Preview hosts require a separate review.
const origin = 'https://bilhealth-secure-admin.bilhealth-app.workers.dev';
Deno.serve((request:Request) => {
  if (!url || !publishable || !serviceKey)
    return new Response('{"error":"service_unavailable"}',{status:503,headers:{
      'content-type':'application/json','cache-control':'no-store'
    }});
  return handleReview(request,{
    env:(key:string)=>{
      if(key==='BIL_ADMIN_WEB_ALLOWED_ORIGINS')return origin;
      if(key==='BIL_ADMIN_WEB_FINANCE_OWNER_IDS')return 'cabcec51-9f56-4bd8-af59-ec0cc5c09e72';
      if(key==='BIL_ADMIN_REVIEW_ENABLED')return 'true';
      if(key==='BIL_ADMIN_REVIEW_WRITE_ENABLED')return 'false'; // transition gate: separate approval
      return Deno.env.get(key)?.trim()||'';
    },
    now:()=>Date.now(),
    makeUserClient:(token:string)=>createClient(url,publishable,{
      global:{headers:{Authorization:'Bearer '+token}},
      auth:{persistSession:false,autoRefreshToken:false}
    }),
    makeServiceClient:()=>createClient(url,serviceKey,{
      auth:{persistSession:false,autoRefreshToken:false}
    }),
  });
});