// Independent website bridge. No database, authentication, app, or site mutations.
export const VERSION = 'bil-friend-link-web-20261005-v1';
export const CODE_PATTERN = /^[a-f0-9]{32}$/;
export function parseCode(value) {
  if (typeof value !== 'string') return null;
  const candidate = value.trim().toLowerCase();
  return CODE_PATTERN.test(candidate) ? candidate : null;
}
export function nativeUri(code) {
  const parsed = parseCode(code);
  if (!parsed) throw new TypeError('Invalid BIL public code');
  return `bil://community/member/${parsed}`;
}
const strings = {
  ar: {
    dir: 'rtl', title: 'افتح صديقك في BIL', overline: 'مجتمع BIL',
    heading: 'تواصلوا. وتقدّموا معًا.',
    intro: 'افتح الملف داخل تطبيق BIL، ثم أرسل طلب الصداقة من هناك.',
    open: 'فتح الملف في BIL', copy: 'نسخ رابط المشاركة', share: 'مشاركة الرابط',
    help: 'لم يفتح التطبيق؟ افتح هذه الصفحة في Safari على iPhone أو Chrome على Android، ثم اضغط «فتح الملف في BIL». يجب أن يكون التطبيق مثبتًا.',
    safety: 'هذا رابط لملف عام فقط؛ لا يسجّل دخولًا ولا يضيف صديقًا تلقائيًا. يتحقق BIL من صلاحية الرمز وخصوصية الملف عند الفتح.',
    paste: 'الصق رمز BIL أو الرابط الذي يبدأ بـ bil://', create: 'إنشاء رابط قابل للمشاركة',
    invalid: 'الرابط غير صحيح. استخدم رمز BIL من 32 حرفًا ورقمًا أو رابط مشاركة الرمز الأصلي.',
    copied: 'تم نسخ الرابط. أرسله لصديقك.', copyFailed: 'تعذّر النسخ التلقائي. اضغط مطولًا على الرابط أدناه لنسخه.',
    label: 'رابط المشاركة', home: 'موقع BIL', waiting: 'أنشئ رابطًا يفتح في المتصفح، ومنه افتح تطبيق BIL.',
  },
  en: {
    dir: 'ltr', title: 'Open your friend in BIL', overline: 'BIL COMMUNITY',
    heading: 'Connect. Make progress together.',
    intro: 'Open the profile in BIL, then send your friend request in the app.',
    open: 'Open profile in BIL', copy: 'Copy share link', share: 'Share link',
    help: 'App did not open? Open this page in Safari on iPhone or Chrome on Android, then tap “Open profile in BIL”. BIL must be installed.',
    safety: 'This is a public-profile link only. It does not sign you in or add a friend automatically. BIL checks the code and profile privacy when opened.',
    paste: 'Paste your BIL code or the original bil:// link', create: 'Create a shareable link',
    invalid: 'Invalid link. Use your 32-character BIL public code or the original share-code link.',
    copied: 'Link copied. Send it to your friend.', copyFailed: 'Automatic copy failed. Press and hold the link below to copy it.',
    label: 'Share link', home: 'BIL website', waiting: 'Create a browser link, then open BIL from that page.',
  },
};
const escapeHtml = (text) => String(text).replace(/[&<>"']/g, ch => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[ch]));
export function renderPage({code = null, lang = 'ar', origin = '', nonce = '', invalid = false} = {}) {
  const s = strings[lang] || strings.ar;
  const clean = parseCode(code);
  const shareUrl = clean ? `${origin}/open-bil?code=${clean}` : '';
  const alt = lang === 'en' ? 'ar' : 'en';
  const altHref = `/open-bil?lang=${alt}${clean ? `&code=${clean}` : ''}`;
  const action = clean ? `<a class="primary" id="open-app" href="${nativeUri(clean)}">${s.open}<span aria-hidden="true">↗</span></a>` : '';
  const share = clean ? `<div class="row"><button id="copy-link" type="button">${s.copy}</button><button id="share-link" type="button">${s.share}</button></div><label for="share-url">${s.label}</label><input id="share-url" dir="ltr" readonly value="${escapeHtml(shareUrl)}" aria-label="${s.label}">` : '';
  return `<!doctype html>
<html lang="${lang}" dir="${s.dir}"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover"><meta name="robots" content="noindex,nofollow"><meta name="referrer" content="no-referrer"><meta name="color-scheme" content="dark"><title>${s.title}</title><meta property="og:title" content="${s.title}"><meta property="og:description" content="${s.intro}"><meta property="og:type" content="website"><meta name="bil-bridge-version" content="${VERSION}">
<style nonce="${nonce}">
*{box-sizing:border-box}html{font-family:system-ui,-apple-system,"Segoe UI",sans-serif;background:#08111b;color:#edf7ff}body{margin:0;min-height:100svh;padding:24px max(18px,env(safe-area-inset-right)) max(24px,env(safe-area-inset-bottom));background:radial-gradient(ellipse at 70% 0%,#123653 0,transparent 55%)}main{max-width:520px;margin:0 auto}header{display:flex;align-items:center;justify-content:space-between;padding:10px 0 36px}.logo{font-size:28px;font-weight:850;letter-spacing:2px}.lang{border:1px solid #36536b;border-radius:999px;padding:9px 16px;text-decoration:none;color:#dbf1ff}.card{border:1px solid #294154;border-radius:28px;padding:28px 24px;background:#0d1b29;box-shadow:0 25px 60px #0004}.eyebrow{font-size:12px;letter-spacing:1.8px;font-weight:750;color:#72d9fb}.mark{display:grid;place-items:center;width:64px;height:64px;border:1px solid #377097;border-radius:20px;background:linear-gradient(145deg,#123454,#123d54);font-size:28px;margin:18px 0 24px}h1{font-size:clamp(28px,7vw,36px);line-height:1.3;letter-spacing:-.8px;margin:14px 0}p{font-size:16px;line-height:1.85;color:#b6cada;margin:12px 0 22px}a,button,input,textarea{font:inherit}.primary{display:flex;justify-content:center;align-items:center;gap:14px;width:100%;min-height:58px;padding:15px;border-radius:17px;background:linear-gradient(100deg,#159fdd,#356be6);color:white;text-decoration:none;font-weight:750;border:0;cursor:pointer}.row{display:flex;gap:10px;margin:12px 0 22px}.row button{flex:1;min-width:0;background:#142c40;border:1px solid #355268;color:#e6f3fe;padding:12px 8px;border-radius:14px;cursor:pointer}label{display:block;color:#92adc2;font-size:13px;margin:18px 0 8px}input,textarea{width:100%;min-width:0;background:#08131e;color:#c2dbea;border:1px solid #314b5f;border-radius:12px;padding:12px;font-size:13px}textarea{resize:vertical;min-height:95px}.help{font-size:14px;margin-top:22px}.safety{font-size:12px;color:#8aa5b9;margin:22px 0 0;padding-top:18px;border-top:1px solid #243b4f}footer{padding:24px;text-align:center}footer a{color:#8eb4d2;font-size:13px;text-decoration:none}#status{margin:12px 0 0;color:#9be5c9;font-size:14px;min-height:1.5em}#error{color:#ffd39e}details{margin-top:22px}summary{cursor:pointer;color:#bcd5e7;font-size:14px}.create{margin-top:12px}.primary:focus-visible,button:focus-visible,a:focus-visible,input:focus-visible,textarea:focus-visible{outline:3px solid #83e3ff;outline-offset:3px}@media(prefers-reduced-motion:reduce){*{scroll-behavior:auto!important}}@media(max-width:350px){.card{padding:22px 16px}.row{flex-direction:column}}
</style></head><body><main><header><div class="logo" dir="ltr">BIL<span aria-hidden="true">.</span></div><a class="lang" href="${escapeHtml(altHref)}" lang="${alt}">${alt === 'ar' ? 'العربية' : 'English'}</a></header><section class="card"><div class="eyebrow">${s.overline}</div><div class="mark" aria-hidden="true">↗</div><h1>${s.heading}</h1><p>${clean ? s.intro : s.waiting}</p>${invalid ? `<p id="error" role="alert">${s.invalid}</p>` : ''}${action}${share}<p id="status" role="status" aria-live="polite"></p>${clean ? `<p class="help">${s.help}</p>` : ''}<details ${clean ? '' : 'open'}><summary>${s.paste}</summary><form id="code-form"><label for="code-input">${s.paste}</label><textarea id="code-input" dir="ltr" maxlength="700" spellcheck="false" autocapitalize="none" required></textarea><button class="primary create" type="submit">${s.create}</button></form></details><p class="safety">${s.safety}</p></section><footer><a href="https://www.bilhealth.com/" rel="noreferrer">${s.home}</a></footer></main>
<script nonce="${nonce}">
const validCode = /^[a-f0-9]{32}$/;
const status = document.querySelector('#status');
const shareField = document.querySelector('#share-url');
const messages = ${JSON.stringify({invalid:s.invalid,copied:s.copied,copyFailed:s.copyFailed,title:s.title})};
function extractCode(value) {
  const text = value.trim();
  if (validCode.test(text.toLowerCase())) return text.toLowerCase();
  const pattern = new RegExp('bil://community/member/([a-fA-F0-9]{32})(?![a-zA-Z0-9/?#])', 'g');
  const matches = [...text.matchAll(pattern)];
  if (matches.length !== 1) return null;
  return matches[0][1].toLowerCase();
}
document.querySelector('#code-form').addEventListener('submit', event => {
  event.preventDefault();
  const code = extractCode(document.querySelector('#code-input').value);
  if (!code) { status.textContent = messages.invalid; return; }
  const url = new URL('/open-bil', window.location.origin);
  url.searchParams.set('code', code);
  url.searchParams.set('lang', document.documentElement.lang);
  window.location.assign(url.href);
});
document.querySelector('#copy-link')?.addEventListener('click', async () => {
  try { await navigator.clipboard.writeText(shareField.value); status.textContent = messages.copied; }
  catch { shareField.focus(); shareField.select(); status.textContent = messages.copyFailed; }
});
document.querySelector('#share-link')?.addEventListener('click', async () => {
  if (!navigator.share) { document.querySelector('#copy-link').click(); return; }
  try { await navigator.share({title:messages.title,text:'BIL',url:shareField.value}); }
  catch(error) { if (error.name !== 'AbortError') document.querySelector('#copy-link').click(); }
});
</script></body></html>`;
}
export async function handle(request) {
  const url = new URL(request.url);
  const responseHeaders = {'cache-control':'no-store','x-content-type-options':'nosniff','referrer-policy':'no-referrer','x-robots-tag':'noindex, nofollow','x-bil-bridge':VERSION};
  if (!['GET','HEAD'].includes(request.method)) return new Response('Method not allowed', {status:405,headers:{...responseHeaders,allow:'GET, HEAD'}});
  if (!['/','/open-bil','/open-bil/'].includes(url.pathname)) return new Response(request.method==='HEAD'?null:'Not found', {status:404,headers:responseHeaders});
  if (request.url.length > 2048) return new Response(null,{status:414,headers:responseHeaders});
  const params = url.searchParams;
  const raw = params.get('code');
  const invalid = (raw !== null && !parseCode(raw)) || params.getAll('code').length>1 || params.getAll('lang').length>1 || [...params.keys()].some(key=>!['code','lang'].includes(key));
  const lang = params.get('lang') === 'en' ? 'en' : params.get('lang') === 'ar' ? 'ar' : /^en\b/i.test(request.headers.get('accept-language')||'') ? 'en' : 'ar';
  const nonce = crypto.randomUUID().replaceAll('-','');
  return new Response(request.method==='HEAD'?null:renderPage({code:invalid?null:raw,lang,origin:url.origin,nonce,invalid}), {status:invalid?400:200,headers:{...responseHeaders,'content-type':'text/html; charset=utf-8','content-security-policy':`default-src 'none'; script-src 'nonce-${nonce}'; style-src 'nonce-${nonce}'; img-src 'none'; connect-src 'none'; base-uri 'none'; form-action 'self'; frame-ancestors 'none'`,'permissions-policy':'camera=(), microphone=(), geolocation=()'}});
}
export default {fetch:handle};
