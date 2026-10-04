import assert from 'node:assert/strict';
export function validateReviewerTarget(id,email,acknowledgement) {
  assert.equal(acknowledgement,'OWNER_APPROVED_GOOGLE_REVIEWER_CONFIRMATION');
  assert.match(id,/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/);
  assert.match(email,/^google-play-review-[0-9]{8}@bilhealth[.]com$/);
  return {id,email};
}
export async function confirmReviewer({id,email,acknowledgement,key,fetcher=fetch}) {
  validateReviewerTarget(id,email,acknowledgement);
  assert.ok(key && key.length>30,'Missing server-only administrative credential');
  const origin='https://tgmanzhqulksykhslrzb.supabase.co';
  const request=async(method,body)=>{
    const response=await fetcher(origin+'/auth/v1/admin/users/'+id,{method,redirect:'error',signal:AbortSignal.timeout(15000),headers:{apikey:key,Authorization:'Bearer '+key,'Content-Type':'application/json'},body:body?JSON.stringify(body):undefined});
    if(!response.ok)throw new Error('reviewer_admin_request_failed_'+response.status);
    const parsed=await response.json();
    return parsed.user??parsed;
  };
  const before=await request('GET');
  assert.equal(before.id,id,'Reviewer identity mismatch');
  assert.equal(before.email?.toLowerCase(),email,'Reviewer email mismatch');
  if(!before.email_confirmed_at) await request('PUT',{email_confirm:true});
  const after=await request('GET');
  assert.equal(after.id,id);
  assert.equal(after.email?.toLowerCase(),email);
  assert.ok(after.email_confirmed_at,'Reviewer confirmation readback missing');
  // Never change credentials, app roles, store state or fabricate purchases.
  return {result:'OWNER_APPROVED_REVIEWER_EMAIL_CONFIRMED',ownerId:id,confirmed:true,passwordChanged:false,entitlementChanged:false};
}
if(process.argv[1]?.endsWith('confirm_owner_google_reviewer.mjs')){
  try { console.log(JSON.stringify(await confirmReviewer({id:process.env.BIL_REVIEWER_OWNER_ID,email:process.env.BIL_REVIEWER_EMAIL,acknowledgement:process.env.BIL_REVIEWER_OWNER_ACK,key:process.env.BIL_SUPABASE_SERVICE_ROLE_KEY}))); }
  catch { console.error('Owner-approved reviewer confirmation failed; no credentials exported.');process.exitCode=1; }
}

