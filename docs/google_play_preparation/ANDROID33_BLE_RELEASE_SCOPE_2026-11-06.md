# Android 33 connected-device release scope — 6 November 2026

## Release decision / قرار الإصدار

Android Bluetooth linking is withheld from this release until a compatible
physical fitness device has demonstrated discovery, connection, measurement
receipt and disconnect/reconnect. The existing implementation supports the
standard weight-scale, body-composition and heart-rate GATT profiles; source
inspection and mocked tests do not prove an actual hardware reading.

أُغلق ربط Bluetooth الاختياري في Android لهذا الإصدار بتفويض المالك، لعدم وجود
إثبات قراءة جهاز لياقة فعلي. هذا قرار جاهزية للإصدار، وليس شرطًا إضافيًا ورد من
Google، ولا حكمًا بأن شفرة GATT غير منفذة. لم تُحذف البيانات المحلية السابقة.

The Android manifest omits Bluetooth and its legacy scan-location permissions.
Optional hardware declarations remain `required=false` for device compatibility;
they do not grant access or re-enable the feature.
The Android activity does not register the BLE channel or request permission.
The shared release policy blocks direct Android bridge/controller operations,
saved-device restoration and the Android scan/connect, search, compatibility
and capability surfaces. iOS retains its existing BLE journey and native code.
The global product runtime registers no Android fitness BLE provider, so its
health synchronization cannot fail by attempting the withheld BLE channel.

Health Connect remains a separate optional, foreground, read-only connection:
steps, distance and active calories only. No health write, background-health,
location or Bluetooth permission is needed for that Android journey. Manual
logging remains available when optional health access is declined.

يبقى Health Connect اختياريًا بصلاحيات قراءة الخطوات والمسافة والسعرات النشطة
فقط. لا يطلب هذا القرار كتابة بيانات صحية أو وصولًا في الخلفية. لا يتطلب هذا
الإصدار شراء جهاز Bluetooth لإتمام تجربة المراجع.

## Google conditional acceptance and reviewer instructions

The 4 November 2026 decision for case `5-0719000041209`, package
`com.bilhealth.bodyintelligencelog`, conditionally accepts the appeal and asks
for full review access behind the subscription paywall without purchase.
It is not a reinstatement or release approval.

Use one consistently verified dedicated Google reviewer identity in the secure
Play Console username/password fields. No credentials belong in this document.
The current Console fields have not been read back; the official browser tool
failed its Trusted RPC dependency-path check before any tab action.

English instruction draft: **Sign in → Store reviewer access → enter the
supplied email and password → Sign in**. This visible route uses ordinary
server password authentication. The regular email route uses a one-time code.
Let account verification complete. A verified active Premium AI Coach account
should show its current plan as Active; Continue returns to the app without
repurchasing that same subscription. If verification is unavailable, Retry
must resolve it; a purchase is not a remedy for an unverified account.

تعليمات الدخول: **تسجيل الدخول ← دخول مراجع المتجر ← البريد وكلمة المرور
المقدّمان في حقول Console الآمنة ← تسجيل الدخول**. هذا مسار مصادقة عادي، وليس
منح صلاحيات مخفيًا. يجب فتح الأهداف والتحليلات والتخطيط والمدرب بنفس الحساب
دون شراء. لا تُستنتج النتيجة من المنحة وحدها.

The existing account's previous normal login and own-row RLS reads passed on
5 November. Its previously observed access expires on 5 October 2027; included
AI allowance is 2,500 weekly with a 10,000 monthly cap plus a separate 2,500
credit ledger. Do not describe this finite snapshot as unlimited AI or lifetime
access. Maintain the reusable credentials and enough access throughout review.
No account, credit, grant, consent or Production setting was changed here.

Remote AI remains optional. The reviewer must read the Google Gemini disclosure
and choose whether to consent. Denial must keep remote transmission blocked.
A minimal general Coach test requires a fresh conversation, all optional
context categories off, no image or voice, and verified runtime scope before
sending. No new login or Gemini request was repeated during this source change.

Historical October drafts remain historical. This addendum supersedes their
Android Bluetooth navigation for the intended new artifact. Before any Google
submission, verify the exact signed AAB/merged manifest, reusable login, premium
routes and real Coach response on stable Android. The earlier APK33 emulator
attempt was blocked by Android SystemUI/service ANRs: **no Native PASS**.
There was no Play Console save, Send for review, email, commit or push here.

## Current official references

- [Sensitive permissions and Health Connect scope](https://support.google.com/googleplay/android-developer/answer/16558241?hl=en)
- [Health apps and unused permissions](https://support.google.com/googleplay/android-developer/answer/16679511?hl=en)
- [Android Bluetooth runtime permissions](https://developer.android.com/develop/connectivity/bluetooth/bt-permissions)
- [Reusable English sign-in details and free review access](https://support.google.com/googleplay/android-developer/answer/15748846?hl=en)
- [Public BIL privacy policy](https://www.bilhealth.com/privacy)

These pages were reviewed on 6 November 2026. A source audit and local tests
establish their stated boundaries only; they do not guarantee Google approval.
