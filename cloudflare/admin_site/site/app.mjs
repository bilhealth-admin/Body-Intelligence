import { createClient } from '@supabase/supabase-js';
import { SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY } from './config.mjs';

const sdk = createClient(SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY, {
  auth: { autoRefreshToken: true, persistSession: true, detectSessionInUrl: true },
  global: { headers: { 'x-client-info': 'bil-admin-web-cloudflare-1.0' } },
});
const edge = Object.freeze({
  finance: `${SUPABASE_URL}/functions/v1/bil-admin-web-v1`,
  ops: `${SUPABASE_URL}/functions/v1/bil-admin-web-ops-v1`,
  review: `${SUPABASE_URL}/functions/v1/bil-admin-web-review-v1`,
});

const ar = {
  portal:'بوابة الإدارة',overview:'نظرة عامة',finance:'الاشتراكات والمنح',coach:'إدارة المدرب الذكي',notifications:'الإشعارات',moderation:'المراجعة والبلاغات',moderators:'المشرفون',members:'وصول الأعضاء',audit:'سجل التدقيق',security:'الأمن والاتصال',protected:'بوابة محمية بصلاحيات الخادم',offline:'غير متصل',online:'متصل وآمن',logout:'خروج',intro:'إدارة BIL بأذونات واضحة وسجل عمليات قابل للتدقيق.',secureLogin:'تسجيل دخول الإدارة',secureLoginDesc:'التحقق عبر بريدك الإلكتروني ثم رمز المصادقة الثنائية. الوصول للمالك المخوّل فقط.',email:'البريد الإلكتروني',sendCode:'إرسال رمز الدخول',emailCode:'الرمز الذي وصل إلى بريدك',verifyEmail:'تأكيد البريد',changeEmail:'تغيير البريد',totp:'رمز المصادقة الثنائية',verifyMfa:'تحقق وأدخل',enrollHelp:'أضف هذا الحساب إلى تطبيق المصادقة ثم أكد رمز الأمان.',noPasswords:'لا تُعرض مفاتيح الخادم أو كلمات المرور داخل هذا الموقع.',grants:'المنح الإدارية',sourceFinance:'مصدرها دفتر المنح الفعلي',authorizedCount:'بعد التحقق من الصلاحيات',reports:'البلاغات المفتوحة',sourceReports:'قائمة المراجعة الفعلية',suspended:'الأعضاء الموقوفون',sourceMembers:'وفق سجل الوصول الفعلي',connection:'حالة الاتصال',refresh:'تحديث',principles:'ضوابط التشغيل',principlesText:'أوامر الإدارة مُقيّدة بهوية المسؤول، والمصادقة الثنائية، وتأكيد المستفيد؛ كل عملية تُسجل على الخادم. لا تُعرض مفاتيح البيانات في المتصفح.',opsLock:'تغييرات الإدارة الأخرى مقفلة إلى حين اكتمال التحقق',newGrant:'منح اشتراك جديد',grantWarning:'المنحة الإدارية مستقلة عن مشتريات المتجر وأرصدة Boost. لا تستخدم حسابات حقيقية لأغراض الاختبار.',recipientEmail:'بريد المستفيد',plan:'الباقة',duration:'المدة',reason:'سبب المنحة',confirmEmail:'تأكيد البريد (أعد كتابته)',grantAck:'أؤكد أن هذه منحة إدارية وليست شراءً من المتجر.',submitGrant:'مراجعة المنحة وإرسالها',existingGrants:'المنح القائمة',loadData:'اضغط تحديث لجلب السجل الحقيقي',prev:'السابق',next:'التالي',lastCommand:'آخر أمر مالي غير محسوم',noPending:'لا يوجد أمر معلّق في هذه الجلسة.',reconcile:'تحقق من الإيصال',individualReset:'إعادة ضبط حساب واحد',message:'رسالة الإشعار',execute:'تنفيذ',globalReset:'إعادة ضبط جميع الحسابات',globalWarning:'إجراء شامل يعيد ضبط عدادات استخدام المدرب للفترة الحالية لجميع الحسابات المستحقة ويرسل إشعارات لهم. لا يُلغي مشتريات المتجر أو يمسح المحادثات. يتطلب كتابة العبارة المحددة ورمز مصادقة جديد.',confirmPhrase:'أدخل عبارة التأكيد الإنجليزية',composeNotification:'إعداد إشعار BIL',notificationWarning:'المخصص: رسالة فقط. الهدية أو التعويض: يمنح الخادم ٢٬٥٠٠ توكن AI لكل مستفيد. راجع المستفيدين ونص الإشعار جيداً وأكّد المصادقة الثنائية.',kind:'النوع',audience:'المستفيدون',confirmTarget:'تأكيد المستفيد (أو SEND TO ALL)',tokenAcknowledgment:'أفهم أن تعويضًا أو هدية قد يضيف توكنات.',send:'إرسال',posts:'المنشورات',safety:'سلامة المدرب',addModerator:'إضافة مشرف',suspendMember:'تعليق وصول عضو',financialAudit:'سجل العمليات المالية',identity:'حالة الهوية',securityBoundaries:'حدود الأمان',securityText:'كل طلب يمرّ من بوابة Supabase ويُراجع الخادم صلاحياته. مفاتيح الخدمة والإدارة المالية لا تُخزن في المتصفح. عمليات الكتابة تتطلب صلاحية مسؤول وتأكيدًا صريحًا ومصادقة حديثة.',noRealUsers:'لا تُنفذ تجارب على مستخدمين حقيقيين أو أرصدتهم.',stepUp:'تأكيد المصادقة الثنائية قبل تنفيذ العملية',stepUpDesc:'أدخل الرمز الجديد من تطبيق المصادقة. لن ننفذ العملية دون التحقق من صلاحياتك.',cancel:'إلغاء',confirm:'تأكيد',locked:'مقفلة',active:'نشطة',available:'متاحة',notAvailable:'غير متاحة',financeGateway:'بوابة الاشتراكات المالية',operationsGateway:'بوابة بقية الإدارة',signedIn:'الجلسة',twoFactor:'التحقق الثنائي',protectedRole:'صلاحية المالك',enableNotice:'وظائف الكتابة قيد الاعتماد؛ يمكن الاطلاع على السجلات المصرح بها.',notAuthorized:'هذه الجلسة لا تملك صلاحية الإدارة المطلوبة.',confirmAction:'هل تريد تنفيذ هذا الإجراء على البيانات الفعلية؟',completed:'اكتملت العملية، وتم استلام إيصال الخادم.',pending:'قد تكون العملية نُفذت لكن تأكيد النتيجة معلّق. استرجع الإيصال قبل إعادة المحاولة.',failed:'تعذّر تنفيذ العملية أو تأكيد نتيجتها.',empty:'لا توجد سجلات في الصفحة الحالية.',loading:'جاري القراءة من الخادم...',failedRead:'تعذّر جلب البيانات. لم تُعرض أي بيانات وهمية.',revoke:'سحب المنحة',remove:'إزالة',reinstate:'استعادة الوصول',unavailable:'غير مفعل: قيد اعتماد الربط السحابي',testRequired:'متاح تقنيًا، لكن يُرجى استخدام حساب اختبار آمن عند التجربة الأولى.',account:'الحساب',result:'النتيجة',created:'التاريخ',status:'الحالة',actions:'إجراءات',formatError:'فشل التحقق من تنسيق رد الخادم.',missingMfa:'يلزم إعداد المصادقة الثنائية أولًا.'
};
const en = {
  portal:'Administration',overview:'Overview',finance:'Subscriptions & grants',coach:'AI Coach management',notifications:'Notifications',moderation:'Moderation & reports',moderators:'Moderators',members:'Member access',audit:'Audit trail',security:'Security & connectivity',protected:'Server-authorized management',offline:'Disconnected',online:'Connected securely',logout:'Sign out',intro:'BIL management with explicit permissions and auditable actions.',secureLogin:'Administration sign-in',secureLoginDesc:'Sign in via email verification then authenticator TOTP. Owner-only access.',email:'Email address',sendCode:'Send sign-in code',emailCode:'Code sent to your email',verifyEmail:'Verify email',changeEmail:'Change email',totp:'Authenticator code',verifyMfa:'Verify and enter',enrollHelp:'Enroll in your authenticator, scan the code below, then verify your TOTP.',noPasswords:'No backend secrets or passwords are stored in this website.',grants:'Administrative grants',sourceFinance:'From the authoritative grants ledger',authorizedCount:'After permission verification',reports:'Open reports',sourceReports:'Authoritative review queue',suspended:'Suspended members',sourceMembers:'From authoritative access records',connection:'Connection status',refresh:'Refresh',principles:'Operating controls',principlesText:'Admin actions require verified owner identity, fresh two-factor confirmation, exact recipients and server audit receipts. No service-role secrets enter the browser.',opsLock:'Other administrative writes are locked pending live testing.',newGrant:'New subscription grant',grantWarning:'Admin grants are separate from store purchases and Boost. Do not test on real users.',recipientEmail:'Recipient email',plan:'Plan',duration:'Duration',reason:'Grant reason',confirmEmail:'Confirm recipient email (type again)',grantAck:'I acknowledge this is an external admin grant, not a store purchase.',submitGrant:'Review and send grant',existingGrants:'Existing grants',loadData:'Select refresh to read live records',prev:'Previous',next:'Next',lastCommand:'Last unresolved command',noPending:'No pending command in this session.',reconcile:'Reconcile receipt',individualReset:'Reset one AI Coach account',message:'Notification message',execute:'Execute',globalReset:'Reset ALL AI Coach accounts',globalWarning:'Global action: resets AI Coach usage counters for current eligible periods and notifies users. It does not delete chats or store purchases. Requires typed confirmation and fresh MFA.',confirmPhrase:'Enter the English confirmation phrase',composeNotification:'Compose BIL notification',notificationWarning:'Custom notifications send text only. Gifts and compensation credit 2,500 AI tokens per recipient. Verify the recipients, message and fresh MFA before sending.',kind:'Kind',audience:'Audience',confirmTarget:'Confirm recipient (or SEND TO ALL)',tokenAcknowledgment:'I understand gift or compensation may grant tokens.',send:'Send',posts:'Posts',safety:'AI Coach safety',addModerator:'Add moderator',suspendMember:'Suspend access',financialAudit:'Financial audit trail',identity:'Identity status',securityBoundaries:'Security boundaries',securityText:'Every request is verified by Supabase and server-side admin authority. Service-role keys stay server-side, writes require authorized user confirmation and fresh MFA.',noRealUsers:'Do not test with real user accounts or balances.',stepUp:'Fresh TOTP required for this action',stepUpDesc:'Enter a new authenticator code. No action proceeds without verified permissions.',cancel:'Cancel',confirm:'Confirm',locked:'Locked',active:'Active',available:'Available',notAvailable:'Unavailable',financeGateway:'Financial grants gateway',operationsGateway:'Administrative ops gateway',signedIn:'Session',twoFactor:'Two-factor verification',protectedRole:'Owner permissions',enableNotice:'Write operations are pending authorization. Allowed records can be read.',notAuthorized:'Your account is not authorized for administration.',confirmAction:'Execute this action against live data?',completed:'The operation completed and a server receipt was received.',pending:'The operation may have committed, but readback is pending. Reconcile before retrying.',failed:'The operation failed or could not be confirmed.',empty:'No records on this page.',loading:'Reading from the server...',failedRead:'Could not load authoritative data. No fabricated records are shown.',revoke:'Revoke grant',remove:'Remove',reinstate:'Reinstate access',unavailable:'Disabled: pending secure backend cutover',testRequired:'Technically enabled, but use an isolated test account for first verification.',account:'Account',result:'Result',created:'Created',status:'Status',actions:'Actions',formatError:'Invalid backend response.',missingMfa:'A verified TOTP factor is required.'
};
// Human-readable, safety-conscious labels. All detailed records remain bound to verified owner sessions.
Object.assign(ar,{
  operation:'العملية',active:'نشطة',revoked:'ملغاة',expired:'منتهية',open:'مفتوح',reviewing:'قيد المراجعة',closed:'مغلق',approved:'مقبول',rejected:'مرفوض',
  protectedModerator:'مسؤول محمي',regularModerator:'مشرف',pendingStatus:'بانتظار المراجعة',unknownStatus:'غير معروفة',
  reportSender:'صاحب البلاغ',reportEmail:'بريد صاحب البلاغ',accountIdentifier:'معرّف الحساب',reportId:'رقم البلاغ',postAuthor:'صاحب المنشور',
  reportReason:'سبب البلاغ',contentType:'نوع المحتوى',contentIdentifier:'معرّف المحتوى',reportDate:'تاريخ البلاغ',
  userMessage:'رسالة المستخدم',coachReply:'رد المدرب المُبلّغ عنه',postBody:'نص المنشور',reportRuntime:'بيئة عمل المدرب',
  reportLocale:'لغة البلاغ',reportedStatus:'حالة البلاغ',reportDecision:'قرار المراجعة',
  findReporterUnavailable:'تعذّر العثور على بريد صاحب البلاغ؛ قد يكون الحساب محذوفًا.',
  identityExplanation:'هذا البريد لصاحب البلاغ، وقد يختلف عن صاحب المحتوى المُبلّغ عنه. يُستخدم لمتابعة البلاغ فقط.',
  prepareCompensation:'إعداد رسالة تعويض لهذا المستخدم',prepareCompensationDone:'تم ملء بريد صاحب البلاغ في نموذج الإشعارات. راجع السبب والرسالة ثم أكد بنفسك؛ لم يُرسل أي شيء.',
  senderNotAvailable:'هوية المُبلّغ غير متاحة لهذه القائمة',
  reasonUnsafe:'إجابة غير آمنة',reasonInaccurate:'معلومات غير صحيحة',reasonOffensive:'محتوى مسيء',reasonOther:'سبب آخر',
  runtimeLocalFallback:'رد محلي احتياطي عند تعذّر خدمة المدرب',
  approve:'قبول المنشور',reject:'رفض المنشور',dismissReport:'إغلاق البلاغ دون حذف المحتوى',removeContent:'حذف المحتوى المخالف',
  noViolation:'لا توجد مخالفة',confirmedIssue:'مشكلة سلامة مؤكدة',
  reviewStatusOpen:'مفتوح',reviewStatusReviewed:'تمت المراجعة',
  operationGrant:'منح اشتراك',operationRevoke:'سحب منحة',resultChanged:'تم تغيير الحالة',resultUnchanged:'دون تغيير',resultUnmatched:'لم يُعثر على المستفيد',
  grantIdentifier:'معرّف المنحة',readOnlyTitle:'متاحة للقراءة فقط',whyLocked:'زر التنفيذ معطّل بإعداد أمني للخادم، وليس بسبب خطأ في الصفحة. يُفعَّل بعد اختبار حساب مخصّص والمصادقة الثنائية والتحقق من الإيصالات.',
  individualResetHelp:'يُعيد ضبط استخدام المدرب الذكي للحساب المحدد في الفترة الحالية ويرسل له إشعارًا، دون حذف المحادثات أو الاشتراك. يحتاج تأكيدًا صريحًا.',
  globalWarning:'عملية واسعة الأثر: تُصفّر عدادات استخدام AI Coach الحالية للحسابات المؤهلة، وتُنشئ إشعارات لهم. لا تلغي الاشتراكات أو مشتريات المتجر. هذا الإجراء يتطلب صلاحية المالك، تأكيد الأثر، ثم رمز مصادقة حديث.',
  notificationWarning:'إشعار مخصّص: رسالة فقط دون توكنات. الهدية والتعويض: قد يمنح كل مستفيد 2,500 توكن طبقًا لعقد الخادم. اختر المستفيد وأكد البريد أو عبارة الإرسال للجميع قبل التنفيذ. يتطلب الإرسال تأكيد المستفيد ورمز مصادقة جديدًا، والمنح الجماعي موافقة إضافية.',
  notificationKindHelpCustom:'إشعار مخصّص: نص إعلامي فقط، لا يمنح توكنات.',
  notificationKindHelpGift:'هدية: رسالة مع أثر محتمل على رصيد توكنات AI Coach. تأكد من المستفيد والسجل.',
  notificationKindHelpCompensation:'تعويض: استعمله بعد التحقق من بلاغ المستخدم؛ قد يمنح توكنات وفق سياسة الخادم.',
  notificationAudienceAll:'يستهدف جميع الحسابات فقط بعد تأكيدك الصريح. اكتب SEND TO ALL في خانة التأكيد. لا تجربة على مستخدمين حقيقيين.',
  notificationAudienceEmail:'سيصل إلى الحساب الذي تكتبه فقط. أعد كتابة البريد نفسه في خانة التأكيد.',
  giftLabel:'هدية',compensationLabel:'تعويض',customLabel:'إشعار مخصّص',oneAccountLabel:'حساب واحد',allAccountsLabel:'جميع الحسابات',
  moderatorsHelp:'المشرف مسؤول عن مراجعة محتوى المجتمع؛ لا يحصل تلقائيًا على صلاحية مالية أو اشتراك Premium. لا يمكن إزالة مسؤول محمي هنا.',
  membersHelp:'هذه الصفحة للتحكم بوصول الحساب إلى ميزات المجتمع فقط: تعليق التفاعل ثم استعادته بعد المراجعة. لا تحذف حساب BIL ولا تلغي الاشتراكات أو مشتريات المتجر.',
  auditHelp:'يعرض هذا السجل الأوامر المالية التي وثّقها الخادم: وقت العملية ونوعها ونتيجتها. «دون تغيير» تعني أن الأمر لم يغيّر المنحة، وليس فشلًا تقنيًا.',
  noSuspendedMembers:'لا يوجد أعضاء معلّق وصولهم إلى المجتمع.',noModerators:'لا يوجد مشرفون في القائمة.',
  noReports:'لا توجد بلاغات في القائمة الحالية.', noPosts:'لا توجد منشورات تنتظر المراجعة.',
  unknownRecipient:'لا يظهر بريد المستفيد في هذه الصفحة من السجل؛ يمكن مراجعة المنحة في قسم الاشتراكات.',
  privacyNotice:'تُعرض معلومات صاحب البلاغ للمسؤول المخوّل فقط، ويجب استخدامها للمتابعة والتعويض عند الاستحقاق.',
  viewDetails:'عرض النص الكامل',hideDetails:'إخفاء التفاصيل',notProvided:'لم يُضف المستخدم نصًا',
  statusActive:'نشطة',statusLocked:'مقفلة حتى اكتمال الاختبارات',
  resetAllButton:'مراجعة إعادة ضبط جميع الحسابات',resetIndividualButton:'مراجعة إعادة ضبط هذا الحساب',
  suspendButton:'مراجعة تعليق وصول المجتمع',notificationSendButton:'مراجعة الإشعار وإرساله',
  emailOnlyHint:'بريد صاحب البلاغ يظهر عند وجود حساب مسجّل وصلاحية إدارية للتحقق.'
});
Object.assign(en,{
  operation:'Operation',active:'Active',revoked:'Revoked',expired:'Expired',open:'Open',reviewing:'Under review',closed:'Closed',approved:'Approved',rejected:'Rejected',
  protectedModerator:'Protected administrator',regularModerator:'Moderator',pendingStatus:'Awaiting review',unknownStatus:'Unknown',
  reportSender:'Report submitted by',reportEmail:'Reporter email',accountIdentifier:'Account ID',reportId:'Report ID',postAuthor:'Post author',
  reportReason:'Report reason',contentType:'Content type',contentIdentifier:'Content ID',reportDate:'Reported on',
  userMessage:'User message',coachReply:'Reported AI Coach response',postBody:'Post text',reportRuntime:'AI Coach runtime',
  reportLocale:'Report language',reportedStatus:'Report status',reportDecision:'Review decision',
  findReporterUnavailable:'Reporter email unavailable; the account may have been deleted.',
  identityExplanation:'This email belongs to the reporter, who may differ from the reported content author. Use it only for case follow-up.',
  prepareCompensation:'Prepare compensation notification for this user',prepareCompensationDone:'Reporter email was prefilled in Notifications. Review the reason and manually confirm; nothing was sent.',
  senderNotAvailable:'Reporter identity is not available for this record',
  reasonUnsafe:'Unsafe response',reasonInaccurate:'Inaccurate answer',reasonOffensive:'Offensive content',reasonOther:'Other reason',
  runtimeLocalFallback:'Local fallback response while AI Coach was unavailable',
  approve:'Approve post',reject:'Reject post',dismissReport:'Dismiss report, keep content',removeContent:'Remove violating content',
  noViolation:'No violation',confirmedIssue:'Confirmed safety issue',
  reviewStatusOpen:'Open',reviewStatusReviewed:'Reviewed',
  operationGrant:'Grant subscription',operationRevoke:'Revoke grant',resultChanged:'State changed',resultUnchanged:'No change',resultUnmatched:'No matching recipient',
  grantIdentifier:'Grant ID',readOnlyTitle:'Read-only access',whyLocked:'Execution is disabled by a server-side security lock, not a page error. An isolated test account, fresh MFA, and receipt verification are required before enabling writes.',
  individualResetHelp:'Resets the AI Coach usage counters for the specified account in the current period and notifies the user. It does not delete conversations or purchased subscriptions.',
  globalWarning:'High-impact operation: resets the current AI Coach usage counters for eligible accounts and issues notifications. Store purchases and subscriptions remain intact. Requires owner authorization, explicit confirmation and fresh TOTP.',
  notificationWarning:'Custom: sends text only and does not grant tokens. Gift or compensation: the server may grant 2,500 AI Coach tokens per recipient. Select recipients and confirm the email, or SEND TO ALL. Requires recipient confirmation and fresh MFA; mass grants need another approval.',
  notificationKindHelpCustom:'Custom notice: information only, no tokens added.',notificationKindHelpGift:'Gift: message with potential AI Coach token credit. Verify recipient and audit.',
  notificationKindHelpCompensation:'Compensation: use after verifying a user report; may grant tokens under the server policy.',
  notificationAudienceAll:'This targets all accounts only after explicit confirmation. Type SEND TO ALL to confirm. Never test on real users.',
  notificationAudienceEmail:'One registered account only. Re-enter the exact email to confirm.',
  giftLabel:'Gift',compensationLabel:'Compensation',customLabel:'Custom notice',oneAccountLabel:'One account',allAccountsLabel:'All accounts',
  moderatorsHelp:'Moderators review community content; this does not give finance access or Premium rights. Protected administrators cannot be removed here.',
  membersHelp:'This manages access to community features only: suspend participation, then reinstate after review. It does not delete the BIL account or cancel subscriptions or purchases.',
  auditHelp:'Shows server-recorded financial commands, timestamps and outcomes. “No change” means the grant record was not modified; it is not necessarily a technical failure.',
  noSuspendedMembers:'No suspended community members.',noModerators:'No moderators listed.',noReports:'No reports in the current queue.',noPosts:'No posts waiting for review.',
  unknownRecipient:'Recipient email is not available from this audit row. Check the grant in Subscriptions.',
  privacyNotice:'Reporter details are visible only to authorized administrators and must be used only for case follow-up and justified compensation.',
  viewDetails:'View full text',hideDetails:'Hide details',notProvided:'No additional user text',
  statusActive:'Active',statusLocked:'Locked pending verification',
  resetAllButton:'Review global AI Coach reset',resetIndividualButton:'Review individual AI Coach reset',
  suspendButton:'Review community suspension',notificationSendButton:'Review and send notification',
  emailOnlyHint:'Reporter email appears only when a registered identity is available to an authorized administrator.'
});

Object.assign(ar,{
  earn:'طلبات Earn',postTitle:'عنوان المنشور',postBody:'النص الكامل للمنشور',postPhotos:'صور المنشور كاملة',postImage:'صورة',
  postVisibility:'الخصوصية',postLocation:'الموقع',postTags:'الوسوم',postPoll:'استطلاع المنشور',postAuthorEmail:'بريد صاحب المنشور',
  moderatorReview:'قرار مراجعة المنشور',viewOriginal:'فتح الصورة كاملة',imageUnavailable:'تعذرت معاينة الصور بالكامل. أُوقفت أزرار القرار لحماية المستخدم.',
  imageEmpty:'لم يرفق المنشور صورًا',imageAll:'الصور المعتمدة للمنشور',earnEligible:'مكافأة Earn عند اعتماد المنشور',
  earnDescription:'قبول المنشور المؤهل يمنح 5 توكنات AI، حتى 5 منشورات مكافأة للمستخدم خلال يوم UTC واحد؛ إذا بلغ الحد، تكون المكافأة 0. يحدد الخادم النتيجة ويمنع التكرار.',
  earnQueueHelp:'طلبات Earn منفصلة عن قبول المنشور. تظهر المنشورات المعتمدة التي تحتاج مراجعة مكافأة مستقلة، ولا تُصرف مكافأة إضافية لمنشور سبق صرفها له.',
  earnRequest:'فتح طلب مكافأة',earnApprove:'اعتماد مكافأة Earn',earnReject:'رفض طلب المكافأة',
  earnRequestStatus:'حالة طلب المكافأة',earnNoRequest:'لم تُقدَّم مراجعة مكافأة',earnRequested:'طلب ينتظر قرارًا',
  earnAlreadyHandled:'تمت مراجعة المكافأة',earnNoRows:'لا توجد طلبات مكافأة للمراجعة الآن.',
  earnAmount:'مقدار Earn',earnDailyCap:'الحد اليومي',earnMaximum:'الحد الأقصى يوميًا',
  earnReceipt:'نتيجة صرف التوكنات من الخادم',earnedGranted:'تم منح 5 AI Tokens',earnedZero:'0 توكنات: بلغ المستخدم حد المكافأة أو لم يستحقها',
  earnNotification:'إشعار قبول المنشور: «تم اعتماد منشورك وأُكدت مكافأة 5 توكنات AI» عند الصرف الفعلي، أو إشعار اعتماد دون توكنات عند بلوغ الحد. إشعار الرفض: «منشورك يحتاج تعديلات». يُنشئ الخادم إيصالًا وإشعارًا داخل التطبيق ويضع الإشعار الفوري في قائمة الإرسال؛ نجاح التسليم الخارجي يحتاج تحققًا مستقلًا.',
  reviewDetailsRequired:'يجب مشاهدة عنوان المنشور ونصه وصوره كاملة قبل اتخاذ قرار.',reviewAllAcknowledged:'راجعت عنوان المنشور ونصه وجميع الصور والمرفقات المتاحة.',
  rejectionReason:'سبب الرفض (إلزامي ويُسجل للمراجعة)',reviewFreshMfa:'يتطلب القرار تأكيدًا حديثًا من المصادقة الثنائية.',
  chooseDecision:'راجع القرار قبل التنفيذ',cancelReview:'إلغاء القرار',confirmReview:'متابعة إلى تأكيد TOTP',
  reviewBlocked:'عمليات المراجعة معطلة حاليًا بإعداد خادمي مستقل. إذا كانت نشطة، يلزم مراجعة المنشور كاملًا ثم تأكيد TOTP جديد.',
  reviewEnabled:'المراجعة متاحة للمسؤول المخوّل مع تأكيد TOTP حديث',
  noteMediaExpiry:'روابط الصور خاصة ومؤقتة لمدة 3 دقائق؛ أعد تحميل المعاينة إذا انتهت.',
  missingDetails:'تفاصيل المنشور غير مكتملة؛ لا يمكن قبول أو رفض قبل معاينتها.',
  decisionApproved:'تم قبول المنشور',decisionRejected:'تم رفض المنشور',
  rewardDecisionFailed:'لم يؤكد الخادم منح أي توكنات. راجع الإيصال ولا تعاود التنفيذ تلقائيًا.',
  notificationPreview:'نص الإشعار المتوقع',approvedWithReward:'تم اعتماد منشورك وأُكدت مكافأة 5 توكنات AI. Post approved; +5 AI tokens confirmed.',approvedWithoutReward:'تم اعتماد منشورك، لكن حد المكافأة اليومي اكتمل. Post approved; the daily reward limit was reached.',rejectedCopy:'منشورك يحتاج تعديلات. Your post needs changes.',receiptExplanation:'يصرف الخادم المكافأة بحسب الحد اليومي ويكتب إيصالًا غير قابل للتكرار. قد يتأخر وصول Push الفعلي.',
  serverReview:'بوابة مراجعة المحتوى وEarn',viewGrantExplanation:'معرّف المنحة: رمز تقني فريد لربط عملية المنح بسجل السحب؛ ليس بريد الحساب ولا رقم شراء متجر.',
  noEarnPreview:'تعذرت مراجعة تفاصيل المكافأة؛ لا يتم أي صرف دون معاينة.',
  reviewOutcome:'نتيجة القرار',receiptTokens:'التوكنات الفعلية',rewardCapped:'بلغ حد المكافآت اليومي',
  noMediaApproval:'منع القرار لأن بعض الصور لم تُعايَن.',
  mediaLoaded:'تم التحقق من النص والصور',postContentChanged:'تغير المنشور أثناء المراجعة؛ حدّث تفاصيله ولا تستخدم قرارًا قديمًا.',
  moderationPolicy:'نظام المراجعة والمكافأة',reportNotice:'يجب فحص النص والصور والبلاغ وسبب القرار قبل النشر أو الإزالة، مع عدم كشف بيانات المستخدم خارج لوحة الإدارة.',
  pendingPosts:'المنشورات بانتظار المراجعة',reviewPolicyDetails:'مكافآت Earn وسياسة الإشعار',noClaimOfDelivery:'الإيصال يثبت قرار الخادم فقط، لا يثبت وصول إشعار Push إلى الهاتف.',
  authorizedReview:'بوابة المراجعة الآمنة',moderationLockedReason:'مقفلة لأن خطوة تحقق إدارية أو اختبارًا مطلوبًا لم يكتمل، وليست لأن الزر معطّل عشوائيًا.'
});
Object.assign(en,{
  earn:'Earn requests',postTitle:'Full post title',postBody:'Complete post text',postPhotos:'All post photos',postImage:'Image',
  postVisibility:'Visibility',postLocation:'Location',postTags:'Hashtags',postPoll:'Poll',postAuthorEmail:'Post author email',
  moderatorReview:'Post moderation decision',viewOriginal:'Open full-size image',imageUnavailable:'Image previews could not be verified; moderation is blocked until all evidence can be reviewed.',
  imageEmpty:'This post has no images',imageAll:'Verified post images',earnEligible:'Earn on post approval',
  earnDescription:'An eligible approval earns 5 AI tokens, for at most 5 rewarded posts per user per UTC day. Once the daily cap is reached, the award is 0. SQL decides the real award and prevents duplicates.',
  earnQueueHelp:'Earn requests are separate from post publishing. Approved posts needing an additional reward review appear here; already credited posts never receive duplicate rewards.',
  earnRequest:'Request reward review',earnApprove:'Approve Earn reward',earnReject:'Reject reward request',
  earnRequestStatus:'Earn request status',earnNoRequest:'No reward review requested',earnRequested:'Reward decision pending',
  earnAlreadyHandled:'Reward already reviewed',earnNoRows:'No Earn requests awaiting review.',
  earnAmount:'Earn amount',earnDailyCap:'Daily reward cap',earnMaximum:'Maximum per UTC day',
  earnReceipt:'Actual token grant receipt',earnedGranted:'5 AI tokens credited',earnedZero:'0 tokens: daily cap or ineligible',
  earnNotification:'If 5 tokens are granted, the app notifies the user that the post was approved and +5 AI tokens were confirmed. At the daily limit, approval is still communicated but no tokens are awarded. Rejected posts receive “Your post needs changes.” In-app receipts and push delivery queues are created by SQL; actual push delivery needs separate verification.',
  reviewDetailsRequired:'Inspect the entire title, text and all images before acting.',reviewAllAcknowledged:'I have inspected the full title, content and every available attachment.',
  rejectionReason:'Rejection reason (required and audited)',reviewFreshMfa:'A fresh authenticator verification is required.',
  chooseDecision:'Review before applying this decision',cancelReview:'Cancel review',confirmReview:'Continue to TOTP verification',
  reviewBlocked:'Moderation is disabled by a separate backend gate. When enabled, actions require reviewing complete content and fresh TOTP.',
  reviewEnabled:'Authorized moderation available with a fresh TOTP verification',
  noteMediaExpiry:'Private signed previews expire in 3 minutes; refresh if needed.',
  missingDetails:'Incomplete review evidence; cannot publish or reject yet.',
  decisionApproved:'Post approved',decisionRejected:'Post rejected',
  rewardDecisionFailed:'The backend did not confirm any tokens. Reconcile the receipt, do not retry blindly.',
  notificationPreview:'Expected notification copy',approvedWithReward:'تم اعتماد منشورك وأُكدت مكافأة 5 توكنات AI. Post approved; +5 AI tokens confirmed.',approvedWithoutReward:'تم اعتماد منشورك، لكن حد المكافأة اليومي اكتمل. Post approved; the daily reward limit was reached.',rejectedCopy:'منشورك يحتاج تعديلات. Your post needs changes.',receiptExplanation:'The server enforces the daily cap, returns an idempotent receipt and queues notifications. Actual push delivery may be delayed.',
  serverReview:'Content moderation and Earn gateway',viewGrantExplanation:'A grant ID is a unique technical identifier linking grant and revoke audit receipts; it is neither an email nor a store purchase ID.',
  noEarnPreview:'Reward content not fully verified; nothing was awarded.',
  reviewOutcome:'Decision outcome',receiptTokens:'Actual tokens granted',rewardCapped:'Daily reward limit reached',
  noMediaApproval:'Cannot approve without reviewing every photo.',
  mediaLoaded:'Text and images verified',postContentChanged:'This post changed while you were reviewing it. Refresh the content; do not apply a stale decision.',
  moderationPolicy:'Review and rewards policy',reportNotice:'Inspect the complete content, images and report reason before publishing/removing. Keep account information visible only to administrators.',
  pendingPosts:'Posts awaiting review',reviewPolicyDetails:'Earn rewards and notifications',noClaimOfDelivery:'The receipt proves the server decision, not guaranteed delivery to a device.',
  authorizedReview:'Secure moderation gateway',moderationLockedReason:'Locked because a required administrative validation or test has not completed, not a broken button.'
});
Object.assign(ar,{
  reviewReadFailure:'تعذّر تحميل محتوى المراجعة بسبب إعدادات القراءة في الخادم، وليس بسبب عدم أهلية حسابك. جرّب تحديث القسم.',
  reviewDataPermission:'لم تكتمل صلاحية قراءة مرفقات المنشور أو سياسة المكافآت. أُوقفت قرارات هذا المحتوى لحمايته.',
  scopedAuthorizationFailure:'هذه الوظيفة تحديدًا رفضت الإذن. يمكنك الاستمرار في بقية الأقسام، أو تحديث الجلسة وإعادة المحاولة.',
  sessionExpired:'انتهت جلسة الدخول. أعد تسجيل الدخول للمواصلة بأمان.',
  reviewChanged:'تغيّر المحتوى أثناء المراجعة. حدّث المنشور واقرأ التفاصيل مجددًا قبل اتخاذ قرار.',
  retryAfterLimit:'وصلت الطلبات للحد المسموح مؤقتًا. انتظر ثم أعد المحاولة.',
  protectedWriteLocked:'الأزرار الإدارية المؤثرة في الحسابات أو التوكنات مقفلة على الخادم إلى حين اعتماد اختبار فعلي آمن. الاتصال والقراءة يعملان بصورة مستقلة.',
  moderationReadAndDecisions:'القراءة وقرارات المراجعة متاحتان',
  connectionReadOnly:'القراءة متاحة · التعديلات مقفلة',
  connectionReadWrite:'القراءة والتعديلات متاحتان',
  connectionPartial:'اتصال جزئي؛ تحقّق من الأقسام',
  menuClose:'إغلاق قائمة الإدارة',
  moderatorsHelp:'قائمة حسابات المشرفين المصرّح لهم بمراجعة المحتوى. قد تبقى صلاحيات تغيير المشرفين مقفلة بينما تعمل القراءة.',
  auditHelp:'سجل الخادم الفعلي للمنح والسحب. المعرفات التقنية تساعد التدقيق لكنها ليست بديلًا عن بريد المستفيد والنتيجة.',
  whyNotWorking:'لماذا بعض الأزرار غير متاحة؟',
  availableReadOnly:'القسم متاح للقراءة. تنفيذ التغييرات يحتاج تفعيلًا منفصلًا بعد اختبار الصلاحيات.',
  unknownError:'تعذّر إكمال الطلب. لم يحدث تغيير مؤكد؛ جرّب إعادة المحاولة أو مراجعة حالة الاتصال.'
});
Object.assign(en,{
  reviewReadFailure:'The moderation data service could not read a required resource. This is not proof that your administrator account lacks permission. Refresh this section.',
  reviewDataPermission:'The service could not read the post attachments or reward policy. Decisions on this content are blocked for safety.',
  scopedAuthorizationFailure:'This operation was denied. Other authorized areas can still work; refresh your session and retry.',
  sessionExpired:'Your sign-in session expired. Sign in again to continue safely.',
  reviewChanged:'This content changed during review. Reload and examine it before taking action.',
  retryAfterLimit:'This action was rate limited. Please wait before retrying.',
  protectedWriteLocked:'Account and token-changing administrative actions are locked at the server pending a safe live acceptance test. Read access is independent.',
  moderationReadAndDecisions:'Reading and moderation decisions enabled',
  connectionReadOnly:'Reading available · changes locked',
  connectionReadWrite:'Reading and changes available',
  connectionPartial:'Some services need attention',
  menuClose:'Close admin navigation',
  moderatorsHelp:'Authorized moderation accounts. Role changes may be locked while records are readable.',
  auditHelp:'Real grant and revoke receipts. Technical identifiers should accompany a recipient email and outcome.',
  whyNotWorking:'Why are some buttons unavailable?',
  availableReadOnly:'This section is readable; changes require separate production acceptance approval.',
  unknownError:'This request could not be completed. No change was confirmed. Please retry or inspect connection status.'
});
Object.assign(ar,{
  taskCenter:'مركز التشغيل',taskCenterIntro:'قائمة عمل يومية متصلة ببيانات BIL الفعلية، لا أرقام تقديرية.',
  quickModeration:'راجع المنشورات والبلاغات',quickGrants:'إدارة الاشتراكات',quickMembers:'إدارة الحسابات والمشرفين',
  quickAudit:'فتح سجل العمليات',awaitingPosts:'منشورات بانتظار القرار',awaitingEarn:'طلبات ومراجعات Earn',
  fromLiveQueue:'من بيانات طابور المراجعة',recentUpdated:'آخر تحديث',searchCurrentGrants:'ابحث في منح الصفحة الحالية بالاسم أو البريد أو المعرّف أو الحالة',
  searchCurrentAudit:'ابحث في السجل بالعملية أو البريد أو المعرّف',expiresAt:'تاريخ الانتهاء',adminActor:'نفّذها',
  grantReason:'سبب المنحة',financialReceipt:'معرّف الإيصال',fullIdentifier:'إظهار المعرّف الكامل',copyIdentifier:'نسخ المعرّف',
  copied:'تم نسخ المعرّف',notCopied:'يمكن تحديد المعرّف الكامل ونسخه يدويًا',
  noMatchingSearch:'لا توجد نتائج تطابق البحث في هذه الصفحة.',operatorModeActive:'أوامر الإدارة متاحة للمسؤول المخوّل مع تأكيد مصادقة ثنائية جديد لكل عملية.',
  compMassWarning:'هذه عملية جماعية تؤثر في رصيد AI لجميع المستفيدين. اكتب العبارة الإنجليزية للتأكيد على علمك بالأثر.',
  highImpactLabel:'تأكيد إضافي لمنح 2,500 توكن لكل حساب في إشعار جماعي',highImpactPhrase:'GRANT 2500 AI TOKENS TO ALL USERS',
  grantActionConfirm:'تأكيد المنحة',revokeActionConfirm:'تأكيد سحب المنحة',adminActionConfirm:'تأكيد التغيير الإداري',
  noRecipientsYet:'لم يتم العثور على سجلات فعلية، أو لم يتحقق تحميلها بعد.',scopeReadWrite:'قراءة وتنفيذ محمي',
  operatorIntro:'لوحة عمل للمنح، والتدقيق، ومراجعة المحتوى، وإدارة الحسابات. تُسجّل النتائج على الخادم وتحتاج العمليات الحساسة لتأكيد حديث.',
});
Object.assign(en,{
  taskCenter:'Operations command center',taskCenterIntro:'Daily workflow with live BIL data—no estimated counts.',
  quickModeration:'Review posts and reports',quickGrants:'Manage subscriptions',quickMembers:'Manage members and moderators',
  quickAudit:'View financial audit',awaitingPosts:'Posts awaiting review',awaitingEarn:'Earn review items',
  fromLiveQueue:'From the actual review queue',recentUpdated:'Last updated',searchCurrentGrants:'Search current page by name, email, ID or status',
  searchCurrentAudit:'Search audit by operation, email or ID',expiresAt:'Expires',adminActor:'Performed by',
  grantReason:'Grant reason',financialReceipt:'Receipt ID',fullIdentifier:'Show full identifier',copyIdentifier:'Copy ID',
  copied:'Identifier copied',notCopied:'You can select and copy the full identifier manually.',
  noMatchingSearch:'No records on this page match that search.',operatorModeActive:'Owner-only administration is enabled with fresh two-factor confirmation on every write.',
  compMassWarning:'Global operation: this may credit every recipient. Type the exact English phrase to confirm the impact.',
  highImpactLabel:'Extra approval for 2,500 AI tokens per account in an all-users message',highImpactPhrase:'GRANT 2500 AI TOKENS TO ALL USERS',
  grantActionConfirm:'Confirm subscription grant',revokeActionConfirm:'Confirm revocation',adminActionConfirm:'Confirm admin change',
  noRecipientsYet:'No authoritative records found, or data not loaded yet.',scopeReadWrite:'Authorized read/write',
  operatorIntro:'Manage subscriptions, audit, community moderation and accounts. Server-signed receipts and fresh MFA protect sensitive changes.',
});
Object.assign(ar,{
  grantAlreadyRevoked:'هذه المنحة ملغاة بالفعل؛ لا تحتاج سحبًا آخر.',
  grantAlreadyExpired:'انتهت هذه المنحة؛ لا توجد منحة نشطة لسحبها.',
  grantNotActive:'لا يمكن سحب هذه المنحة لأنها غير نشطة.',
});
Object.assign(en,{
  grantAlreadyRevoked:'This grant is already revoked; no further revocation is needed.',
  grantAlreadyExpired:'This grant has expired; there is no active grant to revoke.',
  grantNotActive:'This grant cannot be revoked because it is not active.',
});
const dict={ar,en};
const state={language:'ar',page:'overview',queue:'posts',email:'',factor:null,finance:null,ops:null,user:null,financeRows:[],auditRows:[],mods:[],members:[],queueRows:[],review:null,earnPolicy:null,financeOffset:0,hasMore:false,pendingCommand:null,authenticated:false,modalResolve:null,loading:false};
const $ = id=>document.getElementById(id);
const tr=k=>(dict[state.language][k]??k);
const elem=(name,text,cls)=>{const e=document.createElement(name);if(text!==undefined&&text!==null)e.textContent=String(text);if(cls)e.className=cls;return e};
function setText(id,x){$(id).textContent=String(x)}
function showNotice(message,bad=false){const n=$('notice');n.textContent=String(message);n.classList.toggle('error',bad);n.hidden=false;clearTimeout(showNotice.timer);showNotice.timer=setTimeout(()=>n.hidden=true,13000)}
function translate(){document.documentElement.lang=state.language;document.documentElement.dir=state.language==='ar'?'rtl':'ltr';for(const node of document.querySelectorAll('[data-i18n]')){node.textContent=tr(node.dataset.i18n)}$('language').textContent=state.language==='ar'?'EN':'AR';setText('breadcrumb',tr(state.page));setText('page-title',tr(state.page));updateNotificationHelp();}
function setPage(page){
  if(!document.getElementById(page+'-page'))return;
  state.page=page;
  for(const panel of document.querySelectorAll('.page'))panel.classList.toggle('active',panel.id===page+'-page');
  for(const item of document.querySelectorAll('[data-page]'))item.classList.toggle('selected',item.dataset.page===page);
  setText('breadcrumb',tr(page));setText('page-title',tr(page));
  const summaries={overview:'intro',finance:'grantWarning',coach:'individualResetHelp',
    notifications:'notificationWarning',moderation:'reportNotice',
    moderators:'moderatorsHelp',members:'membersHelp',audit:'auditHelp',security:'securityText'};
  setText('page-subtitle',tr(summaries[page]||'intro'));
  closeSidebar();
  window.scrollTo({top:0,behavior:'instant'});
}
function authUi(view){$('auth-view').hidden=view==='admin';$('admin-view').hidden=view!=='admin';$('logout').hidden=view!=='admin'&&view!=='mfa';$('top-status').textContent=view==='admin'?tr('online'):tr('offline');$('top-status').classList.toggle('connected',view==='admin')}
function count(rows){return Array.isArray(rows)?rows.length:'—'}
function rowsOf(data){if(Array.isArray(data))return data;if(!data||typeof data!=='object')return[];if(Array.isArray(data.rows))return data.rows;if(Array.isArray(data.items))return data.items;if(Array.isArray(data.reports))return data.reports;if(Array.isArray(data.posts))return data.posts;return []}
function fmtDate(v){if(!v)return '—';const d=new Date(v);return Number.isNaN(+d)?'—':new Intl.DateTimeFormat(state.language,{dateStyle:'medium',timeStyle:'short'}).format(d)}
function statusLabel(value) {
  const code=String(value??'').toLowerCase();
  const map={active:'active',revoked:'revoked',expired:'expired',open:'open',reviewing:'reviewing',closed:'closed',
    approved:'approved',rejected:'rejected',reviewed:'reviewStatusReviewed',pending:'pendingStatus',
    no_violation:'noViolation',confirmed_safety_issue:'confirmedIssue',protected:'protectedModerator',changed:'resultChanged',unchanged:'resultUnchanged',unmatched:'resultUnmatched'};
  return map[code]?tr(map[code]):(value??'—');
}
function badge(value){
  const code=String(value??'').toLowerCase();
  const span=elem('span',statusLabel(value),'pill');
  span.setAttribute('data-status',code);
  if(/revoked|expired|rejected|removed|closed|inactive|confirmed_safety_issue/.test(code))span.classList.add('revoked');
  return span;
}
function identifier(id) {
  const value=String(id??'');
  if(!value)return elem('span','—','short-id');
  const root=elem('details',null,'full-identifier');
  const summary=elem('summary',value.length>23?value.slice(0,8)+'…'+value.slice(-5):value,'short-id');
  summary.title=tr('fullIdentifier');summary.dir='ltr';
  const text=elem('code',value,'complete-id');text.dir='ltr';
  const copy=elem('button',tr('copyIdentifier'),'copy-id secondary');copy.type='button';
  copy.addEventListener('click',async()=>{
    try{await navigator.clipboard.writeText(value);showNotice(tr('copied'))}
    catch{showNotice(tr('notCopied'),true);text.focus()}
  });
  text.tabIndex=0;
  root.append(summary,text,copy);return root;
}
function textNode(value,{email=false,code=false}={}){
  if(code)return identifier(value);
  const e=elem('span',value??'—',email?'bidi-isolate email-field':'bidi-isolate');
  if(email || /^[0-9a-f]{8}-[0-9a-f-]{27,}$/i.test(String(value??'')))e.dir='ltr';
  return e;
}
function empty(parent,text=tr('empty')){parent.replaceChildren(elem('div',text,'empty-state'))}
function addRow(container,key,value,className){const row=elem('div',null,'status-row');row.append(elem('span',key),elem('strong',value,className));container.append(row)}
function makeTable(container,headers,rows,render,emptyMessage=tr('empty')){
  container.classList.remove('empty-state');
  container.replaceChildren();
  if(!Array.isArray(rows)||rows.length===0){empty(container,emptyMessage);return}
  container.classList.remove('empty-state');
  const table=elem('table',null,'data-table'),head=elem('thead'),trh=elem('tr');
  for(const x of headers){const h=elem('th',x);h.scope='col';trh.append(h)}head.append(trh);
  const body=elem('tbody');
  for(const record of rows){
    const row=elem('tr');const columns=render(record);
    for(let i=0;i<columns.length;i++){
      const cell=columns[i],td=elem('td');td.dataset.label=headers[i]||'';
      if(cell instanceof Node)td.append(cell);else td.append(textNode(cell));
      row.append(td);
    }
    body.append(row);
  }
  table.append(head,body);container.append(table);
}
function displayDetail(label,value,{email=false,identifierValue=false,paragraph=false,muted=false}={}){
  const wrap=elem('div',null,'report-field');
  wrap.append(elem('dt',label,'report-field-label'));
  const dd=elem('dd',null,'report-field-value');
  if(identifierValue)dd.append(identifier(value));
  else if(paragraph){
    const raw=String(value??'').trim();
    if(raw.length>1800){
      const details=elem('details',null,'report-disclosure');
      details.open=true;details.append(elem('summary',raw.slice(0,145)+'…','report-summary'),elem('p',raw,'report-long-text'));
      dd.append(details);
    }else dd.append(elem('p',raw||tr('notProvided'),'report-long-text'));
  }else dd.append(textNode(value,{email}));
  if(muted)dd.classList.add('soft');
  wrap.append(dd);
  return wrap;
}
function labelReason(value){
  const map={unsafe:'reasonUnsafe',inaccurate:'reasonInaccurate',offensive:'reasonOffensive',other:'reasonOther'};
  return tr(map[String(value??'').toLowerCase()]||String(value??'')||'reasonOther');
}
function labelRuntime(value){return value==='local_fallback'?tr('runtimeLocalFallback'):String(value||'—').replaceAll('_',' ')}
function renderReporterContact(card,row,{reporter=true}={}){
  const email=reporter?row?.reporter_email:(row?.author_email??row?.reporter_email);
  const ownerId=row?.reporter_user_id??row?.reporter_id??null;
  const area=elem('div',null,'report-identity');
  area.append(displayDetail(reporter?tr('reportEmail'):tr('postAuthorEmail'),email||tr('findReporterUnavailable'),{email:!!email}));
  if(ownerId)area.append(displayDetail(tr('accountIdentifier'),ownerId,{identifierValue:true}));
  if(reporter)area.append(elem('p',tr('identityExplanation'),'privacy-note'));
  if(email && reporter){
    const button=elem('button',tr('prepareCompensation'),'secondary compensation-draft');button.type='button';
    button.addEventListener('click',()=>prepareCompensation(email));
    area.append(button);
  }
  card.append(area);
}
function prepareCompensation(email){
  if(!state.authenticated||!state.user)return;
  const form=$('notification-form');
  form.elements.namedItem('kind').value='compensation';
  form.elements.namedItem('audience').value='email';
  form.elements.namedItem('email').value=email;
  form.elements.namedItem('confirm_target').value='';
  form.elements.namedItem('acknowledge_token_grant').checked=false;
  form.elements.namedItem('message').value='';
  updateNotificationHelp();
  setPage('notifications');
  showNotice(tr('prepareCompensationDone'));
}
function validReviewImage(url){
  if(typeof url!=='string'||url.length>2000)return false;
  try{
    const u=new URL(url);
    return u.origin===new URL(SUPABASE_URL).origin && u.protocol==='https:' &&
      u.pathname.startsWith('/storage/v1/object/sign/community-post-images/') &&
      u.searchParams.has('token');
  }catch{return false}
}
function cardButtonsForMediaRow(row){return Array.isArray(row._reviewButtons)?row._reviewButtons:[]}
function reviewPictureGallery(images,count,row){
  const figure=elem('section',null,'post-gallery');
  figure.append(elem('h4',`${tr('postPhotos')} (${count})`));
  if(!Array.isArray(images)||images.length!==count||images.some(x=>!validReviewImage(x.url))){
    figure.append(elem('p',tr('imageUnavailable'),'warning'));return figure;
  }
  if(!count){figure.append(elem('p',tr('imageEmpty'),'muted'));return figure}
  const grid=elem('div',null,'post-gallery-grid');
  for(let i=0;i<images.length;i++){
    const img=images[i];
    const wrap=elem('figure',null,'post-image-wrap');
    const a=elem('a');a.href=img.url;a.target='_blank';a.rel='noopener noreferrer';
    a.setAttribute('aria-label',`${tr('viewOriginal')} ${i+1}`);
    const picture=elem('img');picture.src=img.url;picture.loading='lazy';
    picture.decoding='async';picture.referrerPolicy='no-referrer';
    picture.alt=`${tr('postImage')} ${i+1} / ${count}`;
    picture.addEventListener('error',()=>{wrap.classList.add('media-broken');
      row.media_complete=false;picture.alt=tr('imageUnavailable');
      for(const button of cardButtonsForMediaRow(row)){button.dataset.caseEligible='false';button.disabled=true;}
      showNotice(tr('imageUnavailable'),true)});
    a.append(picture);wrap.append(a,elem('figcaption',`${tr('postImage')} ${i+1} / ${count}`));grid.append(wrap);
  }
  figure.append(grid,elem('p',tr('noteMediaExpiry'),'micro'));return figure;
}
function renderRecords(container,rows,queue){
  container.classList.remove('empty-state');container.replaceChildren();
  const emptyKey=queue==='posts'?'noPosts':queue==='earn'?'earnNoRows':queue==='reports'?'noReports':'empty';
  if(!Array.isArray(rows)||!rows.length){empty(container,tr(emptyKey));return}
  for(const row of rows){
    if(!row||typeof row!=='object'||Array.isArray(row))continue;
    const card=elem('article',null,'report-card case-card');
    const id=row.post_id??row.report_id??row.id;
    const heading=elem('strong',queue==='posts'?tr('pendingPosts'):queue==='earn'?tr('earn'):queue==='safety'?tr('safety'):tr('reports'),'report-title');
    const hdr=elem('header',null,'report-header');hdr.append(heading,badge(row.status??row.moderation_status));card.append(hdr);
    const dl=elem('dl',null,'report-grid');
    if(queue==='posts'||queue==='earn'){
      const posterEmail=row.author_email??row.reporter_email;
      const contact=elem('div',null,'report-identity');
      contact.append(displayDetail(tr('postAuthorEmail'),posterEmail??'—',{email:!!posterEmail}));
      if(row.author_id)contact.append(displayDetail(tr('accountIdentifier'),row.author_id,{identifierValue:true}));
      card.append(contact);
      dl.append(displayDetail(tr('postAuthor'),row.author_name??'—'));
      dl.append(displayDetail(tr('postTitle'),row.title??'—',{paragraph:true}));
      dl.append(displayDetail(tr('postBody'),row.body??tr('notProvided'),{paragraph:true}));
      dl.append(displayDetail(tr('reportDate'),fmtDate(row.created_at)));
      dl.append(displayDetail(tr('contentIdentifier'),id,{identifierValue:true}));
      if(row.visibility)dl.append(displayDetail(tr('postVisibility'),row.visibility));
      if(row.location)dl.append(displayDetail(tr('postLocation'),row.location));
      if(Array.isArray(row.hashtags)&&row.hashtags.length)dl.append(displayDetail(tr('postTags'),row.hashtags.join(' · ')));
      if(row.poll?.question)dl.append(displayDetail(tr('postPoll'),`${row.poll.question} — ${(row.poll.options??[]).join(' • ')}`,{paragraph:true}));
      if(queue==='earn'){
        const st=row.request_id?(row.status==='requested'?tr('earnRequested'):tr('earnAlreadyHandled')):tr('earnNoRequest');
        dl.append(displayDetail(tr('earnRequestStatus'),st));
      }
    }else if(queue==='reports'){
      renderReporterContact(card,row,{reporter:true});
      dl.append(displayDetail(tr('reportReason'),row.reason??tr('notProvided'),{paragraph:true}));
      dl.append(displayDetail(tr('contentType'),row.target_kind??'—'));
      dl.append(displayDetail(tr('reportDate'),fmtDate(row.created_at)));
      dl.append(displayDetail(tr('reportId'),id,{identifierValue:true}));
      if(row.target_id)dl.append(displayDetail(tr('contentIdentifier'),row.target_id,{identifierValue:true}));
    }else if(queue==='safety'){
      renderReporterContact(card,row,{reporter:true});
      dl.append(displayDetail(tr('reportReason'),labelReason(row.reason)));
      dl.append(displayDetail(tr('reportDate'),fmtDate(row.created_at)));
      dl.append(displayDetail(tr('reportLocale'),String(row.locale||'—').toUpperCase()));
      dl.append(displayDetail(tr('reportRuntime'),labelRuntime(row.runtime)));
      if(row.user_note)dl.append(displayDetail(tr('userMessage'),row.user_note,{paragraph:true}));
      if(row.answer_text)dl.append(displayDetail(tr('coachReply'),row.answer_text,{paragraph:true}));
      if(row.decision)dl.append(displayDetail(tr('reportDecision'),statusLabel(row.decision)));
      dl.append(displayDetail(tr('reportId'),id,{identifierValue:true}));
    }
    card.append(dl);
    if(queue==='posts'||queue==='earn'){
      card.append(reviewPictureGallery(row.images||[],Number(row.media_count??(row.images?.length??0)),row));
      if(row.media_complete!==true)card.append(elem('p',tr('imageUnavailable'),'warning'));
    }
    const actions=elem('div',null,'report-actions');
    const canWrite=state.review?.moderation_writes_enabled===true;
    const specs=queue==='posts'?[[tr('approve'),'approved'],[tr('reject'),'rejected']]:
      queue==='earn'?row.request_id && row.status==='requested'?
        [[tr('earnApprove'),'earn-approve'],[tr('earnReject'),'earn-reject']]:
        !row.request_id?[[tr('earnRequest'),'earn-request']]:[]:
      queue==='reports'?[[tr('dismissReport'),'dismiss'],[tr('removeContent'),'remove']]:
      queue==='safety'?[[tr('noViolation'),'no_violation'],[tr('confirmedIssue'),'confirmed_safety_issue']]:[];
    for(const [label,decision] of specs){
      const button=elem('button',label,(decision==='rejected'||decision==='earn-reject'||decision==='remove'||decision==='confirmed_safety_issue')?'danger':'secondary');
      button.type='button';button.classList.add('review-write');
      const isVerified=queue!=='posts'&&queue!=='earn'||row.media_complete===true;
      button.dataset.caseEligible=String(isVerified&&!(queue==='safety'&&row.status==='reviewed'));
      button.disabled=!canWrite||button.dataset.caseEligible==='false';
      button.title=!canWrite?tr('reviewBlocked'):!isVerified?tr('missingDetails'):label;
      button.addEventListener('click',()=>reviewQueueRecord(queue,row,decision));(row._reviewButtons??=[]).push(button);actions.append(button);
    }
    if(queue==='posts'||queue==='earn'){
      const expand=elem('button',tr('refresh'),'secondary');expand.type='button';
      expand.title=tr('reviewDetailsRequired');
      expand.addEventListener('click',()=>loadQueue());actions.append(expand);
    }
    card.append(actions);container.append(card);
  }
}

function previewRows(container,rows,label='id',queue=null){renderRecords(container,rows,queue)}
function updateNotificationHelp(){
  const form=$('notification-form'),kind=form.elements.namedItem('kind').value;
  const aud=form.elements.namedItem('audience').value;
  $('notification-kind-help').textContent=tr('notificationKindHelp'+kind[0].toUpperCase()+kind.slice(1));
  $('notification-audience-help').textContent=tr(aud==='all'?'notificationAudienceAll':'notificationAudienceEmail');
  const target=form.elements.namedItem('email');target.required=aud==='email';target.disabled=aud!=='email';
  if(aud==='all')target.value='';
  const tokenAck=form.elements.namedItem('acknowledge_token_grant');
  tokenAck.required=kind!=='custom';
  if(kind==='custom')tokenAck.checked=false;
  const mass=$('mass-grant-confirmation'),needsMass=kind!=='custom'&&aud==='all';
  if(mass){mass.hidden=!needsMass;
    const input=mass.querySelector('input');input.required=needsMass;input.disabled=!needsMass;
    if(!needsMass)input.value='';}
}
function token(){return crypto.randomUUID()}
function explainBackendError(code,scope){
  const reason=String(code??'');
  if(reason==='review_context_configuration_error'||reason==='review_service_read_unavailable'||reason==='invalid_backend_result')
    return tr('reviewDataPermission');
  if(reason==='not_authorized'||reason==='not_found'||reason==='administrator_required')
    return tr('scopedAuthorizationFailure');
  if(reason==='authentication_required'||reason==='invalid_session'||reason==='mfa_required')
    return tr('sessionExpired');
  if(reason==='admin_ops_writes_locked'||reason==='moderation_writes_locked')
    return tr('protectedWriteLocked');
  if(reason==='stale_content'||reason==='content_changed'||reason==='post_not_reviewable')
    return tr('reviewChanged');
  if(reason==='rate_limited')return tr('retryAfterLimit');
  return tr('unknownError');
}
async function api(type,body){
  const {data:{session},error}=await sdk.auth.getSession();
  if(error||!session?.access_token)throw new Error(tr('sessionExpired'));
  const response=await fetch(edge[type],{method:'POST',mode:'cors',cache:'no-store',credentials:'omit',
    headers:{'content-type':'application/json','apikey':SUPABASE_PUBLISHABLE_KEY,
      'authorization':`Bearer ${session.access_token}`},body:JSON.stringify(body)});
  let data;try{data=await response.json()}catch{throw new Error(tr('unknownError'))}
  if(!response.ok){
    const code=String(data?.error||'backend_unavailable');
    const e=new Error(explainBackendError(code,type));
    e.httpStatus=response.status;e.backendCode=code;e.gateway=type;e.operation=body?.operation;
    throw e;
  }
  return data;
}
async function emailOtp(ev){ev.preventDefault();const value=$('email').value.trim().toLowerCase();if(!value)return;const btn=ev.submitter;btn.disabled=true;try{const {error}=await sdk.auth.signInWithOtp({email:value,options:{shouldCreateUser:false}});if(error)throw error;state.email=value;$('email-form').hidden=true;$('otp-form').hidden=false;showNotice(state.language==='ar'?'تم طلب رمز الدخول. تحقق من بريدك.':'Sign-in code requested. Check your email.')}catch(e){showNotice(e.message||tr('failed'),true)}finally{btn.disabled=false}}
async function verifyEmail(ev){ev.preventDefault();const code=$('email-code').value.trim();const btn=ev.submitter;btn.disabled=true;try{const {error}=await sdk.auth.verifyOtp({email:state.email,token:code,type:'email'});if(error)throw error;$('otp-form').hidden=true;await enterMfaFlow()}catch(e){showNotice(e.message||tr('failed'),true)}finally{btn.disabled=false}}
async function findFactor(){const {data,error}=await sdk.auth.mfa.listFactors();if(error)throw error;return (data?.totp??[]).find(f=>f.status==='verified')??null}
async function enterMfaFlow(){authUi('mfa');const {data}=await sdk.auth.mfa.getAuthenticatorAssuranceLevel();if(data?.currentLevel==='aal2'){await loadAdmin();return}state.factor=await findFactor();$('mfa-area').hidden=!!(!state.factor);$('enroll-area').hidden=!!state.factor;if(!state.factor){const {data:enrolled,error}=await sdk.auth.mfa.enroll({factorType:'totp',friendlyName:'BIL Secure Admin'});if(error)throw error;state.factor=enrolled;if(enrolled.totp?.qr_code)$('enroll-qr').src=enrolled.totp.qr_code}}
async function verifyFactor(code){if(!state.factor?.id)throw new Error(tr('missingMfa'));if(!/^\d{6,8}$/.test(code))throw new Error('invalid_totp');const {data,error}=await sdk.auth.mfa.challengeAndVerify({factorId:state.factor.id,code});if(error)throw error;return data}
async function verifyMfa(ev){ev.preventDefault();const btn=ev.submitter;btn.disabled=true;try{const code=$('mfa-code').value.trim();await verifyFactor(code);$('mfa-code').value='';$('mfa-area').hidden=true;await loadAdmin()}catch(e){showNotice(e.message||tr('failed'),true)}finally{btn.disabled=false}}
async function verifyEnroll(ev){ev.preventDefault();const btn=ev.submitter;btn.disabled=true;try{await verifyFactor($('enroll-code').value.trim());$('enroll-code').value='';$('enroll-area').hidden=true;await loadAdmin()}catch(e){showNotice(e.message||tr('failed'),true)}finally{btn.disabled=false}}
async function loadAdmin(){const {data:{user}}=await sdk.auth.getUser();if(!user)throw new Error('invalid_session');state.user=user;const finance=await api('finance',{operation:'status'});if(finance.access!=='authorized')throw new Error('unauthorized');state.finance=finance;let ops=null;try{ops=await api('ops',{operation:'status'})}catch(e){ops={access:'unavailable',error:e.message,writes_enabled:false}}state.ops=ops;let review=null;try{review=await api('review',{operation:'status'})}catch(e){review={access:'unavailable',error:e.message,moderation_writes_enabled:false}}state.review=review;state.authenticated=true;authUi('admin');restorePending();updateStatuses();await Promise.allSettled([loadFinance(),loadModerators(),loadMembers(),loadQueue(),loadDashboardWorkload()]);updateStatuses()}
function updateStatuses(){
  const finance=state.finance?.access==='authorized';
  const ops=state.ops?.access==='authorized';
  const review=state.review?.access==='authorized';
  const lock=ops&&state.ops?.writes_enabled===true;
  const reviewWrite=review&&state.review?.moderation_writes_enabled===true;
  const financeWrite=finance&&state.finance?.financial_writes_enabled===true;
  setText('top-status',finance&&ops&&review?tr('online'):finance||ops||review?tr('connectionPartial'):tr('offline'));
  $('top-status').classList.toggle('connected',finance&&ops&&review);
  const container=$('status-cards');container.replaceChildren();
  addRow(container,tr('financeGateway'),finance?(financeWrite?tr('connectionReadWrite'):tr('connectionReadOnly')):tr('notAvailable'),finance?(financeWrite?'':'pending'):'bad');
  addRow(container,tr('operationsGateway'),ops?(lock?tr('connectionReadWrite'):tr('connectionReadOnly')):tr('notAvailable'),ops?(lock?'':'pending'):'bad');
  addRow(container,tr('serverReview'),review?(reviewWrite?tr('moderationReadAndDecisions'):tr('connectionReadOnly')):tr('notAvailable'),review?(reviewWrite?'':'pending'):'bad');
  addRow(container,tr('twoFactor'),state.authenticated?tr('active'):tr('notAvailable'),state.authenticated?'':'bad');
  addRow(container,tr('protectedRole'),state.authenticated?tr('active'):tr('notAvailable'),state.authenticated?'':'bad');
  for(const b of document.querySelectorAll('.ops-write')){
    b.disabled=!lock;
    b.title=!lock?tr('protectedWriteLocked'):'';
    b.setAttribute('aria-describedby','ops-lock');
  }
  for(const b of document.querySelectorAll('.review-write'))
    b.disabled=!reviewWrite||b.dataset.caseEligible==='false';
  $('ops-lock').textContent=lock?tr('operatorModeActive'):tr('protectedWriteLocked');
  for(const message of document.querySelectorAll('.write-explanation:not(.review-write-explanation)'))message.hidden=lock;
  for(const message of document.querySelectorAll('.review-write-explanation')){
    message.hidden=reviewWrite;message.textContent=tr('reviewBlocked');
  }
  const identity=$('identity-content');identity.replaceChildren();
  addRow(identity,tr('signedIn'),state.user?.email||'—');
  addRow(identity,tr('twoFactor'),state.authenticated?'AAL2':'—');
  addRow(identity,tr('financeGateway'),finance?(financeWrite?tr('connectionReadWrite'):tr('connectionReadOnly')):tr('notAvailable'),finance?'':'bad');
  addRow(identity,tr('operationsGateway'),ops?(lock?tr('connectionReadWrite'):tr('connectionReadOnly')):tr('notAvailable'),ops?'':'bad');
  addRow(identity,tr('serverReview'),review?(reviewWrite?tr('moderationReadAndDecisions'):tr('connectionReadOnly')):tr('notAvailable'),review?'':'bad');
}
async function init(){
  translate();authUi('auth');
  sdk.auth.onAuthStateChange((event)=>{
    if(event==='SIGNED_OUT')clearPrivateView();
  });
  try{const {data:{session}}=await sdk.auth.getSession();if(session){await enterMfaFlow()}}
  catch(e){showNotice(e.message||tr('failed'),true)}
}
function searchableText(record){
  return Object.values(record??{}).filter(v=>v!=null&&typeof v!=='object').join(' ').toLowerCase();
}
function grantPlan(plan){return plan==='premium_ai_coach'?'Premium + AI Coach':plan==='premium'?'Premium':String(plan||'—')}
function filtered(rows,inputId){
  const value=$(inputId)?.value?.trim().toLowerCase()||'';
  return value?rows.filter(row=>searchableText(row).includes(value)):rows;
}
function revokeAvailability(status,canWrite){
  if(!canWrite)return {disabled:true,titleKey:'protectedWriteLocked'};
  if(status==='revoked')return {disabled:true,titleKey:'grantAlreadyRevoked'};
  if(status==='expired')return {disabled:true,titleKey:'grantAlreadyExpired'};
  if(status!=='active')return {disabled:true,titleKey:'grantNotActive'};
  return {disabled:false,titleKey:'revoke'};
}
function renderFinanceRows(){
  const c=$('finance-list'),rows=filtered(state.financeRows,'finance-filter');
  makeTable(c,[tr('account'),tr('plan'),tr('status'),tr('created'),tr('expiresAt'),tr('grantIdentifier'),tr('actions')],rows,row=>{
    const action=elem('button',tr('revoke'),'secondary');action.type='button';
    const availability=revokeAvailability(row.status,state.finance?.financial_writes_enabled===true);
    action.disabled=availability.disabled;
    action.title=tr(availability.titleKey);
    action.addEventListener('click',()=>revokeGrant(row));
    return [textNode(row.email,{email:true}),grantPlan(row.plan_id),badge(row.status),fmtDate(row.created_at),
      fmtDate(row.expires_at),identifier(row.id),action];
  },$('finance-filter')?.value?.trim()?tr('noMatchingSearch'):tr('empty'));
}
function renderAuditRows(){
  const c=$('audit-content'),rows=filtered(state.auditRows,'audit-filter');
  makeTable(c,[tr('created'),tr('operation'),tr('result'),tr('account'),tr('plan'),tr('grantIdentifier'),tr('adminActor')],rows,row=>{
    const email=row.recipient_email||state.financeRows.find(g=>g.id===row.grant_id)?.email||null;
    return [fmtDate(row.created_at),tr(row.operation==='grant'?'operationGrant':'operationRevoke'),
      badge(row.changed?'changed':row.matched?'unchanged':'unmatched'),textNode(email??tr('unknownRecipient'),{email:!!email}),
      grantPlan(row.plan_id),identifier(row.grant_id),
      textNode(row.actor_email??row.actor_id??'—',{email:!!row.actor_email})];
  },$('audit-filter')?.value?.trim()?tr('noMatchingSearch'):tr('empty'));
}
async function loadFinance(){
  if(!state.authenticated)return;
  const c=$('finance-list');c.textContent=tr('loading');
  try{
    const d=await api('finance',{operation:'list',offset:state.financeOffset});
    if(!Array.isArray(d.rows)||typeof d.has_more!=='boolean')throw Error(tr('formatError'));
    state.financeRows=d.rows;state.hasMore=d.has_more;
    setText('metric-grants',state.financeOffset===0?String(d.rows.length)+(d.has_more?'+':''):String(d.rows.length));
    $('finance-prev').disabled=state.financeOffset===0;$('finance-next').disabled=!d.has_more;
    $('finance-page-index').textContent=String(state.financeOffset/50+1);
    renderFinanceRows();updateLastSync();
  }catch(e){empty(c,tr('failedRead'));showNotice(e.message||tr('failedRead'),true)}
}
async function loadAudit(){
  if(!state.authenticated)return;
  const c=$('audit-content');c.textContent=tr('loading');
  try{
    const d=await api('finance',{operation:'audit',offset:0});
    if(!Array.isArray(d.rows))throw Error(tr('formatError'));
    state.auditRows=d.rows;renderAuditRows();updateLastSync();
  }catch(e){empty(c,tr('failedRead'));showNotice(e.message||tr('failedRead'),true)}
}
function updateLastSync(){
  const el=$('last-synced');if(el)el.textContent=tr('recentUpdated')+': '+fmtDate(new Date().toISOString());
}
async function loadDashboardWorkload(){
  if(!state.authenticated)return;
  const checks=[
    ['metric-posts','review',{operation:'posts.queue',limit:25},v=>rowsOf(v?.receipt).length],
    ['metric-earn','review',{operation:'earn.queue'},v=>rowsOf(v?.receipt).length],
    ['metric-reports','ops',{operation:'moderation.reports.open'},v=>rowsOf(v?.receipt).length]
  ];
  const responses=await Promise.allSettled(checks.map(([,type,body])=>api(type,body)));
  responses.forEach((result,i)=>{
    const [metric,,,countRecords]=checks[i];
    if(result.status==='fulfilled')setText(metric,String(countRecords(result.value)));
    else setText(metric,'—');
  });
  updateLastSync();
}
async function loadModerators(){const c=$('moderator-content');c.textContent=tr('loading');try{const d=await api('ops',{operation:'moderators.list'});const rows=rowsOf(d.receipt);if(!Array.isArray(d.receipt)&&!Array.isArray(d.receipt?.rows))throw new Error(tr('formatError'));state.mods=rows;setText('metric-mods',String(rows.length));makeTable(c,[tr('account'),tr('created'),tr('status'),tr('actions')],rows,row=>{const action=elem('button',tr('remove'),'secondary');action.type='button';action.disabled=!state.ops?.writes_enabled||row.protected_administrator===true;action.addEventListener('click',()=>opsConfirm('moderators.remove',{user_id:row.user_id,confirm_user_id:row.user_id}));return[textNode(row.email,{email:true}),fmtDate(row.created_at),row.protected_administrator?tr('protectedModerator'):tr('regularModerator'),action]},tr('noModerators'))}catch(e){empty(c,tr('failedRead'));setText('metric-mods','—');showNotice(e.message||tr('failedRead'),true)}}
async function loadMembers(){const c=$('member-content');c.textContent=tr('loading');try{const d=await api('ops',{operation:'members.list'});const rows=rowsOf(d.receipt);if(!Array.isArray(d.receipt)&&!Array.isArray(d.receipt?.rows))throw new Error(tr('formatError'));state.members=rows;setText('metric-members',String(rows.length));makeTable(c,[tr('account'),tr('reason'),tr('created'),tr('actions')],rows,row=>{const action=elem('button',tr('reinstate'),'secondary');action.type='button';action.disabled=!state.ops?.writes_enabled;action.addEventListener('click',()=>opsConfirm('members.reinstate',{user_id:row.user_id,confirm_user_id:row.user_id}));return[textNode(row.email,{email:true}),String(row.reason??'—'),fmtDate(row.suspended_at),action]},tr('noSuspendedMembers'))}catch(e){empty(c,tr('failedRead'));setText('metric-members','—');showNotice(e.message||tr('failedRead'),true)}}
async function loadReviewPolicy(){
  try{const p=await api('review',{operation:'earn.policy'});const value=p?.receipt;
    if(!Number.isInteger(value?.tokens_per_approval)||!Number.isInteger(value?.max_rewarded_posts_per_owner_per_utc_day))throw Error('invalid_reward_policy');
    state.earnPolicy=value;
    const text=`${tr('earnAmount')}: ${value.tokens_per_approval} AI Tokens · ${tr('earnDailyCap')}: ${value.max_rewarded_posts_per_owner_per_utc_day} · ${tr('earnMaximum')}: ${value.max_daily_tokens}`;
    setText('earn-policy-summary',text);
  }catch(err){state.earnPolicy=null;setText('earn-policy-summary',tr('failedRead'));showNotice(err.message||tr('failedRead'),true)}
}
async function loadQueue(){
  if(!state.authenticated)return;
  const c=$('queue-content');c.textContent=tr('loading');
  const cases={posts:{type:'review',op:'posts.queue',args:{limit:12}},earn:{type:'review',op:'earn.queue',args:{}},
    reports:{type:'ops',op:'moderation.reports.open',args:{}},
    safety:{type:'ops',op:'moderation.safety.open',args:{}}};
  const current=state.queue;const q=cases[current];if(!q)return;
  try{
    const d=await api(q.type,{operation:q.op,...q.args});
    const rows=current==='posts'?d.receipt?.rows:rowsOf(d.receipt);
    if(!Array.isArray(rows))throw Error(tr('formatError'));
    if(current!==state.queue)return;
    state.queueRows=rows;
    if(current==='reports')setText('metric-reports',String(rows.length));
    renderRecords(c,rows,current);
    if(current==='earn'||current==='posts')await loadReviewPolicy();
  }catch(err){
    if(current!==state.queue)return;
    empty(c,`${tr('failedRead')} · ${err.message||tr('reviewReadFailure')}`);
    if(current==='reports')setText('metric-reports','—');
    showNotice(err.message||tr('reviewReadFailure'),true);
  }
}
async function reviewQueueRecord(queue,row,decision){
  if(!state.review?.moderation_writes_enabled){showNotice(tr('reviewBlocked'),true);return}
  const mediaRequired=queue==='posts'||queue==='earn';
  if(mediaRequired && (row.media_complete!==true||row.preview_error)){
    showNotice(tr('missingDetails'),true);return;
  }
  try{
    let body=null;
    if(queue==='posts'){
      const latest=await api('review',{operation:'posts.detail',post_id:row.post_id||row.id});
      if(latest.receipt?.revision!==row.revision||latest.receipt?.media_complete!==true){
        showNotice(tr('postContentChanged'),true);await loadQueue();return;
      }
      const confirmation=await showReviewDecision(row,decision);
      if(!confirmation)return;
      body={operation:'posts.review',post_id:row.post_id||row.id,confirm_post_id:row.post_id||row.id,
        expected_revision:row.revision,decision,reason:confirmation.reason,
        acknowledge_full_content:confirmation.acknowledged,operation_id:token()};
    }else if(queue==='earn'){
      const latest=await api('review',{operation:'earn.queue'});
      const selected=rowsOf(latest.receipt).find(x=>x.post_id===row.post_id);
      if(!selected||selected.revision!==row.revision){showNotice(tr('postContentChanged'),true);await loadQueue();return}
      const yes=await showReviewDecision(row,decision);
      if(!yes)return;
      if(decision==='earn-request')body={operation:'earn.request',post_id:row.post_id,confirm_post_id:row.post_id,expected_revision:row.revision};
      else body={operation:'earn.decide',request_id:row.request_id,confirm_request_id:row.request_id,
        approve:decision==='earn-approve',reason:yes.reason};
    }else if(queue==='reports'){
      const id=row.id;
      const source=row.target_kind==='comment'?'comment':'community';
      const record=await api('review',{operation:'reports.content',report_id:id,source});
      const rev=record?.receipt?.revision;
      if(!/^[0-9a-f]{64}$/i.test(rev||''))throw Error('missing_report_revision');
      const yes=await showReviewDecision(row,decision);
      if(!yes)return;
      body={operation:'reports.decide',report_id:id,confirm_report_id:id,source,
        expected_revision:rev,remove:decision==='remove',confirm_remove:decision==='remove',operation_id:token()};
    }else if(queue==='safety'){
      const yes=await showReviewDecision(row,decision);
      if(!yes)return;
      body={operation:'safety.decide',report_id:row.report_id,confirm_report_id:row.report_id,
        decision,operation_id:token()};
    }
    if(!body)return;
    const verified=await showStepUp();if(!verified)return;
    const result=await api('review',body);
    const receipt=result?.receipt;
    if(receipt==null)throw Error('invalid_review_receipt');
    if(queue==='posts'){
      if(receipt.decision!==decision||!Number.isInteger(receipt.tokens_granted))throw Error('invalid_post_receipt');
      const award=receipt.tokens_granted;
      showNotice(`${decision==='approved'?tr('decisionApproved'):tr('decisionRejected')} · ${tr('receiptTokens')}: ${award} AI Tokens${receipt.reward_reason==='daily_cap_reached'?' · '+tr('rewardCapped'):''}`);
    }else if(queue==='earn'){
      showNotice(`${tr('reviewOutcome')}: ${statusLabel(receipt.status)} · ${tr('receiptTokens')}: ${Number(receipt.tokens_granted??0)} AI Tokens`);
    }else showNotice(tr('completed'));
    await loadQueue();
  }catch(err){if(err.httpStatus===409)showNotice(tr('postContentChanged'),true);
    else showNotice(err.message||tr('failed'),true)}
}
async function showReviewDecision(row,decision){
  const dlg=$('review-confirm-modal');
  const info=$('review-confirm-text');info.replaceChildren();
  const fields=[
    [tr('chooseDecision'),decision.startsWith('earn')?tr('earn'):tr('moderatorReview')],
    [tr('postTitle'),row.title??tr('notProvided')],
    [tr('postBody'),row.body??tr('notProvided')],
    [tr('postPhotos'),String(row.media_count??0)],
    [row.author_email?tr('postAuthorEmail'):tr('reportEmail'),row.author_email??row.reporter_email??'—'],
    [tr('earnEligible'),tr('earnDescription')],
    [tr('noClaimOfDelivery'),tr('receiptExplanation')]
  ];
  for(const [k,v] of fields)info.append(displayDetail(k,v,{paragraph:k===tr('postBody')}));
  // These bilingual copies are server-defined post-review receipt templates.
  // The final amount can still be 0 after the author's daily cap; never promise delivery.
  const preview=decision==='approved'?[tr('approvedWithReward'),tr('approvedWithoutReward')]:
    decision==='rejected'?[tr('rejectedCopy')]:[];
  if(preview.length)info.append(displayDetail(tr('notificationPreview'),preview.join(' / '),{paragraph:true}));
  $('review-confirm-checkbox').checked=false;
  $('review-confirm-reason').value='';
  const needsReason=['rejected','earn-reject'].includes(decision);
  $('review-reason-container').hidden=!needsReason;
  $('review-confirm-reason').required=needsReason;
  dlg.hidden=false;
  return await new Promise(resolve=>{
    const cancel=$('review-confirm-cancel'),submit=$('review-confirm-accept');
    const finish=value=>{dlg.hidden=true;cancel.removeEventListener('click',onCancel);submit.removeEventListener('click',onSubmit);resolve(value)};
    const onCancel=()=>finish(null);
    const onSubmit=()=>{
      const acknowledged=$('review-confirm-checkbox').checked;
      const reason=$('review-confirm-reason').value.trim();
      if(!acknowledged){showNotice(tr('reviewAllAcknowledged'),true);return}
      if(needsReason && !reason){showNotice(tr('rejectionReason'),true);return}
      finish({acknowledged,reason});
    };
    cancel.addEventListener('click',onCancel);submit.addEventListener('click',onSubmit);
  });
}

async function refreshAll(){if(!state.authenticated)return;await Promise.allSettled([loadFinance(),loadModerators(),loadMembers(),loadQueue(),loadAudit(),loadDashboardWorkload()]);updateStatuses()}
async function statusRefresh(){
  const sources=['finance','ops','review'];
  const settled=await Promise.allSettled(sources.map(type=>api(type,{operation:'status'})));
  const failures=[];
  settled.forEach((result,i)=>{
    const type=sources[i];
    state[type]=result.status==='fulfilled'?result.value:{access:'unavailable',
      writes_enabled:false,moderation_writes_enabled:false,financial_writes_enabled:false};
    if(result.status==='rejected')failures.push(result.reason?.message||tr('unknownError'));
  });
  updateStatuses();
  if(state.authenticated)await refreshAll();
  if(failures.length)showNotice(`${tr('connectionPartial')} · ${failures[0]}`,true);
  else $('notice').hidden=true;
}
async function showStepUp(){return new Promise((resolve)=>{state.modalResolve=resolve;$('mfa-modal').hidden=false;$('step-up-code').value='';$('step-up-code').focus()})}
function resolveStepUp(ok){$('mfa-modal').hidden=true;$('step-up-code').value='';const cb=state.modalResolve;state.modalResolve=null;if(cb)cb(ok)}
async function confirmStepUp(){const code=$('step-up-code').value.trim();const btn=$('confirm-stepup');btn.disabled=true;try{state.factor=await findFactor();await verifyFactor(code);resolveStepUp(true)}catch(e){showNotice(e.message||tr('failed'),true)}finally{btn.disabled=false}}
function actionConfirmation(type,payload){
  const op=String(payload?.operation||'');
  if(type==='finance')return [tr(op==='grant'?'grantActionConfirm':'revokeActionConfirm'),
    payload?.email||payload?.grant_id||'',grantPlan(payload?.plan_id||''),
    payload?.duration_days?String(payload.duration_days)+' days':'',
    tr('stepUpDesc')].filter(Boolean).join('\n');
  const scope=payload?.email||payload?.user_id||payload?.audience||'';
  const consequence=op==='coach.reset.all'?'RESET ALL AI COACH ACCOUNTS':
    op==='notifications.send'&&payload?.audience==='all'&&payload?.kind!=='custom'?
      '2,500 AI TOKENS per recipient':op==='members.suspend'?'COMMUNITY ACCESS ONLY':op;
  return [tr('adminActionConfirm'),consequence,scope,
    payload?.message?payload.message:'',tr('stepUpDesc')].filter(Boolean).join('\n');
}
async function transaction(type,payload){
  if(!window.confirm(actionConfirmation(type,payload)))return null;
  const fresh=await showStepUp();if(!fresh)return null;return await api(type,payload)
}
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
  state.authenticated=false;state.finance=null;state.ops=null;state.review=null;state.user=null;
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
function closeSidebar(restoreFocus=false){
  const aside=$('sidebar');
  if(!aside.classList.contains('open'))return;
  aside.classList.remove('open');
  $('sidebar-scrim').hidden=true;
  $('mobile-menu').setAttribute('aria-expanded','false');
  document.body.classList.remove('admin-nav-open');
  if(restoreFocus)$('mobile-menu').focus({preventScroll:true});
}
function toggleSidebar(){
  const aside=$('sidebar');
  if(aside.classList.contains('open')){closeSidebar(true);return}
  if(document.activeElement?.matches?.('input,textarea,select'))document.activeElement.blur();
  aside.classList.add('open');
  $('sidebar-scrim').hidden=false;
  $('mobile-menu').setAttribute('aria-expanded','true');
  document.body.classList.add('admin-nav-open');
}
function setNavigation(){
  for(const b of document.querySelectorAll('[data-page]'))b.addEventListener('click',()=>{
    setPage(b.dataset.page);
    if(b.dataset.page==='audit'&&state.authenticated)loadAudit();
  });
  $('mobile-menu').addEventListener('click',toggleSidebar);
  $('sidebar-close').addEventListener('click',()=>closeSidebar(true));
  $('sidebar-scrim').addEventListener('click',()=>closeSidebar(true));
  document.addEventListener('keydown',event=>{
    if(event.key==='Escape' && $('sidebar').classList.contains('open')){
      event.preventDefault();closeSidebar(true);
    }
  });
  document.addEventListener('pointerdown',event=>{
    if($('sidebar').classList.contains('open') &&
       !$('sidebar').contains(event.target) &&
       !$('mobile-menu').contains(event.target))closeSidebar();
  },{capture:true});
  window.addEventListener('resize',()=>{
    if(window.innerWidth>850)closeSidebar();
  });
  for(const b of document.querySelectorAll('[data-queue]'))b.addEventListener('click',()=>{
    state.queue=b.dataset.queue;
    for(const btn of document.querySelectorAll('[data-queue]'))btn.classList.toggle('selected',btn===b);
    setText('queue-title',tr(state.queue));
    if(state.authenticated)loadQueue();
  });
  $('language').addEventListener('click',()=>{
    closeSidebar();
    state.language=state.language==='ar'?'en':'ar';translate();updateStatuses();
    if(state.authenticated){
      if(state.page==='finance')loadFinance();
      else if(state.page==='audit')loadAudit();
      else if(state.page==='moderators')loadModerators();
      else if(state.page==='members')loadMembers();
      else if(state.page==='moderation')previewRows($('queue-content'),state.queueRows,'id',state.queue);
    }
  });
}
function setEvents(){setNavigation();$('email-form').addEventListener('submit',emailOtp);$('otp-form').addEventListener('submit',verifyEmail);$('mfa-form').addEventListener('submit',verifyMfa);$('enroll-form').addEventListener('submit',verifyEnroll);$('back-email').addEventListener('click',()=>{$('otp-form').hidden=true;$('email-form').hidden=false});$('logout').addEventListener('click',async()=>{await sdk.auth.signOut();clearPrivateView();showNotice(tr('offline'))});$('grant-form').addEventListener('submit',grantForm);$('refresh-status').addEventListener('click',statusRefresh);$('refresh-finance').addEventListener('click',loadFinance);$('refresh-audit').addEventListener('click',loadAudit);$('refresh-mods').addEventListener('click',loadModerators);$('refresh-members').addEventListener('click',loadMembers);$('refresh-queue').addEventListener('click',loadQueue);$('finance-next').addEventListener('click',()=>{state.financeOffset+=50;loadFinance()});$('finance-prev').addEventListener('click',()=>{state.financeOffset=Math.max(0,state.financeOffset-50);loadFinance()});$('reconcile').addEventListener('click',reconcile);$('cancel-stepup').addEventListener('click',()=>resolveStepUp(false));$('confirm-stepup').addEventListener('click',confirmStepUp);makeOpsForm('moderator-form','moderators.add',f=>({email:String(f.get('email')).trim().toLowerCase(),confirm_email:String(f.get('confirm_email')).trim().toLowerCase()}));makeOpsForm('member-form','members.suspend',f=>({email:String(f.get('email')).trim().toLowerCase(),confirm_email:String(f.get('confirm_email')).trim().toLowerCase(),reason:String(f.get('reason')).trim()}));makeOpsForm('coach-individual-form','coach.reset.user',f=>({email:String(f.get('email')).trim().toLowerCase(),confirm_email:String(f.get('confirm_email')).trim().toLowerCase(),reason:String(f.get('reason')).trim(),message:String(f.get('message')).trim()}));makeOpsForm('coach-global-form','coach.reset.all',f=>({confirm_phrase:String(f.get('confirm_phrase')).trim(),message:String(f.get('message')).trim()}));makeOpsForm('notification-form','notifications.send',f=>({kind:String(f.get('kind')),audience:String(f.get('audience')),email:String(f.get('email')||'').trim().toLowerCase(),confirm_target:String(f.get('confirm_target')||'').trim(),message:String(f.get('message')||'').trim(),acknowledge_token_grant:f.get('acknowledge_token_grant')==='on',confirm_mass_grant:String(f.get('confirm_mass_grant')||'').trim()}));for(const name of ['kind','audience'])$('notification-form').elements.namedItem(name).addEventListener('change',updateNotificationHelp)}
$('ops-explain').addEventListener('click',()=>showNotice(tr('operatorModeActive')));
$('finance-filter').addEventListener('input',()=>{if(state.authenticated)renderFinanceRows()});
$('audit-filter').addEventListener('input',()=>{if(state.authenticated)renderAuditRows()});
for(const btn of document.querySelectorAll('[data-quick-nav]'))btn.addEventListener('click',()=>{
  const page=btn.dataset.quickNav;setPage(page);
  if(page==='moderation'&&state.authenticated){state.queue='posts';
    for(const q of document.querySelectorAll('[data-queue]'))q.classList.toggle('selected',q.dataset.queue==='posts');
    setText('queue-title',tr('posts'));loadQueue();}
  else if(page==='audit'&&state.authenticated)loadAudit();
});
setEvents();init();
