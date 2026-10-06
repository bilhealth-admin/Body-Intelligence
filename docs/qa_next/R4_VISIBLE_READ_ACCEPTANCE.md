# R4: automatic visible Community activity receipts

Base under review: `8f42b54027580dcaab8a0e702c5a174e8145d15a`.
The preceding run `37420897825` passed its focused, selected four-shard regression,
SQL, and Community capture jobs. This is not device or reference-parity acceptance.

R4 replaces the missing automatic-read behavior, not the approved visual design.
A row must remain at least half visible in the foreground for 600 ms. Loading,
caching, background delivery, covered routes, and off-screen rows do not qualify.
Failures remain retryable without a network retry loop or fake zero badge.

The existing authenticated mark-activity RPC is retained. Actual readback uses the
original pagination windows and merges only known rows; it does not drop older
loaded pages or reset the scroll position. The shared badge is refreshed from its
authoritative controller. Private-message reads, friend acceptance, moderation,
reward authority, subscriptions, production schema and release builds are outside
this change. Account changes invalidate old responses and receipt work.

Acceptance requires the real Flutter scope, page integration and older regression
suites to run on the same committed source. A fixture is not APNs/FCM or phone E2E.
No claim of complete Coach/Community implementation or pixel parity is made here.
