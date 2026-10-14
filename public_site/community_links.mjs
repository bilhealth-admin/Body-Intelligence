// Public member/referral codes only. Never fetch profiles, sign in, accept
// friends, grant rewards, or forward arbitrary credentials from this landing.
const hosts = new Set(['www.bilhealth.com', 'bilhealth.com']);
const memberPattern = /^[a-f0-9]{32}$/i;
const invitePattern = /^[a-f0-9]{48}$/i;

export function communityLandingModel(rawUrl) {
  let url;
  try { url = new URL(rawUrl); } catch { return null; }
  const authority = /^https:\/\/([^/?#]+)/i.exec(String(rawUrl))?.[1];
  if (!authority || authority.includes(':')
      || url.protocol !== 'https:' || !hosts.has(url.hostname.toLowerCase())
      || url.username || url.password || url.port || url.hash) return null;
  const keys = [...url.searchParams.keys()];
  if (keys.some((key) => !['member', 'lang'].includes(key))
      || keys.length !== new Set(keys).size
      || (url.searchParams.has('lang')
        && !['ar', 'en'].includes(url.searchParams.get('lang')))) return null;
  if (url.pathname === '/download') {
    const member = url.searchParams.get('member');
    if (member === null) return { kind: 'download', appUrl: 'bil://community' };
    if (!memberPattern.test(member)) return null;
    return { kind: 'member', appUrl: `bil://community/member/${member.toLowerCase()}` };
  }
  const match = /^\/invite\/([a-f0-9]{48})$/i.exec(url.pathname);
  if (!match || !invitePattern.test(match[1]) || url.searchParams.has('member')) return null;
  return { kind: 'invite', appUrl: `bil://invite/${match[1].toLowerCase()}` };
}

function safeAppleUrl(value) {
  if (!value) return null;
  try {
    const url = new URL(value);
    return url.protocol === 'https:' && url.hostname === 'apps.apple.com'
        && !url.username && !url.password && !url.port && !url.search && !url.hash
        && /\/id[0-9]+(?:\/|$)/.test(url.pathname) ? url.href : null;
  } catch { return null; }
}

export function renderCommunityLanding(document, rawUrl, locale, { appleStoreUrl } = {}) {
  const model = communityLandingModel(rawUrl);
  const ar = locale === 'ar';
  const app = document.getElementById('app');
  const section = document.createElement('section');
  section.className = 'reset-card community-link-card';
  const heading = document.createElement('h1');
  heading.textContent = !model ? (ar ? 'الرابط غير صالح' : 'Invalid link')
      : model.kind === 'invite' ? (ar ? 'دعوة BIL' : 'BIL invitation')
      : model.kind === 'member' ? (ar ? 'تواصل عبر BIL' : 'Connect on BIL')
      : (ar ? 'تطبيق BIL' : 'Get BIL');
  section.append(heading);
  const body = document.createElement('p');
  body.className = 'reset-status';
  body.textContent = !model ? (ar ? 'اطلب رابطًا جديدًا من المرسل.' : 'Ask the sender for a new link.')
      : model.kind === 'invite' ? (ar
        ? 'افتح الدعوة في BIL للتحقق منها ثم اختر قبولها. هذه الصفحة لا تنشئ صداقة أو تمنح مكافأة.'
        : 'Open BIL to verify this invitation, then choose whether to accept. This page creates no friendship or reward.')
      : model.kind === 'member' ? (ar
        ? 'افتح الملف العام في BIL، ثم اختر إضافة صديق. فتح الرابط لا يرسل طلبًا تلقائيًا.'
        : 'Open the public profile in BIL, then choose Add Friend. Opening this link sends no request.')
      : (ar ? 'افتح BIL أو تحقق من توفره في المتجر.' : 'Open BIL or check availability in your store.');
  section.append(body);
  function link(id, text, href, primary = false) {
    const element = document.createElement('a');
    element.id = id; element.textContent = text; element.href = href;
    element.className = primary ? 'button primary' : 'button secondary';
    element.rel = 'noopener noreferrer';
    section.append(element);
  }
  if (model) {
    link('community-open-app', ar ? 'فتح في BIL' : 'Open in BIL', model.appUrl, true);
    link('community-google-play', 'Google Play',
      'https://play.google.com/store/apps/details?id=com.bilhealth.bodyintelligencelog');
    const apple = safeAppleUrl(appleStoreUrl);
    if (apple) link('community-apple-store', 'App Store', apple);
    const hint = document.createElement('p');
    hint.className = 'reset-status';
    hint.textContent = ar
      ? 'إذا احتجت رابط تثبيت iOS أو كان التطبيق غير متاح، تواصل مع الدعم. بعد التثبيت أعد فتح رابط الدعوة.'
      : 'For an iOS installation link or unavailable store listing, contact support. Reopen this invitation after installing BIL.';
    section.append(hint);
  }
  link('community-link-support', ar ? 'الدعم' : 'Support', '/support');
  app.replaceChildren(section);
  return model;
}
