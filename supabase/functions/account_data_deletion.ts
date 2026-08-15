import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

Deno.serve(async (request) => {
  if (request.headers.get('x-bil-deletion-secret') !== Deno.env.get('BIL_INTERNAL_DELETION_SECRET')) return new Response('unauthorized', {status: 401});
  const url = Deno.env.get('SUPABASE_URL');
  const key = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!url || !key) return new Response('cloud_not_configured', {status: 503});
  const client = createClient(url, key, {auth: {persistSession: false}});
  const {data: requests, error} = await client.from('bil_account_deletion_requests').select('id,user_id').eq('status', 'pending').order('requested_at').limit(25);
  if (error) return new Response('request_read_failed', {status: 500});
  let completed = 0;
  let failed = 0;
  for (const item of requests ?? []) {
    const { data: claimed } = await client
      .from('bil_account_deletion_requests')
      .update({status: 'processing'})
      .eq('id', item.id)
      .eq('status', 'pending')
      .select('id')
      .maybeSingle();
    if (!claimed) continue;
    const {error: deletionError} = await client.auth.admin.deleteUser(item.user_id, false);
    if (!deletionError) {
      completed += 1;
      continue;
    }
    failed += 1;
    await client
      .from('bil_account_deletion_requests')
      .update({status: 'pending'})
      .eq('id', item.id)
      .eq('status', 'processing');
  }
  return Response.json({processed: requests?.length ?? 0, completed, failed});
});
