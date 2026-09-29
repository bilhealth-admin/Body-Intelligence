# Community / Android 30 / iOS 33 preparation

Base application source: `9f439cae97d72b784880a1b1ac4ef1d33ede30c1`.

## Functional changes
- Authoritative own-account message and incoming-request counts; no 100-preview cap.
- Shared in-app badges across More (compact and wide), Community, actions, Messages and requests.
- Exact visible incoming-message acknowledgements only while the chat is active. The old RPC remains compatible with installed clients.
- New Messages entry in Community actions; one canonical connections destination.
- Preserve message subject envelopes, remove duplicate sender names, show time and unread styling, maintain natural content direction in RTL rows.
- Shared reading scale, restrained post cards, real compose prompt and optional emoji insertion. No fabricated social activity.
- Android Facebook uses existing Supabase browser OAuth; iOS Facebook and Google remain native.
- Both final build commands enable runtime push definitions. Android 13+ explicitly requests notification permission before token registration.
- APNs/FCM payloads carry optional authoritative badge counts; old gateway payloads remain valid. iOS reconciles the badge when active. Android launcher presentation remains OS-dependent.
- QR visibility fix is recorded from the already-deployed migration, not reimplemented or reverted.

## Safety and release boundary
No store uploads; no production secrets bundled; no permission weakening of private profiles or messages. The counts API accepts no arbitrary owner. Only the internal service role can request another owner's provider badge count. No message is marked read by opening More or Community.

The two release manifests remain draft (`NO/NO`) until the exact final commit and manifest digests are bound and approved. The old release source bindings must not be reused. A passing source/test check is not a signed build or evidence of delivery on a physical phone.

## Review basis
Flutter accessibility guidance, Material Badge semantics/RTL, Apple UserNotifications badge reconciliation, and official FCM notification-count fields. Keep Dynamic Type and theme font families; do not replace them with fixed text-scale overrides.

## Remaining physical acceptance
Open a chat from a push while terminated/backgrounded; re-login Facebook on Android twice; grant/deny notification permission; receive a message while reading old history; read on another signed-in device; check VoiceOver/TalkBack, Arabic/Latin mixed rows and large type. No such device runs are claimed by the CI workflow.
