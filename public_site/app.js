const SUPABASE_URL = 'https://tgmanzhqulksykhslrzb.supabase.co';
const SUPABASE_KEY = 'sb_publishable_eMoUVfgwfU0RpQOwPJr-yw_ZgtStgld';
const SUPPORT_EMAIL = 'support@bilhealth.com';
const PRIVACY_EMAIL = 'privacy@bilhealth.com';
const ADMIN_EMAIL = 'bilhealth.app@gmail.com';

const ui = {
  en: {
    product: 'Product', privacy: 'Privacy', support: 'Support', health: 'Health', supportCta: 'Get support', language: 'العربية',
    updated: 'Last updated', date: '29 August 2026', official: 'Official BIL Health document', contents: 'On this page',
  },
  ar: {
    product: 'المنتج', privacy: 'الخصوصية', support: 'الدعم', health: 'الصحة', supportCta: 'احصل على الدعم', language: 'English',
    updated: 'آخر تحديث', date: '29 أغسطس 2026', official: 'وثيقة رسمية من BIL Health', contents: 'في هذه الصفحة',
  },
};

const home = {
  en: {
    eyebrow: 'Your body, made understandable',
    title: 'Turn daily signals into <span class="gradient-text">clear direction.</span>',
    lead: 'BIL brings nutrition, body trends, connected health, progress, and explainable AI coaching into one calm, intelligent experience.',
    primary: 'Explore privacy', secondary: 'Read the health promise',
    proofs: ['Local-first core', '25 interface languages', 'No health data used for ads'],
    cardTitle: 'Today’s intelligence', live: 'PRIVATE BY DESIGN', score: '72', scoreLabel: 'daily readiness',
    signals: [['Nutrition', 'On track'], ['Recovery', 'Stable'], ['Trend', '−0.4 kg']],
    insight: 'Your recent pattern is steady. Keep today simple: protein, hydration, and a consistent evening routine.',
    featuresEyebrow: 'ONE CONNECTED SYSTEM', featuresTitle: 'Less logging friction. More useful understanding.',
    featuresLead: 'Built around decisions people make every day—not dashboards that only collect numbers.',
    features: [
      ['◫', 'Effortless daily log', 'Track meals, water, weight, activity, and body context without losing the shape of your day.'],
      ['◎', 'Body trends', 'See calories, nutrients, weight, and wellness signals with honest empty, offline, and confidence states.'],
      ['✦', 'BIL AI Coach', 'Ask naturally in the language you speak. Remote AI is used only after consent and never executes actions without approval.'],
      ['⌁', 'Connected health', 'Import supported records only after platform permission, with clear source and connection status.'],
    ],
    trustTitle: 'Intelligence deserves restraint.',
    trust: ['Health data is never sold.', 'Free-tier ads never use health context.', 'AI answers are guidance, not diagnosis.', 'Cloud features remain off until consent.', 'Store prices come from Apple or Google.', 'Account deletion is available in-app and online.'],
    docsEyebrow: 'TRUST CENTER', docsTitle: 'Clear answers before you share anything.',
  },
  ar: {
    eyebrow: 'جسمك بصورة يمكنك فهمها',
    title: 'حوّل إشاراتك اليومية إلى <span class="gradient-text">اتجاه واضح.</span>',
    lead: 'يجمع BIL التغذية واتجاهات الجسم والصحة المتصلة والتقدم والمدرب الذكي القابل للتفسير في تجربة واحدة هادئة وذكية.',
    primary: 'استكشف الخصوصية', secondary: 'اقرأ التزامنا الصحي',
    proofs: ['الأساس يعمل محليًا', '25 لغة للواجهة', 'لا تُستخدم البيانات الصحية للإعلانات'],
    cardTitle: 'ذكاء اليوم', live: 'الخصوصية أولًا', score: '72', scoreLabel: 'الاستعداد اليومي',
    signals: [['التغذية', 'على المسار'], ['التعافي', 'مستقر'], ['الاتجاه', '−0.4 كجم']],
    insight: 'نمطك الأخير مستقر. اجعل اليوم بسيطًا: بروتين وماء وروتين مسائي منتظم.',
    featuresEyebrow: 'نظام واحد مترابط', featuresTitle: 'تسجيل أسهل. فهم أكثر فائدة.',
    featuresLead: 'مصمم حول القرارات التي تتخذها كل يوم، وليس حول لوحات تجمع الأرقام فقط.',
    features: [
      ['◫', 'يوميات بلا تعقيد', 'سجّل الطعام والماء والوزن والنشاط وسياق جسمك من دون أن تضيع صورة يومك.'],
      ['◎', 'اتجاهات الجسم', 'شاهد السعرات والمغذيات والوزن وإشارات العافية مع حالات صادقة للثقة وعدم الاتصال ونقص البيانات.'],
      ['✦', 'مدرب BIL الذكي', 'اسأل بطبيعتك وباللغة التي تتحدثها. لا يُستخدم الذكاء البعيد إلا بعد الموافقة ولا ينفذ إجراءً دون إذنك.'],
      ['⌁', 'الصحة المتصلة', 'استورد السجلات المدعومة فقط بعد إذن النظام، مع إظهار المصدر وحالة الاتصال بوضوح.'],
    ],
    trustTitle: 'الذكاء الحقيقي يعرف حدوده.',
    trust: ['لا نبيع البيانات الصحية.', 'إعلانات الخطة المجانية لا تستخدم السياق الصحي.', 'إجابات الذكاء إرشاد وليست تشخيصًا.', 'تبقى السحابة متوقفة حتى توافق.', 'الأسعار مصدرها Apple أو Google.', 'حذف الحساب متاح داخل التطبيق وعبر الويب.'],
    docsEyebrow: 'مركز الثقة', docsTitle: 'إجابات واضحة قبل أن تشارك أي شيء.',
  },
};

const docs = [
  ['/privacy', 'Privacy policy', 'What BIL collects, why, and the controls you have.', 'سياسة الخصوصية', 'ما الذي يجمعه BIL ولماذا وما هي خياراتك.'],
  ['/terms', 'Terms of use', 'Rules for accounts, AI, wellness, and services.', 'شروط الاستخدام', 'قواعد الحساب والذكاء والعافية والخدمات.'],
  ['/account-deletion', 'Account deletion', 'Delete an account and associated cloud data.', 'حذف الحساب', 'حذف الحساب والبيانات السحابية المرتبطة به.'],
  ['/data-deletion', 'Data choices', 'Clear local data, cloud records, and permissions.', 'خيارات البيانات', 'مسح البيانات المحلية والسحابية والأذونات.'],
  ['/subscription-terms', 'Subscriptions', 'Billing, renewal, cancellation, and restoration.', 'الاشتراكات', 'الدفع والتجديد والإلغاء والاستعادة.'],
  ['/health-disclaimer', 'Health disclaimer', 'The safe boundary of wellness and AI guidance.', 'إخلاء المسؤولية الصحي', 'الحد الآمن لإرشادات العافية والذكاء.'],
  ['/support', 'Support', 'Help with accounts, logging, devices, and purchases.', 'الدعم', 'مساعدة للحساب والتسجيل والأجهزة والمشتريات.'],
  ['/community-guidelines', 'Community guidelines', 'Safety, reporting, moderation, and acceptable conduct.', 'إرشادات المجتمع', 'السلامة والإبلاغ والإشراف والسلوك المقبول.'],
  ['/contact', 'Contact', 'Official support, privacy, and security channels.', 'تواصل معنا', 'قنوات الدعم والخصوصية والأمان الرسمية.'],
];

const legal = {
  en: {
    '/privacy': {
      eyebrow: 'TRUST CENTER', title: 'Privacy policy', intro: 'This policy explains how BIL Health handles personal information when you use Body Intelligence Log (BIL), its cloud features, AI tools, connected-health integrations, website, and support channels.',
      sections: [
        ['scope', 'Who is responsible', `<p>BIL Health is the product publisher and data controller for developer-operated services. Contact <a href="mailto:${PRIVACY_EMAIL}">${PRIVACY_EMAIL}</a> for privacy requests. Store operators, device platforms, and services you independently choose may act under their own privacy terms.</p>`],
        ['data', 'Information we process', '<ul><li><b>Account:</b> email address, optional display name, account identifier, and a phone number where the registration path you choose asks for one. Other sign-in options do not require a phone number. Supabase also processes authentication and security events, IP address, and user-agent metadata.</li><li><b>Health and wellness:</b> profile details, age range or date of birth, biological sex where supplied, dietary preferences, nutrition, meals, water, weight, measurements, activity, sleep, goals, and notes.</li><li><b>Connected sources:</b> records you authorize through HealthKit or Health Connect, plus readings from compatible external fitness devices. These records remain on the device or in the source platform by default.</li><li><b>Search:</b> after local food sources return no match, the food search text and locale can be sent through the signed-in account session to BIL’s trusted gateway and USDA. BIL does not retain a dedicated search-history record or use the text for advertising, but treats this authenticated processing as linked to the account for store privacy disclosure.</li><li><b>User and community content:</b> AI questions and recognized voice transcripts; meal-analysis images; a selected profile photo that can be uploaded and shown as your public Community avatar; Community profile/biography, post text, images and audience; access-controlled private messages; reports; food submissions, peer reviews and label/evidence images; feedback; and support requests. Community visibility follows the audience you choose. Private messages are stored with access controls but are not end-to-end encrypted.</li><li><b>Commerce and technical data:</b> store product, entitlement and receipt-verification results, a cloud-sync device identifier, product interactions, AI request/token/provider and latency records, language, app version, device platform, security diagnostics, and limited operational logs. Where contextual free-tier ads are available on supported Android builds, Google Mobile Ads may automatically process IP address (which can estimate general location), product interactions, diagnostics, and device or account identifiers for advertising delivery, analytics and fraud prevention. BIL does not receive your full payment-card number.</li></ul>'],
        ['collection', 'How data reaches BIL', '<p>Most information is entered by you or imported only after a platform permission. The local-first diary works without a cloud account. If a signed-in user enables cloud sync, the current selective sync scope is profile/body settings, weight, and hydration—not a general copy of every meal record. Remote AI is separate: only after you ask the AI Coach, BIL creates a bounded context for that answer, which can include dietary preferences and recent nutrition, weight, activity, sleep, or verified connected-health summaries. Image analysis, purchases, push notifications, community tools, and device connections likewise activate only when configured and requested.</p>'],
        ['facebook-login', 'Optional Facebook Login', '<p>If Facebook Login is available and you choose it, Meta authenticates you and may provide BIL and its authentication processor, Supabase, with an app-scoped Facebook user identifier and public-profile information returned by Meta, such as your name and profile picture. Your email address is received only when you grant the email permission and Meta makes it available. BIL requests only <b>public_profile</b> and <b>email</b> for this flow and uses the result only to create, sign in to, secure, or link your BIL account. BIL does not post to Facebook or use Facebook account data to personalize health, nutrition, AI, or advertising. You can disconnect the provider where available or delete the BIL account and associated eligible data through the in-app controls or the <a href="/account-deletion">Account deletion</a> page.</p>'],
        ['purpose', 'Why we use information', '<ul><li>Provide logging, goals, calculations, charts, reports, synchronization, restore, and support.</li><li>Personalize requested insights and AI Coach responses.</li><li>Authenticate accounts, protect the service, prevent abuse, and verify purchases.</li><li>Meet legal obligations and resolve disputes.</li></ul><p>Where law requires a legal basis, BIL relies on performance of the service you request, consent for optional sensitive features, legitimate interests in security and reliability, and legal obligations. You may withdraw consent without affecting earlier lawful processing.</p>'],
        ['ai', 'AI, voice, and photos', '<p>Remote AI is opt-in. Only the context needed for the requested answer is sent through BIL-controlled gateways to a configured model provider such as Google Gemini. Connected-health summaries are included only in a user-requested AI turn and only when the source is verified. Voice capture starts only after you press a microphone control. Apple or another platform speech service may process that initiated audio under its own terms and availability. BIL’s backend and Gemini receive the recognized transcript—not raw microphone audio—from the current app. Meal photos are sent only after you choose image analysis. AI can be wrong and must not be treated as medical advice.</p>'],
        ['sharing', 'Processors and disclosure', '<p>BIL may use Supabase for authentication, authenticated cloud storage, support records and server functions; Apple or Google for distribution, billing, speech and connected-fitness permissions; Google Gemini for requested remote AI processing; and Google Mobile Ads for contextual, non-personalized or limited ads where enabled on supported Android builds. Supabase service and authentication logs can include user ID, IP address, user agent, request/response metadata and operational diagnostics for security, abuse prevention and reliability. Ads are excluded for guests and paid users. Before any eligible registered adult Free-user ad request, Google UMP is the authoritative consent gate where required. Google Mobile Ads must never receive BIL health, nutrition, weight, profile, search, precise-location, private-community, or AI-conversation content from BIL for targeting. Health data is not sold, shared with data brokers, or used to target ads. We may disclose limited information when legally required or to protect users and the service.</p>'],
        ['website', 'Website storage and edge delivery', '<p>The public BIL website stores only your language choice in browser local storage. It does not currently set BIL marketing cookies or load a BIL web-analytics beacon. Cloudflare delivers and protects the public site and may process IP address, user agent, requested URL and time, network/security signals, and operational diagnostics under its role and retention terms. The public website does not read the private diary or connected-health data from the BIL app.</p>'],
        ['retention', 'Retention and deletion', '<p>Local records remain until you delete them or the app data. Cloud records remain while your account and the related feature are active, then are deleted or de-identified according to the deletion workflow, backups, fraud-prevention needs, and legal retention duties. AI usage, performance and operational logs are minimized and retained under service-security and quota requirements. Store transaction records may remain with Apple or Google under their rules.</p>'],
        ['rights', 'Your choices and rights', `<ul><li>Use core local logging without creating an account.</li><li>Enable or disable remote AI, cloud synchronization, notifications, device access, camera, microphone, and connected-health permissions.</li><li>Access, correct, export, or delete eligible information in the app.</li><li>Initiate full account deletion at <a href="/account-deletion">Account deletion</a>.</li><li>Object, restrict processing, withdraw consent, or lodge a complaint with your local data-protection authority where applicable.</li></ul><p>Email <a href="mailto:${PRIVACY_EMAIL}">${PRIVACY_EMAIL}</a> from your account address so BIL can verify the request without asking you to send raw health exports.</p>`],
        ['security', 'Security and international processing', '<p>BIL uses encrypted transport, platform-protected credentials, access controls, row-level authorization, redacted app diagnostics, and verified server boundaries. Supabase infrastructure still records the limited authentication, IP, user-agent and request diagnostics described above. No system is perfectly secure. Cloud providers may process data in countries outside yours under contractual and legal safeguards appropriate to the service.</p>'],
        ['children', 'Adults only and changes', '<p>BIL is intended only for adults aged 18 or older and is not directed to children or minors. People under 18 must not create or use a BIL account or its local services. Material policy changes will be posted here with a new effective date and, when appropriate, surfaced in the app.</p>'],
      ],
    },
    '/terms': {
      eyebrow: 'LEGAL', title: 'Terms of use', intro: 'These terms govern access to BIL. By using the app or website, you agree to use the service responsibly and within the health and safety boundaries below.',
      sections: [
        ['eligibility', 'Eligibility and accounts', '<p>You must be at least 18 years old and provide accurate account information. People under 18 may not use BIL, including local-only features. Keep credentials confidential and notify BIL if you believe your account is compromised. Core local features may work without an account; cloud and purchase features require authentication.</p>'],
        ['wellness', 'Wellness—not medical care', '<p>BIL is for general wellness, self-tracking, education, and organization. It is not a medical device, clinician, emergency service, diagnosis, treatment, cure, or prevention tool. Do not delay professional care because of BIL. Call local emergency services for urgent symptoms.</p>'],
        ['ai', 'AI and calculated information', '<p>AI responses, calorie estimates, nutrient matches, trend explanations, and connected-device readings may be incomplete or wrong. Confidence indicators are not guarantees. Review inputs and outputs, use qualified professionals for medical decisions, and never rely on BIL to dose medicine or manage an emergency.</p>'],
        ['conduct', 'Acceptable use', '<p>Do not misuse the service, bypass access controls, probe other accounts, upload unlawful or harmful content, impersonate others, automate abusive traffic, reverse engineer protected services where prohibited, or use BIL to make high-impact decisions about another person without lawful authority.</p>'],
        ['content', 'Your content', '<p>You keep ownership of content you submit. You give BIL the limited permission needed to store, process, transmit, display, and moderate it solely to provide and protect the features you request. Do not submit content you lack rights or permission to use.</p>'],
        ['subscriptions', 'Subscriptions and stores', '<p>Paid access is sold through Apple App Store or Google Play. The store displays the controlling price, currency, tax, billing period, trial if any, renewal, and cancellation terms. Subscriptions renew unless cancelled through the store. See <a href="/subscription-terms">Subscription terms</a>.</p>'],
        ['availability', 'Availability and changes', '<p>Features may vary by country, platform, device, plan, consent, store availability, and verified configuration. BIL may improve, suspend, or retire features while protecting paid entitlements as required by law and store policy. External services can be unavailable.</p>'],
        ['liability', 'Disclaimers and responsibility', '<p>To the extent permitted by law, BIL is provided “as is” without guarantees of uninterrupted availability or health outcomes. Nothing in these terms excludes rights or liability that cannot legally be excluded. You remain responsible for decisions made from your data and for keeping independent copies of information you need.</p>'],
        ['termination', 'Ending use and contact', `<p>You may stop using BIL, cancel a store subscription, clear data, or request account deletion. BIL may restrict accounts that materially violate these terms, subject to applicable notice and appeal rights. Questions: <a href="mailto:${SUPPORT_EMAIL}">${SUPPORT_EMAIL}</a>.</p>`],
      ],
    },
    '/account-deletion': {
      eyebrow: 'YOUR CONTROL', title: 'Delete your BIL account', intro: 'You can initiate deletion inside BIL or request it online. Deleting the app alone does not delete a cloud account.',
      sections: [
        ['in-app', 'Fastest: request deletion in the app', '<ol><li>Sign in to the BIL account you want to delete.</li><li>Open <b>More → Delete account</b>.</li><li>Review the consequences, type <b>DELETE</b>, and submit.</li><li>Keep the request reference shown by BIL.</li></ol>'],
        ['web', 'If you cannot access the app', `<p>Email <a href="mailto:${PRIVACY_EMAIL}?subject=BIL%20account%20deletion%20request">${PRIVACY_EMAIL}</a> from the email address linked to the account. State “Delete my BIL account.” Do not send passwords, access tokens, receipts, identity documents, or health exports. BIL will ask only for the minimum information needed to verify control.</p>`],
        ['scope', 'What deletion covers', '<p>After verification, BIL deletes or de-identifies eligible account profile, cloud-synchronized health and wellness records, AI conversation records retained by BIL, community content where legally and technically applicable, notification registrations, and active server entitlements. Local data must be cleared on each device or by removing app data.</p>'],
        ['not-covered', 'What is not controlled by BIL', '<p>Deleting BIL does not delete source records in HealthKit, Health Connect, another health app, a paired device, your email provider, or Apple/Google purchase history. Revoke those permissions or manage those records with the relevant provider.</p>'],
        ['retention', 'Verification, retention, and status', '<p>Deletion runs immediately when the secure worker is available; otherwise BIL keeps the request reference and retries the queued request within 15 minutes. The app confirms the completed state, and support can investigate a request that remains pending. BIL may retain the minimum records required for security, fraud prevention, transaction disputes, tax, or other law, then delete them when the obligation ends. Backups age out under controlled retention. BIL will not keep data merely to avoid deletion.</p>'],
        ['subscriptions', 'Cancel billing separately', '<p>Account deletion does not automatically cancel a subscription managed by Apple or Google, so billing can continue after the BIL account is gone. Cancel it first through <a href="https://apps.apple.com/account/subscriptions">Apple subscription management</a> or <a href="https://play.google.com/store/account/subscriptions">Google Play subscription management</a>. You may also use Restore Purchases before deletion if you need to confirm the account being removed.</p>'],
      ],
    },
    '/data-deletion': {
      eyebrow: 'YOUR DATA', title: 'Data deletion and privacy choices', intro: 'Choose the narrowest action that matches what you want: clear local records, disconnect a source, delete cloud data, or delete the full account.',
      sections: [
        ['local', 'Local device data', '<p>Use BIL Settings and diary controls to remove entries or clear local app data. Removing the app or clearing its storage removes local records from that device, subject to operating-system backups you control.</p>'],
        ['cloud', 'Cloud-synchronized data', '<p>Turn off cloud synchronization to stop future sync. Request deletion of eligible synced records through the in-app privacy controls. A full account deletion request covers associated cloud data as described on the Account deletion page.</p>'],
        ['health', 'HealthKit, Health Connect, and devices', '<p>Disconnect the integration in BIL and revoke permission in system settings. Source records remain in the source platform unless you delete them there. BIL cannot delete data owned by another app or hardware provider.</p>'],
        ['ai', 'AI, voice, and photos', '<p>Disable remote AI consent to stop new requests. Delete supported conversation history in BIL. Voice and meal-photo processing occurs only after your action; provider retention is governed by BIL configuration and the processor agreement.</p>'],
        ['ads', 'Advertising choices', '<p>Paid plans do not display ads. Free-tier ads, when production configuration and required consent are present, are contextual/non-personalized and must not receive health records, diary content, AI prompts, or body measurements.</p>'],
        ['request', 'Request help', `<p>Email <a href="mailto:${PRIVACY_EMAIL}">${PRIVACY_EMAIL}</a> from your account email. Describe the category you want removed, but never attach sensitive exports. BIL will verify the request and explain any lawful limitation.</p>`],
      ],
    },
    '/subscription-terms': {
      eyebrow: 'COMMERCE', title: 'Subscription terms', intro: 'BIL displays only plans and prices returned by the user’s verified Apple or Google storefront. Website text does not override the store checkout screen.',
      sections: [
        ['plans', 'Plans and regional availability', '<p>BIL may offer Free, BIL Premium, BIL Premium AI Coach, and BIL AI Boost. Availability differs by country and storefront economics. In some regions AI usage is offered through token-based Boost rather than an AI-inclusive subscription.</p>'],
        ['billing', 'Billing and renewal', '<p>The store shows the final localized price, currency, tax, billing interval, and any introductory offer before confirmation. Auto-renewable subscriptions renew unless cancelled at least as required by the store. BIL does not independently charge a card.</p>'],
        ['ai', 'AI allowances and Boost', '<p>AI-inclusive plans may have documented weekly and monthly token allowances. AI Boost is a separate consumable or non-expiring balance only where the store and server verify it. An unanswered or rejected request must not be represented as a paid AI response.</p>'],
        ['cancel', 'Cancellation and refunds', '<p>Manage or cancel through Apple App Store or Google Play using the same store account used to purchase. Cancellation normally stops future renewal while access continues through the paid period. Refund eligibility and processing follow store policy and applicable law.</p>'],
        ['restore', 'Restore purchases', '<p>Use Restore Purchases on the BIL plans screen. BIL checks the store and its server entitlement record; it does not unlock access from an unverified local flag. Sign in to the same store and BIL account used for the purchase.</p>'],
        ['changes', 'Price or plan changes', '<p>Stores provide legally required notice and consent for price changes. Feature packaging can change prospectively, but BIL will not fabricate a discount, trial, tax, or “success” state that the store has not verified.</p>'],
        ['support', 'Billing support', `<p>For store charges or refunds, start with Apple or Google. For an entitlement mismatch, contact <a href="mailto:${SUPPORT_EMAIL}">${SUPPORT_EMAIL}</a> and include the platform and approximate purchase time—but never email a full receipt token or password.</p>`],
      ],
    },
    '/health-disclaimer': {
      eyebrow: 'SAFETY FIRST', title: 'Health disclaimer', intro: 'BIL supports general wellness and self-understanding. It does not replace a qualified health professional or emergency service.',
      sections: [
        ['not-medical', 'Not a medical device', '<p>BIL does not diagnose, treat, cure, prevent, or monitor disease as a regulated medical device. Labels such as Body Intelligence, readiness, trend, confidence, or AI Coach describe wellness features, not clinical conclusions.</p>'],
        ['emergency', 'Not for emergencies', '<p>Do not use BIL for urgent symptoms, medication dosing, urgent health emergencies, eating-disorder crisis care, pregnancy complications, or decisions requiring clinical judgment. Contact local emergency services or a qualified professional.</p>'],
        ['estimates', 'Estimates and data quality', '<p>Calories, nutrients, portions, goals, trends, AI answers, device readings, and imported records can be delayed, incomplete, mismatched, or wrong. Check the source, unit, time, serving, and confidence before acting.</p>'],
        ['devices', 'Connected fitness devices', '<p>BIL displays supported fitness records from phones, platform fitness stores, watches, scales, and compatible Bluetooth fitness devices only after permission and connection. BIL does not provide medical-device interfaces and does not guarantee hardware accuracy or compatibility. Follow the device manufacturer’s instructions.</p>'],
        ['nutrition', 'Nutrition, fasting, and exercise', '<p>Needs vary with age, body, health conditions, pregnancy, medication, environment, and training. Consult a qualified professional before restrictive diets, fasting, rapid weight change, or intense exercise when these factors apply.</p>'],
        ['ai', 'AI Coach boundary', '<p>AI may misunderstand language, context, or evidence. It may provide general education and help organize your own plan, but it must not be treated as a clinician and does not execute actions without your approval.</p>'],
        ['professional', 'When to seek professional help', '<p>Seek qualified care for symptoms, diagnosis, treatment, mental-health concerns, disordered eating, or uncertainty about what is safe. Bring source measurements and records—not only a BIL summary—to your appointment.</p>'],
      ],
    },
    '/support': {
      eyebrow: 'WE ARE HERE', title: 'Support', intro: 'Get help with account access, privacy, food logging, subscriptions, connected health, AI Coach, and accessibility.',
      sections: [
        ['contact', 'Contact support', `<p>Email <a href="mailto:${SUPPORT_EMAIL}">${SUPPORT_EMAIL}</a>. Include your platform, app version, language, and a concise description. Never send a password, one-time code, access token, full purchase token, identity document, or raw health export.</p>`],
        ['account', 'Account and sign-in', '<p>Use the in-app password reset flow and the same verified email used to create the account. If a reset link is expired, request a new one and use only the newest message.</p>'],
        ['purchase', 'Purchases and restore', '<p>Confirm you are signed into the same Apple or Google store account, then open BIL Plans and choose Restore Purchases. Store product prices are unavailable on emulators that do not provide real storefront metadata.</p>'],
        ['health', 'Connected health and devices', '<p>Check system permission, Bluetooth state, device compatibility, and the source shown in BIL. BIL never claims a device is connected when the platform has not verified it.</p>'],
        ['privacy', 'Privacy, export, and deletion', `<p>Use in-app privacy controls for consent, synchronization, export, and deletion. For a verified request, email <a href="mailto:${PRIVACY_EMAIL}">${PRIVACY_EMAIL}</a> from the account address.</p>`],
        ['safety', 'Security and community safety', `<p>Report suspected account compromise, harmful content, or a security issue to <a href="mailto:${ADMIN_EMAIL}">${ADMIN_EMAIL}</a>. Do not test against other users or include real health data in a vulnerability report.</p>`],
      ],
    },
    '/community-guidelines': {
      eyebrow: 'COMMUNITY SAFETY', title: 'Community guidelines', intro: 'BIL community spaces are for respectful, adult wellness support. These rules explain what is allowed, how to report harm, and how BIL moderates user-generated content.',
      sections: [
        ['adults', 'Adults only', '<p>BIL and its community features are for people aged 18 or older. Do not create an account for a minor, solicit contact with minors, or post content that depicts or sexualizes minors.</p>'],
        ['respect', 'Respect and safety', '<p>Do not harass, threaten, shame, stalk, discriminate, impersonate, exploit, or disclose another person’s private information. Never encourage self-harm, eating-disorder behavior, dangerous restriction, unsafe exercise, violence, or illegal activity.</p>'],
        ['wellness', 'Wellness—not medical treatment', '<p>Community posts are personal experiences, not diagnosis or treatment. Do not claim guaranteed cures, prescribe medication, market unapproved medical products, or tell someone to ignore qualified care or emergency services.</p>'],
        ['content', 'Content you may share', '<p>Share only content you created or have permission to use. Do not post spam, scams, deceptive promotions, malware, explicit sexual content, graphic violence, copyrighted material without authorization, or health records and identifiers belonging to another person.</p>'],
        ['report', 'Report, block, and urgent risk', `<p>Use in-app report and block controls when available, or email <a href="mailto:${SUPPORT_EMAIL}">${SUPPORT_EMAIL}</a> with the account or post reference and a concise explanation. Do not send passwords, verification codes, or raw health exports. For immediate danger, contact local emergency services; BIL is not an emergency channel.</p>`],
        ['moderation', 'Moderation and enforcement', '<p>BIL may limit visibility, remove content, suspend features, or restrict accounts when reasonably necessary to enforce these rules, protect users, comply with law, or investigate abuse. Context, severity, repetition, and credible risk are considered. Where appropriate, users may request review through support.</p>'],
        ['privacy', 'Privacy and contact', `<p>Community content may be visible to the audience selected in the app. Avoid sharing information that can identify or locate you or another person. Privacy or deletion requests may be sent to <a href="mailto:${PRIVACY_EMAIL}">${PRIVACY_EMAIL}</a>.</p>`],
      ],
    },
    '/contact': {
      eyebrow: 'CONTACT', title: 'Contact BIL Health', intro: 'Use the channel that matches your request so it reaches the right review path.',
      sections: [
        ['support', 'Product support', `<p><a href="mailto:${SUPPORT_EMAIL}">${SUPPORT_EMAIL}</a> — sign-in, logging, purchases, connected health, AI Coach, accessibility, and general questions.</p>`],
        ['privacy', 'Privacy and deletion', `<p><a href="mailto:${PRIVACY_EMAIL}">${PRIVACY_EMAIL}</a> — access, correction, export, consent, objection, restriction, data deletion, and account deletion.</p>`],
        ['admin', 'Administration and security', `<p><a href="mailto:${ADMIN_EMAIL}">${ADMIN_EMAIL}</a> — official administration and responsible security reports. The bilhealth.com aliases receive inbound mail; use the Gmail address if an alias delivery fails.</p>`],
        ['safe', 'Send information safely', '<p>State your app version, platform, language, and a brief issue description. Never email passwords, verification codes, access tokens, private keys, full receipts, government IDs, or complete health exports.</p>'],
      ],
    },
  },
};

legal.ar = {
  '/privacy': { eyebrow: 'مركز الثقة', title: 'سياسة الخصوصية', intro: 'توضح هذه السياسة كيف تتعامل BIL Health مع المعلومات الشخصية عند استخدام تطبيق BIL وميزاته السحابية والذكاء الاصطناعي والصحة المتصلة والموقع والدعم.', sections: [
    ['scope','من المسؤول',`<p>BIL Health هي ناشر المنتج والمسؤول عن الخدمات التي يديرها المطور. لطلبات الخصوصية تواصل عبر <a href="mailto:${PRIVACY_EMAIL}">${PRIVACY_EMAIL}</a>. تخضع المتاجر ومنصات الأجهزة والخدمات التي تختارها لشروطها الخاصة أيضًا.</p>`],
    ['data','البيانات التي نعالجها','<ul><li><b>الحساب:</b> البريد الإلكتروني والاسم الاختياري ومعرّف الحساب، ورقم الهاتف عندما يطلبه مسار التسجيل الذي اخترته. لا تتطلب خيارات الدخول الأخرى رقم هاتف. يعالج Supabase أيضًا أحداث المصادقة والأمان وعنوان IP وبيانات وكيل المستخدم.</li><li><b>الصحة والعافية:</b> الملف الشخصي والعمر أو تاريخ الميلاد والجنس البيولوجي عند إدخاله والتفضيلات الغذائية والتغذية والوجبات والماء والوزن والقياسات والنشاط والنوم والأهداف والملاحظات.</li><li><b>المصادر المتصلة:</b> السجلات التي تسمح بها من HealthKit أو Health Connect وقراءات أجهزة اللياقة الخارجية المتوافقة. تبقى هذه السجلات على الجهاز أو في منصة المصدر افتراضيًا.</li><li><b>البحث:</b> بعد عدم وجود نتيجة في المصادر المحلية، قد يُرسل نص بحث الطعام واللغة عبر جلسة الحساب المسجلة إلى بوابة BIL الموثوقة وUSDA. لا يحتفظ BIL بسجل بحث مخصص ولا يستخدم النص للإعلانات، لكنه يعامل هذه المعالجة الموثقة على أنها مرتبطة بالحساب في إفصاح خصوصية المتجر.</li><li><b>محتوى المستخدم والمجتمع:</b> أسئلة الذكاء والنصوص المتعرّف عليها من الصوت؛ صور تحليل الوجبات؛ صورة الملف التي قد تُرفع وتظهر علنًا كصورة مجتمع؛ ملف المجتمع ونبذته ونصوص المنشورات وصورها وجمهورها؛ الرسائل الخاصة المقيدة بالوصول؛ البلاغات؛ مساهمات الطعام والمراجعات وصور الملصقات أو الأدلة؛ الملاحظات؛ وطلبات الدعم. تتبع رؤية محتوى المجتمع الجمهور الذي تختاره. تُخزّن الرسائل الخاصة بضوابط وصول لكنها ليست مشفرة من طرف إلى طرف.</li><li><b>التجارة والتقنية:</b> المنتج والاستحقاق ونتيجة التحقق من الشراء ومعرّف جهاز للمزامنة وتفاعلات المنتج وسجلات طلبات الذكاء والتوكنات والمزود وزمن الاستجابة واللغة وإصدار التطبيق والمنصة وتشخيصات الأمان وسجلات تشغيل محدودة. حيث تتوفر إعلانات الفئة المجانية على إصدارات Android المدعومة، قد تعالج Google Mobile Ads تلقائيًا عنوان IP الذي يمكن أن يقدّر الموقع العام وتفاعلات المنتج والتشخيصات ومعرّفات الجهاز أو الحساب لتوصيل الإعلان والتحليلات ومنع الاحتيال. لا يستلم BIL رقم بطاقتك الكامل.</li></ul>'],
    ['collection','كيف تصل البيانات','<p>تأتي معظم البيانات منك أو بعد إذن واضح من النظام. تعمل اليوميات الأساسية محليًا دون حساب. إذا فعّل مستخدم مسجل المزامنة السحابية، فإن نطاقها الحالي يقتصر على إعدادات الملف والجسم والوزن والماء، وليس نسخة عامة من كل سجل وجبة. سياق الذكاء منفصل: فقط بعد أن تطلب إجابة من المدرب ينشئ BIL سياقًا محدودًا قد يتضمن التفضيلات الغذائية وملخصات حديثة للتغذية والوزن والنشاط والنوم أو الصحة المتصلة الموثقة. ولا تعمل الصور والمشتريات والإشعارات والمجتمع والأجهزة إلا عند تهيئتها وطلبها.</p>'],
    ['facebook-login','تسجيل الدخول الاختياري عبر Facebook','<p>إذا كان تسجيل الدخول عبر Facebook متاحًا واخترت استخدامه، تتحقق Meta من هويتك وقد تزود BIL ومعالج المصادقة لديه Supabase بمعرّف Facebook خاص بالتطبيق ومعلومات الملف العام التي تعيدها Meta، مثل الاسم وصورة الملف. لا يصل البريد الإلكتروني إلا إذا منحت إذن <b>email</b> وكان متاحًا لدى Meta. يطلب BIL في هذا المسار فقط <b>public_profile</b> و<b>email</b>، ويستخدم النتيجة فقط لإنشاء حساب BIL أو تسجيل الدخول إليه أو حمايته أو ربطه. لا ينشر BIL على Facebook ولا يستخدم بيانات حساب Facebook لتخصيص الصحة أو التغذية أو الذكاء الاصطناعي أو الإعلانات. يمكنك فصل المزود حيث تتوفر هذه الإمكانية، أو حذف حساب BIL وبياناته المؤهلة من أدوات التطبيق أو <a href="/account-deletion?lang=ar">صفحة حذف الحساب</a>.</p>'],
    ['purpose','لماذا نستخدمها','<ul><li>لتقديم التسجيل والأهداف والحسابات والرسوم والتقارير والمزامنة والاستعادة والدعم.</li><li>لتخصيص الرؤى وإجابات المدرب التي تطلبها.</li><li>لحماية الحساب ومنع إساءة الاستخدام والتحقق من المشتريات.</li><li>للوفاء بالالتزامات القانونية وحل النزاعات.</li></ul><p>عند لزوم أساس قانوني نعتمد على تنفيذ الخدمة المطلوبة، وموافقتك للميزات الحساسة الاختيارية، والمصلحة المشروعة في الأمان والموثوقية، والالتزام القانوني.</p>'],
    ['ai','الذكاء والصوت والصور','<p>الذكاء البعيد اختياري. يُرسل فقط السياق اللازم للإجابة المطلوبة عبر بوابات BIL إلى مزود مهيأ مثل Google Gemini. لا تدخل ملخصات الصحة المتصلة إلا في طلب ذكاء بدأه المستخدم ومن مصدر موثق. يبدأ التقاط الصوت فقط بعد ضغطك على أداة الميكروفون. قد تعالج خدمة التعرف على الكلام لدى Apple أو المنصة الصوت الذي بدأتَه وفق شروطها وتوفرها. يستلم خادم BIL وGemini في التطبيق الحالي النص المتعرّف عليه، وليس صوت الميكروفون الخام. لا تُرسل صورة الوجبة إلا بعد اختيار التحليل. قد يخطئ الذكاء ولا يُعد نصيحة طبية.</p>'],
    ['sharing','المعالجون والمشاركة','<p>قد يستخدم BIL: Supabase للمصادقة والتخزين السحابي وطلبات الدعم ووظائف الخادم، وApple أو Google للتوزيع والدفع والكلام وأذونات اللياقة المتصلة، وGoogle Gemini لطلبات الذكاء، وGoogle Mobile Ads لإعلانات سياقية غير مخصصة أو محدودة حيث تُفعّل على إصدارات Android المدعومة. قد تتضمن سجلات Supabase للمصادقة والخدمة معرّف المستخدم وعنوان IP ووكيل المستخدم وبيانات الطلب والاستجابة وتشخيصات التشغيل للأمان ومنع الإساءة والموثوقية. لا تظهر الإعلانات للضيف أو للمستخدم المدفوع، وتكون Google UMP بوابة الموافقة حيث يلزم. لا يجوز أن تتلقى Google Mobile Ads محتوى الصحة أو التغذية أو الوزن أو الملف أو البحث أو الموقع الدقيق أو المجتمع الخاص أو محادثات الذكاء من BIL للاستهداف. لا تُباع البيانات الصحية ولا تُستخدم لاستهداف الإعلانات.</p>'],
    ['website','تخزين الموقع والتوصيل الطرفي','<p>يخزن موقع BIL العام اختيار اللغة فقط في التخزين المحلي للمتصفح. لا يضع حاليًا ملفات تعريف ارتباط تسويقية من BIL ولا يحمّل أداة تحليلات ويب من BIL. يوصّل Cloudflare الموقع ويحميه وقد يعالج عنوان IP ووكيل المستخدم والرابط المطلوب ووقته وإشارات الشبكة والأمان وتشخيصات التشغيل وفق دوره ومدد الاحتفاظ لديه. لا يقرأ الموقع العام اليوميات الخاصة أو بيانات الصحة المتصلة من تطبيق BIL.</p>'],
    ['retention','الاحتفاظ والحذف','<p>تبقى البيانات المحلية حتى تحذفها. تبقى السجلات السحابية أثناء نشاط الحساب والميزة، ثم تُحذف أو تُزال هويتها وفق مسار الحذف والنسخ الاحتياطية ومتطلبات الأمان والقانون. تُقلّل سجلات استخدام الذكاء والأداء والتشغيل ويُحتفظ بها وفق متطلبات أمان الخدمة والحصص. قد يحتفظ Apple أو Google بسجلات المتجر وفق سياساتهما.</p>'],
    ['rights','حقوقك وخياراتك',`<ul><li>استخدام التسجيل المحلي دون حساب.</li><li>تشغيل أو إيقاف الذكاء والمزامنة والإشعارات والأجهزة والكاميرا والميكروفون والأذونات الصحية.</li><li>الوصول والتصحيح والتصدير وحذف البيانات المؤهلة.</li><li>بدء حذف الحساب من <a href="/account-deletion?lang=ar">صفحة حذف الحساب</a>.</li><li>سحب الموافقة أو الاعتراض أو التقييد والشكوى للجهة المختصة حيث ينطبق القانون.</li></ul><p>راسل <a href="mailto:${PRIVACY_EMAIL}">${PRIVACY_EMAIL}</a> من بريد الحساب، ولا ترسل ملفًا صحيًا كاملًا.</p>`],
    ['security','الأمان والمعالجة الدولية','<p>نستخدم اتصالًا مشفرًا وحماية مفاتيح النظام وضوابط وصول وعزل صفوف البيانات وتشخيصات تطبيق منقحة وحدود خادم موثقة. وتبقى بنية Supabase تسجل بيانات المصادقة وIP ووكيل المستخدم وتشخيصات الطلب المحدودة الموضحة أعلاه. لا يوجد نظام آمن بالكامل. قد يعالج المزودون البيانات خارج بلدك وفق ضمانات تعاقدية وقانونية مناسبة.</p>'],
    ['children','للبالغين فقط والتغييرات','<p>التطبيق مخصص فقط للبالغين بعمر 18 عامًا فأكثر، وليس موجهًا للأطفال أو القاصرين. لا يجوز لمن هم دون 18 عامًا إنشاء حساب BIL أو استخدام خدماته المحلية. ننشر التغييرات الجوهرية هنا بتاريخ سريان جديد ونظهرها داخل التطبيق عند الحاجة.</p>'],
  ]},
  '/terms': { eyebrow: 'قانوني', title: 'شروط الاستخدام', intro: 'تنظم هذه الشروط استخدام BIL. باستخدام التطبيق أو الموقع توافق على الاستخدام المسؤول ضمن حدود الصحة والأمان التالية.', sections: [
    ['eligibility','الأهلية والحساب','<p>يجب أن يكون عمرك 18 عامًا على الأقل وأن تقدم معلومات صحيحة. لا يجوز لمن هم دون 18 عامًا استخدام BIL، بما في ذلك الميزات المحلية. يجب حماية بيانات الدخول. تعمل بعض الميزات محليًا دون حساب، بينما تتطلب السحابة والمشتريات تسجيل الدخول.</p>'],
    ['wellness','عافية وليست رعاية طبية','<p>BIL للتوعية والتنظيم والتتبع العام. ليس جهازًا طبيًا أو طبيبًا أو خدمة طوارئ ولا يشخص أو يعالج أو يمنع المرض. لا تؤخر الرعاية المهنية بسببه.</p>'],
    ['ai','الذكاء والحسابات','<p>قد تخطئ إجابات الذكاء وتقديرات السعرات والمغذيات والاتجاهات والأجهزة. راجع المصدر والوحدة والحصة والثقة، ولا تستخدم BIL لجرعات الدواء أو الطوارئ.</p>'],
    ['conduct','الاستخدام المقبول','<p>يُمنع تجاوز الحماية أو الوصول لحسابات الآخرين أو رفع محتوى غير قانوني أو انتحال الآخرين أو إساءة الأتمتة أو اتخاذ قرار عالي الأثر عن شخص آخر دون صلاحية قانونية.</p>'],
    ['content','محتواك','<p>تبقى مالكًا لمحتواك، وتمنح BIL إذنًا محدودًا لمعالجته فقط لتقديم وحماية الميزة التي طلبتها. لا ترسل محتوى لا تملك حق استخدامه.</p>'],
    ['subscriptions','الاشتراكات','<p>يُباع الوصول المدفوع عبر Apple App Store أو Google Play، والمتجر هو مصدر السعر والضريبة والفترة والتجديد والإلغاء. راجع <a href="/subscription-terms?lang=ar">شروط الاشتراكات</a>.</p>'],
    ['availability','التوفر والتغيير','<p>قد تختلف الميزات حسب البلد والمنصة والجهاز والخطة والموافقة وتوفر المتجر. قد تتغير الخدمات مع حماية الحقوق المدفوعة التي يفرضها القانون وسياسة المتجر.</p>'],
    ['liability','المسؤولية','<p>يُقدم BIL كما هو ضمن ما يسمح به القانون دون ضمان نتيجة صحية أو توفر بلا انقطاع. لا تستبعد هذه الشروط حقًا لا يمكن استبعاده قانونًا. أنت مسؤول عن قراراتك ونسخ بياناتك المهمة.</p>'],
    ['termination','إنهاء الاستخدام والتواصل',`<p>يمكنك التوقف أو إلغاء الاشتراك أو مسح البيانات أو حذف الحساب. قد يقيد BIL الحساب المخالف جوهريًا مع الحقوق القانونية المناسبة. للاستفسار: <a href="mailto:${SUPPORT_EMAIL}">${SUPPORT_EMAIL}</a>.</p>`],
  ]},
  '/account-deletion': { eyebrow: 'تحكمك', title: 'حذف حساب BIL', intro: 'يمكنك بدء الحذف من داخل BIL أو عبر طلب إلكتروني. حذف التطبيق وحده لا يحذف الحساب السحابي.', sections: [
    ['in-app','الأسرع: من داخل التطبيق','<ol><li>سجل الدخول للحساب المطلوب.</li><li>افتح <b>المزيد ← حذف الحساب</b>.</li><li>راجع النتائج واكتب <b>DELETE</b> ثم أرسل.</li><li>احتفظ برقم مرجع الطلب.</li></ol>'],
    ['web','إذا تعذر فتح التطبيق',`<p>أرسل من بريد الحساب إلى <a href="mailto:${PRIVACY_EMAIL}?subject=BIL%20account%20deletion%20request">${PRIVACY_EMAIL}</a> واكتب أنك تريد حذف حساب BIL. لا ترسل كلمة مرور أو رمز دخول أو إيصالًا كاملًا أو وثيقة هوية أو ملفًا صحيًا.</p>`],
    ['scope','ما الذي يشمله الحذف','<p>بعد التحقق، نحذف أو نزيل هوية الملف والسجلات الصحية المتزامنة ومحادثات الذكاء التي يحتفظ بها BIL والمحتوى المجتمعي المؤهل وتسجيلات الإشعارات والاستحقاقات النشطة. امسح البيانات المحلية من كل جهاز.</p>'],
    ['not-covered','ما لا يملكه BIL','<p>لا يحذف الطلب سجلات HealthKit أو Health Connect أو جهاز أو تطبيق آخر أو بريدك أو سجل شراء Apple/Google. أدر تلك السجلات والأذونات لدى مزودها.</p>'],
    ['retention','التحقق والاحتفاظ والحالة','<p>يُنفذ الحذف فورًا عندما يكون العامل الآمن متاحًا؛ وإلا يحتفظ BIL برقم مرجع الطلب ويعيد محاولة الطلب في قائمة الانتظار خلال 15 دقيقة. يؤكد التطبيق حالة الاكتمال، ويمكن للدعم فحص أي طلب يبقى معلّقًا. قد نحتفظ بالحد الأدنى اللازم للأمان أو الاحتيال أو نزاع الشراء أو القانون ثم نحذفه عند انتهاء الالتزام.</p>'],
    ['subscriptions','ألغِ الفوترة بشكل منفصل','<p>حذف الحساب لا يلغي تلقائيًا اشتراكًا تديره Apple أو Google، لذلك قد تستمر الفوترة بعد حذف حساب BIL. ألغِه أولًا عبر <a href="https://apps.apple.com/account/subscriptions">إدارة اشتراكات Apple</a> أو <a href="https://play.google.com/store/account/subscriptions">إدارة اشتراكات Google Play</a>.</p>'],
  ]},
  '/data-deletion': { eyebrow: 'بياناتك', title: 'حذف البيانات وخيارات الخصوصية', intro: 'اختر الإجراء المناسب: مسح المحلي، فصل المصدر، حذف السحابي، أو حذف الحساب كاملًا.', sections: [
    ['local','البيانات المحلية','<p>استخدم إعدادات BIL واليوميات لحذف السجلات أو امسح بيانات التطبيق من النظام. تتحكم أنت في نسخ نظام التشغيل الاحتياطية.</p>'],
    ['cloud','البيانات السحابية','<p>أوقف المزامنة لمنع رفع جديد، واستخدم أدوات الخصوصية لحذف السجلات المؤهلة. يشمل حذف الحساب البيانات السحابية المرتبطة كما هو موضح في صفحته.</p>'],
    ['health','المنصات والأجهزة الصحية','<p>افصل التكامل من BIL وألغِ الإذن من إعدادات النظام. تبقى السجلات الأصلية عند المزود حتى تحذفها هناك.</p>'],
    ['ai','الذكاء والصوت والصور','<p>أوقف موافقة الذكاء البعيد لمنع طلبات جديدة، واحذف سجل المحادثة المدعوم. لا يبدأ الصوت أو تحليل الصور إلا باختيارك.</p>'],
    ['ads','اختيارات الإعلانات','<p>لا تعرض الخطط المدفوعة إعلانات. إعلانات المجاني عند تفعيلها سياقية وغير مخصصة، ولا تستلم الصحة أو اليوميات أو أسئلة الذكاء أو قياسات الجسم.</p>'],
    ['request','اطلب المساعدة',`<p>راسل <a href="mailto:${PRIVACY_EMAIL}">${PRIVACY_EMAIL}</a> من بريد الحساب وحدد الفئة دون إرفاق بيانات حساسة.</p>`],
  ]},
  '/subscription-terms': { eyebrow: 'التجارة', title: 'شروط الاشتراكات', intro: 'يعرض BIL الخطط والأسعار التي يعيدها متجر Apple أو Google الموثق للمستخدم. شاشة المتجر هي المرجع النهائي.', sections: [
    ['plans','الخطط والتوفر الإقليمي','<p>قد تتوفر Free وBIL Premium وBIL Premium AI Coach وBIL AI Boost. يختلف التوفر حسب البلد واقتصاد المتجر، وقد يتوفر الذكاء بنظام التوكينات بدل اشتراك شامل.</p>'],
    ['billing','الفوترة والتجديد','<p>يعرض المتجر السعر النهائي والعملة والضريبة والفترة والعرض قبل التأكيد. تتجدد الاشتراكات تلقائيًا ما لم تُلغَ وفق مهلة المتجر. لا يخصم BIL من البطاقة مباشرة.</p>'],
    ['ai','حصص الذكاء وBoost','<p>قد تتضمن الخطط حصة أسبوعية وشهرية موضحة. لا يضاف Boost إلا بعد تحقق المتجر والخادم، ولا يُحسب طلب مرفوض أو بلا جواب كإجابة مدفوعة.</p>'],
    ['cancel','الإلغاء والاسترداد','<p>أدر أو ألغِ من Apple أو Google بالحساب نفسه. يوقف الإلغاء التجديد عادة مع بقاء الوصول حتى نهاية الفترة. يخضع الاسترداد للمتجر والقانون.</p>'],
    ['restore','استعادة المشتريات','<p>استخدم «استعادة المشتريات» في صفحة خطط BIL. يتحقق التطبيق من المتجر والخادم ولا يفتح المزايا بإشارة محلية غير موثقة.</p>'],
    ['changes','تغيير السعر أو الخطة','<p>يرسل المتجر الإشعار والموافقة المطلوبة لتغير السعر. لا يختلق BIL خصمًا أو تجربة أو ضريبة أو نجاح شراء لم يوثقه المتجر.</p>'],
    ['support','دعم الفوترة',`<p>للخصم أو الاسترداد ابدأ بالمتجر. لمشكلة الاستحقاق راسل <a href="mailto:${SUPPORT_EMAIL}">${SUPPORT_EMAIL}</a> دون إرسال رمز الإيصال الكامل.</p>`],
  ]},
  '/health-disclaimer': { eyebrow: 'السلامة أولًا', title: 'إخلاء المسؤولية الصحي', intro: 'يدعم BIL العافية العامة وفهم الذات، ولا يستبدل مهنيًا صحيًا مؤهلًا أو خدمة طوارئ.', sections: [
    ['not-medical','ليس جهازًا طبيًا','<p>لا يشخص BIL المرض ولا يعالجه أو يشفيه أو يمنعه ولا يراقبه كجهاز طبي منظم. كلمات «ذكاء الجسم» و«الاستعداد» و«الثقة» تصف ميزات عافية وليست استنتاجًا سريريًا.</p>'],
    ['emergency','ليس للطوارئ','<p>لا تستخدمه للأعراض العاجلة أو جرعات الدواء أو الطوارئ الصحية العاجلة أو الحمل أو اضطرابات الأكل أو قرار يحتاج حكمًا سريريًا. اتصل بخدمة الطوارئ المحلية.</p>'],
    ['estimates','التقديرات وجودة البيانات','<p>قد تكون السعرات والمغذيات والحصص والاتجاهات وإجابات الذكاء وقراءات الجهاز ناقصة أو متأخرة أو خاطئة. راجع المصدر والوحدة والوقت والثقة.</p>'],
    ['devices','أجهزة اللياقة المتصلة','<p>يعرض BIL سجلات اللياقة المدعومة من الهاتف ومنصات اللياقة والساعات والموازين وأجهزة اللياقة المتوافقة عبر Bluetooth بعد الإذن والاتصال فقط. لا يوفر BIL واجهات أجهزة طبية، ولا يضمن دقة الجهاز أو توافقه. اتبع تعليمات الشركة المصنعة.</p>'],
    ['nutrition','التغذية والصيام والتمرين','<p>تختلف الاحتياجات حسب العمر والجسم والحالة الصحية والحمل والدواء والبيئة والتدريب. استشر متخصصًا قبل تقييد شديد أو صيام أو تغير سريع بالوزن.</p>'],
    ['ai','حدود المدرب الذكي','<p>قد يسيء الذكاء فهم اللغة أو السياق. يساعد في التثقيف والتنظيم لكنه ليس طبيبًا ولا ينفذ إجراءً دون موافقتك.</p>'],
    ['professional','متى تطلب مختصًا','<p>اطلب رعاية مؤهلة للأعراض والتشخيص والعلاج والصحة النفسية واضطرابات الأكل أو عند الشك في الأمان. اعرض القياسات الأصلية لا ملخص BIL وحده.</p>'],
  ]},
  '/support': { eyebrow: 'نحن هنا', title: 'الدعم', intro: 'مساعدة للحساب والخصوصية وتسجيل الطعام والاشتراكات والصحة المتصلة والمدرب الذكي وإمكانية الوصول.', sections: [
    ['contact','تواصل مع الدعم',`<p>راسل <a href="mailto:${SUPPORT_EMAIL}">${SUPPORT_EMAIL}</a> واذكر المنصة وإصدار التطبيق واللغة ووصفًا مختصرًا. لا ترسل كلمة مرور أو رمز تحقق أو توكن أو إيصالًا كاملًا أو وثيقة هوية أو تصديرًا صحيًا.</p>`],
    ['account','الحساب والدخول','<p>استخدم استعادة كلمة المرور داخل التطبيق والبريد الموثق نفسه. إذا انتهت صلاحية الرابط اطلب رابطًا جديدًا واستخدم آخر رسالة فقط.</p>'],
    ['purchase','المشتريات والاستعادة','<p>تأكد من حساب Apple أو Google نفسه ثم افتح الخطط واختر «استعادة المشتريات». قد لا يعرض المحاكي أسعارًا لأنه لا يقدم بيانات متجر حقيقية.</p>'],
    ['health','الصحة المتصلة والأجهزة','<p>راجع إذن النظام وBluetooth والتوافق والمصدر الظاهر. لا يدعي BIL اتصال جهاز لم توثقه المنصة.</p>'],
    ['privacy','الخصوصية والتصدير والحذف',`<p>استخدم إعدادات الخصوصية للموافقة والمزامنة والتصدير والحذف. للطلب الموثق راسل <a href="mailto:${PRIVACY_EMAIL}">${PRIVACY_EMAIL}</a>.</p>`],
    ['safety','الأمان وسلامة المجتمع',`<p>بلّغ عن اختراق أو محتوى ضار أو ثغرة إلى <a href="mailto:${ADMIN_EMAIL}">${ADMIN_EMAIL}</a> من دون اختبار حسابات الآخرين أو تضمين بيانات صحية حقيقية.</p>`],
  ]},
  '/community-guidelines': { eyebrow: 'سلامة المجتمع', title: 'إرشادات المجتمع', intro: 'مساحات مجتمع BIL مخصصة لدعم العافية باحترام بين البالغين. توضح هذه القواعد السلوك المقبول والإبلاغ وكيفية الإشراف على محتوى المستخدمين.', sections: [
    ['adults','للبالغين فقط','<p>تطبيق BIL وميزات المجتمع مخصصة لمن يبلغ 18 عامًا أو أكثر. لا تنشئ حسابًا لقاصر، ولا تطلب التواصل مع القاصرين، ولا تنشر محتوى يصور القاصرين أو يستغلهم.</p>'],
    ['respect','الاحترام والسلامة','<p>يُمنع التحرش والتهديد والتنمر والملاحقة والتمييز والانتحال والاستغلال وكشف معلومات الآخرين الخاصة. لا تشجع إيذاء النفس أو اضطرابات الأكل أو التقييد الخطر أو التمرين غير الآمن أو العنف أو النشاط غير القانوني.</p>'],
    ['wellness','العافية وليست علاجًا طبيًا','<p>منشورات المجتمع تجارب شخصية وليست تشخيصًا أو علاجًا. لا تدّعِ علاجًا مضمونًا، ولا تصف دواءً، ولا تسوّق منتجات طبية غير معتمدة، ولا تطلب من شخص تجاهل الرعاية المؤهلة أو خدمات الطوارئ.</p>'],
    ['content','المحتوى الذي يمكنك مشاركته','<p>شارك فقط ما أنشأته أو تملك إذنًا لاستخدامه. يُمنع السبام والاحتيال والترويج المضلل والبرمجيات الضارة والمحتوى الجنسي الصريح والعنف المصور والمواد المحمية دون إذن والسجلات الصحية أو المعرّفات الخاصة بشخص آخر.</p>'],
    ['report','الإبلاغ والحظر والخطر العاجل',`<p>استخدم أدوات الإبلاغ والحظر داخل التطبيق عند توفرها، أو راسل <a href="mailto:${SUPPORT_EMAIL}">${SUPPORT_EMAIL}</a> مع مرجع الحساب أو المنشور وشرح مختصر. لا ترسل كلمات مرور أو رموز تحقق أو تصديرًا صحيًا خامًا. عند وجود خطر فوري اتصل بخدمات الطوارئ المحلية؛ BIL ليس قناة طوارئ.</p>`],
    ['moderation','الإشراف والتنفيذ','<p>قد يحد BIL من الظهور أو يحذف المحتوى أو يعلّق الميزات أو يقيّد الحسابات عند الحاجة المعقولة لتطبيق القواعد أو حماية المستخدمين أو الامتثال للقانون أو التحقيق في الإساءة. نراعي السياق والخطورة والتكرار والمخاطر الموثوقة، ويمكن طلب مراجعة عبر الدعم عند الاقتضاء.</p>'],
    ['privacy','الخصوصية والتواصل',`<p>قد يظهر محتوى المجتمع للجمهور الذي تحدده في التطبيق. تجنب نشر ما يحدد هويتك أو موقعك أو هوية شخص آخر. لطلبات الخصوصية أو الحذف راسل <a href="mailto:${PRIVACY_EMAIL}">${PRIVACY_EMAIL}</a>.</p>`],
  ]},
  '/contact': { eyebrow: 'تواصل', title: 'تواصل مع BIL Health', intro: 'استخدم القناة المناسبة ليصل طلبك إلى مسار المراجعة الصحيح.', sections: [
    ['support','دعم المنتج',`<p><a href="mailto:${SUPPORT_EMAIL}">${SUPPORT_EMAIL}</a> — الدخول والتسجيل والمشتريات والصحة المتصلة والمدرب وإمكانية الوصول.</p>`],
    ['privacy','الخصوصية والحذف',`<p><a href="mailto:${PRIVACY_EMAIL}">${PRIVACY_EMAIL}</a> — الوصول والتصحيح والتصدير والموافقة والاعتراض وحذف البيانات والحساب.</p>`],
    ['admin','الإدارة والأمان',`<p><a href="mailto:${ADMIN_EMAIL}">${ADMIN_EMAIL}</a> — الإدارة الرسمية وبلاغات الأمان المسؤولة. استخدم Gmail إذا تعذر وصول اسم النطاق.</p>`],
    ['safe','أرسل بأمان','<p>اذكر الإصدار والمنصة واللغة ووصفًا موجزًا. لا ترسل كلمات مرور أو أكواد أو مفاتيح أو إيصالات كاملة أو هويات أو ملفات صحية كاملة.</p>'],
  ]},
};

function currentLanguage() {
  const requested = new URLSearchParams(location.search).get('lang');
  if (requested === 'ar' || requested === 'en') return requested;
  return localStorage.getItem('bil-site-language') === 'ar' ? 'ar' : 'en';
}

function pathKey() {
  const clean = location.pathname.replace(/\/+$/, '') || '/';
  if (clean === '/delete-account') return '/account-deletion';
  return clean;
}

function localizedHref(path, lang) {
  return lang === 'ar' ? `${path}?lang=ar` : path;
}

function setShellLanguage(lang) {
  const copy = ui[lang];
  document.documentElement.lang = lang;
  document.documentElement.dir = lang === 'ar' ? 'rtl' : 'ltr';
  document.querySelector('[data-nav="home"]').textContent = copy.product;
  document.querySelector('[data-nav="privacy"]').textContent = copy.privacy;
  document.querySelector('[data-nav="support"]').textContent = copy.support;
  document.querySelector('[data-nav="health-disclaimer"]').textContent = copy.health;
  document.querySelector('.header-cta').textContent = copy.supportCta;
  document.getElementById('language-toggle').textContent = copy.language;
  document.querySelectorAll('header a, footer a').forEach((link) => {
    const url = new URL(link.href, location.origin);
    if (url.origin === location.origin) link.href = localizedHref(url.pathname, lang);
  });
}

function renderHome(lang) {
  const c = home[lang];
  const featureCards = c.features.map(([icon, title, body]) => `<article class="feature-card"><span class="feature-icon" aria-hidden="true">${icon}</span><h3>${title}</h3><p>${body}</p></article>`).join('');
  const signals = c.signals.map(([label, value]) => `<div class="signal"><span>${label}</span><strong>${value}</strong></div>`).join('');
  const docCards = docs.map((d) => `<a class="legal-link" href="${localizedHref(d[0], lang)}"><strong>${lang === 'ar' ? d[3] : d[1]}</strong><span>${lang === 'ar' ? d[4] : d[2]}</span></a>`).join('');
  return `<section class="hero">
    <div class="hero-copy"><span class="eyebrow">${c.eyebrow}</span><h1>${c.title}</h1><p class="hero-lead">${c.lead}</p>
      <div class="hero-actions"><a class="button primary" href="${localizedHref('/privacy', lang)}">${c.primary} <span aria-hidden="true">→</span></a><a class="button secondary" href="${localizedHref('/health-disclaimer', lang)}">${c.secondary}</a></div>
      <div class="hero-proof">${c.proofs.map((p) => `<span>${p}</span>`).join('')}</div>
    </div>
    <div class="intelligence-card" aria-label="BIL product preview"><div class="card-top"><strong>${c.cardTitle}</strong><span class="live-pill">${c.live}</span></div>
      <div class="orb-wrap"><div class="orb"></div><div class="orb-copy"><strong>${c.score}</strong><small>${c.scoreLabel}</small></div></div>
      <div class="signal-grid">${signals}</div><div class="insight-strip"><span class="spark">✦</span><span>${c.insight}</span></div>
    </div>
  </section>
  <section class="section"><div class="section-heading"><span class="eyebrow">${c.featuresEyebrow}</span><h2>${c.featuresTitle}</h2><p>${c.featuresLead}</p></div><div class="feature-grid">${featureCards}</div></section>
  <section class="section"><div class="trust-band"><h2>${c.trustTitle}</h2><div class="trust-list">${c.trust.map((x) => `<div class="trust-item"><b>✓</b><span>${x}</span></div>`).join('')}</div></div></section>
  <section class="section"><div class="section-heading"><span class="eyebrow">${c.docsEyebrow}</span><h2>${c.docsTitle}</h2></div><div class="legal-links-grid">${docCards}</div></section>`;
}

function renderDocument(page, lang) {
  const copy = ui[lang];
  const toc = page.sections.map(([id, title]) => `<a href="#${id}">${title}</a>`).join('');
  const content = page.sections.map(([id, title, body], index) => `<section class="legal-section ${index === 0 ? 'callout' : ''}" id="${id}"><h2>${title}</h2>${body}</section>`).join('');
  return `<div class="page-shell"><header class="page-hero"><span class="eyebrow">${page.eyebrow}</span><h1>${page.title}</h1><p>${page.intro}</p><div class="document-meta"><span>${copy.official}</span><span>${copy.updated}: ${copy.date}</span><span>bilhealth.com</span></div></header><div class="document-layout"><aside class="toc" aria-label="${copy.contents}"><strong>${copy.contents}</strong>${toc}</aside><article class="document">${content}</article></div></div>`;
}

async function renderPasswordReset(lang) {
  const ar = lang === 'ar';
  const app = document.getElementById('app');
  app.innerHTML = `<section class="reset-card"><span class="eyebrow">BIL SECURITY</span><h1>${ar ? 'إعادة تعيين كلمة المرور' : 'Reset your password'}</h1><p class="reset-status" id="reset-status">${ar ? 'جارٍ التحقق من الرابط الآمن…' : 'Checking your secure reset link…'}</p><div id="reset-form" hidden><label for="new-password">${ar ? 'كلمة المرور الجديدة' : 'New password'}</label><input id="new-password" type="password" minlength="8" autocomplete="new-password"><label for="confirm-password">${ar ? 'تأكيد كلمة المرور' : 'Confirm password'}</label><input id="confirm-password" type="password" minlength="8" autocomplete="new-password"><button class="button primary" id="reset-button" type="button">${ar ? 'تحديث كلمة المرور' : 'Update password'}</button></div></section>`;
  const tokenHash = new URLSearchParams(location.search).get('token_hash');
  const status = document.getElementById('reset-status');
  if (!tokenHash) { status.textContent = ar ? 'الرابط غير مكتمل. اطلب رسالة إعادة تعيين جديدة من BIL.' : 'This link is incomplete. Request a new password-reset email from BIL.'; return; }
  try {
    const verify = await fetch(`${SUPABASE_URL}/auth/v1/verify`, { method: 'POST', headers: { 'Content-Type': 'application/json', apikey: SUPABASE_KEY }, body: JSON.stringify({ token_hash: tokenHash, type: 'recovery' }) });
    const data = await verify.json();
    if (!verify.ok || !data.access_token) throw new Error('invalid');
    status.textContent = ar ? 'تم التحقق. اختر كلمة مرور جديدة.' : 'Link verified. Choose a new password.';
    const form = document.getElementById('reset-form'); form.hidden = false;
    document.getElementById('reset-button').addEventListener('click', async () => {
      const first = document.getElementById('new-password').value;
      const second = document.getElementById('confirm-password').value;
      if (first.length < 8) { status.textContent = ar ? 'يجب أن تتكون كلمة المرور من 8 أحرف على الأقل.' : 'Password must be at least 8 characters.'; return; }
      if (first !== second) { status.textContent = ar ? 'كلمتا المرور غير متطابقتين.' : 'Passwords do not match.'; return; }
      status.textContent = ar ? 'جارٍ التحديث…' : 'Updating password…';
      const update = await fetch(`${SUPABASE_URL}/auth/v1/user`, { method: 'PUT', headers: { 'Content-Type': 'application/json', apikey: SUPABASE_KEY, Authorization: `Bearer ${data.access_token}` }, body: JSON.stringify({ password: first }) });
      if (!update.ok) { status.textContent = ar ? 'تعذر التحديث. اطلب رابطًا جديدًا وحاول مرة أخرى.' : 'Unable to update. Request a new link and try again.'; return; }
      form.hidden = true; status.textContent = ar ? 'تم تغيير كلمة المرور. عد إلى BIL وسجّل الدخول.' : 'Password changed. Return to BIL and sign in.';
    });
  } catch (_) { status.textContent = ar ? 'الرابط منتهي أو مستخدم أو غير صالح. اطلب رابطًا جديدًا.' : 'This link is expired, used, or invalid. Request a new link.'; }
}

function updateDocumentMetadata(path, lang, page) {
  const title = page ? `${page.title} — BIL Health` : (lang === 'ar' ? 'BIL Health — افهم جسمك' : 'BIL Health — Understand your body');
  document.title = title;
  document.querySelector('meta[name="description"]').content = page?.intro || home[lang].lead;
  document.querySelector('link[rel="canonical"]').href = `https://www.bilhealth.com${path === '/' ? '/' : path}`;
  document.querySelector('meta[property="og:title"]').content = title;
  document.querySelector('meta[property="og:description"]').content = page?.intro || home[lang].lead;
  document.querySelector('meta[property="og:url"]').content = `https://www.bilhealth.com${path === '/' ? '/' : path}`;
}

async function render() {
  const lang = currentLanguage();
  const path = pathKey();
  setShellLanguage(lang);
  document.querySelectorAll('[data-nav]').forEach((a) => a.classList.toggle('active', a.getAttribute('data-nav') === (path === '/' ? 'home' : path.slice(1))));
  if (path === '/auth/reset-password') { updateDocumentMetadata(path, lang, { title: lang === 'ar' ? 'إعادة تعيين كلمة المرور' : 'Reset password', intro: 'Secure BIL account recovery.' }); await renderPasswordReset(lang); return; }
  const page = legal[lang][path];
  document.getElementById('app').innerHTML = path === '/' ? renderHome(lang) : page ? renderDocument(page, lang) : renderDocument({ eyebrow: '404', title: lang === 'ar' ? 'الصفحة غير موجودة' : 'Page not found', intro: lang === 'ar' ? 'لم نجد الصفحة المطلوبة. عد إلى موقع BIL Health.' : 'We could not find that page. Return to BIL Health.', sections: [['home', lang === 'ar' ? 'العودة' : 'Go home', `<p><a href="${localizedHref('/', lang)}">${lang === 'ar' ? 'الصفحة الرئيسية' : 'BIL Health home'}</a></p>`]] }, lang);
  updateDocumentMetadata(path, lang, page);
}

document.getElementById('language-toggle').addEventListener('click', () => {
  const next = currentLanguage() === 'ar' ? 'en' : 'ar';
  localStorage.setItem('bil-site-language', next);
  const url = new URL(location.href); if (next === 'ar') url.searchParams.set('lang', 'ar'); else url.searchParams.delete('lang'); location.href = url.toString();
});

render();
