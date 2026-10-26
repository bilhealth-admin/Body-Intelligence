# Physical Build38 purchase/restore observations

Scope: installed signed iOS **1.0.0 (38)**, dedicated new QA account and an actual Apple Sandbox monthly purchase. This is not acceptance of Build39. Private screenshots remain outside Git; the independent reviewer retains 48 initial screenshot hashes and continues the remaining device checks. No store console, prices, subscription settings, customer rights or HealthKit data were changed by this investigation.

## Observed purchase

The user authenticated Apple on the device. Native Apple success was captured at **2026-10-25 23:17:44 Cairo**; BIL still displayed its confirmation-unavailable warning and spinner in a later observation at 23:19:25. The first captured BIL **Purchase verified / Current plan** was at 23:20:25, and **More → Active** at 23:21:35. These are screenshot observation times, not exact transaction/callback timestamps. The spinner disappeared and the warning changed to verified. No second purchase was made.

Read-only Production request logs for the corresponding recent monthly QA account show the first two `verify-store-purchase` HTTP200 responses at **20:19:29 and 20:19:35 UTC**, taking **1,286 and 1,119 milliseconds** in the function. Consequently, the large observed gap after Apple success is predominantly before the first verification request reaches the server. These logs do not establish whether the delay was inside StoreKit, native callbacks, local integrity work, scheduling or another pre-request step. HTTP200 alone was not used to certify delivery; the actual verified/Active screens supply that separate evidence.

## Restore and expiry boundary

The user later entered the Sandbox password in the actual Apple restore prompt. The user reported a brief initial failure message and a long spinner. Subsequent reviewer screenshots showed the spinner gone and **Free / Explore Premium**, so restoration of an active subscription was not marked successful.

Read-only canonical subscription inspection at **21:23:19 UTC** showed a Sandbox monthly lifecycle of **expired**, `auto_renews=false`, latest period **20:49:31–20:52:31 UTC**, with the entitlement mirror also inactive at the same expiry and server verification at **21:13:11 UTC**. The inspected account had been created that evening at 18:57:34 UTC. The observed Free state is consistent with the recorded expiry; restore cannot be certified as an active-access restoration from this expired fixture.

Eight verification responses during **21:12:46–21:13:11 UTC** were HTTP200, each taking **1.006–1.350 seconds**. This distinguishes sequential historical receipt work from a single cloud request running for minutes. It does not by itself explain the initial user-visible error or prove there is no client defect.

Apple documents accelerated and capped Sandbox renewals and allows a Sandbox Apple Account when testing through TestFlight: [subscription testing](https://developer.apple.com/documentation/storekit/testing-an-auto-renewable-subscription), [TestFlight purchase testing](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testing-subscriptions-and-in-app-purchases-in-testflight). The actual stored three-minute period above, rather than a guessed default renewal rate, is the evidence used here. No renewal setting was changed.

## Other findings and source verification

- BIL displayed USD2.49 while the native Sandbox sheet displayed EGP99.99 for Monthly. Both were observed repeatedly. Source uses StoreKit product price/currency and fresh-checkout validation; a Sandbox/storefront difference is plausible but not proven. Prices and the protected payment CTA were not edited.
- The native purchase sheet showed a placeholder icon. No store asset was changed.
- The first dismissal appeared to change the selected plan; a later dismissal preserved Monthly. Exclusive-control reproduction remains necessary before calling this a confirmed bug.
- Light onboarding and Apps & Devices showed white system status text over a light surface. Actual rendered annotation tests reproduced both light-mode failures. BIL39 now specifies status contrast for the transparent, page-scoped pearl app bar and onboarding scaffold. All four Light/Dark layer cases passed without altering Dashboard, the main navigation, status copy or payment controls.

Remaining physical gates: active-subscription restore, renewal cancellation when system authentication permits it, Watch/Health read verification, remaining feature/negative exploration and installation of the actual signed Build39. No final store-readiness or rejection prediction is claimed.
