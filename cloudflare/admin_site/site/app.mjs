import { createClient } from '@supabase/supabase-js';
import { SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY } from './config.mjs';

const sdk = createClient(SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY, {
  auth: { autoRefreshToken: true, persistSession: true, detectSessionInUrl: true },
  global: { headers: { 'x-client-info': 'bil-admin-web-cloudflare-1.0' } },
});
const edge = Object.freeze({
  finance: `${SUPABASE_URL}/functions/v1/bil-admin-web-v1`,
  ops: `${SUPABASE_URL}/functions/v1/bil-admin-web-ops-v1`,
});

const ar = {
  portal:'بوابة الإدارة',overview:'نظرة عامة',finance:'الاشتراكات والمنح',coach:'إدارة المدرب الذكي',notifications:'الإشعارات',moderation:'المراجعة والبلاغات',moderators:'المشرفون',members:'وصول الأعضاء',audit:'سجل التدقيق',security:'الأمن والاتصال',protected:'بوابة محمية بصلاحيات الخادم',offline:'غير متصل',online:'متصل وآمن',logout:'خروج',intro:'إدارة BIL بأذونات واضحة وسجل عمليات قابل للتدقيق.',secureLogin:'تسجيل دخول الإدارة',secureLoginDesc:'التحقق عبر بريدك الإلكتروني ثم رمز المصادقة الثنائية. الوصول للمالك المخوّل فقط.',email:'البريد الإلكتروني',sendCode:'إرسال رمز الدخول',emailCode:'الرمز الذي وصل إلى بريدك',verifyEmail:'تأكيد البريد',changeEmail:'تغيير البريد',totp:'رمز المصادقة الثنائية',verifyMfa:'تحقق وأدخل',enrollHelp:'أضف هذا الحساب إلى تطبيق المصادقة ثم أكد رمز الأمان.',noPasswords:'لا تُعرض مفاتيح الخادم أو كلمات المرور داخل هذا الموقع.',grants:'المنح الإدارية',sourceFinance:'مصدرها دفتر المنح الفعلي',authorizedCount:'بعد التحقق من الصلاحيات',reports:'البلاغات المفتوحة',sourceReports:'قائمة المراجعة الفعلية',suspended:'الأعضاء الموقوفون',sourceMembers:'وفق سجل الوصول الفعلي',connection:'حالة الاتصال',refresh:'تحديث',principles:'ضوابط التشغيل',principlesText:'تظهر البيانات الحقيقية فقط بعد اعتماد جلسة المالك. الوظائف غير المختبرة تبقى مقفلة، ولا تُستخدم مفاتيح إدارة البيانات في المتصفح.',opsLock:'تغييرات الإدارة الأخرى مقفلة إلى حين اكتمال التحقق',newGrant:'منح اشتراك جديد',grantWarning:'المنحة الإدارية مستقلة عن مشتريات المتجر وأرصدة Boost. لا تستخدم حسابات حقيقية لأغراض الاختبار.',recipientEmail:'بريد المستفيد',plan:'الباقة',duration:'المدة',reason:'سبب المنحة',confirmEmail:'تأكيد البريد (أعد كتابته)',grantAck:'أؤكد أن هذه منحة إدارية وليست شراءً من المتجر.',submitGrant:'مراجعة المنحة وإرسالها',existingGrants:'المنح القائمة',loadData:'اضغط تحديث لجلب السجل الحقيقي',prev:'السابق',next:'التالي',lastCommand:'آخر أمر مالي غير محسوم',noPending:'لا يوجد أمر معلّق في هذه الجلسة.',reconcile:'تحقق من الإيصال',individualReset:'إعادة ضبط حساب واحد',message:'رسالة الإشعار',execute:'تنفيذ',globalReset:'إعادة ضبط جميع الحسابات',globalWarning:'عملية واسعة التأثير. لا يمكن استخدامها للاختبارات على المستخدمين الحقيقيين.',confirmPhrase:'أدخل عبارة التأكيد الإنجليزية',composeNotification:'إعداد إشعار BIL',notificationWarning:'إشعارات التعويض والهدية قد تؤثر في التوكنات؛ لا تُرسل دون تفويض واختبار.',kind:'النوع',audience:'المستفيدون',confirmTarget:'تأكيد المستفيد (أو SEND TO ALL)',tokenAcknowledgment:'أفهم أن تعويضًا أو هدية قد يضيف توكنات.',send:'إرسال',posts:'المنشورات',safety:'سلامة المدرب',addModerator:'إضافة مشرف',suspendMember:'تعليق وصول عضو',financialAudit:'سجل العمليات المالية',identity:'حالة الهوية',securityBoundaries:'حدود الأمان',securityText:'كل طلب يمرّ من بوابة Supabase ويُراجع الخادم صلاحياته. مفاتيح الخدمة والإدارة المالية لا تُخزن في المتصفح. عمليات الكتابة غير المختبرة تبقى معطّلة.',noRealUsers:'لا تُنفذ تجارب على مستخدمين حقيقيين أو أرصدتهم.',stepUp:'تأكيد المصادقة الثنائية قبل تنفيذ العملية',stepUpDesc:'أدخل الرمز الجديد من تطبيق المصادقة. لن ننفذ العملية دون التحقق من صلاحياتك.',cancel:'إلغاء',confirm:'تأكيد',locked:'مقفلة',active:'نشطة',available:'متاحة',notAvailable:'غير متاحة',financeGateway:'بوابة الاشتراكات المالية',operationsGateway:'بوابة بقية الإدارة',signedIn:'الجلسة',twoFactor:'التحقق الثنائي',protectedRole:'صلاحية المالك',enableNotice:'وظائف الكتابة قيد الاعتماد؛ يمكن الاطلاع على السجلات المصرح بها.',notAuthorized:'هذه الجلسة لا تملك صلاحية الإدارة المطلوبة.',confirmAction:'هل تريد تنفيذ هذا الإجراء على البيانات الفعلية؟',completed:'اكتملت العملية، وتم استلام إيصال الخادم.',pending:'قد تكون العملية نُفذت لكن تأكيد النتيجة معلّق. استرجع الإيصال قبل إعادة المحاولة.',failed:'تعذّر تنفيذ العملية أو تأكيد نتيجتها.',empty:'لا توجد سجلات في الصفحة الحالية.',loading:'جاري القراءة من الخادم...',failedRead:'تعذّر جلب البيانات. لم تُعرض أي بيانات وهمية.',revoke:'سحب المنحة',remove:'إزالة',reinstate:'استعادة الوصول',unavailable:'غير مفعل: قيد اعتماد الربط السحابي',testRequired:'متاح تقنيًا، لكن يُرجى استخدام حساب اختبار آمن عند التجربة الأولى.',account:'الحساب',result:'النتيجة',created:'التاريخ',status:'الحالة',actions:'إجراءات',formatError:'فشل التحقق من تنسيق رد الخادم.',missingMfa:'يلزم إعداد المصادقة الثنائية أولًا.'
};
const en = {
  portal:'Administration',overview:'Overview',finance:'Subscriptions & grants',coach:'AI Coach management',notifications:'Notifications',moderation:'Moderation & reports',moderators:'Moderators',members:'Member access',audit:'Audit trail',security:'Security & connectivity',protected:'Server-authorized management',offline:'Disconnected',online:'Connected securely',logout:'Sign out',intro:'BIL management with explicit permissions and auditable actions.',secureLogin:'Administration sign-in',secureLoginDesc:'Sign in via email verification then authenticator TOTP. Owner-only access.',email:'Email address',sendCode:'Send sign-in code',emailCode:'Code sent to your email',verifyEmail:'Verify email',changeEmail:'Change email',totp:'Authenticator code',verifyMfa:'Verify and enter',enrollHelp:'Enroll in your authenticator, scan the code below, then verify your TOTP.',noPasswords:'No backend secrets or passwords are stored in this website.',grants:'Administrative grants',sourceFinance:'From the authoritative grants ledger',authorizedCount:'After permission verification',reports:'Open reports',sourceReports:'Authoritative review queue',suspended:'Suspended members',sourceMembers:'From authoritative access records',connection:'Connection status',refresh:'Refresh',principles:'Operating controls',principlesText:'Real data is visible only after owner session approval. Untested actions remain locked and service-role keys never enter the browser.',opsLock:'Other administrative writes are locked pending live testing.',newGrant:'New subscription grant',grantWarning:'Admin grants are separate from store purchases and Boost. Do not test on real users.',recipientEmail:'Recipient email',plan:'Plan',duration:'Duration',reason:'Grant reason',confirmEmail:'Confirm recipient email (type again)',grantAck:'I acknowledge this is an external admin grant, not a store purchase.',submitGrant:'Review and send grant',existingGrants:'Existing grants',loadData:'Select refresh to read live records',prev:'Previous',next:'Next',lastCommand:'Last unresolved command',noPending:'No pending command in this session.',reconcile:'Reconcile receipt',individualReset:'Reset one AI Coach account',message:'Notification message',execute:'Execute',globalReset:'Reset ALL AI Coach accounts',globalWarning:'High-impact operation. Do not test against real accounts.',confirmPhrase:'Enter the English confirmation phrase',composeNotification:'Compose BIL notification',notificationWarning:'Gift and compensation notifications may affect token balances. Do not send without approval and testing.',kind:'Kind',audience:'Audience',confirmTarget:'Confirm recipient (or SEND TO ALL)',tokenAcknowledgment:'I understand gift or compensation may grant tokens.',send:'Send',posts:'Posts',safety:'AI Coach safety',addModerator:'Add moderator',suspendMember:'Suspend access',financialAudit:'Financial audit trail',identity:'Identity status',securityBoundaries:'Security boundaries',securityText:'Every request is verified by Supabase and server-side admin authority. Service-role keys stay server-side, untested writes remain disabled.',noRealUsers:'Do not test with real user accounts or balances.',stepUp:'Fresh TOTP required for this action',stepUpDesc:'Enter a new authenticator code. No action proceeds without verified permissions.',cancel:'Cancel',confirm:'Confirm',locked:'Locked',active:'Active',available:'Available',notAvailable:'Unavailable',financeGateway:'Financial grants gateway',operationsGateway:'Administrative ops gateway',signedIn:'Session',twoFactor:'Two-factor verification',protectedRole:'Owner permissions',enableNotice:'Write operations are pending authorization. Allowed records can be read.',notAuthorized:'Your account is not authorized for administration.',confirmAction:'Execute this action against live data?',completed:'The operation completed and a server receipt was received.',pending:'The operation may have committed, but readback is pending. Reconcile before retrying.',failed:'The operation failed or could not be confirmed.',empty:'No records on this page.',loading:'Reading from the server...',failedRead:'Could not load authoritative data. No fabricated records are shown.',revoke:'Revoke grant',remove:'Remove',reinstate:'Reinstate access',unavailable:'Disabled: pending secure backend cutover',testRequired:'Technically enabled, but use an isolated test account for first verification.',account:'Account',result:'Result',created:'Created',status:'Status',actions:'Actions',formatError:'Invalid backend response.',missingMfa:'A verified TOTP factor is required.'
};

Object.assign(ar,{
  active:'نشطة',revoked:'ملغاة',expired:'منتهية',open:'مفتوح',reviewing:'قيد المراجعة',closed:'مغلق',approved:'مقبول',rejected:'مرفوض',
  protectedModerator:'مسؤول محمي',regularModerator:'مشرف',pendingStatus:'بانتظار المراجعة',
  reportEmail:'بريد صاحب البلاغ',accountIdentifier:'معرّف حساب BIL',reportId:'رقم البلاغ',
  postAuthor:'صاحب المنشور',reportReason:'سبب البلاغ',contentType:'نوع المحتوى',contentIdentifier:'معرّف المحتوى',
  reportDate:'تاريخ البلاغ',userMessage:'ملاحظة المستخدم',coachReply:'رد المدرب المُبلّغ عنه',postBody:'نص المنشور',
  reportRuntime:'حالة تشغيل المدرب',reportLocale:'لغة البلاغ',reportDecision:'نتيجة المراجعة',
  findReporterUnavailable:'البريد غير متاح؛ قد يكون الحساب محذوفًا.',
  identityExplanation:'هذا بريد صاحب البلاغ، وقد يختلف عن صاحب المحتوى. استخدمه لمتابعة البلاغ فقط.',
  prepareCompensation:'إعداد تعويض لهذا المستخدم',
  prepareCompensationDone:'وضعت بريد صاحب البلاغ في إعداد الإشعار. راجع المعلومات وأكد بنفسك؛ لم يُرسل شيء.',
  reasonUnsafe:'إجابة غير آمنة',reasonInaccurate:'إجابة غير دقيقة',reasonOffensive:'محتوى مسيء',reasonOther:'سبب آخر',
  runtimeLocalFallback:'رد احتياطي عند تعذّر خدمة المدرب',
  approve:'قبول المنشور',reject:'رفض المنشور',dismissReport:'إغلاق البلاغ دون حذف',removeContent:'إزالة المحتوى المخالف',
  noViolation:'لا توجد مخالفة',confirmedIssue:'مشكلة سلامة مؤكدة',reviewStatusReviewed:'تمت المراجعة',
  operation:'العملية',operationGrant:'منح اشتراك',operationRevoke:'سحب منحة',resultChanged:'تم تغيير الحالة',
  resultUnchanged:'دون تغيير',resultUnmatched:'لم يُعثر على المستفيد',grantIdentifier:'معرّف المنحة',
  whyLocked:'زر التنفيذ مقفل بإعداد أمني على الخادم، وليس بسبب عطل. لا يُفتح قبل اختبار حساب مخصص وتأكيد المصادقة الثنائية والإيصالات.',
  individualResetHelp:'يعيد ضبط استهلاك AI Coach الحالي للحساب المحدد ويُرسل إشعارًا، دون حذف محادثاته أو اشتراكه.',
  globalWarning:'عملية واسعة التأثير: تصفّر عدادات استخدام AI Coach للفترة الحالية للحسابات المؤهلة وتُنشئ إشعارات. لا تلغي المشتريات أو الاشتراكات. مقفلة الآن لحين اختبار آمن؛ لا يوجد عطل بالزر.',
  notificationWarning:'إشعار مخصص: رسالة فقط دون توكنات. هدية أو تعويض: قد يمنح 2,500 توكن لكل مستفيد وفق عقد الخادم. أكّد البريد أو عبارة الإرسال للجميع. الإرسال مقفل حاليًا حتى اختبار الأمان.',
  notificationKindHelpCustom:'إشعار مخصّص: رسالة معلوماتية فقط دون توكنات.',
  notificationKindHelpGift:'هدية: قد تمنح توكنات AI Coach، فتأكد من المستفيد والسجل.',
  notificationKindHelpCompensation:'تعويض: بعد التحقق من بلاغ المستخدم، وقد يمنح توكنات وفق عقد الخادم.',
  notificationAudienceAll:'جميع الحسابات: اكتب SEND TO ALL للتأكيد. ممنوع التجربة على مستخدمين حقيقيين.',
  notificationAudienceEmail:'حساب واحد: أعد كتابة البريد نفسه للتأكيد.',
  giftLabel:'هدية',compensationLabel:'تعويض',customLabel:'إشعار مخصص',
  oneAccountLabel:'حساب واحد',allAccountsLabel:'جميع الحسابات',
  moderatorsHelp:'المشرف يراجع المجتمع ولا يحصل على صلاحية مالية أو Premium تلقائيًا. المسؤول المحمي لا يمكن إزالته هنا.',
  membersHelp:'هذه الصفحة تعلّق أو تستعيد مشاركة العضو في المجتمع فقط؛ لا تحذف حسابه ولا تلغي اشتراكه أو مشترياته.',
  auditHelp:'سجل خادمي للمنح والسحب وتوقيتها ونتائجها. «دون تغيير» لا تعني تلقائيًا فشل العملية.',
  noSuspendedMembers:'لا يوجد أعضاء موقوفون بالمجتمع.',noModerators:'لا يوجد مشرفون في القائمة.',
  noReports:'لا توجد بلاغات في القائمة.',noPosts:'لا توجد منشورات بانتظار المراجعة.',
  privacyNotice:'تظهر معلومات صاحب البلاغ للمسؤول المخوّل فقط، وتُستخدم للمتابعة والتعويض عند الاستحقاق.',
  viewDetails:'قراءة التفاصيل كاملة',notProvided:'لم يُضف المستخدم نصًا',
  statusLocked:'مقفلة حتى اجتياز الاختبارات',
  resetAllButton:'مراجعة إعادة ضبط جميع الحسابات',resetIndividualButton:'مراجعة إعادة ضبط هذا الحساب',
  suspendButton:'مراجعة تعليق وصول المجتمع',notificationSendButton:'مراجعة الإشعار وإرساله'
});
Object.assign(en,{
  active:'Active',revoked:'Revoked',expired:'Expired',open:'Open',reviewing:'Under review',closed:'Closed',approved:'Approved',rejected:'Rejected',
  protectedModerator:'Protected administrator',regularModerator:'Moderator',pendingStatus:'Awaiting review',
  reportEmail:'Reporter email',accountIdentifier:'BIL account ID',reportId:'Report ID',
  postAuthor:'Post author',reportReason:'Report reason',contentType:'Content type',contentIdentifier:'Content ID',
  reportDate:'Reported on',userMessage:'User note',coachReply:'Reported AI Coach answer',postBody:'Post text',
  reportRuntime:'AI Coach runtime',reportLocale:'Report language',reportDecision:'Review outcome',
  findReporterUnavailable:'Reporter email unavailable; the account may have been deleted.',
  identityExplanation:'This email belongs to the reporter, who may differ from the content author. Use it only for case follow-up.',
  prepareCompensation:'Prepare compensation for this user',
  prepareCompensationDone:'Reporter email was prefilled. Review the details and confirm manually; nothing has been sent.',
  reasonUnsafe:'Unsafe answer',reasonInaccurate:'Inaccurate answer',reasonOffensive:'Offensive content',reasonOther:'Other reason',
  runtimeLocalFallback:'Local fallback while AI Coach was unavailable',
  approve:'Approve post',reject:'Reject post',dismissReport:'Dismiss report without removal',removeContent:'Remove violating content',
  noViolation:'No violation',confirmedIssue:'Confirmed safety issue',reviewStatusReviewed:'Reviewed',
  operation:'Operation',operationGrant:'Grant subscription',operationRevoke:'Revoke grant',resultChanged:'Status changed',
  resultUnchanged:'No change',resultUnmatched:'No matching recipient',grantIdentifier:'Grant ID',
  whyLocked:'Execution is locked by the server-side safety setting, not a broken button. Isolated account E2E, fresh TOTP, and receipt verification are required first.',
  individualResetHelp:'Resets current-period AI Coach usage for one account and notifies the user; conversations and paid rights are retained.',
  globalWarning:'High impact: resets current-period AI Coach usage counters for eligible accounts and sends notices. It does not cancel purchases or subscriptions. Locked pending isolated E2E testing.',
  notificationWarning:'Custom: text only, no tokens. Gift or compensation: the server may grant 2,500 tokens per recipient. Confirm email or SEND TO ALL. Sending is locked pending security testing.',
  notificationKindHelpCustom:'Custom notification: information only, without token grants.',
  notificationKindHelpGift:'Gift: may grant AI Coach tokens. Verify recipient and receipt.',
  notificationKindHelpCompensation:'Compensation: only after verifying a user report; may grant tokens.',
  notificationAudienceAll:'All accounts: type SEND TO ALL. Never test on real users.',
  notificationAudienceEmail:'One account: re-enter the exact email address.',
  giftLabel:'Gift',compensationLabel:'Compensation',customLabel:'Custom notice',
  oneAccountLabel:'One account',allAccountsLabel:'All accounts',
  moderatorsHelp:'Moderators review community content; this does not confer financial access or Premium. Protected administrators cannot be removed here.',
  membersHelp:'This suspends or restores access to community features only; it does not delete the BIL account or cancel a purchase or subscription.',
  auditHelp:'Server-recorded grant/revoke commands, timestamps and outcomes. “No change” does not itself indicate a technical failure.',
  noSuspendedMembers:'No suspended community members.',noModerators:'No moderators listed.',
  noReports:'No reports in this queue.',noPosts:'No posts awaiting moderation.',
  privacyNotice:'Reporter details are visible only to the authorized owner and should be used for case follow-up and justified compensation.',
  viewDetails:'View full details',notProvided:'No note provided',
  statusLocked:'Locked pending E2E verification',
  resetAllButton:'Review reset of all accounts',resetIndividualButton:'Review this account reset',
  suspendButton:'Review community suspension',notificationSendButton:'Review and send notification'
});

const dict={ar,en};
const state={language:'ar',page:'overview',queue:'posts',email:'',factor:null,finance:null,ops:null,user:null,financeRows:[],auditRows:[],mods:[],members:[],queueRows:[],financeOffset:0,hasMore:false,pendingCommand:null,authenticated:false,modalResolve:null,loading:false};
const $ = id=>document.getElementById(id);
const tr=k=>(dict[state.language][k]??k);
const elem=(name,text,cls)=>{const e=document.createElement(name);if(text!==undefined&&text!==null)e.textContent=String(text);if(cls)e.className=cls;return e};
function setText(id,x){$(id).textContent=String(x)}
function showNotice(message,bad=false){const n=$('notice');n.textContent=String(message);n.classList.toggle('error',bad);n.hidden=false;clearTimeout(showNotice.timer);showNotice.timer=setTimeout(()=>n.hidden=true,13000)}
function translate(){document.documentElement.lang=state.language;document.documentElement.dir=state.language==='ar'?'rtl':'ltr';for(const node of document.querySelectorAll('[data-i18n]')){node.textContent=tr(node.dataset.i18n)}$('language').textContent=state.language==='ar'?'EN':'AR';setText('breadcrumb',tr(state.page));setText('page-title',tr(state.page));updateNotificationHelp();}
function setPage(page){if(!document.getElementById(page+'-page'))return;state.page=page;for(const panel of document.querySelectorAll('.page'))panel.classList.toggle('active',panel.id===page+'-page');for(const item of document.querySelectorAll('[data-page]'))item.classList.toggle('selected',item.dataset.page===page);setText('breadcrumb',tr(page));setText('page-title',tr(page));$('sidebar').classList.remove('open')}
function authUi(view){$('auth-view').hidden=view==='admin';$('admin-view').hidden=view!=='admin';$('logout').hidden=view!=='admin'&&view!=='mfa';$('top-status').textContent=view==='admin'?tr('online'):tr('offline');$('top-status').classList.toggle('connected',view==='admin')}
function count(rows){return Array.isArray(rows)?rows.length:'—'}
function rowsOf(data){if(Array.isArray(data))return data;if(!data||typeof data!=='object')return[];if(Array.isArray(data.rows))return data.rows;if(Array.isArray(data.items))return data.items;if(Array.isArray(data.reports))return data.reports;if(Array.isArray(data.posts))return data.posts;return []}
function fmtDate(v){if(!v)return '—';const d=new Date(v);return Number.isNaN(+d)?'—':new Intl.DateTimeFormat(state.language,{dateStyle:'medium',timeStyle:'short'}).format(d)}
function localizedState(value) {
 const code=String(value??'').toLowerCase();
 const labels={active:'active',revoked:'revoked',expired:'expired',open:'open',reviewing:'reviewing',
   closed:'closed',approved:'approved',rejected:'rejected',reviewed:'reviewStatusReviewed',
   pending:'pendingStatus',no_violation:'noViolation',confirmed_safety_issue:'confirmedIssue',
   changed:'resultChanged',unchanged:'resultUnchanged',unmatched:'resultUnmatched'};
 return labels[code]?tr(labels[code]):String(value??'—');
}
function badge(value){
 const code=String(value??'').toLowerCase(),el=elem('span',localizedState(value),'pill');
 el.dataset.status=code;
 if(/revoked|expired|rejected|closed|confirmed_safety_issue/.test(code))el.classList.add('revoked');
 return el;
}
function shortId(value){
 const txt=String(value??'');
 const span=elem('span',txt.length>22?txt.slice(0,8)+'…'+txt.slice(-5):txt||'—','short-id');
 span.dir='ltr';span.title=txt;return span;
}
function emailNode(value){
 const node=elem('span',value??'—','email-field');
 node.dir='ltr';return node;
}
function empty(parent,text=tr('empty')){parent.replaceChildren(elem('div',text,'empty-state'))}
function addRow(container,key,value,className){const row=elem('div',null,'status-row');row.append(elem('span',key),elem('strong',value,className));container.append(row)}
function makeTable(container,headers,rows,render,emptyMessage=tr('empty')){
 container.classList.remove('empty-state');container.replaceChildren();
 if(!Array.isArray(rows)||!rows.length){empty(container,emptyMessage);return}
 const table=elem('table',null,'data-table'),head=elem('thead'),trh=elem('tr');
 for(const label of headers){const th=elem('th',label);th.scope='col';trh.append(th)}
 head.append(trh);const body=elem('tbody');
 for(const data of rows){
   const row=elem('tr');
   render(data).forEach((cell,i)=>{
     const td=elem('td');td.dataset.label=headers[i]||'';
     if(cell instanceof Node)td.append(cell);else td.textContent=String(cell??'—');
     row.append(td);
   });
   body.append(row);
 }
 table.append(head,body);container.append(table);
}
function recordField(label,value,{email=false,code=false,paragraph=false}={}){
 const field=elem('div',null,'report-field'),dt=elem('dt',label,'report-field-label'),dd=elem('dd',null,'report-field-value');
 if(code)dd.append(shortId(value));
 else if(email)dd.append(emailNode(value));
 else if(paragraph){
   const txt=String(value??'').trim();
   if(txt.length>200){
     const details=elem('details',null,'report-disclosure');
     details.append(elem('summary',txt.slice(0,140)+'…','report-summary'),elem('p',txt,'report-long-text'));
     dd.append(details);
   }else dd.append(elem('p',txt||tr('notProvided'),'report-long-text'));
 }else dd.textContent=String(value??'—');
 field.append(dt,dd);return field;
}
function prepareCompensation(email){
 if(!state.authenticated||!state.user||!email)return;
 const f=$('notification-form');
 f.elements.namedItem('kind').value='compensation';
 f.elements.namedItem('audience').value='email';
 f.elements.namedItem('email').value=email;
 f.elements.namedItem('confirm_target').value='';
 f.elements.namedItem('acknowledge_token_grant').checked=false;
 f.elements.namedItem('message').value='';
 updateNotificationHelp();setPage('notifications');showNotice(tr('prepareCompensationDone'));
}
function reporterPanel(card,row,reporter=true){
 const email=row?.reporter_email;
 const box=elem('section',null,'report-identity');
 box.append(recordField(tr('reportEmail'),email||tr('findReporterUnavailable'),{email:!!email}));
 const id=row?.reporter_user_id??row?.reporter_id??null;
 if(id)box.append(recordField(tr('accountIdentifier'),id,{code:true}));
 if(reporter)box.append(elem('p',tr('identityExplanation'),'privacy-note'));
 if(email&&reporter){
  const button=elem('button',tr('prepareCompensation'),'secondary compensation-draft');
  button.type='button';button.addEventListener('click',()=>prepareCompensation(email));box.append(button);
 }
 card.append(box);
}
function reasonText(value){
 const labels={unsafe:'reasonUnsafe',inaccurate:'reasonInaccurate',offensive:'reasonOffensive',other:'reasonOther'};
 return labels[String(value||'').toLowerCase()]?tr(labels[String(value).toLowerCase()]):String(value||tr('reasonOther'));
}
function renderRecords(container,rows,queue){
 container.classList.remove('empty-state');container.replaceChildren();
 if(!Array.isArray(rows)||!rows.length){
   empty(container,tr(queue==='posts'?'noPosts':queue==='reports'?'noReports':'empty'));return;
 }
 for(const row of rows){
   if(!row||typeof row!=='object'||Array.isArray(row))continue;
   const card=elem('article',null,'report-card');
   const h=elem('header',null,'report-header');
   h.append(elem('strong',tr(queue==='posts'?'posts':queue==='reports'?'reports':'safety'),'report-title'),
    badge(row.status??row.moderation_status));card.append(h);
   const dl=elem('dl',null,'report-grid');
   const id=row.report_id??row.id??row.post_id;
   if(queue==='posts'){
     dl.append(recordField(tr('postAuthor'),row.author_name??row.author_id??'—'));
     if(row.reporter_email)reporterPanel(card,row,false);
     dl.append(recordField(tr('reportDate'),fmtDate(row.created_at)));
     dl.append(recordField(tr('postBody'),row.body,{paragraph:true}));
     dl.append(recordField(tr('contentIdentifier'),id,{code:true}));
   }else if(queue==='reports'){
     reporterPanel(card,row);
     dl.append(recordField(tr('reportReason'),row.reason,{paragraph:true}));
     dl.append(recordField(tr('contentType'),String(row.target_kind??'—')));
     dl.append(recordField(tr('reportDate'),fmtDate(row.created_at)));
     dl.append(recordField(tr('reportId'),id,{code:true}));
     if(row.target_id)dl.append(recordField(tr('contentIdentifier'),row.target_id,{code:true}));
   }else if(queue==='safety'){
     reporterPanel(card,row);
     dl.append(recordField(tr('reportReason'),reasonText(row.reason)));
     dl.append(recordField(tr('reportDate'),fmtDate(row.created_at)));
     dl.append(recordField(tr('reportLocale'),String(row.locale??'—').toUpperCase()));
     dl.append(recordField(tr('reportRuntime'),row.runtime==='local_fallback'?tr('runtimeLocalFallback'):String(row.runtime??'—').replaceAll('_',' ')));
     if(row.user_note)dl.append(recordField(tr('userMessage'),row.user_note,{paragraph:true}));
     if(row.answer_text)dl.append(recordField(tr('coachReply'),row.answer_text,{paragraph:true}));
     if(row.decision)dl.append(recordField(tr('reportDecision'),localizedState(row.decision)));
     dl.append(recordField(tr('reportId'),id,{code:true}));
   }
   card.append(dl);
   const actions=elem('div',null,'report-actions');
   const choices=queue==='posts'?[[tr('approve'),'approved'],[tr('reject'),'rejected']]:
     queue==='reports'?[[tr('dismissReport'),'dismiss'],[tr('removeContent'),'remove']]:
       queue==='safety'?[[tr('noViolation'),'no_violation'],[tr('confirmedIssue'),'confirmed_safety_issue']]:[];
   for(const [label,decision] of choices){
     const b=elem('button',label,['rejected','remove','confirmed_safety_issue'].includes(decision)?'danger':'secondary');
     b.type='button';b.disabled=!state.ops?.writes_enabled || queue==='safety'&&row.status==='reviewed';
     b.title=b.disabled?tr('whyLocked'):label;
     b.addEventListener('click',()=>reviewQueueRecord(queue,row,decision));actions.append(b);
   }
   card.append(actions);container.append(card);
 }
}
function previewRows(container,rows,label='id',queue=null){renderRecords(container,rows,queue)}
function updateNotificationHelp(){
 const form=$('notification-form');
 if(!form)return;
 const kind=form.elements.namedItem('kind').value,audience=form.elements.namedItem('audience').value;
 $('notification-kind-help').textContent=tr('notificationKindHelp'+kind[0].toUpperCase()+kind.slice(1));
 $('notification-audience-help').textContent=tr(audience==='all'?'notificationAudienceAll':'notificationAudienceEmail');
 const email=form.elements.namedItem('email');email.required=audience==='email';email.disabled=audience!=='email';
 if(audience==='all')email.value='';
 const ack=form.elements.namedItem('acknowledge_token_grant');ack.required=kind!=='custom';
 if(kind==='custom')ack.checked=false;
}
function token(){return crypto.randomUUID()}
async function api(type,body){const {data:{session},error}=await sdk.auth.getSession();if(error||!session?.access_token)throw new Error('authentication_required');const response=await fetch(edge[type],{method:'POST',mode:'cors',cache:'no-store',credentials:'omit',headers:{'content-type':'application/json','apikey':SUPABASE_PUBLISHABLE_KEY,'authorization':`Bearer ${session.access_token}`},body:JSON.stringify(body)});let data;try{data=await response.json()}catch{throw new Error('invalid_backend_response')}if(!response.ok){const e=new Error(data?.error||'backend_unavailable');e.httpStatus=response.status;e.detail=data;throw e}return data}
async function emailOtp(ev){ev.preventDefault();const value=$('email').value.trim().toLowerCase();if(!value)return;const btn=ev.submitter;btn.disabled=true;try{const {error}=await sdk.auth.signInWithOtp({email:value,options:{shouldCreateUser:false}});if(error)throw error;state.email=value;$('email-form').hidden=true;$('otp-form').hidden=false;showNotice(state.language==='ar'?'تم طلب رمز الدخول. تحقق من بريدك.':'Sign-in code requested. Check your email.')}catch(e){showNotice(e.message||tr('failed'),true)}finally{btn.disabled=false}}
async function verifyEmail(ev){ev.preventDefault();const code=$('email-code').value.trim();const btn=ev.submitter;btn.disabled=true;try{const {error}=await sdk.auth.verifyOtp({email:state.email,token:code,type:'email'});if(error)throw error;$('otp-form').hidden=true;await enterMfaFlow()}catch(e){showNotice(e.message||tr('failed'),true)}finally{btn.disabled=false}}
async function findFactor(){const {data,error}=await sdk.auth.mfa.listFactors();if(error)throw error;return (data?.totp??[]).find(f=>f.status==='verified')??null}
async function enterMfaFlow(){authUi('mfa');const {data}=await sdk.auth.mfa.getAuthenticatorAssuranceLevel();if(data?.currentLevel==='aal2'){await loadAdmin();return}state.factor=await findFactor();$('mfa-area').hidden=!!(!state.factor);$('enroll-area').hidden=!!state.factor;if(!state.factor){const {data:enrolled,error}=await sdk.auth.mfa.enroll({factorType:'totp',friendlyName:'BIL Secure Admin'});if(error)throw error;state.factor=enrolled;if(enrolled.totp?.qr_code)$('enroll-qr').src=enrolled.totp.qr_code}}
async function verifyFactor(code){if(!state.factor?.id)throw new Error(tr('missingMfa'));if(!/^\d{6,8}$/.test(code))throw new Error('invalid_totp');const {data,error}=await sdk.auth.mfa.challengeAndVerify({factorId:state.factor.id,code});if(error)throw error;return data}
async function verifyMfa(ev){ev.preventDefault();const btn=ev.submitter;btn.disabled=true;try{const code=$('mfa-code').value.trim();await verifyFactor(code);$('mfa-code').value='';$('mfa-area').hidden=true;await loadAdmin()}catch(e){showNotice(e.message||tr('failed'),true)}finally{btn.disabled=false}}
async function verifyEnroll(ev){ev.preventDefault();const btn=ev.submitter;btn.disabled=true;try{await verifyFactor($('enroll-code').value.trim());$('enroll-code').value='';$('enroll-area').hidden=true;await loadAdmin()}catch(e){showNotice(e.message||tr('failed'),true)}finally{btn.disabled=false}}
async function loadAdmin(){const {data:{user}}=await sdk.auth.getUser();if(!user)throw new Error('invalid_session');state.user=user;const finance=await api('finance',{operation:'status'});if(finance.access!=='authorized')throw new Error('unauthorized');state.finance=finance;let ops=null;try{ops=await api('ops',{operation:'status'})}catch(e){ops={access:'unavailable',error:e.message,writes_enabled:false}}state.ops=ops;state.authenticated=true;authUi('admin');restorePending();updateStatuses();await Promise.allSettled([loadFinance(),loadModerators(),loadMembers(),loadQueue()]);updateStatuses()}
function updateStatuses(){const finance=state.finance?.access==='authorized';const ops=state.ops?.access==='authorized';setText('top-status',finance?tr('online'):tr('offline'));$('top-status').classList.toggle('connected',finance);const container=$('status-cards');container.replaceChildren();addRow(container,tr('financeGateway'),finance?tr('active'):tr('notAvailable'),finance?'':'bad');addRow(container,tr('operationsGateway'),ops?tr('active'):tr('notAvailable'),ops?'':'bad');addRow(container,tr('twoFactor'),state.authenticated?tr('active'):tr('notAvailable'),state.authenticated?'':'bad');addRow(container,tr('protectedRole'),state.authenticated?tr('active'):tr('notAvailable'),state.authenticated?'':'bad');const lock=state.ops?.writes_enabled===true;for(const b of document.querySelectorAll('.ops-write'))b.disabled=!lock;$('ops-lock').textContent=lock?tr('testRequired'):tr('statusLocked');for(const note of document.querySelectorAll('.write-explanation'))note.hidden=lock;const identity=$('identity-content');identity.replaceChildren();addRow(identity,tr('signedIn'),state.user?.email||'—');addRow(identity,tr('twoFactor'),state.authenticated?'AAL2':'—');addRow(identity,tr('financeGateway'),finance?(state.finance.financial_writes_enabled?tr('active'):tr('locked')):tr('notAvailable'),finance?'':'bad');addRow(identity,tr('operationsGateway'),ops?(lock?tr('active'):tr('locked')):tr('notAvailable'),ops?(lock?'':'pending'):'bad');}
async function init(){
  translate();authUi('auth');
  sdk.auth.onAuthStateChange((event)=>{
    if(event==='SIGNED_OUT')clearPrivateView();
  });
  try{const {data:{session}}=await sdk.auth.getSession();if(session){await enterMfaFlow()}}
  catch(e){showNotice(e.message||tr('failed'),true)}
}
async function loadFinance(){if(!state.authenticated)return;const c=$('finance-list');c.textContent=tr('loading');try{const d=await api('finance',{operation:'list',offset:state.financeOffset});if(!Array.isArray(d.rows)||typeof d.has_more!=='boolean')throw new Error(tr('formatError'));state.financeRows=d.rows;state.hasMore=d.has_more;setText('metric-grants',state.financeOffset===0?String(d.rows.length)+(d.has_more?'+':''):String(d.rows.length));$('finance-prev').disabled=state.financeOffset===0;$('finance-next').disabled=!d.has_more;$('finance-page-index').textContent=String(state.financeOffset/50+1);makeTable(c,[tr('account'),tr('plan'),tr('status'),tr('created'),tr('actions')],d.rows,row=>{const action=elem('button',tr('revoke'),'secondary');action.type='button';action.disabled=!(state.finance?.financial_writes_enabled===true)||row.status!=='active';action.addEventListener('click',()=>revokeGrant(row));return[emailNode(row.email),row.plan_id==='premium_ai_coach'?'Premium + AI Coach':'Premium',badge(row.status),fmtDate(row.created_at),action]},tr('empty'))}catch(e){empty(c,tr('failedRead'));showNotice(e.message||tr('failedRead'),true)}}
async function loadAudit(){const c=$('audit-content');c.textContent=tr('loading');try{const d=await api('finance',{operation:'audit',offset:0});if(!Array.isArray(d.rows))throw new Error(tr('formatError'));state.auditRows=d.rows;makeTable(c,[tr('created'),tr('operation'),tr('result'),tr('grantIdentifier')],d.rows,row=>[fmtDate(row.created_at),tr(row.operation==='grant'?'operationGrant':'operationRevoke'),badge(row.changed?'changed':row.matched?'unchanged':'unmatched'),shortId(row.grant_id)])}catch(e){empty(c,tr('failedRead'));showNotice(e.message||tr('failedRead'),true)}}
async function loadModerators(){const c=$('moderator-content');c.textContent=tr('loading');try{const d=await api('ops',{operation:'moderators.list'});const rows=rowsOf(d.receipt);if(!Array.isArray(d.receipt)&&!Array.isArray(d.receipt?.rows))throw new Error(tr('formatError'));state.mods=rows;setText('metric-mods',String(rows.length));makeTable(c,[tr('account'),tr('created'),tr('status'),tr('actions')],rows,row=>{const action=elem('button',tr('remove'),'secondary');action.type='button';action.disabled=!state.ops?.writes_enabled||row.protected_administrator===true;action.addEventListener('click',()=>opsConfirm('moderators.remove',{user_id:row.user_id,confirm_user_id:row.user_id}));return[emailNode(row.email),fmtDate(row.created_at),row.protected_administrator?tr('protectedModerator'):tr('regularModerator'),action]},tr('noModerators'))}catch(e){empty(c,tr('failedRead'));setText('metric-mods','—');showNotice(e.message||tr('failedRead'),true)}}
async function loadMembers(){const c=$('member-content');c.textContent=tr('loading');try{const d=await api('ops',{operation:'members.list'});const rows=rowsOf(d.receipt);if(!Array.isArray(d.receipt)&&!Array.isArray(d.receipt?.rows))throw new Error(tr('formatError'));state.members=rows;setText('metric-members',String(rows.length));makeTable(c,[tr('account'),tr('reason'),tr('created'),tr('actions')],rows,row=>{const action=elem('button',tr('reinstate'),'secondary');action.type='button';action.disabled=!state.ops?.writes_enabled;action.addEventListener('click',()=>opsConfirm('members.reinstate',{user_id:row.user_id,confirm_user_id:row.user_id}));return[emailNode(row.email??'—'),String(row.reason??'—'),fmtDate(row.suspended_at),action]},tr('noSuspendedMembers'))}catch(e){empty(c,tr('failedRead'));setText('metric-members','—');showNotice(e.message||tr('failedRead'),true)}}
async function loadQueue(){const c=$('queue-content');c.textContent=tr('loading');const cases={posts:{op:'moderation.posts.pending',args:{limit:30}},reports:{op:'moderation.reports.open',args:{}},safety:{op:'moderation.safety.open',args:{}}};const q=cases[state.queue];try{const d=await api('ops',{operation:q.op,...q.args});const rows=rowsOf(d.receipt);state.queueRows=rows;if(state.queue==='reports')setText('metric-reports',String(rows.length));previewRows(c,rows,'id',state.queue)}catch(e){empty(c,tr('failedRead'));if(state.queue==='reports')setText('metric-reports','—');showNotice(e.message||tr('failedRead'),true)}}

async function reviewQueueRecord(queue,row,decision){
  if(!state.ops?.writes_enabled){showNotice(tr('unavailable'),true);return}
  try{
    if(queue==='posts'){
      const postId=row?.id;
      if(typeof postId!=='string')throw new Error('missing_post_id');
      const snapshots=await api('ops',{operation:'moderation.posts.snapshots',post_ids:[postId]});
      const snap=rowsOf(snapshots.receipt).find(x=>x?.post?.id===postId);
      if(!snap||!/^[0-9a-f]{64}$/i.test(snap.revision))throw new Error('missing_review_snapshot');
      const reason=decision==='rejected'?window.prompt('Reason for rejection (required, maximum 160 characters):',''):'';
      if(reason===null||decision==='rejected'&&!reason.trim())return;
      await opsConfirm('moderation.posts.review',{
        post_id:postId,expected_revision:snap.revision,decision,reward_mode:'eligible',
        reason:reason.trim(),operation_id:token()});
    }else if(queue==='reports'){
      const reportId=row?.id;
      const source=row?.target_kind==='comment'?'comment':'community';
      const response=await api('ops',{operation:'moderation.reports.content',report_id:reportId,source});
      const snapshot=response.receipt;
      if(!snapshot||!/^[0-9a-f]{64}$/i.test(snapshot.revision))throw new Error('missing_report_revision');
      if(!window.confirm(`Report: ${reportId}\nAction: ${decision}. Continue?`))return;
      await opsConfirm('moderation.reports.decide',{
        report_id:reportId,source,expected_revision:snapshot.revision,
        remove:decision==='remove',confirm_remove:decision==='remove',operation_id:token()});
    }else if(queue==='safety'){
      if(!row.report_id)throw new Error('missing_safety_report_id');
      await opsConfirm('moderation.safety.decide',{
        report_id:row.report_id,decision,operation_id:token()});
    }
  }catch(e){showNotice(e.message||tr('failed'),true)}
}
async function refreshAll(){if(!state.authenticated)return;await Promise.allSettled([loadFinance(),loadModerators(),loadMembers(),loadQueue(),loadAudit()]);updateStatuses()}
async function statusRefresh(){try{state.finance=await api('finance',{operation:'status'});state.ops=await api('ops',{operation:'status'});updateStatuses();await refreshAll()}catch(e){showNotice(e.message||tr('failed'),true)}}
async function showStepUp(){return new Promise((resolve)=>{state.modalResolve=resolve;$('mfa-modal').hidden=false;$('step-up-code').value='';$('step-up-code').focus()})}
function resolveStepUp(ok){$('mfa-modal').hidden=true;$('step-up-code').value='';const cb=state.modalResolve;state.modalResolve=null;if(cb)cb(ok)}
async function confirmStepUp(){const code=$('step-up-code').value.trim();const btn=$('confirm-stepup');btn.disabled=true;try{state.factor=await findFactor();await verifyFactor(code);resolveStepUp(true)}catch(e){showNotice(e.message||tr('failed'),true)}finally{btn.disabled=false}}
async function transaction(type,payload){if(!window.confirm(tr('confirmAction')))return null;const fresh=await showStepUp();if(!fresh)return null;return await api(type,payload)}
const PENDING_STORAGE_KEY='bil:admin:pending-financial-receipt:v1';
function persistPending(){
  try {
    if(state.pendingCommand&&state.user?.id)
      sessionStorage.setItem(PENDING_STORAGE_KEY,JSON.stringify({...state.pendingCommand,owner_id:state.user.id}));
    else if(!state.pendingCommand) sessionStorage.removeItem(PENDING_STORAGE_KEY);
  }catch {/* Private browsing storage may be unavailable; memory-only recovery remains possible. */}
}
function restorePending(){
  try {
    const stored=JSON.parse(sessionStorage.getItem(PENDING_STORAGE_KEY)||'null');
    if(stored?.owner_id===state.user?.id && ['grant','revoke'].includes(stored.operation)
       && /^[A-Za-z0-9:_-]{16,128}$/.test(stored.idempotency_key)){
      state.pendingCommand={operation:stored.operation,idempotency_key:stored.idempotency_key};
      $('reconcile').disabled=false;
      setText('pending-operation',`${stored.operation} · ${stored.idempotency_key}`);
      return;
    }
  }catch {/* Corrupt or unavailable session storage is ignored. */}
  state.pendingCommand=null;
  $('reconcile').disabled=true;
  setText('pending-operation',tr('noPending'));
}
function setPending(op,id){state.pendingCommand={operation:op,idempotency_key:id};persistPending();$('reconcile').disabled=false;setText('pending-operation',`${op} · ${id}`)}
function clearPending(){state.pendingCommand=null;persistPending();$('reconcile').disabled=true;setText('pending-operation',tr('noPending'))}
function explainReceipt(d){if(d?.state==='verified'||d?.state==='committed_receipt'){clearPending();showNotice(tr('completed'));return}if(d?.state==='committed_readback_pending'){showNotice(tr('pending'));return}if(d?.state==='no_matching_recipient')throw new Error('no_matching_recipient');showNotice(tr('pending'))}
async function grantForm(ev){ev.preventDefault();if(!state.finance?.financial_writes_enabled){showNotice(tr('unavailable'),true);return}const f=new FormData(ev.target);const email=String(f.get('email')||'').trim().toLowerCase(),confirm=String(f.get('confirm_email')||'').trim().toLowerCase();if(email!==confirm){showNotice(tr('confirmEmail'),true);return}const plan=String(f.get('plan'));const key=token();const p={operation:'grant',email,plan_id:plan,duration_days:Number(f.get('days')),reason:String(f.get('reason')).trim(),confirm_email:confirm,confirm_plan:plan,acknowledge_external_grant:f.get('external_grant')==='on',idempotency_key:key};setPending('grant',key);const submit=ev.submitter;submit.disabled=true;try{const r=await transaction('finance',p);if(r){explainReceipt(r);await loadFinance();await loadAudit()}else clearPending()}catch(e){showNotice(e.message||tr('pending'),true)}finally{submit.disabled=false}}
async function revokeGrant(row){if(!state.finance?.financial_writes_enabled)return;const key=token();setPending('revoke',key);try{const d=await transaction('finance',{operation:'revoke',grant_id:row.id,confirm_grant_id:row.id,idempotency_key:key});if(d){explainReceipt(d);await loadFinance();await loadAudit()}else clearPending()}catch(e){showNotice(e.message||tr('pending'),true)}}
async function reconcile(){
  if(!state.pendingCommand)return;
  const p=state.pendingCommand;
  try {
    const d=await api('finance',{operation:'reconcile',expected_operation:p.operation,idempotency_key:p.idempotency_key});
    if(d.found===true && d.receipt?.matched===true && d.operation===p.operation){
      clearPending();showNotice(tr('completed'));await loadFinance();await loadAudit();return;
    }
    if(d.found===true && d.receipt?.matched===false){
      clearPending();showNotice('No matching recipient/grant; no change was recorded.',true);return;
    }
    showNotice(tr('pending'),true);
  }catch(e){showNotice(e.message||tr('failedRead'),true)}
}
async function opsConfirm(operation,args){if(!state.ops?.writes_enabled){showNotice(tr('unavailable'),true);return}const key=token();try{const d=await transaction('ops',{operation,...args,idempotency_key:key});if(!d)return;if(d.state!=='executed')showNotice(tr('pending'),true);else showNotice(tr('completed'));await refreshAll()}catch(e){showNotice(e.message||tr('failed'),true)}}
function makeOpsForm(id,operation,fields){$(id).addEventListener('submit',ev=>{ev.preventDefault();const f=new FormData(ev.target),args=fields(f);opsConfirm(operation,args)})}
function clearPrivateView(){
  state.authenticated=false;state.finance=null;state.ops=null;state.user=null;
  state.financeRows=[];state.auditRows=[];state.mods=[];state.members=[];state.queueRows=[];
  for(const name of ['finance-list','audit-content','moderator-content','member-content','queue-content']){
    const container=$(name);if(container)empty(container,tr('loadData'));
  }
  for(const name of ['metric-grants','metric-mods','metric-reports','metric-members'])setText(name,'—');
  authUi('auth');
  $('email-form').hidden=false;$('otp-form').hidden=true;
  $('mfa-area').hidden=true;$('enroll-area').hidden=true;
  $('reconcile').disabled=true;
  setText('pending-operation',tr('noPending'));
  updateStatuses();
}
function setNavigation(){for(const b of document.querySelectorAll('[data-page]'))b.addEventListener('click',()=>{setPage(b.dataset.page);if(b.dataset.page==='audit'&&state.authenticated)loadAudit()});$('mobile-menu').addEventListener('click',()=>$('sidebar').classList.toggle('open'));for(const b of document.querySelectorAll('[data-queue]'))b.addEventListener('click',()=>{state.queue=b.dataset.queue;for(const btn of document.querySelectorAll('[data-queue]'))btn.classList.toggle('selected',btn===b);setText('queue-title',tr(state.queue));if(state.authenticated)loadQueue()});$('language').addEventListener('click',()=>{state.language=state.language==='ar'?'en':'ar';translate();updateStatuses();if(state.authenticated){if(state.page==='finance')loadFinance();else if(state.page==='audit')loadAudit();else if(state.page==='moderators')loadModerators();else if(state.page==='members')loadMembers();else if(state.page==='moderation')previewRows($('queue-content'),state.queueRows,'id',state.queue)}})}
function setEvents(){setNavigation();$('email-form').addEventListener('submit',emailOtp);$('otp-form').addEventListener('submit',verifyEmail);$('mfa-form').addEventListener('submit',verifyMfa);$('enroll-form').addEventListener('submit',verifyEnroll);$('back-email').addEventListener('click',()=>{$('otp-form').hidden=true;$('email-form').hidden=false});$('logout').addEventListener('click',async()=>{await sdk.auth.signOut();clearPrivateView();showNotice(tr('offline'))});$('grant-form').addEventListener('submit',grantForm);$('refresh-status').addEventListener('click',statusRefresh);$('refresh-finance').addEventListener('click',loadFinance);$('refresh-audit').addEventListener('click',loadAudit);$('refresh-mods').addEventListener('click',loadModerators);$('refresh-members').addEventListener('click',loadMembers);$('refresh-queue').addEventListener('click',loadQueue);$('finance-next').addEventListener('click',()=>{state.financeOffset+=50;loadFinance()});$('finance-prev').addEventListener('click',()=>{state.financeOffset=Math.max(0,state.financeOffset-50);loadFinance()});$('reconcile').addEventListener('click',reconcile);$('cancel-stepup').addEventListener('click',()=>resolveStepUp(false));$('confirm-stepup').addEventListener('click',confirmStepUp);makeOpsForm('moderator-form','moderators.add',f=>({email:String(f.get('email')).trim().toLowerCase(),confirm_email:String(f.get('confirm_email')).trim().toLowerCase()}));makeOpsForm('member-form','members.suspend',f=>({email:String(f.get('email')).trim().toLowerCase(),confirm_email:String(f.get('confirm_email')).trim().toLowerCase(),reason:String(f.get('reason')).trim()}));makeOpsForm('coach-individual-form','coach.reset.user',f=>({email:String(f.get('email')).trim().toLowerCase(),confirm_email:String(f.get('confirm_email')).trim().toLowerCase(),reason:String(f.get('reason')).trim(),message:String(f.get('message')).trim()}));makeOpsForm('coach-global-form','coach.reset.all',f=>({confirm_phrase:String(f.get('confirm_phrase')).trim(),message:String(f.get('message')).trim()}));makeOpsForm('notification-form','notifications.send',f=>({kind:String(f.get('kind')),audience:String(f.get('audience')),email:String(f.get('email')||'').trim().toLowerCase(),confirm_target:String(f.get('confirm_target')||'').trim(),message:String(f.get('message')||'').trim(),acknowledge_token_grant:f.get('acknowledge_token_grant')==='on'}));for(const name of ['kind','audience'])$('notification-form').elements.namedItem(name).addEventListener('change',updateNotificationHelp)}
setEvents();init();