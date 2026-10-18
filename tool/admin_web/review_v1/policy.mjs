// BIL verified identity and strict-origin shared policy (server-side only).
const UUID=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
export class WebAdminError extends Error {
  constructor(code,status=400){super(code);this.code=code;this.status=status}
}
export function exactOrigins(raw){
  const entries=String(raw??'').split(',').map(x=>x.trim()).filter(Boolean);
  if(entries.length===0||entries.length>8)return [];
  const origins=[];
  for(const value of entries){
    let u;try{u=new URL(value)}catch{return []}
    if(u.protocol!=='https:'||u.origin!==value||u.username||u.password||u.pathname!=='/'||u.search||u.hash||u.port)return [];
    if(!origins.includes(value))origins.push(value);
  }
  return origins;
}
export function ownersAllowlist(raw){
  const entries=String(raw??'').split(',').map(x=>x.trim().toLowerCase()).filter(Boolean);
  if(!entries.length||entries.some(x=>!UUID.test(x)))return new Set();
  return new Set(entries);
}
export function readBearer(raw){
  const match=/^Bearer ([A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+)$/.exec(String(raw||''));
  if(!match)throw new WebAdminError('authentication_required',401);
  return match[1];
}
export function verifiedClaims(token,id,now){
  let claims;
  try{
    let b64=token.split('.')[1].replace(/-/g,'+').replace(/_/g,'/');
    b64+='='.repeat((4-(b64.length%4))%4);
    claims=JSON.parse(atob(b64));
  }catch{throw new WebAdminError('invalid_session',401)}
  if(!claims||claims.sub!==id||claims.role!=='authenticated'||
     !Number.isFinite(claims.exp)||claims.exp<=now||
     (typeof claims.nbf==='number'&&claims.nbf>now)){
    throw new WebAdminError('invalid_session',401);
  }
  return claims;
}
export function requireAal2(claims){
  if(claims?.aal!=='aal2')throw new WebAdminError('mfa_required',403);
}
export function requireRecentTotp(claims,now,maxAge=90){
  requireAal2(claims);
  const recent=Array.isArray(claims?.amr)&&claims.amr.some(item=>
    item&&item.method==='totp'&&Number.isSafeInteger(item.timestamp)&&
    item.timestamp>=now-maxAge&&item.timestamp<=now+30);
  if(!recent)throw new WebAdminError('fresh_mfa_required',403);
  return true;
}
export function requireObject(v){
  if(!v||typeof v!=='object'||Array.isArray(v)||Object.getPrototypeOf(v)!==Object.prototype)
    throw new WebAdminError('invalid_body');
  return v;
}