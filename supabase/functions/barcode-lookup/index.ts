import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { isValidGtin } from '../_shared/gtin.ts';

const json=(body:unknown,status=200)=>new Response(JSON.stringify(body),{status,headers:{'content-type':'application/json'}});
const env=(name:string)=>Deno.env.get(name)?.trim()??'';

function normalizedUsda(food:Record<string,unknown>,gtin:string){
  const nutrients=Array.isArray(food.foodNutrients)?food.foodNutrients:[];
  return {gtin,name:String(food.description??'').trim(),brand:String(food.brandOwner??food.brandName??'').trim(),
    ingredients:String(food.ingredients??'').trim(),serving_size:food.servingSize??null,
    serving_unit:food.servingSizeUnit??null,fdc_id:food.fdcId??null,
    nutrients:nutrients.slice(0,40).map((row)=>{const n=row as Record<string,unknown>;return {
      name:String(n.nutrientName??''),unit:String(n.unitName??''),amount:n.value??null};})};
}

Deno.serve(async(request)=>{
  if(request.method!=='POST')return json({error:'method_not_allowed'},405);
  const declaredLength=Number(request.headers.get('content-length')??0);
  if(declaredLength>4096)return json({error:'request_too_large'},413);
  const url=env('SUPABASE_URL'),service=env('SUPABASE_SERVICE_ROLE_KEY');
  if(!url||!service)return json({error:'server_not_configured'},503);
  const authorization=request.headers.get('authorization')??'';
  const token=authorization.replace(/^Bearer\s+/i,'').trim();
  if(!token)return json({error:'invalid_session'},401);
  const admin=createClient(url,service);
  const {data,error}=await admin.auth.getUser(token);
  if(error||!data.user)return json({error:'invalid_session'},401);
  const body=await request.json().catch(()=>null) as Record<string,unknown>|null;
  const gtin=body?.gtin;
  if(!isValidGtin(gtin))return json({error:'invalid_gtin'},400);
  const {data:allowed,error:gateError}=await admin.rpc('bil_has_premium_barcode_access',{p_owner_id:data.user.id});
  if(gateError)return json({error:'entitlement_unavailable'},503);
  if(allowed!==true)return json({error:'premium_required'},403);
  const {data:cached,error:cacheError}=await admin.rpc('bil_get_cached_barcode',{p_gtin:gtin});
  if(cacheError)return json({error:'barcode_cache_unavailable'},503);
  if(cached&&typeof cached==='object'&&!Array.isArray(cached))
    return json({status:'found',gtin,cache_hit:true,...cached});

  const key=env('BIL_USDA_API_KEY');
  if(!key)return json({status:'unresolved',gtin,cache_hit:false,
    next_step:'capture_product_label','notice':'No trusted product record matched. Scan the food label; BIL will not invent nutrition.'},404);
  const controller=new AbortController();const timer=setTimeout(()=>controller.abort(),8000);
  try{
    const response=await fetch(`https://api.nal.usda.gov/fdc/v1/foods/search?api_key=${encodeURIComponent(key)}`,{
      method:'POST',signal:controller.signal,headers:{'content-type':'application/json'},
      body:JSON.stringify({query:gtin,dataType:['Branded'],pageSize:10})});
    if(!response.ok)return json({error:'usda_unavailable'},503);
    const result=await response.json() as Record<string,unknown>;
    const foods=(Array.isArray(result.foods)?result.foods:[]) as Array<Record<string,unknown>>;
    const exact=foods.find((food)=>String(food.gtinUpc??'').replace(/\D/g,'')===gtin);
    if(!exact)return json({status:'unresolved',gtin,cache_hit:false,
      next_step:'capture_product_label','notice':'No trusted product record matched. Scan the food label; BIL will not invent nutrition.'},404);
    const payload=normalizedUsda(exact,gtin);
    if(!payload.name||payload.nutrients.length===0)return json({error:'untrusted_usda_record'},422);
    const {error:putError}=await admin.rpc('bil_put_cached_barcode',{p_gtin:gtin,p_source:'usda',p_payload:payload,p_ttl_days:30});
    if(putError)return json({error:'barcode_cache_unavailable'},503);
    return json({status:'found',gtin,source:'usda',cache_hit:false,payload});
  }catch{return json({error:'usda_unavailable'},503);}finally{clearTimeout(timer);}
});
